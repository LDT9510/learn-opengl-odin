// Draw 2 triangles next two each other using more vertices

package learn_opengl

import "core:c"
import "core:log"
import "core:mem"
import "core:sys/windows"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

import glc "lib:glcore"

_ :: glc.OPENGL_EXERCISES_MODE  // do not raise unused error

// odinfmt: disable
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

vertex_shader_source: cstring = `
#version 330 core
layout (location = 0) in vec3 aPos;

void main()
{
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}`

fragment_shader_source: cstring = `
#version 330 core
out vec4 FragColor;

void main()
{
    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
} `

vertices := [?]f32 {
    // first triangle
    -0.9, -0.5, 0.0,  // left 
    -0.0, -0.5, 0.0,  // right
    -0.45, 0.5, 0.0,  // top 
    // second triangle
     0.0, -0.5, 0.0,  // left
     0.9, -0.5, 0.0,  // right
     0.45, 0.5, 0.0,   // top 
}

// odinfmt: enable

main :: proc() {
	when ODIN_OS == .Windows {
		windows.SetProcessDPIAware()
	}

	cl := log.create_console_logger(opt = {.Level})
	context.logger = cl

	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	defer reset_tracking_allocator()

	print_sdl_version()

	if !sdl.Init({.VIDEO}) {
		log.fatalf("SDL: could not initialize: %s", sdl.GetError())
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
		log.fatalf("SDL: could not create window: %s", sdl.GetError())
	}
	defer sdl.DestroyWindow(window)

	gl_context := sdl.GL_CreateContext(window)
	if gl_context == nil {
		log.fatalf("SDL: could not create OpenGL context: %s", sdl.GetError())
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

	success: i32
	info_log: [512]c.char

	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vertex_shader_source, nil)
	gl.CompileShader(vertex_shader)
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
	if success != 1 {
		gl.GetShaderInfoLog(vertex_shader, size_of(info_log), nil, &info_log[0])
		log.errorf("Vertex compilation error: \n\t\t\t%s", cast(cstring)&info_log[0])
	}

	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, &fragment_shader_source, nil)
	gl.CompileShader(fragment_shader)
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)
	if success != 1 {
		gl.GetShaderInfoLog(fragment_shader, size_of(info_log), nil, &info_log[0])
		log.errorf("Fragment compilation error: \n\t\t\t%s", cast(cstring)&info_log[0])
	}

	shader_program := gl.CreateProgram()
	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, fragment_shader)
	gl.LinkProgram(shader_program)
	gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success)
	if success != 1 {
		gl.GetProgramInfoLog(shader_program, size_of(info_log), nil, &info_log[0])
		log.errorf("Shader program link error: \n\t\t\t%s", cast(cstring)&info_log[0])
	}
	defer gl.DeleteProgram(shader_program)
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

	gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

	vbo, vao: u32

	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	should_close := false
	for !should_close {
		should_close = handle_input()

		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.BindVertexArray(vao)
		gl.UseProgram(shader_program)
		gl.DrawArrays(gl.TRIANGLES, 0, 6)

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

	if use_wireframe {
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	} else {
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	}

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

reset_tracking_allocator :: proc() -> bool {
	a := cast(^mem.Tracking_Allocator)context.allocator.data
	err := false
	if len(a.allocation_map) > 0 {
		log.warnf("Leaked allocation count: %v", len(a.allocation_map))
	}
	for _, v in a.allocation_map {
		log.warnf("%v: Leaked %v bytes", v.location, v.size)
		err = true
	}

	mem.tracking_allocator_clear(a)
	return err
}
