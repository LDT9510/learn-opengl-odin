// Simulate real world materials
package learn_opengl

import "core:log"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:sys/windows"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"
import stbi "vendor:stb/image"

import im "extern:imgui"
import "lib:devui"
import glc "lib:glcore"

// avoids unused import error when ODIN_DEBUG is 0
_ :: mem

State :: struct {
	use_wireframe:        bool,
	program_should_close: bool,
	camera:               glc.Camera,
	window:               ^sdl.Window,
	is_capturing_mouse:   bool,
	show_ui:              bool,
	varying_light:        bool,
	current_material:     struct {
		value: Material,
		index: i32,
	},
}
g_state: State

// odinfmt: disable
@(rodata)
CUBE_VERTICES := [?]f32 {
	-0.5, -0.5, -0.5,  0.0,  0.0, -1.0,
     0.5, -0.5, -0.5,  0.0,  0.0, -1.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
    -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,

    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,
     0.5, -0.5,  0.5,  0.0,  0.0,  1.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
    -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,

    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,
    -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,
    -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,
    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,

     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,
     0.5,  0.5, -0.5,  1.0,  0.0,  0.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,
     0.5, -0.5,  0.5,  1.0,  0.0,  0.0,
     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,

    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,
     0.5, -0.5, -0.5,  0.0, -1.0,  0.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
    -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,

    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
     0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
    -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
}

@(rodata)
CUBE_POSITIONS := [?]glm.vec3 {
	{ 0.0,  0.0,  0.0},
	{ 2.0,  5.0, -15.0},
    {-1.5, -2.2, -2.5},
    {-3.8, -2.0, -12.3},
    { 2.4, -0.4, -3.5},
    {-1.7,  3.0, -7.5},
    { 1.3, -2.0, -2.5},
    { 1.5,  2.0, -2.5},
    { 1.5,  0.2, -1.5},
    {-1.3,  1.0, -1.5},
}

Material :: struct {
	ambient: glm.vec3,
	diffuse: glm.vec3,
	specular: glm.vec3,
	shininess: f32,
}

