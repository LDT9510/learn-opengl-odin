package app

import "main:glc"

import "core:slice"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

@(rodata)
SCENE_REGISTRY := [Scene_Index]Scene {
	.Empty                        = {"Empty", proc(_: ^State) {}},
	.Reflection_and_Refraction    = {
		"Reflective and refractive cubes, backpack with cubemap",
		refr_cubes_and_backpack,
	},
	.Outlined_Cubes_Plane_Windows = {
		"Outlined cubes in a plane with transparent windows and grass",
		cubes_in_plane,
	},
	.Many_Cubes                   = {"Many Cubes", many_cubes},
	.Grass_And_Windows            = {"Grass and transparent windows", grass_and_windows},
	.Simple_Model                 = {"Simple Model", simple_model},
	.Window_Relative              = {
		"Color specific to screen space position",
		windows_relative_colors,
	},
}

Scene_Index :: enum {
	Empty,
	Reflection_and_Refraction,
	Outlined_Cubes_Plane_Windows,
	Many_Cubes,
	Grass_And_Windows,
	Simple_Model,
	Window_Relative,
}

Scene :: struct {
	name:      cstring,
	draw_proc: proc(s: ^State),
}

@(private)
refr_cubes_and_backpack :: proc(s: ^State) {
	dp := glc.draw_params_default(&s.rs)

	refract_shader := glc.shader_program_resource(.Refraction)
	glc.shader_use_program(refract_shader)
	glc.shader_uniform_set(refract_shader, "u_camera_position", s.app.camera.position)

	reflect_shader := glc.shader_program_resource(.Reflection)
	glc.shader_use_program(reflect_shader)
	glc.shader_uniform_set(reflect_shader, "u_camera_position", s.app.camera.position)

	dp_sky := glc.draw_params_default(&s.rs)
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

@(private)
cubes_in_plane :: proc(s: ^State) {
	cube := glc.primitive_resource(.Cube)
	plane := glc.primitive_resource(.Plane)

	container_tex := glc.texture_resource(.Container)
	plane_tex := glc.texture_resource(.Marble)

	shader := glc.shader_program_resource(.Simple_Texture)

	dp := glc.draw_params_default(&s.rs)
	dp.shader = shader
	glc.shader_use_program(dp.shader)

	dp_sky := glc.draw_params_default(&s.rs)
	dp_sky.shader = glc.shader_program_resource(.Skybox)
	glc.draw(glc.cubemap_resource(.Sky), dp_sky)

	dp.translation.x = 0.0
	dp.translation.y = -0.01
	dp.outline.use = false
	glc.draw(plane, &dp, plane_tex)

	dp.translation.x = -2.0
	dp.outline.use = true
	glc.draw(cube, &dp, container_tex)

	dp.translation.x = 1.0
	dp.translation.z = 1.0
	glc.draw(cube, &dp, container_tex)
}

@(private)
many_cubes :: proc(s: ^State) {
	tex := glc.texture_resource(.Container)
	cube := glc.primitive_resource(.Cube)
	shader := glc.shader_program_resource(.Simple_Texture)

	dp_sky := glc.draw_params_default(&s.rs)
	dp_sky.shader = glc.shader_program_resource(.Skybox)
	glc.draw(glc.cubemap_resource(.Sky), dp_sky)

	dp := glc.draw_params_default(&s.rs)
	dp.shader = shader
	glc.shader_use_program(dp.shader)

	// 3x3 cube matrix
	// do some animation
	gap := abs(glm.sin(timing_get_elapsed_seconds())) + 1.0
	side := 5
	for i in 0 ..< side * side * side {
		x := i % side
		y := (i / side) % side
		z := i / (side * side)
		dp.translation = {f32(x) * gap, f32(y) * gap, f32(z) * gap}
		glc.draw(cube, &dp, tex)
	}
}

Window_Position :: struct {
	distance_to_camera: f32,
	position:           glm.vec3,
}
// odinfmt: disable
window_positions := [?]Window_Position {
	{0.0, {-1.5,  0.0, -0.48},},
	{0.0, { 1.5,  0.0,  0.51},},
	{0.0, { 0.0,  0.0,  0.7},},
    {0.0, {-0.3,  0.0, -2.3},},
    {0.0, { 0.5,  0.0, -0.6},},
}
// odinfmt: enable

@(private)
grass_and_windows :: proc(s: ^State) {
	plane := glc.primitive_resource(.Plane)
	quad := glc.primitive_resource(.Quad)

	plane_tex := glc.texture_resource(.Marble)
	grass_tex := glc.texture_resource(.Grass)
	window_tex := glc.texture_resource(.Transparent_Window)

	shader := glc.shader_program_resource(.Simple_Texture)

	dp := glc.draw_params_default(&s.rs)
	dp.shader = shader
	glc.shader_use_program(dp.shader)

	dp.translation.x = 0.0
	dp.translation.y = -0.01
	glc.draw(plane, &dp, plane_tex)

	for i in 0 ..< 20 {
		dp.translation.x = (f32(i % 5) + f32(i % 2) * 0.5) - 3.0
		dp.translation.z = f32(i / 5) + f32(i % 2) * 0.5
		glc.draw(quad, &dp, grass_tex)
	}

	// sort by distance (farthest to closest)
	for &wp in window_positions {
		// can also use glm.dot here and reverse the comparison during sorting
		wp.distance_to_camera = glm.distance(s.app.camera.position, wp.position)
	}
	slice.sort_by(window_positions[:], proc(i, j: Window_Position) -> bool {
		return i.distance_to_camera > j.distance_to_camera
	})

	for wp in window_positions {
		dp.translation = wp.position
		glc.draw(quad, &dp, window_tex)
	}
}

@(private)
simple_model :: proc(s: ^State) {
	model := glc.model_resource(.Backpack)
	shader := glc.shader_program_resource(.Simple_Texture)
	dp := glc.draw_params_default(&s.rs)
	dp.shader = shader
	glc.shader_use_program(dp.shader)

	glc.draw(model, &dp)
}

@(private)
windows_relative_colors :: proc(s: ^State) {
	// disable to see the back face modified by `gl_FrontFacing` 
	gl.Disable(gl.CULL_FACE)

	cube := glc.primitive_resource(.Cube)
	shader := glc.shader_program_resource(.Win_Rel)
	dp := glc.draw_params_default(&s.rs)
	dp.shader = shader
	glc.shader_use_program(dp.shader)

	glc.draw(cube, &dp)
}
