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

NUM_ASTEROIDS :: 1000 // need to match the vertex shader

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

	radius := f32(50.0)
	offset := f32(2.5)

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

	// trigger model loading
	// glc.model_resource(.Planet)
	// glc.model_resource(.Rock)
	// glc.cubemap_resource(.Space)

	// // do not use a resource for the cube because we write to the VAO
	// data.cube = glc.primitive_create(.Cube)
	// data.shader = glc.shader_program_resource(.Instancing_Attr)
	//
	// // new buffer
	// gl.GenBuffers(1, &data.instance_vbo)
	// gl.BindBuffer(gl.ARRAY_BUFFER, data.instance_vbo)
	// gl.BufferData(
	// 	gl.ARRAY_BUFFER,
	// 	size_of(glm.vec3) * NUM_ASTEROIDS,
	// 	&data.translations[0],
	// 	gl.STATIC_DRAW,
	// )
	//
	// // vertex attribute pointer config
	// gl.BindVertexArray(data.cube.vao)
	// gl.EnableVertexAttribArray(3)
	// gl.BindBuffer(gl.ARRAY_BUFFER, data.instance_vbo)
	// gl.VertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, size_of(glm.vec3), 0)
	// gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	// gl.VertexAttribDivisor(3, 1) // this marks as an instance attribute
	// gl.BindVertexArray(0)
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

	for m in data.asteroids_model_matrices {
		dp.model_matrix = m
		glc.draw(asteroid, &dp)
	}
}
