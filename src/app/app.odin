package app

import "main:devui"
import "main:glc"

import "core:log"
import glm "core:math/linalg/glsl"
import sdl "vendor:sdl3"

INITIAL_SCENE_IDX :: Scene_Index.Many_Cubes

setup :: proc(s: ^State) {
	// initial state
	s.app = {
		camera             = camera_create(pos = {-0.1, 2.7, 9.9}, pitch = -18, yaw = -82),
		is_capturing_mouse = false,
		show_ui            = true,
	}
	s.rs = {
		view_mode   = .Normal,
		clear_color = {0.392, 0.584, 0.929},
	}
	s.scene = {
		current = SCENE_REGISTRY[INITIAL_SCENE_IDX],
		idx     = INITIAL_SCENE_IDX,
	}

	log_sdl_version()

	// setup window
	s.app.window, s.app.gl_context = glc.create_opengl_window()

	// setup developer UI
	devui.init_for_sdl_window(s.app.window, s.app.gl_context)

	s.rs.post_process.fb = glc.framebuffer_create(.Full_Quad, glc.WINDOW_WIDTH, glc.WINDOW_HEIGHT)

	// dynamic resources
	glc.post_process_effects_get_available()
}

teardown :: proc(s: ^State) {
	devui.deinit()

	glc.framebuffer_destroy(&s.rs.post_process.fb)

	glc.destroy_all()

	// must be done last
	glc.destroy_opengl_window(s.app.window, s.app.gl_context)
}

update :: proc(s: ^State) {
	events_handle(s)
	timing_update_delta_time(&s.timings)

	if s.app.should_reload_shaders {
		glc.shader_reload_all_program_resources()
		glc.post_process_effects_reload_all()
		s.app.should_reload_shaders = false
	}
}

draw :: proc(s: ^State) {
	glc.renderer_begin_drawing(&s.rs)
	get_view_proj_and_frustrum(s)

	s.scene.current.draw_proc(s)

	glc.renderer_end_drawing(&s.rs)

	if s.app.show_ui {
		render_main_ui_window(s)
	}

	sdl.GL_SwapWindow(s.app.window)
}

process_key_input :: proc(s: ^State) {
	switch {
	case events_is_key_just_pressed(.ESCAPE):
		s.app.should_close = true
	case events_is_key_just_pressed(.U):
		glc.renderer_state_toggle_normal(&s.rs, .Wireframe)
	case events_is_key_just_pressed(.P):
		glc.renderer_state_toggle_normal(&s.rs, .Depth)
	case events_is_key_just_pressed(.I):
		s.app.show_ui = !s.app.show_ui
	case events_is_key_just_pressed(.R):
		s.app.should_reload_shaders = true
	}

	camera_handle_input(&s.app.camera, s.timings.delta_time)
}

process_events :: proc(event: sdl.Event, s: ^State) {
	s.app.is_capturing_mouse = events_is_mouse_button_pressed({.RIGHT})
	_ = sdl.SetWindowRelativeMouseMode(s.app.window, s.app.is_capturing_mouse)

	#partial switch event.type {
	case .QUIT:
		s.app.should_close = true
	case .WINDOW_PIXEL_SIZE_CHANGED:
		w := event.window
		glc.renderer_handle_viewport_changed(&s.rs, w.data1, w.data2)
	case .MOUSE_WHEEL:
		camera_on_mouse_wheel_scroll(&s.app.camera, event.wheel.y)
	case .MOUSE_MOTION:
		if s.app.is_capturing_mouse {
			camera_on_mouse_move(&s.app.camera, event.motion.xrel, -event.motion.yrel, true)
		}
	}
}

get_view_proj_and_frustrum :: proc(s: ^State) {
	s.rs.view = camera_get_view_matrix(s.app.camera)
	s.rs.projection = glm.mat4Perspective(
		glm.radians(s.app.camera.zoom),
		glc.window_get_aspect_ratio(s.app.window),
		s.app.camera.frustrum_near,
		s.app.camera.frustrum_far,
	)
	s.rs.frustrum.near = s.app.camera.frustrum_near
	s.rs.frustrum.far = s.app.camera.frustrum_far
}

should_close :: proc(s: ^State) -> bool {
	return s.app.should_close
}

log_sdl_version :: proc() {
	log.infof(
		"SDL: compiled againts %d.%d.%d",
		sdl.MAJOR_VERSION,
		sdl.MINOR_VERSION,
		sdl.MICRO_VERSION,
	)

	linked := sdl.GetVersion()
	log.infof(
		"SDL: linked againts %d.%d.%d",
		sdl.VERSIONNUM_MAJOR(linked),
		sdl.VERSIONNUM_MINOR(linked),
		sdl.VERSIONNUM_MICRO(linked),
	)
}

State :: struct {
	app:     struct {
		should_close:          bool,
		camera:                Camera,
		window:                ^sdl.Window,
		is_capturing_mouse:    bool,
		should_reload_shaders: bool,
		show_ui:               bool,
		gl_context:            sdl.GLContext,
	},
	timings: Timings,
	rs:      glc.Render_State,
	scene:   struct {
		current: Scene,
		idx:     Scene_Index,
	},
}
