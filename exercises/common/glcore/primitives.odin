package glcore

import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"

Primitive_Type :: enum {
	Cube,
	Plane,
	Quad,
	Full_Quad,
	Mini_Quad,
}

Primitive :: struct {
	vao, vbo:    u32,
	texture:     Texture_Id,
	vertex_size: i32,
	type:        Primitive_Type,
}

primitive_create :: proc {
	primitive_create_untextured,
	primitive_create_from_image,
	primitive_create_from_texture,
}

primitive_create_untextured :: proc(
	p_type: Primitive_Type,
) -> (
	p: Primitive,
) {
	p = _primitive_create_internal(p_type, false, false)
	return
}

primitive_create_from_texture :: proc(
	p_type: Primitive_Type,
	texture: Texture_Id,
	flip_texture_vertically := false,
	transparent := false,
) -> (
	p: Primitive,
) {
	p = _primitive_create_internal(p_type, flip_texture_vertically, transparent)

	p.texture = texture

	return

}

primitive_create_from_image :: proc(
	p_type: Primitive_Type,
	image_name: string,
	flip_texture_vertically := false,
	transparent := false,
) -> (
	p: Primitive,
) {
	p = _primitive_create_internal(p_type, flip_texture_vertically, transparent)

	p.texture =
		texture_load(image_name, flip_texture_vertically, transparent) or_else panic(
			"Cannot load texture",
		)

	return
}

@(private)
_primitive_create_internal :: proc(
	p_type: Primitive_Type,
	flip_texture_vertically: bool,
	transparent: bool,
) -> (
	p: Primitive,
) {
	p.type = p_type

	vertices: []Vertex
	switch p_type {
	case .Cube:
		vertices = CUBE_VERTICES[:]
	case .Plane:
		vertices = PLANE_VERTICES[:]
	case .Quad:
		vertices = QUAD_VERTICES[:]
	case .Full_Quad:
		vertices = FULL_SCREEN_QUAD_VERTICES[:]
	case .Mini_Quad:
		vertices = MINI_QUAD_VERTICES[:]
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
	// positions
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), 0)

	// normals
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(
		1,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		offset_of(Vertex, normal),
	)

	// textures
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(
		2,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		offset_of(Vertex, tex_coords),
	)
	gl.BindVertexArray(0)

	return
}

primitive_draw :: proc(
	p: Primitive,
	shader: Shader_Program_Handle,
	translation: glm.vec3 = 0,
	scale: glm.vec3 = 1,
	camera_pos: glm.vec3 = 1,
) {
	shader_use_program(shader)
	gl.BindVertexArray(p.vao)

	if p.type == .Full_Quad {
		shader_uniform_set(shader, "u_screen_texture", 0)

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, cast(u32)p.texture)

	} else {
		shader_uniform_set(shader, "u_texture_diffuse1", 0)

		model_matrix := glm.mat4Translate(translation)
		model_matrix *= glm.mat4Scale(scale)
		shader_uniform_set(shader, "u_model", &model_matrix)

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, cast(u32)p.texture)
	}

	gl.DrawArrays(gl.TRIANGLES, 0, p.vertex_size)
}

primitive_destroy :: proc(p: ^Primitive) {
	gl.DeleteVertexArrays(1, &p.vao)
	gl.DeleteBuffers(1, &p.vbo)
	texture_destroy(p.texture)
}



// odinfmt: disable
	/*
    Remember: to specify vertices in a counter-clockwise winding order you need to visualize the triangle
    as if you're in front of the triangle and from that point of view, is where you set their order.
    
    To define the order of a triangle on the right side of the cube for example, you'd imagine yourself looking
    straight at the right side of the cube, and then visualize the triangle and make sure their order is specified
    in a counter-clockwise order. This takes some practice, but try visualizing this yourself and see that this
    is correct.
*/

