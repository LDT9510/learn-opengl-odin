#+private file
package app

import "main:glc"
import mod "main:modules"

import "core:fmt"
import glm "core:math/linalg/glsl"

@(private)
SCENE_INSTANCING := scene(
	"Instanced boxes",
	"Use instancing to draw many boxes with a single draw call",
	setup,
	draw,
)

NUM_INSTANCES :: 100 // need to match the vertex shader
SIDE :: 10 // ~sqrt(NUM_INSTANCES)

g_data : struct {
	translations: [NUM_INSTANCES]glm.vec3,
}

setup :: proc(s: ^State) {
	s.app.camera = mod.camera_create(pos = {7.3, 1.6, 42.3}, yaw = -90, pitch = -3)

	index := 0
	for y := -SIDE; y < SIDE; y += 2 {
		for x := -SIDE; x < SIDE; x += 2 {
			g_data.translations[index] = {f32(x), f32(y), 0.0}
			index += 1
		}
	}
}

draw :: proc(s: ^State) {
	cube := glc.primitive_resource(.Cube)
	container_tex := glc.texture_resource(.Container)
	dp := glc.dpd(&s.rs)

	dp.shader = glc.shader_program_resource(.Instancing)
	glc.shader_use_program(dp.shader)
	for i in 0 ..< len(g_data.translations) {
		glc.shader_uniform_set(dp.shader, fmt.ctprintf("u_offsets[%d]", i), g_data.translations[i])
	}

	dp.num_instances = len(g_data.translations)
	glc.draw(cube, &dp, container_tex)
}
