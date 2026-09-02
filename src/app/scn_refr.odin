#+private file
package app

import "main:glc"

@(private)
SCENE_REFR :: Scene {
	"Reflect and Refract",
	"Reflective and refractive cubes, backpack with cubemap",
	nil,
	nil_scn_proc,
	draw,
	nil_scn_proc,
	false,
}

draw :: proc(s: ^State, _data: rawptr) {
	dp := glc.dpd(&s.rs)

	refract_shader := glc.shader_program_resource(.Refraction)
	glc.shader_use_program(refract_shader)
	glc.shader_uniform_set(refract_shader, "u_camera_position", s.app.camera.position)

	reflect_shader := glc.shader_program_resource(.Reflection)
	glc.shader_use_program(reflect_shader)
	glc.shader_uniform_set(reflect_shader, "u_camera_position", s.app.camera.position)

	dp_sky := glc.dpd(&s.rs)
	dp_sky.shader = glc.shader_program_resource(.Skybox)

	glc.draw(glc.cubemap_resource(.Sky), dp_sky)
	dp.shader = refract_shader
	dp.translation = {-2.0, 0.0, 0.0}
	glc.draw(glc.primitive_resource(.Cube), &dp)

	dp.translation = {0.0, 0.0, 0.0}
	dp.scale = 0.4
	glc.draw(glc.model_resource(.Backpack), &dp)

	dp.translation = {2.0, 0.0, 0.0}
	dp.shader = refract_shader
	dp.scale = 1.0
	glc.draw(glc.primitive_resource(.Cube), &dp)

	dp.shader = reflect_shader
	dp.translation = {-2.0, 2.0, 1.0}
	glc.draw(glc.primitive_resource(.Cube), &dp)

	dp.translation = {0.0, 2.0, 1.0}
	dp.scale = 0.4
	glc.draw(glc.model_resource(.Backpack), &dp)

	dp.translation = {2.0, 2.0, 1.0}
	dp.shader = reflect_shader
	dp.scale = 1.0
	glc.draw(glc.primitive_resource(.Cube), &dp)
}
