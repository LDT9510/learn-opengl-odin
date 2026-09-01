#+private file
package app

import "main:glc"

import "core:fmt"
import glm "core:math/linalg/glsl"

@(private)
SCENE_INSTANCING := Scene {
	"Instanced boxes",
	"Use instancing to draw many boxes with a single draw call",
	&g_scene_data,
	setup,
	draw,
	false,
}

Scene_Data :: struct {
	translations: [100]glm.vec3,
	shader:       glc.Shader_Program,
}
g_scene_data: Scene_Data

setup :: proc(s: ^State, data: rawptr) {
	data := scene_data(data, Scene_Data)

	index := 0
	for y := -10; y < 10; y += 2 {
		for x := -10; x < 10; x += 2 {
			data.translations[index] = {f32(x), f32(y), 0.0}
			index += 1
		}
	}

	data.shader = glc.shader_program_resource(.Instancing)
	glc.shader_use_program(data.shader)
	for i in 0 ..< len(data.translations) {
		glc.shader_uniform_set(data.shader, fmt.ctprintf("u_offsets[%d]", i), data.translations[i])
	}
}

draw :: proc(s: ^State, data: rawptr) {
	data := scene_data(data, Scene_Data)

	cube := glc.primitive_resource(.Cube)
	container_tex := glc.texture_resource(.Container)
	dp := glc.dpd(&s.rs)
	dp.shader = data.shader
	dp.num_instances = len(data.translations)
	glc.draw(cube, &dp, container_tex)
}
