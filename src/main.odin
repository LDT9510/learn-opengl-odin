package learn_opengl

import "core:c"
import "core:log"
import "core:mem"
import "core:os"
import "core:sys/windows"

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600


// odinfmt: disable

g_vertices := [?]f32 {
     // positions     // colors
     0.5, -0.5, 0.0,  1.0, 0.0, 0.0,  // bottom right
    -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  // bottom let
     0.0,  0.5, 0.0,  0.0, 0.0, 1.0,  // top
}

// odinfmt: enable

main :: proc() {
	when ODIN_OS == .Windows {
		windows.SetProcessDPIAware()
	}

	cl := log.create_console_logger(opt = {.Level})
	context.logger = cl

	when ODIN_DEBUG {
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
		defer reset_tracking_allocator()
		log.info("Debug mode")
	}

	print_sdl_version()

	if !sdl.Init({.VIDEO}) {
		crash("SDL: could not initialize: %s", sdl.GetError())
	}
	defer sdl.Quit()

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 3)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, cast(c.int)sdl.GL_CONTEXT_PROFILE_CORE)

	window := sdl.CreateWindow(
		"Learning OpenGL",
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		{.OPENGL, .RESIZABLE},
	)
	if window == nil {
		crash("SDL: could not create window: %s", sdl.GetError())
	}
	defer sdl.DestroyWindow(window)

	gl_context := sdl.GL_CreateContext(window)
	if gl_context == nil {
		crash("SDL: could not create OpenGL context: %s", sdl.GetError())
	}
	defer sdl.GL_DestroyContext(gl_context)

	gl.load_up_to(3, 3, sdl.gl_set_proc_address)
	log.infof(
		"OpenGL: loaded OpenGL %d.%d Core Profile",
		gl.loaded_up_to_major,
		gl.loaded_up_to_minor,
	)

	loaded_renderer := gl.GetString(gl.RENDERER)
	log.infof("OpenGL: renderer %s", loaded_renderer)

	glsl_version := gl.GetString(gl.SHADING_LANGUAGE_VERSION)
	log.infof("OpenGL: GLSL version %s", glsl_version)

	max_attrs: i32
	gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &max_attrs)
	log.infof("OpenGL: Maximum number of vertex attributes supported: %d", max_attrs)

	shader_program :=
		shader_load_from_files("vertex", "fragment") or_else crash(
			"Error loading shaders",
		)
	defer shader_delete_program(shader_program)

	gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

	vbo, vao: u32

	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(g_vertices), &g_vertices, gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 0) // position
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 3 * size_of(f32)) // color
	gl.EnableVertexAttribArray(1)

	gl.BindVertexArray(0)

	should_close := false
	for !should_close {
		should_close = handle_input()

		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		shader_use_program(shader_program)
		gl.BindVertexArray(vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		sdl.GL_SwapWindow(window)
	}
}

handle_input :: proc() -> bool {
	@(static) use_wireframe := false

	e: sdl.Event = ---
	for sdl.PollEvent(&e) {
		#partial switch e.type {
		case .KEY_DOWN:
			if e.key.key == sdl.K_ESCAPE do return true
			if e.key.key == sdl.K_U do use_wireframe = !use_wireframe
		case .QUIT:
			return true
		case .WINDOW_PIXEL_SIZE_CHANGED:
			gl.Viewport(0, 0, e.window.data1, e.window.data2)
		}
	}

	gl.PolygonMode(gl.FRONT_AND_BACK, use_wireframe ? gl.LINE : gl.FILL)

	return false
}

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

import "core:fmt"

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
