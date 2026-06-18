// Specify a triangle offset and move it on the screen

package learn_opengl

import "core:log"
import "core:mem"
import "core:sys/windows"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

import im "extern:imgui"
import "lib:devui"
import glc "lib:glcore"

// avoids unused import error when ODIN_DEBUG is 0
_ :: mem

State :: struct {
	use_wireframe:        bool,
	program_should_close: bool,
	horizontal_offset:    f32,
}
g_state: State

// odinfmt: disable
g_vertices := [?]f32 {
     // positions     // colors
     0.5, -0.5, 0.0,  1.0, 0.0, 0.0,  // bottom right
    -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  // bottom let
     0.0,  0.5, 0.0,  0.0, 0.0, 1.0,  // top
}
// odinfmt: enable

main :: proc() {
	when ODIN_OS == .Windows {
		windows.SetProcessDPIAware()
	}

	cl := log.create_console_logger(opt = {.Level})
	context.logger = cl

	when ODIN_DEBUG {
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
		defer glc.reset_tracking_allocator()
		log.info("Debug mode")
	}

	glc.print_sdl_version()

	window, gl_ctx := glc.create_opengl_window()
	defer glc.destroy_opengl_window(window, gl_ctx)

	devui.init_for_sdl_window(window, gl_ctx)
	defer devui.destroy()

	shader_program :=
		glc.shader_load_from_files("horizontal_offset", "basic") or_else glc.crash(
			"Error loading shaders",
		)
	defer glc.shader_delete_program(shader_program)

	vbo, vao: u32

	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(g_vertices), &g_vertices, gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 0) // position
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 3 * size_of(f32)) // color
	gl.EnableVertexAttribArray(1)

	gl.BindVertexArray(0)

	for !g_state.program_should_close {
		handle_events()

		gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		glc.shader_use_program(shader_program)
		glc.shader_uniform_set(shader_program, "horizontal_offset", g_state.horizontal_offset)

		gl.BindVertexArray(vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		devui.render_ui("Learning OpenGL", ui_render, ui_render_shortcuts)

		sdl.GL_SwapWindow(window)
	}
}

ui_render :: proc() {
	im.SliderFloat("Horizontal Offset", &g_state.horizontal_offset, -0.5, 0.5)
}

ui_render_shortcuts :: proc() {
	devui.shortcut("ESC", "Close program")
	devui.shortcut("  U", "Enables wireframe mode")
}

process_key_inputs :: proc(keycode: sdl.Keycode) {
	switch keycode {
	case sdl.K_ESCAPE:
		g_state.program_should_close = true
	case sdl.K_U:
		g_state.use_wireframe = !g_state.use_wireframe
	}
}

handle_events :: proc() {
	e: sdl.Event = ---
	for sdl.PollEvent(&e) {
		devui.process_event(&e)

		#partial switch e.type {
		case .KEY_DOWN:
			process_key_inputs(e.key.key)
		case .QUIT:
			g_state.program_should_close = true
		case .WINDOW_PIXEL_SIZE_CHANGED:
			gl.Viewport(0, 0, e.window.data1, e.window.data2)
		}
	}
}
