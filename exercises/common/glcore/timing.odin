package glcore

import sdl "vendor:sdl3"

g_delta_time: f32

timing_get_elapsed_seconds :: proc() -> f64 {
	return cast(f64)sdl.GetTicks() / 1000
}

timing_update_delta_time :: proc() {
	@(static) last_frame_time: f32

	curr_frame_time := cast(f32)timing_get_elapsed_seconds()
	g_delta_time = curr_frame_time - last_frame_time
	last_frame_time = curr_frame_time
}
