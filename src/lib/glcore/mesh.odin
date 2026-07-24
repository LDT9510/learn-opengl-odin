package glcore

import "core:fmt"
import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"

Vertex :: struct {
	positions:  glm.vec3,
	normals:    glm.vec3,
	tex_coords: glm.vec2,
}

Mesh :: struct {
	vertices:      [dynamic]Vertex,
	indices:       [dynamic]u32,
	textures:      [dynamic]Texture,
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
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, normals))
	gl.EnableVertexAttribArray(1)

	// textures coords
	gl.VertexAttribPointer(
		2,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		offset_of(Vertex, tex_coords),
	)
	gl.EnableVertexAttribArray(2)

	gl.BindVertexArray(0)
}

mesh_delete :: proc(mesh: ^Mesh) {
	defer gl.DeleteBuffers(1, &mesh.vbo)
	defer gl.DeleteBuffers(1, &mesh.ebo)
	defer gl.DeleteVertexArrays(1, &mesh.vao)
}

mesh_draw :: proc(mesh: Mesh, shader: Shader_Program_Handle) {
	diffuse_num := 1
	specular_num := 1

	for i in 0 ..< len(mesh.textures) {
		gl.ActiveTexture(gl.TEXTURE0 + cast(u32)i)

		texture := mesh.textures[i]
		name: string
		binding_num: int
		switch texture.type {
		case .Difusse:
			name = "diffuse"
			binding_num = diffuse_num
			diffuse_num += 1
		case .Specular:
			name = "specular"
			binding_num = specular_num
			specular_num += 1
		}

		shader_uniform_set(
			shader,
			fmt.ctprint("material.texture_%s%d", name, binding_num),
			cast(i32)i,
		)

		gl.BindTexture(gl.TEXTURE_2D, cast(u32)texture.id)
	}
	gl.ActiveTexture(gl.TEXTURE0)

	gl.BindVertexArray(mesh.vao)
	gl.DrawElements(gl.TRIANGLES, cast(i32)len(mesh.indices), gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
}
