package glcore

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

handle_input :: proc() -> bool {
	@(static) use_wireframe := false

	e: sdl.Event = ---
	for sdl.PollEvent(&e) {
		#partial switch e.type {
		case .KEY_DOWN:
			if e.key.key == sdl.K_ESCAPE do return true
			if e.key.key == sdl.K_U do use_wireframe = !use_wireframe
		case .QUIT:
			return true
		case .WINDOW_PIXEL_SIZE_CHANGED:
			gl.Viewport(0, 0, e.window.data1, e.window.data2)
		}
	}

	gl.PolygonMode(gl.FRONT_AND_BACK, use_wireframe ? gl.LINE : gl.FILL)

	return false
}
