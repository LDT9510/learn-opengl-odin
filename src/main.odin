package learn_opengl

@(require) import "core:mem"
@(require) import "core:fmt"
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

// global application state
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
	shaders:               struct {
		main:   glc.Shader_Program_Handle,
		border: glc.Shader_Program_Handle,
		quad:   glc.Shader_Program_Handle,
	},
	objects:               struct {
		cube:  glc.Primitive,
		plane: glc.Primitive,
	},
	depth:                 struct {
		check_function:     Depth_Function,
		see_buffer:         bool,
		see_buffer_toggled: bool,
	},
	stencil:               struct {
		border_size:        f32,
		border_color:       glm.vec3,
		should_draw_border: bool,
	},
} = {
	camera = glc.camera_create(pos = {0.0, 0.0, 3.0}),
	frustrum = {0.1, 100.0},
	is_capturing_mouse = false,
	show_ui = true,
	background_color = {0.05, 0.05, 0.05},
	depth = {check_function = .Less},
	stencil = {border_size = 0.1, border_color = {0.04, 0.28, 0.26}, should_draw_border = true},
}

Window_Position :: struct {
	distance_to_camera: f32,
	position:           glm.vec3,
}
// odinfmt: disable
window_positions := [?]Window_Position {
	{0.0, {-1.5,  0.0, -0.48},},
	{0.0, { 1.5,  0.0,  0.51},},
	{0.0, { 0.0,  0.0,  0.7},},
    {0.0, {-0.3,  0.0, -2.3},},
    {0.0, { 0.5,  0.0, -0.6},},
}
// odinfmt: enable


main :: proc() {
	// windows specific fix
	when ODIN_OS == .Windows {
		windows.SetProcessDPIAware()
	}

	// setup allocation
	when ODIN_DEBUG {
		tracking_allocator := glc.create_tracking_allocator(context.allocator)
		defer glc.destroy_tracking_allocator(tracking_allocator)
		context.allocator = tracking_allocator

		tracking_temp_allocator := glc.create_tracking_allocator(context.temp_allocator)
		defer glc.destroy_tracking_allocator(tracking_temp_allocator, temp = true)
		context.temp_allocator = tracking_temp_allocator

		fmt.eprintln("-------- Debug mode --------")
	}

	// setup logging
	cl := log.create_console_logger(opt = {.Level})
	defer log.destroy_console_logger(cl)
	context.logger = cl

	glc.print_sdl_version()

	// setup window
	gl_ctx: sdl.GLContext
	g_state.window, gl_ctx = glc.create_opengl_window()
	defer glc.destroy_opengl_window(g_state.window, gl_ctx)

	// setup developer UI
	devui.init_for_sdl_window(g_state.window, gl_ctx)
	defer devui.destroy()

	// load shaders
	g_state.shaders.main =
		glc.shader_load_from_files(MAIN_SHADER_NAME) or_else panic("Error loading shaders")
	defer glc.shader_delete_program(g_state.shaders.main)

	g_state.shaders.border =
		glc.shader_load_from_files(MAIN_SHADER_NAME, "colored_border") or_else panic(
			"Error loading shaders",
		)
	defer glc.shader_delete_program(g_state.shaders.border)

	g_state.shaders.quad =
		glc.shader_load_from_files("quad") or_else panic(
			"Error loading shaders",
		)
	defer glc.shader_delete_program(g_state.shaders.quad)

	// load models/primitives
	g_state.objects.cube = glc.primitive_create(.Cube, "container.jpg")
	defer glc.primitive_destroy(&g_state.objects.cube)
	g_state.objects.plane = glc.primitive_create(.Plane, "metal.png")
	defer glc.primitive_destroy(&g_state.objects.plane)

	// required when loading any model
	defer glc.model_unload_loaded_textures_path()

	// framebuffer setup
	framebuffer: u32
	gl.GenFramebuffers(1, &framebuffer)
	gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer)

	// use a texture for the color
	render_texture := glc.texture_load(glc.WINDOW_WIDTH, glc.WINDOW_HEIGHT)
	defer glc.texture_destroy(render_texture)
	screen_quad := glc.primitive_create(.Full_Quad, render_texture)
	defer glc.primitive_destroy(&screen_quad)

	// bind to framebuffer
	gl.BindTexture(gl.TEXTURE_2D, cast(u32)render_texture)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, cast(u32)render_texture, 0)

	// use a renderbuffer object for depth and stencil as there is no need to read back
	rbo: u32
	gl.GenRenderbuffers(1, &rbo)
	gl.BindRenderbuffer(gl.RENDERBUFFER, rbo)
	gl.RenderbufferStorage(
		gl.RENDERBUFFER,
		gl.DEPTH24_STENCIL8,
		glc.WINDOW_WIDTH,
		glc.WINDOW_HEIGHT,
	)
	// attach to framebuffer
	gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo)

	// check framebuffer
	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
		glc.crash("Framebuffer is not complete!")
	}
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)


	// main loop
	for !g_state.program_should_close {
		// setup frame, camera and event handling
		glc.events_handle(process_events, process_key_input)
		glc.timing_update_delta_time()

		// first pass (draw to texture)
		gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer)
		draw_main_scene()

		// second pass (draw to screen quad)
		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
		gl.ClearColor(1.0, 1.0, 1.0, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)
		gl.Disable(gl.DEPTH_TEST)
		glc.primitive_draw(screen_quad, g_state.shaders.quad)

		// render developer UI (always to screen)
		if g_state.show_ui {
			devui.render_ui("Learning OpenGL", ui_render, ui_render_shortcuts)
		}

		// frame end
		sdl.GL_SwapWindow(g_state.window)
		free_all(context.temp_allocator)
	}
}

