#+private file
package app

import "main:glc"
import mod "main:modules"

// import im "extern:imgui"

import glm "core:math/linalg/glsl"

import im "extern:imgui"

@(private)
SCENE_BLINN_PHONG := scene("Blinn Phong", "Showcasing Blinn-Phong rendering", setup, draw, ui)

g_data: struct {
	lights:             glc.Lights,
	blinn:              bool,
	linear_attenuation: bool,
}

// odinfmt: disable
@rodata
POINT_LIGHTS_INITIAL_POSITIONS := [?]glm.vec3 {
	{ 0.7,  0.2,  2.0},
	{ 2.3, 1.2, -4.0},
	{-4.0,  2.2, -5.0},
	{ 0.0,  0.0, -3.0},
}
// odinfmt: enable

setup :: proc(s: ^State) {
	s.app.camera = mod.camera_create(pos = {4.2, 3.1, 11.5}, yaw = -100, pitch = -17)
	g_data.lights = glc.lights_default(&POINT_LIGHTS_INITIAL_POSITIONS)
	g_data.blinn = true
	g_data.linear_attenuation = false
}

draw :: proc(s: ^State) {
	floor := glc.primitive_resource(.Plane)
	texture := glc.texture_resource(.Wood)
	shader := glc.shader_program_resource(.Blinn_Phong)

	glc.lights_set_uniforms(
		g_data.lights,
		shader,
		s.app.camera,
		g_data.blinn,
		s.rs.features.gamma_correction,
		g_data.linear_attenuation,
	)

	dp := glc.dpd(&s.rs)
	dp.shader = shader
	glc.draw(floor, &dp, texture)

	cube := glc.primitive_resource(.Cube)
	glc.lights_render_point_lights(g_data.lights, cube, &s.rs)
}

ui :: proc(s: ^State) {
	im.RadioButtonIntPtr("Phong", cast(^i32)&g_data.blinn, 0)
	im.SameLine()
	im.RadioButtonIntPtr("Blinn-Phong", cast(^i32)&g_data.blinn, 1)

	im.Text("Attenuation: ")
	im.SameLine()
	im.RadioButtonIntPtr("Linear", cast(^i32)&g_data.linear_attenuation, 0)
	im.SameLine()
	im.RadioButtonIntPtr("Quadratic", cast(^i32)&g_data.linear_attenuation, 1)
	glc.lights_dev_ui(&g_data.lights)
}
