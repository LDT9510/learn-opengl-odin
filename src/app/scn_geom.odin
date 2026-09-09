#+private file
package app

import "main:glc"

@(private)
SCENE_GEOMETRY := scene("Geometry Shaders", "Use geometry shaders to draw 2D houses", setup, draw)


setup :: proc(s: ^State) {}

draw :: proc(s: ^State) {
	points := glc.primitive_resource(.Points)
	glc.draw(points, glc.shader_program_resource(.Geometry_Demo))
}
