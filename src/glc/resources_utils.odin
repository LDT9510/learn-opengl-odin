package glc

import res "main:.generated/resources"

import "core:log"
import "core:reflect"

// ============================== SHADERS ==============================
@(private = "file")
g_shader_program_registry: [res.Shaders_Program_Index]Resource(Shader_Program)

shader_program_resource :: proc(index: res.Shaders_Program_Index) -> Shader_Program {
	if !g_shader_program_registry[index].is_loaded {
		program_code := res.SHADERS_PROGRAM_LOCATION[index]
		log.debugf("Loading Shader Program: '%s'", program_code.name)
		vertex := program_code.vertex_name
		fragment := program_code.fragment_name
		geometry: Maybe(string)
		if program_code.geometry_name != nil {
			geometry = program_code.geometry_name.?
		}

		program, ok := shader_create_program(vertex, fragment, geometry)
		if !ok {
			log.errorf("Cannot load Shader Program: '%s'", program_code.name)
		}

		// set UBOs
		shader_ubo_bind(program, "Matrices", 0)

		program.name = program_code.name
		g_shader_program_registry[index].value = program
		g_shader_program_registry[index].is_loaded = true
	}

	return g_shader_program_registry[index].value
}

shader_reload_all_program_resources :: proc() {
	for &shader_res in g_shader_program_registry {
		if shader_res.is_loaded {
			old := shader_res.value
			v, f, g := old.vertex_name, old.fragment_name, old.geometry_name
			program, ok := shader_create_program(v, f, g)
			if ok {
				// set UBOs
				shader_ubo_bind(program, "Matrices", 0)

				program.name = old.name
				shader_delete_program(old)
				shader_res.value = program
				log.infof("Shader program '%s' reloaded sucessfully.", program.name)
			} else {
				log.errorf("Cannot reload Shader Program: %s", program.name)
			}
		}
	}
}

destroy_all_shaders_resources :: proc() {
	for resource in g_shader_program_registry {
		shader_delete_program(resource.value)
	}
}

// ============================== TEXTURES ==============================
@(private = "file")
g_texture_registry: [res.Textures_Index]Resource(Texture_Id)

texture_resource :: proc(index: res.Textures_Index) -> Texture_Id {

	if !g_texture_registry[index].is_loaded {
		location := res.TEXTURES_LOCATION[index]
		log.debugf("Loading image: '%s'", location.name)
		resource, ok := texture_load(location.name, location.flip, location.transparent, location.gamma_corrected)
		if !ok {
			log.errorf("Cannot load image: %s", location.name)
		} else {
			g_texture_registry[index].value = resource
			g_texture_registry[index].is_loaded = true
		}
	}

	return g_texture_registry[index].value
}

destroy_all_textures_resources :: proc() {
	for resource in g_texture_registry {
		texture_destroy(resource.value)
	}
}

// ============================== MODELS ==============================
@(private = "file")
g_model_registry: [res.Models_Index]Resource(Model)

model_resource :: proc(index: res.Models_Index) -> Model {

	loader :: proc(location: string) -> (Model, bool) {
		return model_load(location)
	}

	return resource_indexer("3D model", index, loader, res.MODELS_LOCATION, &g_model_registry)
}

destroy_all_models_resources :: proc() {
	for &resource in g_model_registry {
		model_delete(&resource.value)
	}

	model_unload_loaded_textures_path()
}

// ============================== CUBEMAPS ==============================
@(private = "file")
g_cubemap_registry: [res.Cubemaps_Index]Resource(Cubemap)

cubemap_resource :: proc(index: res.Cubemaps_Index) -> Cubemap {
	loader :: proc(location: string) -> (Cubemap, bool) {
		// assume in sRGB
		return cubemap_load(location, true)
	}

	return resource_indexer(
		"Skybox (cubemap)",
		index,
		loader,
		res.CUBEMAPS_LOCATION,
		&g_cubemap_registry,
	)
}

destroy_all_cubemaps_resources :: proc() {
	for &resource in g_cubemap_registry {
		cubemap_destroy(&resource.value)
	}
}


// ============================== PRIMITIVES ==============================
// primitives take advantage of the ones defined in `primitives.odin`
Primitive_Resource_Index :: Primitive_Type

@(private = "file")
s_primitive_registry: [Primitive_Resource_Index]Resource(Primitive)

primitive_resource :: proc(index: Primitive_Resource_Index) -> Primitive {
	if !s_primitive_registry[index].is_loaded {
		name := reflect.enum_name_from_value(index) or_else panic("Bad reflect")
		log.debugf("Loading Primitive: '%s'", name)

		s_primitive_registry[index].value = primitive_create(index)
		s_primitive_registry[index].is_loaded = true
	}

	return s_primitive_registry[index].value
}

destroy_all_primitives_resources :: proc() {
	for &resource in s_primitive_registry {
		primitive_destroy(&resource.value)
	}
}

// ============================== HELPERS ==============================
destroy_all :: proc() {
	destroy_all_cubemaps_resources()
	destroy_all_primitives_resources()
	destroy_all_shaders_resources()
	destroy_all_textures_resources()
	destroy_all_models_resources()
	destroy_all_post_process_effects_resources()
}

@(private = "file")
resource_indexer :: proc(
	type_name: string,
	index: $TIndex,
	loader: proc(_: string) -> ($TReturn, bool),
	location: $TLocation,
	registry: ^[TIndex]Resource(TReturn),
) -> TReturn {
	if !registry[index].is_loaded {
		location := location[index]
		log.debugf("Loading %s: '%s'", type_name, location)
		resource, ok := loader(location)
		if !ok {
			log.errorf("Cannot load %s: %s", type_name, location)
		} else {
			registry[index].value = resource
			registry[index].is_loaded = true
		}
	}

	return registry[index].value
}


Resource :: struct($T: typeid) {
	value:     T,
	is_loaded: bool,
}
