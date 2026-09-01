package glc

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

Vertex :: struct {
	position:   glm.vec3,
	normal:     glm.vec3,
	tex_coords: glm.vec2,
}

Point2D_Vertex :: struct {
	positions: glm.vec2,
}

Mesh :: struct {
	vertices:      [dynamic]Vertex,
	indices:       [dynamic]u32,
	textures:      [dynamic]Model_Texture,
	vao, vbo, ebo: u32,
}

mesh_init :: proc(mesh: ^Mesh) {
	gl.GenVertexArrays(1, &mesh.vao)
	gl.GenBuffers(1, &mesh.vbo)
	gl.GenBuffers(1, &mesh.ebo)

	gl.BindVertexArray(mesh.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(mesh.vertices) * size_of(Vertex),
		&mesh.vertices[0],
		gl.STATIC_DRAW,
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(mesh.indices) * size_of(u32),
		&mesh.indices[0],
		gl.STATIC_DRAW,
	)

	// positions
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), 0)

	// normals
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, normal))

	// textures coords
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
}

mesh_delete :: proc(mesh: ^Mesh) {
	gl.DeleteBuffers(1, &mesh.vbo)
	gl.DeleteBuffers(1, &mesh.ebo)
	gl.DeleteVertexArrays(1, &mesh.vao)

	delete(mesh.vertices)
	delete(mesh.indices)

	for &model_texture in mesh.textures {
		texture_destroy(model_texture.id)
	}
	delete(mesh.textures)
}
