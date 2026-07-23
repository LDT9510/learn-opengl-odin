package glcore

import "core:os"
import "core:log"
import "core:mem"
import "core:fmt"

import sdl "vendor:sdl3"

MAX_ALLOCATION_ERROR_MESSAGES :: 20

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

create_tracking_allocator :: proc(allocator: mem.Allocator) -> mem.Allocator {
	tracking_allocator := new(mem.Tracking_Allocator)
	mem.tracking_allocator_init(tracking_allocator, allocator)
	return mem.tracking_allocator(tracking_allocator)
}

destroy_tracking_allocator :: proc(allocator: mem.Allocator, temp := false) -> bool {
	a := cast(^mem.Tracking_Allocator)allocator.data
	err := false
	remaining_allocations := len(a.allocation_map)

	if remaining_allocations > 0 {
		prefix := temp ? "Temp Allocator" : "Heap Allocator"
		fmt.eprintfln(
			"------ (%s) Leaked allocation count: %v ------",
			prefix,
			len(a.allocation_map),
		)
	}

	allocations_noticed := 0
	for _, v in a.allocation_map {
		fmt.eprintfln("%v: Leaked %v bytes", v.location, v.size)
		err = true
		allocations_noticed += 1

		if allocations_noticed > MAX_ALLOCATION_ERROR_MESSAGES {
			fmt.eprintfln(
				"(... + %d allocations)",
				remaining_allocations - allocations_noticed + 1,
			)
			break
		}
	}

	mem.tracking_allocator_destroy(a)
	free(a)

	return err
}

crash :: proc(fmt_str: string, args: ..any, location := #caller_location) -> ! {
	log.fatalf(fmt_str, ..args, location = location)
	log.fatal("Crashing program...")
	os.exit(1)
}
