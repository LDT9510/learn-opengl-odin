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
	geometry_name: Maybe(string),
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
	prog: Shader_Program
	prog.vertex_name = vertex.name
	prog.fragment_name = fragment.name

	prog.id = gl.CreateProgram()
	gl.AttachShader(prog.id, vertex.id)
	gl.AttachShader(prog.id, fragment.id)

	geom, geom_ok := geometry.?
	if geom_ok {
		prog.geometry_name = geom.name
		gl.AttachShader(prog.id, geom.id)
	}

	gl.LinkProgram(prog.id)

	success: i32
	gl.GetProgramiv(prog.id, gl.LINK_STATUS, &success)
	if success != 1 {
		info_log: [512]c.char
		gl.GetProgramInfoLog(prog.id, size_of(info_log), nil, &info_log[0])
		log.errorf("Shader program link error: \n\t\t\t%s", cast(cstring)&info_log[0])
		return
	}

	return prog, true
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
	program: Shader_Program,
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
	shader_uniform_set_vec2,
	shader_uniform_set_vec3,
	shader_uniform_set_vec4,
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

shader_uniform_set_vec2 :: proc(program: Shader_Program, name: cstring, value: glm.vec2) {
	gl.Uniform2f(gl.GetUniformLocation(program.id, name), **value)
}

shader_uniform_set_vec3 :: proc(program: Shader_Program, name: cstring, value: glm.vec3) {
	gl.Uniform3f(gl.GetUniformLocation(program.id, name), **value)
}

shader_uniform_set_vec4 :: proc(program: Shader_Program, name: cstring, value: glm.vec4) {
	gl.Uniform4f(gl.GetUniformLocation(program.id, name), **value)
}

shader_uniform_set_mat2 :: proc(program: Shader_Program, name: cstring, value: glm.mat2) {
	flat := transmute([4]f32)value
	gl.UniformMatrix2fv(gl.GetUniformLocation(program.id, name), 1, false, raw_data(flat[:]))
}

shader_uniform_set_mat3 :: proc(program: Shader_Program, name: cstring, value: glm.mat3) {
	flat := transmute([9]f32)value
	gl.UniformMatrix3fv(gl.GetUniformLocation(program.id, name), 1, false, raw_data(flat[:]))
}

shader_uniform_set_mat4 :: proc(program: Shader_Program, name: cstring, value: glm.mat4) {
	flat := transmute([16]f32)value
	gl.UniformMatrix4fv(gl.GetUniformLocation(program.id, name), 1, false, raw_data(flat[:]))
}

shader_ubo_bind :: proc(program: Shader_Program, ubo_name: cstring, bind_point: u32) {
	ubo_index := gl.GetUniformBlockIndex(program.id, ubo_name)
	if ubo_index != gl.INVALID_INDEX {
		gl.UniformBlockBinding(program.id, ubo_index, bind_point)
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
	code := shader_data.code

	sh: Shader_Stage
	sh.name = shader_data.name
	sh.id = gl.CreateShader(cast(u32)type)

	gl.ShaderSource(sh.id, 1, &code, nil)
	gl.CompileShader(sh.id)

	success: i32
	gl.GetShaderiv(sh.id, gl.COMPILE_STATUS, &success)
	if success != 1 {
		info_log: [512]c.char
		gl.GetShaderInfoLog(sh.id, size_of(info_log), nil, &info_log[0])

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
			sh.name,
			cast(cstring)&info_log[0],
		)
		return
	}

	return sh, true
}
