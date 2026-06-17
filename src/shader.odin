package learn_opengl

import "core:c"
import "core:log"
import "core:math/linalg"
import "core:strings"

import gl "vendor:OpenGL"

Shader_Type :: enum u32 {
	Vertex   = gl.VERTEX_SHADER,
	Fragment = gl.FRAGMENT_SHADER,
}

Shader_Handle :: distinct u32
Shader_Program_Handle :: distinct u32

shader_create :: proc(type: Shader_Type, code: cstring) -> (shader_id: Shader_Handle, ok: bool) {
	code := code

	success: i32
	native_shader_id := gl.CreateShader(cast(u32)type)
	shader_id = cast(Shader_Handle)native_shader_id
	gl.ShaderSource(native_shader_id, 1, &code, nil)
	gl.CompileShader(native_shader_id)
	gl.GetShaderiv(native_shader_id, gl.COMPILE_STATUS, &success)

	if success != 1 {
		info_log: [512]c.char
		gl.GetShaderInfoLog(native_shader_id, size_of(info_log), nil, &info_log[0])
		shader_type_name := type == .Vertex ? "Vertex" : "Fragment"
		log.errorf(
			"%s shader compilation error: \n\t\t\t%s",
			shader_type_name,
			cast(cstring)&info_log[0],
		)
		return
	}

	return shader_id, true
}

shader_load_from_glsl_code :: proc(
	vertex_code: cstring,
	fragment_code: cstring,
) -> (
	program_id: Shader_Program_Handle,
	ok: bool,
) {
	vertex_id := cast(u32)shader_create(.Vertex, vertex_code) or_return
	fragment_id := cast(u32)shader_create(.Fragment, fragment_code) or_return
	defer {
		gl.DeleteShader(vertex_id)
		gl.DeleteShader(fragment_id)
	}

	success: i32
	native_program_id := gl.CreateProgram()
	program_id = cast(Shader_Program_Handle)native_program_id
	gl.AttachShader(native_program_id, vertex_id)
	gl.AttachShader(native_program_id, fragment_id)
	gl.LinkProgram(native_program_id)
	gl.GetProgramiv(native_program_id, gl.LINK_STATUS, &success)
	if success != 1 {
		info_log: [512]c.char
		gl.GetProgramInfoLog(native_program_id, size_of(info_log), nil, &info_log[0])
		log.errorf("Shader program link error: \n\t\t\t%s", cast(cstring)&info_log[0])
		return
	}

	return program_id, true
}

shader_load_from_files :: proc(
	vertex_file_name: string,
	fragment_file_name: string,
) -> (
program_id: Shader_Program_Handle,
ok: bool,
) {
	// NOTE: to avoid unnecessary allocations, read the file as a cstring directly
	vertex_content := content_shader_read(vertex_file_name) or_return
	fragment_content := content_shader_read(fragment_file_name) or_return
	defer {
		content_delete(vertex_content)
		content_delete(fragment_content)
	}

	vertex_code := strings.clone_to_cstring(cast(string)vertex_content)
	fragment_code := strings.clone_to_cstring(cast(string)fragment_content)
	defer {
		delete(vertex_code)
		delete(fragment_code)
	}

	return shader_load_from_glsl_code(vertex_code, fragment_code)
}

shader_use_program :: proc(program_id: Shader_Program_Handle) {
	gl.UseProgram(cast(u32)program_id)
}

shader_delete_program :: proc(program_id: Shader_Program_Handle) {
	gl.DeleteProgram(cast(u32)program_id)
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

shader_uniform_set_bool :: proc(program_id: Shader_Program_Handle, name: cstring, value: bool) {
	gl.Uniform1i(gl.GetUniformLocation(cast(u32)program_id, name), cast(i32)value)
}

shader_uniform_set_int32 :: proc(program_id: Shader_Program_Handle, name: cstring, value: i32) {
	gl.Uniform1i(gl.GetUniformLocation(cast(u32)program_id, name), value)
}

shader_uniform_set_float :: proc(program_id: Shader_Program_Handle, name: cstring, value: f32) {
	gl.Uniform1f(gl.GetUniformLocation(cast(u32)program_id, name), value)
}

shader_uniform_set_vec2_f :: proc(program_id: Shader_Program_Handle, name: cstring, x, y: f32) {
	gl.Uniform2f(gl.GetUniformLocation(cast(u32)program_id, name), x, y)
}

shader_uniform_set_vec3_f :: proc(program_id: Shader_Program_Handle, name: cstring, x, y, z: f32) {
	gl.Uniform3f(gl.GetUniformLocation(cast(u32)program_id, name), x, y, z)
}

shader_uniform_set_vec4_f :: proc(program_id: Shader_Program_Handle, name: cstring, x, y, z, w: f32) {
	gl.Uniform4f(gl.GetUniformLocation(cast(u32)program_id, name), x, y, z, w)
}

shader_uniform_set_vec2_v :: proc(
	program_id: Shader_Program_Handle,
	name: cstring,
	value: linalg.Vector2f32,
) {
	gl.Uniform2f(gl.GetUniformLocation(cast(u32)program_id, name), value.x, value.y)
}

shader_uniform_set_vec3_v :: proc(
	program_id: Shader_Program_Handle,
	name: cstring,
	value: linalg.Vector3f32,
) {
	gl.Uniform3f(gl.GetUniformLocation(cast(u32)program_id, name), value.x, value.y, value.z)
}

shader_uniform_set_vec4_v :: proc(
	program_id: Shader_Program_Handle,
	name: cstring,
	value: linalg.Vector4f32,
) {
	gl.Uniform4f(gl.GetUniformLocation(cast(u32)program_id, name), value.x, value.y, value.z, value.w)
}

shader_uniform_set_mat2 :: proc(
	program_id: Shader_Program_Handle,
	name: cstring,
	value: ^linalg.Matrix2x2f32,
) {
	gl.UniformMatrix2fv(gl.GetUniformLocation(cast(u32)program_id, name), 1, false, &value[0][0])
}

shader_uniform_set_mat3 :: proc(
	program_id: Shader_Program_Handle,
	name: cstring,
	value: ^linalg.Matrix3x3f32,
) {
	gl.UniformMatrix3fv(gl.GetUniformLocation(cast(u32)program_id, name), 1, false, &value[0][0])
}

shader_uniform_set_mat4 :: proc(
	program_id: Shader_Program_Handle,
	name: cstring,
	value: ^linalg.Matrix4x4f32,
) {
	gl.UniformMatrix4fv(gl.GetUniformLocation(cast(u32)program_id, name), 1, false, &value[0][0])
}
