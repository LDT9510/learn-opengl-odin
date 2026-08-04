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

Depth_Function :: enum u32 {
	Always,
	Never,
	Less,
	Equal,
	// + others
}
@(rodata)
DEPTH_FUNCTION_NAMES := [?]cstring{"Always", "Never", "Less", "Equal"}

get_depth_test_function_value :: proc(func: Depth_Function) -> u32 {
	switch func {
	case .Always:
		return gl.ALWAYS
	case .Never:
		return gl.NEVER
	case .Less:
		return gl.LESS
	case .Equal:
		return gl.EQUAL
	}

	return 0
}

g_state: struct {
	use_wireframe:         bool,
	frustrum:              struct {
		near: f32,
		far:  f32,
	},
	wireframe_toggled:     bool,
	program_should_close:  bool,
	camera:                glc.Camera,
	window:                ^sdl.Window,
	is_capturing_mouse:    bool,
	should_reload_shaders: bool,
	show_ui:               bool,
	background_color:      glm.vec3,
	shader_program:        glc.Shader_Program_Handle,
	depth:                 struct {
		check_function:     Depth_Function,
		see_buffer:         bool,
		see_buffer_toggled: bool,
	},
} = {
	camera               = glc.camera_create(pos = {0.0, 0.0, 3.0}),
	frustrum             = {0.1, 100.0},
	is_capturing_mouse   = false,
	show_ui              = true,
	background_color     = {0.05, 0.05, 0.05},
	depth = {
		check_function = .Less,
	},
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

	gl.Enable(gl.DEPTH_TEST)

	cube := glc.primitive_create(.Cube, "marble.jpg")
	defer glc.primitive_destroy(&cube)
	plane := glc.primitive_create(.Plane, "metal.png")
	defer glc.primitive_destroy(&plane)

	for !g_state.program_should_close {
		glc.events_handle(process_events, process_key_input)
		glc.timing_update_delta_time()

		gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

		gl.DepthFunc(get_depth_test_function_value(g_state.depth.check_function))
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

		if g_state.depth.see_buffer_toggled {
			g_state.depth.see_buffer_toggled = false
			fragment_name := g_state.depth.see_buffer ? "depth_buffer_view" : MAIN_SHADER_NAME
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

			// to avoid this, keep both shader stages referenced globally
			g_state.use_wireframe = false
			g_state.depth.see_buffer = false
			g_state.shader_program = glc.shader_reload(g_state.shader_program, MAIN_SHADER_NAME)
		}

		view := glc.camera_get_view_matrix(g_state.camera)
		proj := glm.mat4Perspective(
			glm.radians(g_state.camera.zoom),
			glc.window_get_aspect_ratio(g_state.window),
			g_state.frustrum.near,
			g_state.frustrum.far,
		)

		glc.shader_use_program(g_state.shader_program)
		glc.shader_uniform_set(g_state.shader_program, "u_view", &view)
		glc.shader_uniform_set(g_state.shader_program, "u_projection", &proj)

		if g_state.depth.see_buffer {
			glc.shader_uniform_set(g_state.shader_program, "u_near", g_state.frustrum.near)
			glc.shader_uniform_set(g_state.shader_program, "u_far", g_state.frustrum.far)
		}

		glc.primitive_draw(cube, g_state.shader_program, {-1.0, 0.01, -1.0})
		glc.primitive_draw(cube, g_state.shader_program, {2.0, 0.01, 0.0})
		glc.primitive_draw(plane, g_state.shader_program, 0.0)

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
		if im.Checkbox("Use wireframe", &g_state.use_wireframe) {
			g_state.wireframe_toggled = true
		}
		im.DragFloat("Near Plane", &g_state.frustrum.near, 0.01, 0.1, 99.9)
		im.DragFloat("Far Plane", &g_state.frustrum.far, 1.0, 50.0, 150.0)
		if im.Button("Reload Shaders") {
			g_state.should_reload_shaders = true
		}
		if im.Button("Hide UI") {
			g_state.show_ui = false
			im.UpdateHoveredWindowAndCaptureFlags(0)
		}
	}

	glc.camera_dev_ui_frame(&g_state.camera)

	if im.CollapsingHeader("Depth testing") {
		depth_test_raw := cast(i32)g_state.depth.check_function
		if im.ComboCallback(
			"Test function",
			&depth_test_raw,
			get_depth_test_func_name,
			nil,
			len(Depth_Function),
		) {
			g_state.depth.check_function = cast(Depth_Function)depth_test_raw
		}

		if im.Checkbox("See depth buffer", &g_state.depth.see_buffer) {
			g_state.depth.see_buffer_toggled = true
		}
	}

	get_depth_test_func_name :: proc "c" (_user_data: rawptr, idx: i32) -> cstring {
		return DEPTH_FUNCTION_NAMES[idx]
	}

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
	devui.shortcut("D", "Toogle depth buffer view")
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
		g_state.depth.see_buffer = false
	case glc.events_is_key_just_pressed(.I):
		g_state.show_ui = !g_state.show_ui
	case glc.events_is_key_just_pressed(.R):
		g_state.should_reload_shaders = true
	case glc.events_is_key_just_pressed(.P):
		g_state.depth.see_buffer = !g_state.depth.see_buffer
		g_state.depth.see_buffer_toggled = true
		g_state.use_wireframe = false
	}

	glc.camera_handle_input(&g_state.camera)
}
