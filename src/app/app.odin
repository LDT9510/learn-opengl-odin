package app

import "main:devui"
import "main:glc"
import mod "main:modules"

import sdl "vendor:sdl3"

SCENES_COUNT :: 10

setup :: proc(s: ^State) {
	// initial state
	s.app = {
		camera             = mod.camera_create(pos = {-0.1, 2.7, 9.9}, pitch = -18, yaw = -82),
		is_capturing_mouse = false,
		show_ui            = true,
	}
	s.rs = {
		view_mode   = .Normal,
		clear_color = {0.392, 0.584, 0.929},
	}
	s.scene = {
		registry = {
			{"Empty", "An empty scene", nil, nil_scn_proc, nil_scn_proc, false},
			SCENE_THREE_CUBES,
			SCENE_REFR,
			SCENE_MANY_CUBES,
			SCENE_GRASS_N_WIN,
			SCENE_SIMPLE_MODEL,
			SCENE_SCRN_POS,
			SCENE_GEOMETRY,
			SCENE_EXPLODING,
			SCENE_INSTANCING,
		},
		// always the last one
		idx      = 1,//SCENES_COUNT - 1,
	}

	log_sdl_version()

	// setup window
	s.app.window, s.app.gl_context = glc.create_opengl_window()
	update_vsync_state(s)

	// setup developer UI
	devui.init_for_sdl_window(s.app.window, s.app.gl_context)

	s.rs.post_process.fb = glc.framebuffer_create(.Full_Quad, glc.WINDOW_WIDTH, glc.WINDOW_HEIGHT)

	// dynamic resources
	glc.post_process_effects_get_available()

	// renderer setup
	glc.renderer_log_info()
	glc.renderer_setup_ubos(&s.rs)
}

teardown :: proc(s: ^State) {
	devui.deinit()

	glc.framebuffer_destroy(&s.rs.post_process.fb)

	glc.destroy_all()

	// must be done last
	glc.destroy_opengl_window(s.app.window, s.app.gl_context)
}


update :: proc(s: ^State) {
	mod.events_handle(process_key_input, process_events, s)
	mod.timing_update(&s.timings)

	if s.app.should_reload_shaders {
		glc.shader_reload_all_program_resources()
		glc.post_process_effects_reload_all()
		s.app.should_reload_shaders = false
	}
}

draw :: proc(s: ^State) {
	glc.renderer_begin_drawing(&s.rs)
	get_view_proj_and_frustrum(s)

	scene := current_scene(s)
	if !scene.is_loaded {
		scene.setup_proc(s, scene.data)
		scene.is_loaded = true
	}

	scene.draw_proc(s, scene.data)

	glc.renderer_end_drawing(&s.rs)

	if s.app.show_ui {
		render_main_ui_window(s)
	}

	sdl.GL_SwapWindow(s.app.window)
}

process_key_input :: proc(state: rawptr) {
	s := cast(^State)state
	switch {
	case mod.events_is_key_just_pressed(.ESCAPE):
		s.app.should_close = true
	case mod.events_is_key_just_pressed(.U):
		glc.renderer_state_toggle_normal(&s.rs, .Wireframe)
	case mod.events_is_key_just_pressed(.O):
		glc.renderer_state_toggle_normal(&s.rs, .Points)
	case mod.events_is_key_just_pressed(.P):
		glc.renderer_state_toggle_normal(&s.rs, .Depth)
	case mod.events_is_key_just_pressed(.I):
		s.app.show_ui = !s.app.show_ui
	case mod.events_is_key_just_pressed(.R):
		s.app.should_reload_shaders = true
	}

	mod.camera_handle_input(&s.app.camera, s.timings.delta_time)
}

process_events :: proc(event: sdl.Event, state: rawptr) {
	s := cast(^State)state
	s.app.is_capturing_mouse = mod.events_is_mouse_button_pressed({.RIGHT})
	_ = sdl.SetWindowRelativeMouseMode(s.app.window, s.app.is_capturing_mouse)

	#partial switch event.type {
	case .QUIT:
		s.app.should_close = true
	case .WINDOW_PIXEL_SIZE_CHANGED:
		w := event.window
		glc.renderer_handle_viewport_changed(&s.rs, w.data1, w.data2)
	case .MOUSE_WHEEL:
		mod.camera_on_mouse_wheel_scroll(&s.app.camera, event.wheel.y)
	case .MOUSE_MOTION:
		if s.app.is_capturing_mouse {
			mod.camera_on_mouse_move(&s.app.camera, event.motion.xrel, -event.motion.yrel, true)
		}
	}
}

State :: struct {
	app:     struct {
		should_close:          bool,
		camera:                mod.Camera,
		window:                ^sdl.Window,
		is_capturing_mouse:    bool,
		should_reload_shaders: bool,
		show_ui:               bool,
		vsync_on:              bool,
		gl_context:            sdl.GLContext,
	},
	timings: mod.Timings,
	rs:      glc.Render_State,
	scene:   struct {
		registry: [SCENES_COUNT]Scene,
		idx:      i32,
	},
}

Scene :: struct {
	name:        cstring,
	description: cstring,
	data:        rawptr,
	setup_proc:  proc(s: ^State, data: rawptr),
	draw_proc:   proc(s: ^State, data: rawptr),
	is_loaded:   bool,
}
