// Upside down triangle

package learn_opengl

import "core:log"
import "core:mem"
import "core:sys/windows"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

import glc "lib:glcore"

// avoids unused import error when ODIN_DEBUG is 0
_ :: mem

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

	window := glc.create_opengl_window()
	defer glc.destroy_opengl_window(window)

	shader_program :=
		glc.shader_load_from_files("upside_down_triangle_vertex", "fragment") or_else glc.crash("Error loading shaders")
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

	should_close := false
	for !should_close {
		should_close = glc.handle_input()

		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		glc.shader_use_program(shader_program)

		gl.BindVertexArray(vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		sdl.GL_SwapWindow(window)
	}
}
