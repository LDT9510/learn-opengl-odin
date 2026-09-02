#+private file
package app

import "main:glc"

@private
SCENE_GEOMETRY :: Scene {
	"Geometry Shaders",
	"Use geometry shaders to draw 2D houses",
	nil,
	nil_scn_proc,
	draw,
	nil_scn_proc,
	false,
}

draw :: proc(s: ^State, _data: rawptr) {
	points := glc.primitive_resource(.Points)
	glc.draw(points, glc.shader_program_resource(.Geometry_Demo))
}
