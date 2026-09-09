#+private file
package app

import "main:glc"
import mod "main:modules"

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

@(private)
SCENE_INSTANCING_ATTR := Scene {
	"Instanced boxes (vertex attr)",
	"Use instancing to draw many boxes using instancing with vertex attributes",
	&g_scene_data,
	setup,
	draw,
	destroy,
	false,
}

NUM_INSTANCES :: 100 // need to match the vertex shader
SIDE :: 10 // ~sqrt(NUM_INSTANCES)

Scene_Data :: struct {
	translations: [NUM_INSTANCES]glm.vec3,
	cube:         glc.Primitive,
	instance_vbo: u32,
}
g_scene_data: Scene_Data

destroy :: proc(s: ^State, data: rawptr) {
	data := scene_data(data, Scene_Data)
	glc.primitive_destroy(&data.cube)
	gl.DeleteBuffers(1, &data.instance_vbo)
}

setup :: proc(s: ^State, data: rawptr) {
	data := scene_data(data, Scene_Data)

	s.app.camera = mod.camera_create(pos = {7.3, 1.6, 42.3}, yaw = -90, pitch = -3)

	index := 0
	for y := -SIDE; y < SIDE; y += 2 {
		for x := -SIDE; x < SIDE; x += 2 {
			data.translations[index] = {f32(x), f32(y), 0.0}
			index += 1
		}
	}

	// do not use a resource for the cube because we write to the VAO
	data.cube = glc.primitive_create(.Cube)

	// new buffer
	gl.GenBuffers(1, &data.instance_vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, data.instance_vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		size_of(glm.vec3) * NUM_INSTANCES,
		&data.translations[0],
		gl.STATIC_DRAW,
	)

	// vertex attribute pointer config
	gl.BindVertexArray(data.cube.vao)
	gl.EnableVertexAttribArray(3)
	gl.BindBuffer(gl.ARRAY_BUFFER, data.instance_vbo)
	gl.VertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, size_of(glm.vec3), 0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.VertexAttribDivisor(3, 1) // this marks as an instance attribute
	gl.BindVertexArray(0)
}

draw :: proc(s: ^State, data: rawptr) {
	data := scene_data(data, Scene_Data)

	container_tex := glc.texture_resource(.Container)
	dp := glc.dpd(&s.rs)
	dp.shader = glc.shader_program_resource(.Instancing_Attr)
	dp.num_instances = len(data.translations)
	glc.draw(data.cube, &dp, container_tex)
}
