#+private file
package app

import "main:glc"

import "core:time"
import "core:c/libc"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

@(private)
SCENE_ASTEROID_FIELD := Scene {
	"An asteroid field",
	"Asteroid field drawn using instancing",
	&g_scene_data,
	setup,
	draw,
	destroy,
	false,
}

NUM_ASTEROIDS :: 100_000

Scene_Data :: struct {
	asteroids_model_matrices: [NUM_ASTEROIDS]glm.mat4,
	planet_model_matrix:      glm.mat4,
	instance_vbo:             u32,
}
g_scene_data: Scene_Data

destroy :: proc(s: ^State, data: rawptr) {
	data := scene_data(data, Scene_Data)
	gl.DeleteBuffers(1, &data.instance_vbo)
}

setup :: proc(s: ^State, data: rawptr) {
	data := scene_data(data, Scene_Data)
	libc.srand(cast(u32)time.now()._nsec)

	radius := f32(150.0)
	offset := f32(25.0)

	for &m, i in data.asteroids_model_matrices {
		// translation: displace along circle with radius in [-offset, offset]
		angle := f32(i) / f32(NUM_ASTEROIDS) * 360.0
		displacement := f32(libc.rand() % i32(2 * offset * 100)) / 100.0 - offset
		x := glm.sin(angle) * radius + displacement
		displacement = f32(libc.rand() % i32(2 * offset * 100)) / 100.0 - offset
		y := displacement * 0.4
		displacement = f32(libc.rand() % i32(2 * offset * 100)) / 100.0 - offset
		z := glm.cos(angle) * radius + displacement
		m = glm.mat4Translate({x, y, z})
		// scale: between 0.05 and 0.25
		scale := f32(libc.rand() % 20) / 100.0 + 0.05
		m *= glm.mat4Scale(glm.vec3(scale))
		// rotation: around (semi)random rotation axis
		rot_angle := f32(libc.rand() % 360)
		m *= glm.mat4Rotate({0.4, 0.6, 0.8}, rot_angle)
	}

	data.planet_model_matrix = glm.mat4Translate({0.0, -3.0, 0.0})
	data.planet_model_matrix *= glm.mat4Scale({4.0, 4.0, 4.0})


	gl.GenBuffers(1, &data.instance_vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, data.instance_vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		size_of(glm.mat4) * NUM_ASTEROIDS,
		&data.asteroids_model_matrices[0],
		gl.STATIC_DRAW,
	)

	asteroid := glc.model_resource(.Rock)
	mat4_size := i32(size_of(glm.mat4))

	for mesh in asteroid.meshes {
		gl.BindVertexArray(mesh.vao)
		gl.BindBuffer(gl.ARRAY_BUFFER, data.instance_vbo)

		gl.EnableVertexAttribArray(3)
		gl.VertexAttribPointer(3, 4, gl.FLOAT, gl.FALSE, mat4_size, 0)
		gl.EnableVertexAttribArray(4)
		gl.VertexAttribPointer(4, 4, gl.FLOAT, gl.FALSE, mat4_size, uintptr(size_of(glm.vec4)))
		gl.EnableVertexAttribArray(5)
		gl.VertexAttribPointer(5, 4, gl.FLOAT, gl.FALSE, mat4_size, uintptr(size_of(glm.vec4) * 2))
		gl.EnableVertexAttribArray(6)
		gl.VertexAttribPointer(6, 4, gl.FLOAT, gl.FALSE, mat4_size, uintptr(size_of(glm.vec4) * 3))

		gl.VertexAttribDivisor(3, 1)
		gl.VertexAttribDivisor(4, 1)
		gl.VertexAttribDivisor(5, 1)
		gl.VertexAttribDivisor(6, 1)

		gl.BindVertexArray(0)
	}
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
}

draw :: proc(s: ^State, data: rawptr) {
	data := scene_data(data, Scene_Data)

	planet := glc.model_resource(.Planet)
	asteroid := glc.model_resource(.Rock)
	space := glc.cubemap_resource(.Space)

	dp := glc.dpd(&s.rs)
	dp.shader = glc.shader_program_resource(.Skybox)
	glc.draw(space, dp)

	dp.shader = glc.shader_program_resource(.Simple_Texture)
	dp.model_matrix = data.planet_model_matrix
	glc.draw(planet, &dp)

	dp.shader = glc.shader_program_resource(.Instancing_Model)
	dp.num_instances = NUM_ASTEROIDS
	glc.draw(asteroid, &dp)
}
