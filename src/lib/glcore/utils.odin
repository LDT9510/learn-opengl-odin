package glcore

import "core:os"
import "core:log"
import "core:mem"
import "core:fmt"
import sdl "vendor:sdl3"

print_sdl_version :: proc() {
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

reset_tracking_allocator :: proc() -> bool {
	a := cast(^mem.Tracking_Allocator)context.allocator.data
	err := false
	if len(a.allocation_map) > 0 {
		log.warnf("Leaked allocation count: %v", len(a.allocation_map))
	}
	for _, v in a.allocation_map {
		fmt.eprintfln("%v: Leaked %v bytes", v.location, v.size)
		err = true
	}

	mem.tracking_allocator_clear(a)
	return err
}

crash :: proc(fmt_str: string, args: ..any, location := #caller_location) -> ! {
	log.fatalf(fmt_str, ..args, location = location)
	log.fatal("Crashing program...")
	os.exit(1)
}
