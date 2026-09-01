package glc

import "core:log"
import "core:reflect"

// ============================== SHADERS ==============================
Vert_Shader_Code_Resource_index :: enum {
	Pos_Norm_Tex,
	Pos_Norm_Tex_Inst,
	Cubemap,
	Points,
	Normals,
	// used by post process effects only
	// Quad,
}
@(rodata)
VERTEX_CODE_LOCATION := [Vert_Shader_Code_Resource_index]string {
	.Pos_Norm_Tex      = "pos_norm_tex",
	.Pos_Norm_Tex_Inst = "pos_norm_tex_instanced",
	.Cubemap           = "cubemap",
	.Points            = "points",
	.Normals           = "normals",
	// used by post process effects only
	// .Quad         = "quad",
}

Frag_Shader_Code_Resource_Index :: enum {
	Light_Cube,
	UV_Map,
	UV_Map2,
	Phong,
	Reflective,
	Refractive,
	Skybox,
	Outline,
	Magenta,
	Depth,
	Green,
	Color,
	Yellow,
	Win_Rel,
}
@(rodata)
FRAGMENT_CODE_LOCATION := [Frag_Shader_Code_Resource_Index]string {
	.Light_Cube = "light_cube",
	.UV_Map     = "uv_map",
	.UV_Map2    = "uv_map2",
	.Phong      = "phong",
	.Reflective = "reflective",
	.Refractive = "refractive",
	.Skybox     = "skybox",
	.Outline    = "colored_outline",
	.Win_Rel    = "window_relative_color",
	.Magenta    = "magenta",
	.Depth      = "depth",
	.Green      = "green",
	.Yellow     = "yellow",
	.Color      = "color",
}

Geom_Shader_Code_Resource_Index :: enum {
	Basic,
	Explode,
	Normals,
}
@(rodata)
GEOMETRY_CODE_LOCATION := [Geom_Shader_Code_Resource_Index]string {
	.Basic   = "basic",
	.Explode = "explode",
	.Normals = "normals",
}

Shader_Program_Code :: struct {
	name:         string,
	vertex_idx:   Vert_Shader_Code_Resource_index,
	fragment_idx: Frag_Shader_Code_Resource_Index,
	geometry_idx: Maybe(Geom_Shader_Code_Resource_Index),
}
Shader_Program_Resource_index :: enum {
	Simple_Texture,
	Reflection,
	Refraction,
	Skybox,
	Magenta,
	Outline,
	Green,
	Depth,
	Win_Rel,
	Geom_Demo,
	Exploding,
	Normals,
	Instancing,
}

@(private = "file")
g_shader_program_registry: [Shader_Program_Resource_index]Resource(Shader_Program)

