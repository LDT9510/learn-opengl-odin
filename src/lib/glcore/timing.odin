package glcore

import sdl "vendor:sdl3"

timing_get_elapsed_seconds :: proc() -> f64 {
	return cast(f64)sdl.GetTicks() / 1000
}
