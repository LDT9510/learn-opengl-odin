package glcore

import "core:c"
import "core:log"

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

create_opengl_window :: proc() -> (window: ^sdl.Window, gl_ctx: sdl.GLContext) {
	if !sdl.Init({.VIDEO}) {
		crash("SDL: could not initialize: %s", sdl.GetError())
	}

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 3)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, cast(c.int)sdl.GL_CONTEXT_PROFILE_CORE)
	sdl.GL_SetAttribute(.DEPTH_SIZE, 24)
	sdl.GL_SetAttribute(.STENCIL_SIZE, 8)

	window = sdl.CreateWindow(
		"Learning OpenGL",
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		{.OPENGL, .RESIZABLE},
	)
	if window == nil {
		crash("SDL: could not create window: %s", sdl.GetError())
	}

	gl_ctx = sdl.GL_CreateContext(window)
	if gl_ctx == nil {
		crash("SDL: could not create OpenGL context: %s", sdl.GetError())
	}

	gl.load_up_to(3, 3, sdl.gl_set_proc_address)
	log.infof(
		"OpenGL: loaded OpenGL %d.%d Core Profile",
		gl.loaded_up_to_major,
		gl.loaded_up_to_minor,
	)

	loaded_renderer := gl.GetString(gl.RENDERER)
	log.infof("OpenGL: renderer %s", loaded_renderer)

	glsl_version := gl.GetString(gl.SHADING_LANGUAGE_VERSION)
	log.infof("OpenGL: GLSL version %s", glsl_version)

	max_attrs: i32
	gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &max_attrs)
	log.infof("OpenGL: Maximum number of vertex attributes supported: %d", max_attrs)

	gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

	return window, gl_ctx
}

window_get_resolution :: proc(window: ^sdl.Window) -> (f32, f32) {
	x, y: i32
	sdl.GetWindowSize(window, &x, &y)
	return cast(f32)x, cast(f32)y
}

window_get_aspect_ratio :: proc(window: ^sdl.Window) -> f32 {
	x, y := window_get_resolution(window)
	return x / y
}

destroy_opengl_window :: proc(window: ^sdl.Window, gl_context: sdl.GLContext) {
	sdl.DestroyWindow(window)
	sdl.GL_DestroyContext(gl_context)
	sdl.Quit()
}
