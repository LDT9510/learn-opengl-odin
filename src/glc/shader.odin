package glc

import "core:c"
import "core:log"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

Shader_Stage :: struct {
	name: string,
	id:   u32,
}

Shader_Program :: struct {
	name:          string,
	vertex_name:   string,
	fragment_name: string,
	geometry_name: string,
	id:            u32,
}

Shader_Type :: enum u32 {
	Vertex   = gl.VERTEX_SHADER,
	Fragment = gl.FRAGMENT_SHADER,
	Geometry = gl.GEOMETRY_SHADER,
}

shader_create_program :: proc {
	shader_create_program_from_stages,
	shader_create_program_from_code,
	shader_create_program_from_content,
}

shader_create_program_from_stages :: proc(
	vertex: Shader_Stage,
	fragment: Shader_Stage,
	geometry: Maybe(Shader_Stage) = nil,
) -> (
	program: Shader_Program,
	ok: bool,
) {
	success: i32
	program.vertex_name = vertex.name
	program.fragment_name = fragment.name

	program.id = gl.CreateProgram()
	gl.AttachShader(program.id, vertex.id)
	gl.AttachShader(program.id, fragment.id)

	geom, geom_ok := geometry.?
	if geom_ok {
		program.geometry_name = geom.name
		gl.AttachShader(program.id, geom.id)
	}

	gl.LinkProgram(program.id)
	gl.GetProgramiv(program.id, gl.LINK_STATUS, &success)
	if success != 1 {
		info_log: [512]c.char
		gl.GetProgramInfoLog(program.id, size_of(info_log), nil, &info_log[0])
		log.errorf("Shader program link error: \n\t\t\t%s", cast(cstring)&info_log[0])
		return
	}

	return program, true
}

shader_create_program_from_code :: proc(
	vertex_code: Content_Shader_Data,
	fragment_code: Content_Shader_Data,
	geometry_code: Maybe(Content_Shader_Data) = nil,
) -> (
	program: Shader_Program,
	ok: bool,
) {
	vertex := shader_create_stage(vertex_code, .Vertex) or_return
	fragment := shader_create_stage(fragment_code, .Fragment) or_return

	geometry: Maybe(Shader_Stage)
	geom, geom_ok := geometry_code.?
	if geom_ok {
		geometry = shader_create_stage(geom, .Geometry) or_return
	}

	return shader_create_program_from_stages(vertex, fragment, geometry)
}

shader_create_program_from_content :: proc(
	vertex_file_name: string,
	fragment_file_name: string,
	geometry_file_name: Maybe(string) = nil,
) -> (
	program_id: Shader_Program,
	ok: bool,
) {
	vertex_code := content_load_shader_code(vertex_file_name, .Vertex) or_return
	fragment_code := content_load_shader_code(fragment_file_name, .Fragment) or_return

	geometry_code: Maybe(Content_Shader_Data)
	geom, geom_ok := geometry_file_name.?
	if geom_ok {
		geometry_code = content_load_shader_code(geom, .Geometry) or_return
	}

	defer {
		content_destroy_shader_data(vertex_code)
		content_destroy_shader_data(fragment_code)
		if geom_ok {
			content_destroy_shader_data(geometry_code.?)
		}
	}

	return shader_create_program_from_code(vertex_code, fragment_code, geometry_code)
}

shader_use_program :: proc(program: Shader_Program) {
	@(static) s_last_program_id_set: u32

	// avoid calling GLUseProgram for nothing
	if program.id != s_last_program_id_set {
		gl.UseProgram(program.id)
		s_last_program_id_set = program.id
	}
}

shader_delete_program :: proc(program: Shader_Program) {
	gl.DeleteProgram(program.id)
}

shader_uniform_set :: proc {
	shader_uniform_set_bool,
	shader_uniform_set_int32,
	shader_uniform_set_float,
	shader_uniform_set_vec2_f,
	shader_uniform_set_vec3_f,
	shader_uniform_set_vec4_f,
	shader_uniform_set_vec2_v,
	shader_uniform_set_vec3_v,
	shader_uniform_set_vec4_v,
	shader_uniform_set_mat2,
	shader_uniform_set_mat3,
	shader_uniform_set_mat4,
}

shader_uniform_set_bool :: proc(program: Shader_Program, name: cstring, value: bool) {
	gl.Uniform1i(gl.GetUniformLocation(program.id, name), cast(i32)value)
}

shader_uniform_set_int32 :: proc(program: Shader_Program, name: cstring, value: i32) {
	gl.Uniform1i(gl.GetUniformLocation(program.id, name), value)
}

shader_uniform_set_float :: proc(program: Shader_Program, name: cstring, value: f32) {
	gl.Uniform1f(gl.GetUniformLocation(program.id, name), value)
}

shader_uniform_set_vec2_f :: proc(program: Shader_Program, name: cstring, x, y: f32) {
	gl.Uniform2f(gl.GetUniformLocation(program.id, name), x, y)
}

