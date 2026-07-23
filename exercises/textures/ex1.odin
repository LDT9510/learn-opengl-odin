// Make the happy face texture look the other direction (fragment shader)

package learn_opengl

import "core:log"
import "core:mem"
import "core:sys/windows"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"
import stbi "vendor:stb/image"

import "lib:devui"
import glc "lib:glcore"

// avoids unused import error when ODIN_DEBUG is 0
_ :: mem

State :: struct {
	use_wireframe:        bool,
	program_should_close: bool,
}
g_state: State

// odinfmt: disable
g_vertices := [?]f32 {
     // positions      // colors        // texture coords
     0.5,  0.5, 0.0,   1.0, 0.0, 0.0,   1.0, 1.0,   // top right
     0.5, -0.5, 0.0,   0.0, 1.0, 0.0,   1.0, 0.0,   // bottom right
    -0.5, -0.5, 0.0,   0.0, 0.0, 1.0,   0.0, 0.0,   // bottom left
    -0.5,  0.5, 0.0,   1.0, 1.0, 0.0,   0.0, 1.0,    // top left
}

g_indices := [?]i32 {
	0, 1, 3,
	1, 2, 3,
}
// odinfmt: enable

main :: proc() {
	when ODIN_OS == .Windows {
		windows.SetProcessDPIAware()
	}

	cl := log.create_console_logger(opt = {.Level})
	context.logger = cl

	when ODIN_DEBUG {
		tracking_allocator := glc.create_tracking_allocator(context.allocator)
		defer glc.destroy_tracking_allocator(tracking_allocator)
		context.allocator = tracking_allocator

		tracking_temp_allocator := glc.create_tracking_allocator(context.temp_allocator)
		defer glc.destroy_tracking_allocator(tracking_temp_allocator, temp = true)
		context.temp_allocator = tracking_temp_allocator

		log.info("Debug mode")
	}

	glc.print_sdl_version()

	window, gl_ctx := glc.create_opengl_window()
	defer glc.destroy_opengl_window(window, gl_ctx)

	devui.init_for_sdl_window(window, gl_ctx)
	defer devui.destroy()

	shader_program :=
		glc.shader_load_from_files("main", "happy_face_look_other_way") or_else glc.crash(
			"Error loading shaders",
		)
	defer glc.shader_delete_program(shader_program)

	vbo, vao, ebo: u32

	gl.GenVertexArrays(1, &vao)
	defer gl.DeleteVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(g_vertices), &g_vertices, gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0) // position
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 3 * size_of(f32)) // color
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 6 * size_of(f32)) // texture coords
	gl.EnableVertexAttribArray(2)

	gl.GenBuffers(1, &ebo)
	defer gl.DeleteBuffers(1, &ebo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(g_indices), &g_indices, gl.STATIC_DRAW)

	gl.BindVertexArray(0)

	texture1, texture2: u32
	gl.GenTextures(1, &texture1)
	defer gl.DeleteTextures(1, &texture1)
	gl.BindTexture(gl.TEXTURE_2D, texture1)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	width, height, channels: i32
	data := stbi.load("content/images/container.jpg", &width, &height, &channels, 0)
	if data != nil {
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
		stbi.image_free(data)
	} else {
		glc.crash("Bad image")
	}

	gl.GenTextures(1, &texture2)
	defer gl.DeleteTextures(1, &texture2)
	gl.BindTexture(gl.TEXTURE_2D, texture2)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	stbi.set_flip_vertically_on_load(1)
	data = stbi.load("content/images/awesomeface.png", &width, &height, &channels, 0)
	if data != nil {
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
		stbi.image_free(data)
	} else {
		glc.crash("Bad image")
	}

	glc.shader_use_program(shader_program)
	glc.shader_uniform_set(shader_program, "texture1", 0)
	glc.shader_uniform_set(shader_program, "texture2", 1)


	for !g_state.program_should_close {
		handle_events()

		gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, texture1)
		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, texture2)

		glc.shader_use_program(shader_program)
		gl.BindVertexArray(vao)
		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

		devui.render_ui("Learning OpenGL", ui_render, ui_render_shortcuts)

		sdl.GL_SwapWindow(window)
	}
}

ui_render :: proc() {
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
