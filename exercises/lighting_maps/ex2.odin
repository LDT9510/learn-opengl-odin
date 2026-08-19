// Invert the colors of the specular map in the fragment shader
package learn_opengl

import "core:log"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:sys/windows"

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

import "../common/devui"
import glc "../common/glcore"

// avoids unused import error when ODIN_DEBUG is 0
_ :: mem

State :: struct {
	use_wireframe:        bool,
	program_should_close: bool,
	camera:               glc.Camera,
	window:               ^sdl.Window,
	is_capturing_mouse:   bool,
	show_ui:              bool,
}
g_state: State

// odinfmt: disable
@(rodata)
CUBE_VERTICES := [?]f32 {
	 // positions         // normals           // textures coords
    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,
     0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 0.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
    -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 1.0,
    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,

    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 0.0,
     0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 0.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
    -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 1.0,
    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 0.0,

    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,
    -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0, 1.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
    -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0, 0.0,
    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,

     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0, 1.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
     0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0, 0.0,
     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,

    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,
     0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0, 1.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
    -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0, 0.0,
    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,

    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0,
     0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0, 1.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
    -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0, 0.0,
    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0,
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

	// intial state
	g_state = {
		camera             = glc.camera_create(pos = {-3, 1, -2}, yaw = 44, pitch = -11),
		is_capturing_mouse = false,
		show_ui            = true,
	}

	gl_ctx: sdl.GLContext
	g_state.window, gl_ctx = glc.create_opengl_window()
	defer glc.destroy_opengl_window(g_state.window, gl_ctx)

	devui.init_for_sdl_window(g_state.window, gl_ctx)
	defer devui.deinit()

	lighting_shader :=
		glc.shader_load("main", "specular_inverted") or_else glc.crash(
			"Error loading shaders",
		)
	defer glc.shader_delete_program(lighting_shader)

	light_cube_shader :=
		glc.shader_load("light_cube") or_else glc.crash("Error loading shaders")
	defer glc.shader_delete_program(light_cube_shader)

	vbo, vao, light_vao: u32

	gl.GenVertexArrays(1, &vao)
	defer gl.DeleteVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(CUBE_VERTICES), &CUBE_VERTICES, gl.STATIC_DRAW)
	// positions
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)
	// normals
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 3 * size_of(f32))
	gl.EnableVertexAttribArray(1)
	// textures coords
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 6 * size_of(f32))
	gl.EnableVertexAttribArray(2)

	gl.BindVertexArray(0)

	gl.GenVertexArrays(1, &light_vao)
	defer gl.DeleteVertexArrays(1, &light_vao)
	gl.BindVertexArray(light_vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	// position
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	diffuse_map := glc.texture_load("crate_diffuse.png") or_else glc.crash("Error loading image")
	defer glc.texture_destroy(diffuse_map)
	specular_map := glc.texture_load("crate_specular.png") or_else glc.crash("Error loading image")
	defer glc.texture_destroy(specular_map)

	gl.Enable(gl.DEPTH_TEST)

	container_model := glm.mat4(1)

	light_pos := glm.vec3{1.2, 1.0, 2.0}
	light_cube_model := glm.mat4Translate(light_pos)
	light_cube_model *= glm.mat4Scale(0.2)

	free_all(context.allocator)

	for !g_state.program_should_close {
		glc.events_handle(process_events, process_key_input)
		glc.timing_update_delta_time()

		gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

		gl.ClearColor(0.0, 0.0, 0.0, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		view := glc.camera_get_view_matrix(g_state.camera)
		proj := glm.mat4Perspective(
			glm.radians(g_state.camera.zoom),
			glc.window_get_aspect_ratio(g_state.window),
			0.1,
			100.0,
		)

		light_color := glm.vec3(1)
		diffuse_color := light_color * glm.vec3(0.5)
		ambient_color := diffuse_color * glm.vec3(0.2)

		// container
		glc.shader_use_program(lighting_shader)
		glc.shader_uniform_set(lighting_shader, "model", &container_model)
		glc.shader_uniform_set(lighting_shader, "view", &view)
		glc.shader_uniform_set(lighting_shader, "projection", &proj)
		glc.shader_uniform_set(lighting_shader, "lightPos", light_pos)
		glc.shader_uniform_set(lighting_shader, "viewPos", g_state.camera.position)
		glc.shader_uniform_set(lighting_shader, "light.ambient", ambient_color)
		glc.shader_uniform_set(lighting_shader, "light.diffuse", diffuse_color)
		glc.shader_uniform_set(lighting_shader, "light.specular", 1.0, 1.0, 1.0)
		glc.shader_texture_sampler_set(lighting_shader, "material.diffuse", diffuse_map, 0)
		glc.shader_texture_sampler_set(lighting_shader, "material.specular", specular_map, 1)
		glc.shader_uniform_set(lighting_shader, "material.shininess", 32.0)
		gl.BindVertexArray(vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		// light
		glc.shader_use_program(light_cube_shader)
		glc.shader_uniform_set(light_cube_shader, "model", &light_cube_model)
		glc.shader_uniform_set(light_cube_shader, "view", &view)
		glc.shader_uniform_set(light_cube_shader, "projection", &proj)
		gl.BindVertexArray(light_vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		if (g_state.show_ui) {
			devui.render_ui("Learning OpenGL", ui_render, ui_render_shortcuts)
		}

		sdl.GL_SwapWindow(g_state.window)

		free_all(context.allocator)
	}
}

ui_render :: proc() {
	glc.camera_dev_ui_frame(&g_state.camera)
}

ui_render_shortcuts :: proc() {
	devui.shortcut("ESC", "Close program")
	devui.shortcut("U", "Enables wireframe mode")
	devui.shortcut("I", "Togle UI")
	devui.shortcut("(Shift +)WASD", "(Sprint) Camera move")
	devui.shortcut("Right click (hold)", "Look around")
}

process_events :: proc(event: sdl.Event) {
	if (glc.events_is_mouse_button_pressed({.RIGHT})) {
		g_state.is_capturing_mouse = true
	} else {
		g_state.is_capturing_mouse = false
	}
	_ = sdl.SetWindowRelativeMouseMode(g_state.window, g_state.is_capturing_mouse)

	#partial switch event.type {
	case .QUIT:
		g_state.program_should_close = true
	case .WINDOW_PIXEL_SIZE_CHANGED:
		gl.Viewport(0, 0, event.window.data1, event.window.data2)
	case .MOUSE_WHEEL:
		glc.camera_on_mouse_wheel_scroll(&g_state.camera, event.wheel.y)
	case .MOUSE_MOTION:
		if (g_state.is_capturing_mouse) {
			glc.camera_on_mouse_move(&g_state.camera, event.motion.xrel, -event.motion.yrel, true)
		}
	}
}

process_key_input :: proc() {
	switch {
	case glc.events_is_key_just_pressed(.ESCAPE):
		g_state.program_should_close = true
	case glc.events_is_key_just_pressed(.U):
		g_state.use_wireframe = !g_state.use_wireframe
	case glc.events_is_key_just_pressed(.I):
		g_state.show_ui = !g_state.show_ui
	}

	glc.camera_handle_input(&g_state.camera)
}
