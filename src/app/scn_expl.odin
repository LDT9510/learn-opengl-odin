#+private file
package app

import "main:glc"
import mod "main:modules"

import gl "vendor:OpenGL"

@(private)
SCENE_EXPLODING :: Scene {
	"Exploding objects",
	"Use geometry shaders to explode some objects",
	nil,
	nil_scn_proc,
	draw,
	nil_scn_proc,
	false,
}

draw :: proc(s: ^State, _data: rawptr) {
	// to see all the parts
	gl.Disable(gl.CULL_FACE)

	model := glc.model_resource(.Backpack)
	cube := glc.primitive_resource(.Cube)
	container_tex := glc.texture_resource(.Container)
	dp := glc.dpd(&s.rs)
	dp.shader = glc.shader_program_resource(.Exploding)
	glc.shader_uniform_set(dp.shader, "u_time", mod.timing_get_elapsed_seconds())

	glc.draw(model, &dp)

	dp.translation.y = 5.0
	glc.draw(cube, &dp, container_tex)
}
