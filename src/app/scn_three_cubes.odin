#+private file
package app

import "main:glc"

@(private)
SCENE_THREE_CUBES :: Scene {
	"Three Cubes",
	"Outlined cubes in a plane, and a floating cube showing normals",
	nil,
	nil_scn_proc,
	draw,
	nil_scn_proc,
	false,
}

draw :: proc(s: ^State, _data: rawptr) {
	cube := glc.primitive_resource(.Cube)
	plane := glc.primitive_resource(.Plane)

	container_tex := glc.texture_resource(.Container)
	plane_tex := glc.texture_resource(.Marble)

	shader := glc.shader_program_resource(.Simple_Texture)

	dp := glc.dpd(&s.rs)
	dp.shader = shader
	glc.shader_use_program(dp.shader)

	dp_sky := glc.dpd(&s.rs)
	dp_sky.shader = glc.shader_program_resource(.Skybox)
	glc.draw(glc.cubemap_resource(.Sky), dp_sky)

	dp.translation.xy = {0.0, -0.01}
	glc.draw(plane, &dp, plane_tex)

	dp.translation.xy = {0.0, 0.0}
	dp.effect = .Outline
	glc.draw(cube, &dp, container_tex)

	dp.translation.xy = {3.0, 0.0}
	dp.effect = .Outline
	glc.draw(cube, &dp, container_tex)

	dp.translation.xy = {-3.0, 1.0}
	dp.effect = .Normals
	glc.draw(cube, &dp, container_tex)
}
