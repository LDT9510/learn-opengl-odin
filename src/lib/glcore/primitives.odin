package glcore

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

Primitive_Type :: enum {
	Cube,
	Plane,
}

// while not using normals, else just use "mesh.Vertex"
Primitive_Vertex :: struct {
	position:   glm.vec3,
	tex_coords: glm.vec2,
}

Primitive :: struct {
	vao, vbo:    u32,
	texture:     Texture_Id,
	vertex_size: i32,
}

primitive_create :: proc(p_type: Primitive_Type, image_name: string) -> (p: Primitive) {
	vertices: []Primitive_Vertex
	switch p_type {
	case .Cube:
		vertices = CUBE_VERTICES[:]
	case .Plane:
		vertices = PLANE_VERTICES[:]
	}

	p.vertex_size = cast(i32)len(vertices)

	gl.GenVertexArrays(1, &p.vao)
	gl.GenBuffers(1, &p.vbo)
	gl.BindVertexArray(p.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, p.vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		cast(int)p.vertex_size * size_of(Vertex),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Primitive_Vertex), 0)
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(
		2,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Primitive_Vertex),
		offset_of(Primitive_Vertex, tex_coords),
	)
	gl.BindVertexArray(0)

	p.texture = texture_load(image_name) or_else panic("Cannot load texture")

	return
}

primitive_draw :: proc(
	p: Primitive,
	shader: Shader_Program_Handle,
	translation: glm.vec3 = 0,
	scale: glm.vec3 = 1,
) {
	shader_use_program(shader)
	shader_uniform_set(shader, "u_texture_diffuse1", 0)

	model_matrix := glm.mat4Translate(translation)
	model_matrix *= glm.mat4Scale(scale)
	shader_uniform_set(shader, "u_model", &model_matrix)

	gl.BindVertexArray(p.vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, cast(u32)p.texture)

	gl.DrawArrays(gl.TRIANGLES, 0, p.vertex_size)
}

primitive_destroy :: proc(p: ^Primitive) {
	gl.DeleteVertexArrays(1, &p.vao)
	gl.DeleteBuffers(1, &p.vbo)
	texture_destroy(p.texture)
}

// odinfmt: disable
@(rodata)
CUBE_VERTICES := [?]Primitive_Vertex{
    // positions          // texture Coords
    {{-0.5, -0.5, -0.5,},  {0.0, 0.0,},},
    {{ 0.5, -0.5, -0.5,},  {1.0, 0.0,},},
    {{ 0.5,  0.5, -0.5,},  {1.0, 1.0,},},
    {{ 0.5,  0.5, -0.5,},  {1.0, 1.0,},},
    {{-0.5,  0.5, -0.5,},  {0.0, 1.0,},},
    {{-0.5, -0.5, -0.5,},  {0.0, 0.0,},},
    {{-0.5, -0.5,  0.5,},  {0.0, 0.0,},},
    {{ 0.5, -0.5,  0.5,},  {1.0, 0.0,},},
    {{ 0.5,  0.5,  0.5,},  {1.0, 1.0,},},
    {{ 0.5,  0.5,  0.5,},  {1.0, 1.0,},},
    {{-0.5,  0.5,  0.5,},  {0.0, 1.0,},},
    {{-0.5, -0.5,  0.5,},  {0.0, 0.0,},},
    {{-0.5,  0.5,  0.5,},  {1.0, 0.0,},},
    {{-0.5,  0.5, -0.5,},  {1.0, 1.0,},},
    {{-0.5, -0.5, -0.5,},  {0.0, 1.0,},},
    {{-0.5, -0.5, -0.5,},  {0.0, 1.0,},},
    {{-0.5, -0.5,  0.5,},  {0.0, 0.0,},},
    {{-0.5,  0.5,  0.5,},  {1.0, 0.0,},},
    {{ 0.5,  0.5,  0.5,},  {1.0, 0.0,},},
    {{ 0.5,  0.5, -0.5,},  {1.0, 1.0,},},
    {{ 0.5, -0.5, -0.5,},  {0.0, 1.0,},},
    {{ 0.5, -0.5, -0.5,},  {0.0, 1.0,},},
    {{ 0.5, -0.5,  0.5,},  {0.0, 0.0,},},
    {{ 0.5,  0.5,  0.5,},  {1.0, 0.0,},},
    {{-0.5, -0.5, -0.5,},  {0.0, 1.0,},},
    {{ 0.5, -0.5, -0.5,},  {1.0, 1.0,},},
    {{ 0.5, -0.5,  0.5,},  {1.0, 0.0,},},
    {{ 0.5, -0.5,  0.5,},  {1.0, 0.0,},},
    {{-0.5, -0.5,  0.5,},  {0.0, 0.0,},},
    {{-0.5, -0.5, -0.5,},  {0.0, 1.0,},},
    {{-0.5,  0.5, -0.5,},  {0.0, 1.0,},},
    {{ 0.5,  0.5, -0.5,},  {1.0, 1.0,},},
    {{ 0.5,  0.5,  0.5,},  {1.0, 0.0,},},
    {{ 0.5,  0.5,  0.5,},  {1.0, 0.0,},},
    {{-0.5,  0.5,  0.5,},  {0.0, 0.0,},},
    {{-0.5,  0.5, -0.5,},  {0.0, 1.0,},},
}

@rodata
PLANE_VERTICES := [?]Primitive_Vertex{
    // note we set the texture coordinates higher than 1 
    // (together with GL_REPEAT as texture wrapping mode)
    // this will cause the floor texture to repeat
    // positions          // texture Coords
    {{ 5.0, -0.5,  5.0,},  {2.0, 0.0,},},
    {{-5.0, -0.5,  5.0,},  {0.0, 0.0,},},
    {{-5.0, -0.5, -5.0,},  {0.0, 2.0,},},

    {{ 5.0, -0.5,  5.0,},  {2.0, 0.0,},},
    {{-5.0, -0.5, -5.0,},  {0.0, 2.0,},},
    {{ 5.0, -0.5, -5.0,},  {2.0, 2.0,},},
}
// odinfmt: enable
