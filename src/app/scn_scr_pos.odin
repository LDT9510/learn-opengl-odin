#+private file
package app

import "main:glc"
import mod "main:modules"

import gl "vendor:OpenGL"

@(private)
SCENE_SCRN_POS :: Scene {
	"Screen position",
	"Showcases sceen dependant position drawing",
	nil,
	setup,
	draw,
	nil_scn_proc,
	false,
}

setup :: proc(s: ^State, data: rawptr) {
	s.app.camera = mod.camera_create(pos = {2.3, 0.2, 5.0}, yaw = -106, pitch = -7)
}

draw :: proc(s: ^State, _data: rawptr) {
	// disable to see the back face modified by `gl_FrontFacing`
	gl.Disable(gl.CULL_FACE)

	cube := glc.primitive_resource(.Cube)
	shader := glc.shader_program_resource(.Window_Relative)
	dp := glc.dpd(&s.rs)
	dp.shader = shader
	glc.shader_use_program(dp.shader)

	glc.draw(cube, &dp)
}
