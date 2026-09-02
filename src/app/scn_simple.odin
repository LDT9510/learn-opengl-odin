#+private file
package app

import "main:glc"

@(private)
SCENE_SIMPLE_MODEL :: Scene {
	"Simple Model",
	"Showcasing model drawing and normals using geometry shaders",
	nil,
	nil_scn_proc,
	draw,
	nil_scn_proc,
	false,
}

draw :: proc(s: ^State, _data: rawptr) {
	model := glc.model_resource(.Backpack)
	dp := glc.dpd(&s.rs)
	dp.shader = glc.shader_program_resource(.Simple_Texture)

	glc.draw(model, &dp)

	dp.translation.x = -6.0
	dp.effect = .Normals
	glc.draw(model, &dp)
}
