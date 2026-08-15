package learn_opengl

@(require) import "core:mem"
@(require) import "core:fmt"
import "core:strings"
import "core:path/filepath"
import "core:log"
import "core:os"
import "core:sys/windows"
import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"
import im "extern:imgui"

import "lib:devui"
import glc "lib:glcore"

MAIN_SHADER_NAME :: "reflective"

Background_Type :: enum {
	Solid_Color,
	Skybox,
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
	background:            struct {
		color:   glm.vec3,
		skybox:  glc.Cubemap,
		type:    Background_Type,
		current: i32,
	},
	shaders:               struct {
		main:   glc.Shader_Program_Handle,
		model:   glc.Shader_Program_Handle,
		border: glc.Shader_Program_Handle,
		quad:   glc.Shader_Program_Handle,
		skybox: glc.Shader_Program_Handle,
	},
	objects:               struct {
		cube:  glc.Primitive,
		plane: glc.Primitive,
		backpack: glc.Model,
	},
	depth:                 struct {
		see_buffer:         bool,
		see_buffer_toggled: bool,
	},
	stencil:               struct {
		border_size:        f32,
		border_color:       glm.vec3,
		should_draw_border: bool,
	},
	post_process:          struct {
		toggled:        bool,
		should_use:     bool,
		effects:        [dynamic]Post_Process_Effect,
		current_effect: i32,
	},
} = {
	camera = glc.camera_create(pos = {-0.1, 2.7, 9.9}, pitch = -18, yaw = -82),
	frustrum = {0.1, 100.0},
	is_capturing_mouse = false,
	show_ui = true,
	background = {color = {0.05, 0.05, 0.05}, type = .Skybox},
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
		glc.shader_load_from_files(MAIN_SHADER_NAME) or_else glc.crash("Error loading shaders")
	defer glc.shader_delete_program(g_state.shaders.main)

	g_state.shaders.model =
		glc.shader_load_from_files("model_load") or_else glc.crash(
			"Error loading shaders",
		)
	defer glc.shader_delete_program(g_state.shaders.model)

	g_state.shaders.border =
		glc.shader_load_from_files("model_load", "colored_border") or_else glc.crash(
			"Error loading shaders",
		)
	defer glc.shader_delete_program(g_state.shaders.border)

	g_state.shaders.quad =
		glc.shader_load_from_files("quad") or_else glc.crash("Error loading shaders")
	defer glc.shader_delete_program(g_state.shaders.quad)

	g_state.shaders.skybox =
		glc.shader_load_from_files("skybox") or_else glc.crash("Error loading shaders")
	defer glc.shader_delete_program(g_state.shaders.skybox)

	// post-process effects
	g_state.post_process.effects = load_post_process_effects()
	defer destroy_post_process_effects(g_state.post_process.effects[:])

	g_state.background.skybox = glc.cubemap_load("sky") or_else glc.crash("Failed to load skybox")
	defer glc.cubemap_destroy(&g_state.background.skybox)

	// load models/primitives
	g_state.objects.backpack = glc.model_load("backpack")
	defer glc.model_delete(&g_state.objects.backpack)
	g_state.objects.cube = glc.primitive_create_reflective(.Cube_With_Normals, g_state.background.skybox.texture)
	defer glc.primitive_destroy_reflective(&g_state.objects.cube)
	g_state.objects.plane = glc.primitive_create(.Plane, "metal.png")
	defer glc.primitive_destroy(&g_state.objects.plane)

	// required when loading any model
	defer glc.model_unload_loaded_textures_path()

	screen_fb := glc.framebuffer_create(.Full_Quad, glc.WINDOW_WIDTH, glc.WINDOW_HEIGHT)
	defer glc.framebuffer_destroy(&screen_fb)

	// main loop
	for !g_state.program_should_close {
		// setup frame, camera and event handling
		glc.events_handle(process_events, process_key_input)
		glc.timing_update_delta_time()

		// shader switching
		handle_view_modes()

		// first pass (draw to texture)
		glc.framebuffer_use(screen_fb)
		draw_main_scene()

		// second pass (draw to screen quad)
		glc.framebuffer_draw(screen_fb, g_state.shaders.quad, clear = true)

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
	gl.DepthFunc(gl.LESS)

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

	if g_state.use_wireframe {
		// force the background as solid color,
		// NOTE: this will make the skybox unselectable in the devUI
		g_state.background.type = .Solid_Color
	} else {
		g_state.background.type = .Skybox
	}
	// show the wireframe for the main scene only, not the render texture
	defer gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)

	gl.ClearColor(**g_state.background.color, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

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

	glc.shader_use_program(g_state.shaders.model)
	glc.shader_uniform_set(g_state.shaders.model, "u_view", &view)
	glc.shader_uniform_set(g_state.shaders.model, "u_projection", &proj)

	if g_state.depth.see_buffer {
		glc.shader_uniform_set(g_state.shaders.main, "u_near", g_state.frustrum.near)
		glc.shader_uniform_set(g_state.shaders.main, "u_far", g_state.frustrum.far)
	}

	// floor
	gl.StencilMask(0x00)
	gl.Disable(gl.CULL_FACE)
	glc.primitive_draw(g_state.objects.plane, g_state.shaders.model, 0.0)

	// cubes
	gl.StencilMask(0xff)
	gl.Disable(gl.CULL_FACE)
	glc.primitive_draw(g_state.objects.cube, g_state.shaders.main, {2.0, 0.01, 0.0}, camera_pos = g_state.camera.position)
	glc.primitive_draw(g_state.objects.cube, g_state.shaders.main, {-1.0, 0.01, -1.0}, camera_pos = g_state.camera.position)

	// backpack
	gl.StencilMask(0x00)
	gl.Disable(gl.CULL_FACE)
	glc.model_draw(g_state.objects.backpack, g_state.shaders.main, {0.0, 2.0, 0.0}, 0.4)

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

	// render the skybox last
	if g_state.background.type == .Skybox {
		glc.cubemap_draw(g_state.background.skybox, g_state.shaders.skybox, &view, &proj)
	}
}

// ------------------------ helpers and utilities ------------------------

ui_render :: proc() {
	if im.CollapsingHeader("General") {
		g_state.background.current = cast(i32)g_state.background.type
		if im.ComboCallback(
			"Background type",
			&g_state.background.current,
			get_background_type_name,
			nil,
			len(Background_Type),
		) {
			g_state.background.type = cast(Background_Type)g_state.background.current
		}
		if g_state.background.type == .Solid_Color {
			im.ColorEdit3("Background Color", &g_state.background.color)
		}
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
		if im.Checkbox("See depth buffer", &g_state.depth.see_buffer) {
			g_state.depth.see_buffer_toggled = true
		}
	}

	if im.CollapsingHeader("Border (using Stencil)") {
		im.ColorEdit3("Color", &g_state.stencil.border_color)
		im.DragFloat("Size", &g_state.stencil.border_size, 0.01, 0.02, 0.3)
		im.Checkbox("Show", &g_state.stencil.should_draw_border)
	}

	if im.CollapsingHeader("Post-processing") {
		if im.Checkbox("Use effects", &g_state.post_process.should_use) {
			g_state.post_process.toggled = true
		}
		if im.ComboCallback(
			"Effect",
			&g_state.post_process.current_effect,
			get_post_process_effect_name,
			raw_data(g_state.post_process.effects),
			cast(i32)len(g_state.post_process.effects),
		) {
			g_state.post_process.toggled = true
		}
	}

	get_post_process_effect_name :: proc "c" (user_data: rawptr, idx: i32) -> cstring {
		effects := cast([^]Post_Process_Effect)user_data
		return effects[idx].name
	}

	get_background_type_name :: proc "c" (_user_data: rawptr, idx: i32) -> (name: cstring) {
		switch cast(Background_Type)idx {
		case .Solid_Color:
			name = "Solid Color"
		case .Skybox:
			name = "Skybox"
		case:
			assert_contextless(false, "Unhandled background type name")
		}

		return
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

	// HACK
	@(static) original_quad_shader_backup: glc.Shader_Program_Handle
	@(static) init_once := true
	if init_once {
		init_once = false
		original_quad_shader_backup = g_state.shaders.quad
	}

	if g_state.post_process.toggled {
		g_state.post_process.toggled = false
		if (g_state.post_process.should_use) {
			g_state.shaders.quad =
				g_state.post_process.effects[g_state.post_process.current_effect].shader
		} else {
			g_state.shaders.quad = original_quad_shader_backup
		}
	}
}

Post_Process_Effect :: struct {
	name:   cstring,
	shader: glc.Shader_Program_Handle,
}

load_post_process_effects :: proc(allocator := context.allocator) -> [dynamic]Post_Process_Effect {
	effects := make([dynamic]Post_Process_Effect, allocator)

	f, oerr := os.open(glc.CONTENT_SHADER_PATH + "post/")
	ensure(oerr == nil)
	defer os.close(f)

	it := os.read_directory_iterator_create(f)
	defer os.read_directory_iterator_destroy(&it)

	log.info("Loading post processing effects...")
	for info in os.read_directory_iterator(&it) {
		name_with_path := strings.concatenate({"post/", filepath.stem(info.name)}, allocator)
		defer delete(name_with_path)

		effect_shader, ok := glc.shader_load_from_files("quad", name_with_path)

		if !ok {
			glc.crash("Error loading post processing effect")
		}

		capitalized_name := strings.to_pascal_case(filepath.stem(info.name), allocator)
		defer delete(capitalized_name)

		effect := Post_Process_Effect {
			name   = strings.clone_to_cstring(capitalized_name),
			shader = effect_shader,
		}

		append(&effects, effect)
	}
	log.infof("Loaded %d effects", len(effects))

	return effects
}

destroy_post_process_effects :: proc(
	effects: []Post_Process_Effect,
	allocator := context.allocator,
) {
	for effect in effects {
		delete(effect.name, allocator)
		glc.shader_delete_program(effect.shader)
	}

	delete(effects, allocator)
}
