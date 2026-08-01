package learn_opengl

@(require) import "core:mem"
import "core:log"
import "core:sys/windows"
import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"
import im "extern:imgui"

import "lib:devui"
import glc "lib:glcore"

MAIN_SHADER_NAME :: "model_load"

g_state: struct {
	use_wireframe:         bool,
	wireframe_toggled:     bool,
	program_should_close:  bool,
	camera:                glc.Camera,
	window:                ^sdl.Window,
	is_capturing_mouse:    bool,
	should_reload_shaders: bool,
	show_ui:               bool,
	background_color:      glm.vec3,
	shader_program:        glc.Shader_Program_Handle,
} = {
	camera             = glc.camera_create(pos = {-5, 0.5, 7}, yaw = 315, pitch = 0),
	is_capturing_mouse = false,
	show_ui            = true,
	background_color   = {0.05, 0.05, 0.05},
}

main :: proc() {
	when ODIN_OS == .Windows {
		windows.SetProcessDPIAware()
	}

	when ODIN_DEBUG {
		tracking_allocator := glc.create_tracking_allocator(context.allocator)
		defer glc.destroy_tracking_allocator(tracking_allocator)
		context.allocator = tracking_allocator

		tracking_temp_allocator := glc.create_tracking_allocator(context.temp_allocator)
		defer glc.destroy_tracking_allocator(tracking_temp_allocator, temp = true)
		context.temp_allocator = tracking_temp_allocator

		log.info("Debug mode")
	}

	cl := log.create_console_logger(opt = {.Level})
	defer log.destroy_console_logger(cl)
	context.logger = cl

	glc.print_sdl_version()

	gl_ctx: sdl.GLContext
	g_state.window, gl_ctx = glc.create_opengl_window()
	defer glc.destroy_opengl_window(g_state.window, gl_ctx)

	devui.init_for_sdl_window(g_state.window, gl_ctx)
	defer devui.destroy()

	defer glc.model_unload_loaded_textures_path()

	g_state.shader_program =
		glc.shader_load_from_files(MAIN_SHADER_NAME) or_else panic("Error loading shaders")
	defer glc.shader_delete_program(g_state.shader_program)

	model := glc.model_load("backpack")
	defer glc.model_delete(&model)

	gl.Enable(gl.DEPTH_TEST)

	free_all(context.temp_allocator)

	for !g_state.program_should_close {
		glc.events_handle(process_events, process_key_input)
		glc.timing_update_delta_time()

		gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

		gl.ClearColor(**g_state.background_color, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		if g_state.wireframe_toggled {
			g_state.wireframe_toggled = false
			fragment_name := g_state.use_wireframe ? "green" : MAIN_SHADER_NAME
			g_state.shader_program = glc.shader_reload(
				g_state.shader_program,
				MAIN_SHADER_NAME,
				fragment_name,
			)
		}

		if g_state.should_reload_shaders {
			g_state.should_reload_shaders = false
			log.info("Reloading shaders...")
			defer log.info("Done!")

			g_state.use_wireframe = false
			g_state.shader_program = glc.shader_reload(g_state.shader_program, MAIN_SHADER_NAME)
		}

		view := glc.camera_get_view_matrix(g_state.camera)
		proj := glm.mat4Perspective(
			glm.radians(g_state.camera.zoom),
			glc.window_get_aspect_ratio(g_state.window),
			0.1,
			100.0,
		)

		glc.shader_use_program(g_state.shader_program)
		glc.shader_uniform_set(g_state.shader_program, "u_view", &view)
		glc.shader_uniform_set(g_state.shader_program, "u_projection", &proj)

		model_mat := glm.mat4Translate(0)
		model_mat *= glm.mat4Scale(1)
		glc.shader_uniform_set(g_state.shader_program, "u_model", &model_mat)

		glc.model_draw(model, g_state.shader_program)

		if g_state.show_ui {
			devui.render_ui("Learning OpenGL", ui_render, ui_render_shortcuts)
		}

		sdl.GL_SwapWindow(g_state.window)

		free_all(context.temp_allocator)
	}
}

ui_render :: proc() {
	if im.CollapsingHeader("General") {
		im.ColorEdit3("Background Color", &g_state.background_color)
		im.Checkbox("Use wireframe", &g_state.use_wireframe)
		if im.Button("Reload Shaders") {
			g_state.should_reload_shaders = true
		}
		if im.Button("Hide UI") {
			g_state.show_ui = false
			im.UpdateHoveredWindowAndCaptureFlags(0)
		}
	}

	glc.camera_dev_ui_frame(&g_state.camera)
}

process_events :: proc(event: sdl.Event) {
	g_state.is_capturing_mouse = glc.events_is_mouse_button_pressed({.RIGHT})
	_ = sdl.SetWindowRelativeMouseMode(g_state.window, g_state.is_capturing_mouse)

	#partial switch event.type {
	case .QUIT:
		g_state.program_should_close = true
	case .WINDOW_PIXEL_SIZE_CHANGED:
		gl.Viewport(0, 0, event.window.data1, event.window.data2)
	case .MOUSE_WHEEL:
		glc.camera_on_mouse_wheel_scroll(&g_state.camera, event.wheel.y)
	case .MOUSE_MOTION:
		if g_state.is_capturing_mouse {
			glc.camera_on_mouse_move(&g_state.camera, event.motion.xrel, -event.motion.yrel, true)
		}
	}
}

ui_render_shortcuts :: proc() {
	devui.shortcut("ESC", "Close program")
	devui.shortcut("U", "Enables wireframe mode")
	devui.shortcut("I", "Toggle UI")
	devui.shortcut("R", "Reload shaders")
	devui.shortcut("(Shift +)WASD", "(Sprint) Camera move")
	devui.shortcut("Right click (hold)", "Look around")
}

process_key_input :: proc() {
	switch {
	case glc.events_is_key_just_pressed(.ESCAPE):
		g_state.program_should_close = true
	case glc.events_is_key_just_pressed(.U):
		g_state.use_wireframe = !g_state.use_wireframe
		g_state.wireframe_toggled = true
	case glc.events_is_key_just_pressed(.I):
		g_state.show_ui = !g_state.show_ui
	case glc.events_is_key_just_pressed(.R):
		g_state.should_reload_shaders = true
	}

	glc.camera_handle_input(&g_state.camera)
}
