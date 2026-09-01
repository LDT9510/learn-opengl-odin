#+private file
package app

import "main:glc"

import "core:slice"
import glm "core:math/linalg/glsl"

@(private)
SCENE_GRASS_N_WIN :: Scene {
	"Grass and Windows",
	"Showcasing blending",
	nil,
	nil_scn_proc,
	draw,
	false,
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

draw :: proc(s: ^State, _data: rawptr) {
	plane := glc.primitive_resource(.Plane)
	quad := glc.primitive_resource(.Quad)

	plane_tex := glc.texture_resource(.Marble)
	grass_tex := glc.texture_resource(.Grass)
	window_tex := glc.texture_resource(.Transparent_Window)

	shader := glc.shader_program_resource(.Simple_Texture)

	dp := glc.dpd(&s.rs)
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
