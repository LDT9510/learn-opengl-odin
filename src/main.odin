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

State :: struct {
	use_wireframe:         bool,
	program_should_close:  bool,
	camera:                glc.Camera,
	window:                ^sdl.Window,
	is_capturing_mouse:    bool,
	should_reload_shaders: bool,
	show_ui:               bool,
	lights:                glc.Lights,
}
g_state: State

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
		camera = glc.camera_create(pos = {-6, -0.5, 7}, yaw = 315, pitch = 0),
		is_capturing_mouse = false,
		show_ui = true,
		lights = {
			background_color = {0.05, 0.05, 0.05},
			// directional = {
			// 	direction = {-0.2, -1.0, -0.3},
			// 	props = {color = 1.0, ambient = 0.2, diffuse = 0.5, specular = 1.0},
			// },
			// spot = {
			// 	att = {constant = 1.0, linear = 0.09, quadratic = 0.032},
			// 	props = {color = 1.0, ambient = 0.1, diffuse = 0.8, specular = 1.0},
			// 	cutoff_rad = glm.radians_f32(12.0),
			// 	outer_cutoff_rad = glm.radians_f32(17.0),
			// },
		},
	}

	gl_ctx: sdl.GLContext
	g_state.window, gl_ctx = glc.create_opengl_window()
	defer glc.destroy_opengl_window(g_state.window, gl_ctx)

	devui.init_for_sdl_window(g_state.window, gl_ctx)
	defer devui.destroy()

	model_shader := glc.shader_load_from_files("model_load") or_else panic("Error loading shaders")
	defer glc.shader_delete_program(model_shader)

	model := glc.model_load("backpack")
	defer glc.model_delete(&model)

	gl.Enable(gl.DEPTH_TEST)

	free_all(context.temp_allocator)

	for !g_state.program_should_close {
		glc.events_handle(process_events, process_key_input)
		glc.timing_update_delta_time()

		gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

		r, g, b := expand_values(g_state.lights.background_color)
		gl.ClearColor(r, g, b, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		if g_state.should_reload_shaders {
			log.info("Reloading shaders...")
			defer log.info("Done!")

			g_state.should_reload_shaders = false
			glc.shader_delete_program(model_shader)
			model_shader =
				glc.shader_load_from_files("model_load") or_else panic("Error reloading shaders")
		}

		view := glc.camera_get_view_matrix(g_state.camera)
		proj := glm.mat4Perspective(
			glm.radians(g_state.camera.zoom),
			glc.window_get_aspect_ratio(g_state.window),
			0.1,
			100.0,
		)

		glc.shader_use_program(model_shader)
		glc.shader_uniform_set(model_shader, "u_view", &view)
		glc.shader_uniform_set(model_shader, "u_projection", &proj)

		model_mat := glm.mat4Translate(0)
		model_mat *= glm.mat4Scale(1)
		glc.shader_uniform_set(model_shader, "u_model", &model_mat)

		glc.model_draw(model, model_shader)

		if g_state.show_ui {
			devui.render_ui("Learning OpenGL", ui_render, ui_render_shortcuts)
		}

		sdl.GL_SwapWindow(g_state.window)

		free_all(context.temp_allocator)
	}
}

ui_render :: proc() {
	glc.camera_dev_ui_frame(&g_state.camera)

	if im.CollapsingHeader("Lights") {
		im.ColorEdit3("Background", &g_state.lights.background_color)

		// if im.TreeNode("Directional") {
		// 	defer im.TreePop()
		//
		// 	dir_light := &g_state.lights.directional
		// 	im.DragFloat3("Direction", &dir_light.direction, 0.1, -4.0, 4.0)
		// 	props_render(&dir_light.props)
		// }
		// if im.TreeNode("Points") {
		// 	defer im.TreePop()
		// 	for i in 0 ..< MAX_POINT_LIGHTS {
		// 		if im.TreeNode(fmt.ctprintf("Point %d", i)) {
		// 			defer im.TreePop()
		//
		// 			point_light := &g_state.lights.point[i]
		// 			im.DragFloat3("Position", &point_light.position, 0.1, -4.0, 4.0)
		// 			props_render(&point_light.props)
		// 			att_render(&point_light.att)
		// 		}
		// 	}
		// }
		// if im.TreeNode("Spot") {
		// 	defer im.TreePop()
		//
		// 	spot_light := &g_state.lights.spot
		// 	im.SliderAngle("Cutoff Angle", &spot_light.cutoff_rad, 12.0, 16.0)
		// 	im.SliderAngle("Outer Cutoff Angle", &spot_light.outer_cutoff_rad, 17.0, 25.0)
		//
		// 	props_render(&spot_light.props)
		// 	att_render(&spot_light.att)
		// }
	}

	if im.Button("Reload Shaders") {
		g_state.should_reload_shaders = true
	}

	// ----------------- UI helpers ---------------------------
	// props_render :: proc(props: ^Light_Props) {
	// 	im.ColorEdit3("Color", &props.color)
	// 	im.DragFloat("Ambient", &props.ambient, 0.01, 0.0, 1.0)
	// 	im.DragFloat("Diffuse", &props.diffuse, 0.01, 0.0, 1.0)
	// 	im.DragFloat("Specular", &props.specular, 0.01, 0.0, 1.0)
	// }
	//
	// att_render :: proc(att: ^Light_Attenuation) {
	// 	im.DragFloat("Constant", &att.constant, 0.01, 0.01, 1.0)
	// 	im.DragFloat("Linear", &att.linear, 0.01, 0.01, 1.0)
	// 	im.DragFloat("Quadratic", &att.quadratic, 0.01, 0.01, 1.0)
	// }
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
	case glc.events_is_key_just_pressed(.I):
		g_state.show_ui = !g_state.show_ui
	case glc.events_is_key_just_pressed(.R):
		g_state.should_reload_shaders = true
	}

	glc.camera_handle_input(&g_state.camera)
}