@(rodata)
MATERIALS := [?]Material {
	{ ambient = { 0.0215, 0.1745, 0.0215 },
      diffuse = { 0.07568, 0.61424, 0.07568 },
      specular = { 0.633, 0.727811, 0.633 },
      shininess = 76.8 },  // emerald
    { ambient = { 0.135, 0.2225, 0.1575 },
      diffuse = { 0.54, 0.89, 0.63 },
      specular = { 0.316228, 0.316228, 0.316228 },
      shininess = 12.8 },  // jade
    { ambient = { 0.05375, 0.05, 0.06625 },
      diffuse = { 0.18275, 0.17, 0.22525 },
      specular = { 0.332741, 0.328634, 0.346435 },
      shininess = 38.4 },  // obsidian
    { ambient = { 0.25, 0.20725, 0.20725 },
      diffuse = { 1.0, 0.829, 0.829 },
      specular = { 0.296648, 0.296648, 0.296648 },
      shininess = 11.264 },  // pearl
    { ambient = { 0.1745, 0.01175, 0.01175 },
      diffuse = { 0.61424, 0.04136, 0.04136 },
      specular = { 0.727811, 0.626959, 0.626959 },
      shininess = 76.8 },  // ruby
    { ambient = { 0.1, 0.18725, 0.1745 },
      diffuse = { 0.396, 0.74151, 0.69102 },
      specular = { 0.297254, 0.30829, 0.306678 },
      shininess = 12.8 },  // turquoise
    { ambient = { 0.329412, 0.223529, 0.027451 },
      diffuse = { 0.780392, 0.568627, 0.113725 },
      specular = { 0.992157, 0.941176, 0.807843 },
      shininess = 27.897436 },  // brass
    { ambient = { 0.2125, 0.1275, 0.054 },
      diffuse = { 0.714, 0.4284, 0.18144 },
      specular = { 0.393548, 0.271906, 0.166721 },
      shininess = 25.6 },  // bronze
    { ambient = { 0.25, 0.25, 0.25 },
      diffuse = { 0.4, 0.4, 0.4 },
      specular = { 0.774597, 0.774597, 0.774597 },
      shininess = 76.8 },  // chrome
    { ambient = { 0.19125, 0.0735, 0.0225 },
      diffuse = { 0.7038, 0.27048, 0.0828 },
      specular = { 0.256777, 0.137622, 0.086014 },
      shininess = 12.8 },  // copper
    { ambient = { 0.24725, 0.1995, 0.0745 },
      diffuse = { 0.75164, 0.60648, 0.22648 },
      specular = { 0.628281, 0.555802, 0.366065 },
      shininess = 51.2 },  // gold
    { ambient = { 0.19225, 0.19225, 0.19225 },
      diffuse = { 0.50754, 0.50754, 0.50754 },
      specular = { 0.508273, 0.508273, 0.508273 },
      shininess = 51.2 },  // silver
    { ambient = { 0.0, 0.0, 0.0 },
      diffuse = { 0.01, 0.01, 0.01 },
      specular = { 0.50, 0.50, 0.50 },
      shininess = 32.0 },  // black plastic
    { ambient = { 0.0, 0.1, 0.06 },
      diffuse = { 0.0, 0.509804, 0.509804 },
      specular = { 0.501961, 0.501961, 0.501961 },
      shininess = 32.0 },  // cyan plastic
    { ambient = { 0.0, 0.0, 0.0 },
      diffuse = { 0.1, 0.35, 0.1 },
      specular = { 0.45, 0.55, 0.45 },
      shininess = 32.0 },  // green plastic
    { ambient = { 0.0, 0.0, 0.0 },
      diffuse = { 0.5, 0.0, 0.0 },
      specular = { 0.7, 0.6, 0.6 },
      shininess = 32.0 },  // red plastic
    { ambient = { 0.0, 0.0, 0.0 },
      diffuse = { 0.55, 0.55, 0.55 },
      specular = { 0.70, 0.70, 0.70 },
      shininess = 32.0 },  // white plastic
    { ambient = { 0.0, 0.0, 0.0 },
      diffuse = { 0.5, 0.5, 0.0 },
      specular = { 0.60, 0.60, 0.50 },
      shininess = 32.0 },  // yellow plastic
    { ambient = { 0.02, 0.02, 0.02 },
      diffuse = { 0.01, 0.01, 0.01 },
      specular = { 0.4, 0.4, 0.4 },
      shininess = 10.0 },  // black rubber
    { ambient = { 0.0, 0.05, 0.05 },
      diffuse = { 0.4, 0.5, 0.5 },
      specular = { 0.04, 0.7, 0.7 },
      shininess = 10.0 },  // cyan rubber
    { ambient = { 0.0, 0.05, 0.05 },
      diffuse = { 0.4, 0.5, 0.4 },
      specular = { 0.04, 0.7, 0.04 },
      shininess = 10.0 },  // green rubber
    { ambient = { 0.05, 0.0, 0.0 },
      diffuse = { 0.5, 0.4, 0.4 },
      specular = { 0.7, 0.04, 0.04 },
      shininess = 10.0 },  // red rubber
    { ambient = { 0.05, 0.05, 0.05 },
      diffuse = { 0.5, 0.5, 0.5 },
      specular = { 0.7, 0.7, 0.7 },
      shininess = 10.0 },  // white rubber
    { ambient = { 0.05, 0.05, 0.0 },
      diffuse = { 0.5, 0.5, 0.4 },
      specular = { 0.7, 0.7, 0.04 },
      shininess = 10.0 },  // yellow rubber
}
// odinfmt: enable