shader_program_resource :: proc(index: Shader_Program_Resource_index) -> Shader_Program {
	@(static, rodata)
	PROGRAM_CODE := [Shader_Program_Resource_index]Shader_Program_Code {
		.Simple_Texture = {"simple_texture", .Pos_Norm_Tex, .UV_Map, nil},
		.Reflection     = {"reflection", .Pos_Norm_Tex, .Reflective, nil},
		.Refraction     = {"refraction", .Pos_Norm_Tex, .Refractive, nil},
		.Skybox         = {"cubemap", .Cubemap, .Skybox, nil},
		.Magenta        = {"magenta", .Pos_Norm_Tex, .Magenta, nil},
		.Win_Rel        = {"win_rel", .Pos_Norm_Tex, .Win_Rel, nil},
		.Green          = {"green", .Pos_Norm_Tex, .Green, nil},
		.Outline        = {"outline", .Pos_Norm_Tex, .Outline, nil},
		.Depth          = {"depth", .Pos_Norm_Tex, .Depth, nil},
		.Geom_Demo      = {"geom_demo", .Points, .Color, .Basic},
		.Exploding      = {"exploding", .Pos_Norm_Tex, .UV_Map2, .Explode},
		.Normals        = {"normal", .Normals, .Yellow, .Normals},
		.Instancing     = {"instancing", .Pos_Norm_Tex_Inst, .UV_Map, nil},
	}

	if !g_shader_program_registry[index].is_loaded {
		program_code := PROGRAM_CODE[index]
		log.debugf("Loading Shader Program: '%s'", program_code.name)
		vertex := VERTEX_CODE_LOCATION[program_code.vertex_idx]
		fragment := FRAGMENT_CODE_LOCATION[program_code.fragment_idx]
		geometry: Maybe(string)
		if program_code.geometry_idx != nil {
			geometry = GEOMETRY_CODE_LOCATION[program_code.geometry_idx.?]
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
Texture_Resource_Index :: enum {
	Container,
	Create_Diffuse,
	Crate_Specular,
	Grass,
	Marble,
	Metal,
	Transparent_Window,
}

Texture_Resource_Params :: struct {
	name:        string,
	flip:        bool,
	transparent: bool,
}

@(rodata)
TEXTURES_RES_LOCATION := [Texture_Resource_Index]Texture_Resource_Params {
	.Container = {name = "container.jpg"},
	.Create_Diffuse = {name = "crate_diffuse.png"},
	.Crate_Specular = {name = "crate_specular.png"},
	.Grass = {"grass.png", true, true},
	.Marble = {name = "marble.jpg"},
	.Metal = {name = "metal.png"},
	.Transparent_Window = {name = "blending_transparent_window.png", transparent = true},
}

@(private = "file")
g_texture_registry: [Texture_Resource_Index]Resource(Texture_Id)
texture_resource :: proc(index: Texture_Resource_Index) -> Texture_Id {

	if !g_texture_registry[index].is_loaded {
		location := TEXTURES_RES_LOCATION[index]
		log.debugf("Loading image: '%s'", location.name)
		resource, ok := texture_load(location.name, location.flip, location.transparent)
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
Model_Resource_Index :: enum {
	Backpack,
}

@(rodata)
MODEL_RES_LOCATION := [Model_Resource_Index]string {
	.Backpack = "backpack",
}

@(private = "file")
g_model_registry: [Model_Resource_Index]Resource(Model)

model_resource :: proc(index: Model_Resource_Index) -> Model {

	loader :: proc(location: string) -> (Model, bool) {
		return model_load(location)
	}

	return resource_indexer("3D model", index, loader, MODEL_RES_LOCATION, &g_model_registry)
}

destroy_all_models_resources :: proc() {
	for &resource in g_model_registry {
		model_delete(&resource.value)
	}

	model_unload_loaded_textures_path()
}

// ============================== CUBEMAPS ==============================
Cubemap_Resource_Index :: enum {
	Sky,
}

@(rodata)
CUBEMAP_RES_LOCATION := [Cubemap_Resource_Index]string {
	.Sky = "sky",
}

@(private = "file")
g_cubemap_registry: [Cubemap_Resource_Index]Resource(Cubemap)

cubemap_resource :: proc(index: Cubemap_Resource_Index) -> Cubemap {
	loader :: proc(location: string) -> (Cubemap, bool) {
		return cubemap_load(location)
	}

	return resource_indexer(
		"Skybox (cubemap)",
		index,
		loader,
		CUBEMAP_RES_LOCATION,
		&g_cubemap_registry,
	)
}

destroy_all_cubemaps_resources :: proc() {
	for &resource in g_cubemap_registry {
		cubemap_destroy(&resource.value)
	}
}


// ============================== PRIMITIVES ==============================
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

destroy_all :: proc() {
	destroy_all_cubemaps_resources()
	destroy_all_primitives_resources()
	destroy_all_shaders_resources()
	destroy_all_textures_resources()
	destroy_all_models_resources()
	destroy_all_post_process_effects_resources()
}

Resource :: struct($T: typeid) {
	value:     T,
	is_loaded: bool,
}
