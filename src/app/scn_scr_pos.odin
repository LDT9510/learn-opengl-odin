#+private file
package app

import "main:glc"
import mod "main:modules"

import gl "vendor:OpenGL"

@(private)
SCENE_SCRN_POS := scene(
	"Screen position",
	"Showcases sceen dependant position drawing",
	setup,
	draw,
)

setup :: proc(s: ^State) {
	s.app.camera = mod.camera_create(pos = {2.3, 0.2, 5.0}, yaw = -106, pitch = -7)
}

draw :: proc(s: ^State) {
	// disable to see the back face modified by `gl_FrontFacing`
	gl.Disable(gl.CULL_FACE)

	cube := glc.primitive_resource(.Cube)
	shader := glc.shader_program_resource(.Window_Relative)
	dp := glc.dpd(&s.rs)
	dp.shader = shader
	glc.shader_use_program(dp.shader)

	glc.draw(cube, &dp)
}
