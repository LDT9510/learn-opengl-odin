package app

import "main:glc"
import mod "main:modules"

import "core:log"
import glm "core:math/linalg/glsl"
import sdl "vendor:sdl3"


get_view_proj_and_frustrum :: proc(s: ^State) {
	s.rs.view = mod.camera_get_view_matrix(s.app.camera)
	s.rs.projection = glm.mat4Perspective(
		glm.radians(s.app.camera.zoom),
		glc.window_get_aspect_ratio(s.app.window),
		s.app.camera.frustrum_near,
		s.app.camera.frustrum_far,
	)
	s.rs.frustrum.near = s.app.camera.frustrum_near
	s.rs.frustrum.far = s.app.camera.frustrum_far
}

update_vsync_state :: proc(s: ^State) {
	if s.app.vsync_on {
		sdl.GL_SetSwapInterval(1)
	} else {
		sdl.GL_SetSwapInterval(0)
	}
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