material_names :: proc() -> cstring {
	// must match the list above, in order, the last element must always contain `\x00` at the end
	// odinfmt: disable
	@(static, rodata)
	NAMES := [?]cstring {
		"emerald",      "jade",          "obsidian",       "pearl",        "ruby",
		"turquoise",    "brass",         "bronze",         "chrome",       "copper",
		"gold",         "silver",        "black plastic",  "cyan plastic", "green plastic",
		"red plastic",  "white plastic", "yellow plastic", "black rubber", "cyan rubber",
		"green rubber", "red rubber",    "white rubber",   "yellow rubber\x00",
	}
	// odinfmt: enable

	names_bytes := cast([^]u8)NAMES[0]

	return cast(cstring)names_bytes
}

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
		defer glc.reset_tracking_allocator()
		log.info("Debug mode")
	}

	glc.print_sdl_version()

	// intial state
	g_state = {
		camera             = glc.camera_create(pos = {-3, 1, -2}, yaw = 44, pitch = -11),
		is_capturing_mouse = false,
		show_ui            = true,
		varying_light      = true,
		current_material = {
			value = MATERIALS[0],
		},
	}

	gl_ctx: sdl.GLContext
	g_state.window, gl_ctx = glc.create_opengl_window()
	defer glc.destroy_opengl_window(g_state.window, gl_ctx)

	devui.init_for_sdl_window(g_state.window, gl_ctx)
	defer devui.destroy()

	lighting_shader :=
		glc.shader_load_from_files("main") or_else glc.crash("Error loading shaders")
	defer glc.shader_delete_program(lighting_shader)

	light_cube_shader :=
		glc.shader_load_from_files("light_cube", "light_cube_changing") or_else glc.crash(
			"Error loading shaders",
		)
	defer glc.shader_delete_program(light_cube_shader)

	vbo, vao, light_vao: u32

	gl.GenVertexArrays(1, &vao)
	defer gl.DeleteVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(CUBE_VERTICES), &CUBE_VERTICES, gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 0) // position
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 3 * size_of(f32)) // normals
	gl.EnableVertexAttribArray(1)

	gl.BindVertexArray(0)

	gl.GenVertexArrays(1, &light_vao)
	defer gl.DeleteVertexArrays(1, &light_vao)
	gl.BindVertexArray(light_vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 0) // position
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	texture1, texture2: u32
	gl.GenTextures(1, &texture1)
	defer gl.DeleteTextures(1, &texture1)
	gl.BindTexture(gl.TEXTURE_2D, texture1)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	width, height, channels: i32
	data := stbi.load("content/textures/container.jpg", &width, &height, &channels, 0)
	if data != nil {
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
		stbi.image_free(data)
	} else {
		glc.crash("Bad image")
	}

	gl.GenTextures(1, &texture2)
	defer gl.DeleteTextures(1, &texture2)
	gl.BindTexture(gl.TEXTURE_2D, texture2)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	stbi.set_flip_vertically_on_load(1)
	data = stbi.load("content/textures/awesomeface.png", &width, &height, &channels, 0)
	if data != nil {
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
		stbi.image_free(data)
	} else {
		glc.crash("Bad image")
	}

	gl.Enable(gl.DEPTH_TEST)

	container_model: glm.mat4 = 1

	light_pos := glm.vec3{1.2, 1.0, 2.0}
	light_cube_model := glm.mat4Translate(light_pos)
	light_cube_model *= glm.mat4Scale(0.2)

	for !g_state.program_should_close {
		glc.events_handle(process_events, process_key_input)
		glc.timing_update_delta_time()

		gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

		gl.ClearColor(0.0, 0.0, 0.0, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, texture1)
		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, texture2)

		view := glc.camera_get_view_matrix(g_state.camera)
		proj := glm.mat4Perspective(
			glm.radians(g_state.camera.zoom),
			glc.window_get_aspect_ratio(g_state.window),
			0.1,
			100.0,
		)

		diffuse_color: glm.vec3
		ambient_color: glm.vec3
		if (g_state.varying_light) {
			time := cast(f32)glc.timing_get_elapsed_seconds()
			light_color := glm.vec3{glm.sin(time * 2.0), glm.sin(time * 0.7), glm.sin(time * 1.3)}
			diffuse_color = light_color * glm.vec3(0.5)
			ambient_color = diffuse_color * glm.vec3(0.2)
		} else {
			diffuse_color = glm.vec3(0.5)
			ambient_color = glm.vec3(0.2)
		}

		// container
		glc.shader_use_program(lighting_shader)
		glc.shader_uniform_set(lighting_shader, "model", &container_model)
		glc.shader_uniform_set(lighting_shader, "view", &view)
		glc.shader_uniform_set(lighting_shader, "projection", &proj)
		glc.shader_uniform_set(lighting_shader, "lightPos", light_pos)
		glc.shader_uniform_set(lighting_shader, "viewPos", g_state.camera.position)
		glc.shader_uniform_set(lighting_shader, "light.ambient", ambient_color)
		glc.shader_uniform_set(lighting_shader, "light.diffuse", diffuse_color)
		glc.shader_uniform_set(lighting_shader, "light.specular", 1.0, 1.0, 1.0)
		glc.shader_uniform_set(
			lighting_shader,
			"material.ambient",
			g_state.current_material.value.ambient,
		)
		glc.shader_uniform_set(
			lighting_shader,
			"material.diffuse",
			g_state.current_material.value.diffuse,
		)
		glc.shader_uniform_set(
			lighting_shader,
			"material.specular",
			g_state.current_material.value.specular,
		)
		glc.shader_uniform_set(
			lighting_shader,
			"material.shininess",
			g_state.current_material.value.shininess,
		)
		gl.BindVertexArray(vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		// light
		glc.shader_use_program(light_cube_shader)
		glc.shader_uniform_set(light_cube_shader, "model", &light_cube_model)
		glc.shader_uniform_set(light_cube_shader, "view", &view)
		glc.shader_uniform_set(light_cube_shader, "projection", &proj)
		glc.shader_uniform_set(light_cube_shader, "lightDiffuse", diffuse_color)
		gl.BindVertexArray(light_vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		if (g_state.show_ui) {
			devui.render_ui("Learning OpenGL", ui_render, ui_render_shortcuts)
		}

		sdl.GL_SwapWindow(g_state.window)
	}
}

