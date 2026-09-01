#+private file
package app

import "main:glc"

import gl "vendor:OpenGL"

@(private)
SCENE_SCRN_POS :: Scene {
	"Screen position",
	"Showcases sceen dependant position drawing",
	nil,
	nil_scn_proc,
	draw,
	false,
}

draw :: proc(s: ^State, _data: rawptr) {
	// disable to see the back face modified by `gl_FrontFacing`
	gl.Disable(gl.CULL_FACE)

	cube := glc.primitive_resource(.Cube)
	shader := glc.shader_program_resource(.Win_Rel)
	dp := glc.dpd(&s.rs)
	dp.shader = shader
	glc.shader_use_program(dp.shader)

	glc.draw(cube, &dp)
}