@(rodata)
CUBE_VERTICES := [?]Vertex {
	// positions          // normals           // texture Coords
	// back face
	{{-0.5, -0.5, -0.5}, { 0.0,  0.0, -1.0}, {0.0, 0.0}},
	{{ 0.5,  0.5, -0.5}, { 0.0,  0.0, -1.0}, {1.0, 1.0}},
	{{ 0.5, -0.5, -0.5}, { 0.0,  0.0, -1.0}, {1.0, 0.0}},
	{{ 0.5,  0.5, -0.5}, { 0.0,  0.0, -1.0}, {1.0, 1.0}},
	{{-0.5, -0.5, -0.5}, { 0.0,  0.0, -1.0}, {0.0, 0.0}},
	{{-0.5,  0.5, -0.5}, { 0.0,  0.0, -1.0}, {0.0, 1.0}},
	// front face
	{{-0.5, -0.5,  0.5}, { 0.0,  0.0,  1.0}, {0.0, 0.0}},
	{{ 0.5, -0.5,  0.5}, { 0.0,  0.0,  1.0}, {1.0, 0.0}},
	{{ 0.5,  0.5,  0.5}, { 0.0,  0.0,  1.0}, {1.0, 1.0}},
	{{ 0.5,  0.5,  0.5}, { 0.0,  0.0,  1.0}, {1.0, 1.0}},
	{{-0.5,  0.5,  0.5}, { 0.0,  0.0,  1.0}, {0.0, 1.0}},
	{{-0.5, -0.5,  0.5}, { 0.0,  0.0,  1.0}, {0.0, 0.0}},
	// left face
	{{-0.5,  0.5,  0.5}, {-1.0,  0.0,  0.0}, {1.0, 0.0}},
	{{-0.5,  0.5, -0.5}, {-1.0,  0.0,  0.0}, {1.0, 1.0}},
	{{-0.5, -0.5, -0.5}, {-1.0,  0.0,  0.0}, {0.0, 1.0}},
	{{-0.5, -0.5, -0.5}, {-1.0,  0.0,  0.0}, {0.0, 1.0}},
	{{-0.5, -0.5,  0.5}, {-1.0,  0.0,  0.0}, {0.0, 0.0}},
	{{-0.5,  0.5,  0.5}, {-1.0,  0.0,  0.0}, {1.0, 0.0}},
	// right face
	{{ 0.5,  0.5,  0.5}, { 1.0,  0.0,  0.0}, {1.0, 0.0}},
	{{ 0.5, -0.5, -0.5}, { 1.0,  0.0,  0.0}, {0.0, 1.0}},
	{{ 0.5,  0.5, -0.5}, { 1.0,  0.0,  0.0}, {1.0, 1.0}},
	{{ 0.5, -0.5, -0.5}, { 1.0,  0.0,  0.0}, {0.0, 1.0}},
	{{ 0.5,  0.5,  0.5}, { 1.0,  0.0,  0.0}, {1.0, 0.0}},
	{{ 0.5, -0.5,  0.5}, { 1.0,  0.0,  0.0}, {0.0, 0.0}},
	// bottom face
	{{-0.5, -0.5, -0.5}, { 0.0, -1.0,  0.0}, {0.0, 1.0}},
	{{ 0.5, -0.5, -0.5}, { 0.0, -1.0,  0.0}, {1.0, 1.0}},
	{{ 0.5, -0.5,  0.5}, { 0.0, -1.0,  0.0}, {1.0, 0.0}},
	{{ 0.5, -0.5,  0.5}, { 0.0, -1.0,  0.0}, {1.0, 0.0}},
	{{-0.5, -0.5,  0.5}, { 0.0, -1.0,  0.0}, {0.0, 0.0}},
	{{-0.5, -0.5, -0.5}, { 0.0, -1.0,  0.0}, {0.0, 1.0}},
	// top face
	{{-0.5,  0.5, -0.5}, { 0.0,  1.0,  0.0}, {0.0, 1.0}},
	{{ 0.5,  0.5,  0.5}, { 0.0,  1.0,  0.0}, {1.0, 0.0}},
	{{ 0.5,  0.5, -0.5}, { 0.0,  1.0,  0.0}, {1.0, 1.0}},
	{{ 0.5,  0.5,  0.5}, { 0.0,  1.0,  0.0}, {1.0, 0.0}},
	{{-0.5,  0.5, -0.5}, { 0.0,  1.0,  0.0}, {0.0, 1.0}},
	{{-0.5,  0.5,  0.5}, { 0.0,  1.0,  0.0}, {0.0, 0.0}},
}

@(rodata)
PLANE_VERTICES := [?]Vertex {
	// streched textures
	// positions          // normals        // texture Coords
	{{5.0, -0.5, 5.0},   {0.0, 0.0, 0.0}, {2.0, 0.0}},
	{{-5.0, -0.5, 5.0},  {0.0, 0.0, 0.0}, {0.0, 0.0}},
	{{-5.0, -0.5, -5.0}, {0.0, 0.0, 0.0}, {0.0, 2.0}},
	{{5.0, -0.5, 5.0},   {0.0, 0.0, 0.0}, {2.0, 0.0}},
	{{-5.0, -0.5, -5.0}, {0.0, 0.0, 0.0}, {0.0, 2.0}},
	{{5.0, -0.5, -5.0},  {0.0, 0.0, 0.0}, {2.0, 2.0}},
}

@(rodata)
QUAD_VERTICES := [?]Vertex {
	// positions        // normals        // texture Coords
	{{0.0, 0.5, 0.0},  {0.0, 0.0, 0.0}, {0.0, 1.0}},
	{{0.0, -0.5, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0}},
	{{1.0, -0.5, 0.0}, {0.0, 0.0, 0.0}, {1.0, 0.0}},
	{{0.0, 0.5, 0.0},  {0.0, 0.0, 0.0}, {0.0, 1.0}},
	{{1.0, -0.5, 0.0}, {0.0, 0.0, 0.0}, {1.0, 0.0}},
	{{1.0, 0.5, 0.0},  {0.0, 0.0, 0.0}, {1.0, 1.0}},
}

@(rodata)
FULL_SCREEN_QUAD_VERTICES := [?]Vertex {
	// positions        // normals        // texture Coords
	{{-1.0, 1.0, 0.0},  {0.0, 0.0, 0.0}, {0.0, 1.0}},
	{{-1.0, -1.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0}},
	{{1.0, -1.0, 0.0},  {0.0, 0.0, 0.0}, {1.0, 0.0}},
	{{-1.0, 1.0, 0.0},  {0.0, 0.0, 0.0}, {0.0, 1.0}},
	{{1.0, -1.0, 0.0},  {0.0, 0.0, 0.0}, {1.0, 0.0}},
	{{1.0, 1.0, 0.0},   {0.0, 0.0, 0.0}, {1.0, 1.0}},
}

@(rodata)
MINI_QUAD_VERTICES := [?]Vertex {
	// positions        // normals        // texture Coords
	{{-0.3, 1.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 1.0}},
	{{-0.3, 0.7, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0}},
	{{0.3, 0.7, 0.0},  {0.0, 0.0, 0.0}, {1.0, 0.0}},
	{{-0.3, 1.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 1.0}},
	{{0.3, 0.7, 0.0},  {0.0, 0.0, 0.0}, {1.0, 0.0}},
	{{0.3, 1.0, 0.0},  {0.0, 0.0, 0.0}, {1.0, 1.0}},
}


// odinfmt: enable
