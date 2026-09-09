#+private file
package app

import "main:glc"
import mod "main:modules"

@(private)
SCENE_SIMPLE_MODEL := scene(
	"Simple Model",
	"Showcasing model drawing and normals using geometry shaders",
	setup,
	draw,
)

setup :: proc(s: ^State) {
	s.app.camera = mod.camera_create(pos = {1.9, 3.0, 17.8}, yaw = -95, pitch = -11)
}

draw :: proc(s: ^State) {
	model := glc.model_resource(.Backpack)
	dp := glc.dpd(&s.rs)
	dp.shader = glc.shader_program_resource(.Simple_Texture)

	glc.draw(model, &dp)

	dp.translation.x = -6.0
	dp.effect = .Normals
	glc.draw(model, &dp)
}
