package learn_opengl

import "main:app"

import "core:log"
import "core:sys/windows"
import "core:fmt"
import "core:mem"

main :: proc() {
	// windows specific fix
	when ODIN_OS == .Windows {
		windows.SetProcessDPIAware()
	}

	// setup allocation
	when ODIN_DEBUG {
		tracking_allocator := create_tracking_allocator(context.allocator)
		defer destroy_tracking_allocator(tracking_allocator)
		context.allocator = tracking_allocator

		tracking_temp_allocator := create_tracking_allocator(context.temp_allocator)
		defer destroy_tracking_allocator(tracking_temp_allocator, temp = true)
		context.temp_allocator = tracking_temp_allocator

		// cannot use logging here as it is not setup yet
		fmt.eprintln("-------- Debug mode --------")
	} else {
		// avoid unused error
		_ :: fmt
	}

	// setup logging
	cl := log.create_console_logger(opt = {.Level})
	defer log.destroy_console_logger(cl)
	context.logger = cl

	state: app.State
	app.setup(&state)
	defer app.teardown(&state)

	// main loop
	for !app.should_close(&state) {
		app.update(&state)

		app.draw(&state)

		free_all(context.temp_allocator)
	}
}

MAX_ALLOCATION_ERROR_MESSAGES :: 20

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