ui_render :: proc() {
	glc.camera_dev_ui_frame(&g_state.camera)

	im.Checkbox("Varying Light Color", &g_state.varying_light)

	if (im.Combo("Material", &g_state.current_material.index, material_names())) {
		g_state.current_material.value = MATERIALS[g_state.current_material.index]
	}
}

ui_render_shortcuts :: proc() {
	devui.shortcut("ESC", "Close program")
	devui.shortcut("U", "Enables wireframe mode")
	devui.shortcut("I", "Togle UI")
	devui.shortcut("(Shift +)WASD", "(Sprint) Camera move")
	devui.shortcut("Right click (hold)", "Look around")
}

process_events :: proc(event: sdl.Event) {
	if (glc.events_is_mouse_button_pressed({.RIGHT})) {
		g_state.is_capturing_mouse = true
	} else {
		g_state.is_capturing_mouse = false
	}
	_ = sdl.SetWindowRelativeMouseMode(g_state.window, g_state.is_capturing_mouse)

	#partial switch event.type {
	case .QUIT:
		g_state.program_should_close = true
	case .WINDOW_PIXEL_SIZE_CHANGED:
		gl.Viewport(0, 0, event.window.data1, event.window.data2)
	case .MOUSE_WHEEL:
		glc.camera_on_mouse_wheel_scroll(&g_state.camera, event.wheel.y)
	case .MOUSE_MOTION:
		if (g_state.is_capturing_mouse) {
			glc.camera_on_mouse_move(&g_state.camera, event.motion.xrel, -event.motion.yrel, true)
		}
	}
}

process_key_input :: proc() {
	switch {
	case glc.events_is_key_just_pressed(.ESCAPE):
		g_state.program_should_close = true
	case glc.events_is_key_just_pressed(.U):
		g_state.use_wireframe = !g_state.use_wireframe
	case glc.events_is_key_just_pressed(.I):
		g_state.show_ui = !g_state.show_ui
	}

	glc.camera_handle_input(&g_state.camera)
}