shader_uniform_set_vec3_f :: proc(program: Shader_Program, name: cstring, x, y, z: f32) {
	gl.Uniform3f(gl.GetUniformLocation(program.id, name), x, y, z)
}

shader_uniform_set_vec4_f :: proc(program: Shader_Program, name: cstring, x, y, z, w: f32) {
	gl.Uniform4f(gl.GetUniformLocation(program.id, name), x, y, z, w)
}

shader_uniform_set_vec2_v :: proc(program: Shader_Program, name: cstring, value: glm.vec2) {
	gl.Uniform2f(gl.GetUniformLocation(program.id, name), value.x, value.y)
}

shader_uniform_set_vec3_v :: proc(program: Shader_Program, name: cstring, value: glm.vec3) {
	gl.Uniform3f(gl.GetUniformLocation(program.id, name), value.x, value.y, value.z)
}

shader_uniform_set_vec4_v :: proc(program: Shader_Program, name: cstring, value: glm.vec4) {
	gl.Uniform4f(gl.GetUniformLocation(program.id, name), value.x, value.y, value.z, value.w)
}

shader_uniform_set_mat2 :: proc(program: Shader_Program, name: cstring, value: ^glm.mat2) {
	gl.UniformMatrix2fv(gl.GetUniformLocation(program.id, name), 1, false, &value[0][0])
}

shader_uniform_set_mat3 :: proc(program: Shader_Program, name: cstring, value: ^glm.mat3) {
	gl.UniformMatrix3fv(gl.GetUniformLocation(program.id, name), 1, false, &value[0][0])
}

shader_uniform_set_mat4 :: proc(program: Shader_Program, name: cstring, value: ^glm.mat4) {
	gl.UniformMatrix4fv(gl.GetUniformLocation(program.id, name), 1, false, &value[0][0])
}

shader_ubo_bind :: proc(program: Shader_Program, ubo_name: cstring, bind_point: u32) {
	ubo_index := gl.GetUniformBlockIndex(program.id, ubo_name)
	gl.UniformBlockBinding(program.id, ubo_index, bind_point)
}

@(private = "file")
g_shader_program_registry: [Shader_Program_Resource_index]Resource(Shader_Program)

Vert_Shader_Code_Resource_index :: enum {
	Pos_Norm_Tex,
	Cubemap,
	Points,
	// used by post process effects only
	// Quad,
}
@(rodata)
VERTEX_CODE_LOCATION := [Vert_Shader_Code_Resource_index]string {
	.Pos_Norm_Tex = "pos_norm_tex",
	.Cubemap      = "cubemap",
	.Points       = "points",
	// used by post process effects only
	// .Quad         = "quad",
}

Frag_Shader_Code_Resource_Index :: enum {
	Light_Cube,
	UV_Map,
	Phong,
	Reflective,
	Refractive,
	Skybox,
	Outline,
	Magenta,
	Depth,
	Green,
	Win_Rel,
}
@(rodata)
FRAGMENT_CODE_LOCATION := [Frag_Shader_Code_Resource_Index]string {
	.Light_Cube = "light_cube",
	.UV_Map     = "uv_map",
	.Phong      = "phong",
	.Reflective = "reflective",
	.Refractive = "refractive",
	.Skybox     = "skybox",
	.Outline    = "colored_outline",
	.Win_Rel    = "window_relative_color",
	.Magenta    = "magenta",
	.Depth      = "depth",
	.Green      = "green",
}

Geom_Shader_Code_Resource_Index :: enum {
	Basic,
}
@(rodata)
GEOMETRY_CODE_LOCATION := [Geom_Shader_Code_Resource_Index]string {
	.Basic = "basic",
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
}

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
		.Geom_Demo      = {"geom_demo", .Points, .Green, .Basic},
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
			log.panicf("Cannot load Shader Program: '%s'", program_code.name)
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
			v, f := old.vertex_name, old.fragment_name
			program, ok := shader_create_program(v, f)
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

@(private)
shader_create_stage :: proc(
	shader_data: Content_Shader_Data,
	type: Shader_Type,
) -> (
	shader: Shader_Stage,
	ok: bool,
) {
	success: i32
	code := shader_data.code

	shader.name = shader_data.name
	shader.id = gl.CreateShader(cast(u32)type)

	gl.ShaderSource(shader.id, 1, &code, nil)
	gl.CompileShader(shader.id)
	gl.GetShaderiv(shader.id, gl.COMPILE_STATUS, &success)

	if success != 1 {
		info_log: [512]c.char
		gl.GetShaderInfoLog(shader.id, size_of(info_log), nil, &info_log[0])

		shader_type_name: string
		switch type {
		case .Vertex:
			shader_type_name = "Vertex"
		case .Fragment:
			shader_type_name = "Fragment"
		case .Geometry:
			shader_type_name = "Geometry"
		}

		log.errorf(
			"%s shader '%s' compilation error: \n\t\t\t%s",
			shader_type_name,
			shader.name,
			cast(cstring)&info_log[0],
		)
		return
	}

	ok = true

	return
}
