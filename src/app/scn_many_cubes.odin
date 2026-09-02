#+private file
package app

import "main:glc"
import mod "main:modules"

import glm "core:math/linalg/glsl"

@(private)
SCENE_MANY_CUBES :: Scene {
	"Many Cubes",
	"Matrix of cubes with breathing effect",
	nil,
	nil_scn_proc,
	draw,
	nil_scn_proc,
	false,
}

draw :: proc(s: ^State, _data: rawptr) {
	tex := glc.texture_resource(.Container)
	cube := glc.primitive_resource(.Cube)
	shader := glc.shader_program_resource(.Simple_Texture)

	dp_sky := glc.dpd(&s.rs)
	dp_sky.shader = glc.shader_program_resource(.Skybox)
	glc.draw(glc.cubemap_resource(.Sky), dp_sky)

	dp := glc.dpd(&s.rs)
	dp.shader = shader
	glc.shader_use_program(dp.shader)

	// 3x3 cube matrix
	// do some animation
	gap := abs(glm.sin(mod.timing_get_elapsed_seconds())) + 1.0
	side := 5
	for i in 0 ..< side * side * side {
		x := i % side
		y := (i / side) % side
		z := i / (side * side)
		dp.translation = {f32(x) * gap, f32(y) * gap, f32(z) * gap}
		glc.draw(cube, &dp, tex)
	}
}
