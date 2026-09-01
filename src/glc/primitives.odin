package glc

import gl "vendor:OpenGL"

Primitive_Type :: enum {
	Cube,
	Plane,
	Quad,
	Full_Quad,
	Mini_Quad,
	Points,
}

Primitive :: struct {
	vao, vbo:    u32,
	texture:     Texture_Id,
	vertex_size: int,
	type:        Primitive_Type,
}

primitive_create_points :: proc() -> (p: Primitive) {
	p.type = .Points
	p.vertex_size = len(POINTS)

	gl.GenVertexArrays(1, &p.vao)
	gl.GenBuffers(1, &p.vbo)
	gl.BindVertexArray(p.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, p.vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		p.vertex_size * size_of(Point2D_Vertex),
		&POINTS[0],
		gl.STATIC_DRAW,
	)

	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, size_of(Point2D_Vertex), 0)

	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(
		1,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Point2D_Vertex),
		offset_of(Point2D_Vertex, color),
	)
	gl.BindVertexArray(0)

	return
}

primitive_create :: proc {
	primitive_create_untextured,
	primitive_create_from_image,
	primitive_create_from_texture,
}

primitive_create_untextured :: proc(p_type: Primitive_Type) -> (p: Primitive) {
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

	vertices: []Vertex
	switch p_type {
	case .Points:
		return primitive_create_points()
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

	p.type = p_type
	p.vertex_size = len(vertices)

	gl.GenVertexArrays(1, &p.vao)
	gl.GenBuffers(1, &p.vbo)
	gl.BindVertexArray(p.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, p.vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		p.vertex_size * size_of(Vertex),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)
	// positions
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), 0)

	// normals
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, normal))

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

primitive_destroy :: proc(p: ^Primitive) {
	gl.DeleteVertexArrays(1, &p.vao)
	gl.DeleteBuffers(1, &p.vbo)
	texture_destroy(p.texture)
}