draw_main_scene :: proc() {
	// depth setup
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(get_depth_test_function_value(g_state.depth.check_function))

	// stencil setup
	gl.Enable(gl.STENCIL_TEST)
	gl.StencilFunc(gl.ALWAYS, 1, 0xff)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.REPLACE)
	gl.StencilMask(0xff)

	// blending setup
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	// the vertex data must support this, 3D applications consistently
	// use CCW winding order, do keep track of objects that shouln't be culled,
	// like flat quads (the grass)
	// face culling setup
	gl.Enable(gl.CULL_FACE)
	gl.CullFace(gl.BACK) // default
	gl.FrontFace(gl.CCW) // default

	gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

	gl.ClearColor(**g_state.background_color, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

	handle_view_modes()

	view := glc.camera_get_view_matrix(g_state.camera)
	proj := glm.mat4Perspective(
		glm.radians(g_state.camera.zoom),
		glc.window_get_aspect_ratio(g_state.window),
		g_state.frustrum.near,
		g_state.frustrum.far,
	)

	// rendering
	glc.shader_use_program(g_state.shaders.main)
	glc.shader_uniform_set(g_state.shaders.main, "u_view", &view)
	glc.shader_uniform_set(g_state.shaders.main, "u_projection", &proj)

	if g_state.depth.see_buffer {
		glc.shader_uniform_set(g_state.shaders.main, "u_near", g_state.frustrum.near)
		glc.shader_uniform_set(g_state.shaders.main, "u_far", g_state.frustrum.far)
	}

	// floor
	gl.StencilMask(0x00)
	gl.Disable(gl.CULL_FACE)
	glc.primitive_draw(g_state.objects.plane, g_state.shaders.main, 0.0)

	// cubes
	gl.StencilMask(0xff)
	gl.Disable(gl.CULL_FACE)
	glc.primitive_draw(g_state.objects.cube, g_state.shaders.main, {2.0, 0.01, 0.0})
	glc.primitive_draw(g_state.objects.cube, g_state.shaders.main, {-1.0, 0.01, -1.0})

	// cubes outlines
	if g_state.stencil.should_draw_border & !g_state.use_wireframe {
		gl.StencilMask(0x00)
		gl.StencilFunc(gl.NOTEQUAL, 1, 0xff)
		defer gl.StencilFunc(gl.ALWAYS, 1, 0xff)

		glc.shader_use_program(g_state.shaders.border)
		glc.shader_uniform_set(g_state.shaders.border, "u_view", &view)
		glc.shader_uniform_set(g_state.shaders.border, "u_projection", &proj)
		glc.shader_uniform_set(
			g_state.shaders.border,
			"u_border_color",
			g_state.stencil.border_color,
		)
		glc.primitive_draw(
			g_state.objects.cube,
			g_state.shaders.border,
			{-1.0, 0.01, -1.0},
			1.0 + g_state.stencil.border_size,
		)
		glc.primitive_draw(
			g_state.objects.cube,
			g_state.shaders.border,
			{2.0, 0.01, 0.0},
			1.0 + g_state.stencil.border_size,
		)
	}


	gl.BindVertexArray(0)
}

// ------------------------ helpers and utilities ------------------------

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

	if im.CollapsingHeader("Border (using Stencil)") {
		im.ColorEdit3("Color", &g_state.stencil.border_color)
		im.DragFloat("Size", &g_state.stencil.border_size, 0.01, 0.02, 0.3)
		im.Checkbox("Show", &g_state.stencil.should_draw_border)
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
	devui.shortcut("P", "Toogle depth buffer view")
	devui.shortcut("B", "Toogle colored border")
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
	case glc.events_is_key_just_pressed(.B):
		g_state.stencil.should_draw_border = !g_state.stencil.should_draw_border
	}

	glc.camera_handle_input(&g_state.camera)
}

handle_view_modes :: proc() {
	if g_state.wireframe_toggled {
		g_state.wireframe_toggled = false
		fragment_name := g_state.use_wireframe ? "green" : MAIN_SHADER_NAME
		g_state.shaders.main = glc.shader_reload(
			g_state.shaders.main,
			MAIN_SHADER_NAME,
			fragment_name,
		)
	}

	if g_state.depth.see_buffer_toggled {
		g_state.depth.see_buffer_toggled = false
		fragment_name := g_state.depth.see_buffer ? "depth_buffer_view" : MAIN_SHADER_NAME
		g_state.shaders.main = glc.shader_reload(
			g_state.shaders.main,
			MAIN_SHADER_NAME,
			fragment_name,
		)
	}

	if g_state.should_reload_shaders {
		g_state.should_reload_shaders = false
		log.info("Reloading shaders...")
		defer log.info("Done!")

		g_state.use_wireframe = false
		g_state.depth.see_buffer = false
		g_state.shaders.main = glc.shader_reload(g_state.shaders.main, MAIN_SHADER_NAME)
	}
}
