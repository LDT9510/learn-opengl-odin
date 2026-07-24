// Implement gouraud shading

// Question answer (taken from tutorial) :
// We can see that the top-right vertex of the cube's front face is lit with specular highlights.
// Since the top-right vertex of the bottom-right triangle is lit and the other 2 vertices of the
// triangle are not, the bright values interpolates to the other 2 vertices. The same happens for
// the upper-left triangle. Since the intermediate fragment colors are not directly from the light
// source but are the result of interpolation, the lighting is incorrect at the intermediate fragments
// and the top-left and bottom-right triangle collide in their brightness resulting in a visible stripe
// between both triangles.

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
	rendering:            struct {
		ambient:   f32,
		diffuse:   f32,
		specular:  f32,
		shinnines: i32,
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
// odinfmt: enable

TEXTURES_PATH :: glc.OPENGL_EXERCISES_PATH + "../textures/"

main :: proc() {
	when ODIN_OS == .Windows {
		windows.SetProcessDPIAware()
	}

	cl := log.create_console_logger(opt = {.Level})
	context.logger = cl

	when ODIN_DEBUG {
		tracking_allocator := glc.create_tracking_allocator(context.allocator)
		defer glc.destroy_tracking_allocator(tracking_allocator)
		context.allocator = tracking_allocator

		tracking_temp_allocator := glc.create_tracking_allocator(context.temp_allocator)
		defer glc.destroy_tracking_allocator(tracking_temp_allocator, temp = true)
		context.temp_allocator = tracking_temp_allocator

		log.info("Debug mode")
	}

	glc.print_sdl_version()

	// intial state
	g_state = {
		camera = glc.camera_create(pos = {-3, 1, -2}, yaw = 44, pitch = -11),
		is_capturing_mouse = false,
		show_ui = true,
		rendering = {ambient = 0.1, diffuse = 1.0, specular = 0.5, shinnines = 32},
	}

	gl_ctx: sdl.GLContext
	g_state.window, gl_ctx = glc.create_opengl_window()
	defer glc.destroy_opengl_window(g_state.window, gl_ctx)

	devui.init_for_sdl_window(g_state.window, gl_ctx)
	defer devui.destroy()

	gouraud_shader :=
		glc.shader_load_from_files("gouraud_shading") or_else glc.crash("Error loading shaders")
	defer glc.shader_delete_program(gouraud_shader)

	phong_shader :=
		glc.shader_load_from_files("phong_parameters") or_else glc.crash("Error loading shaders")
	defer glc.shader_delete_program(phong_shader)

	light_cube_shader :=
		glc.shader_load_from_files("light_cube") or_else glc.crash("Error loading shaders")
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
	data := stbi.load(TEXTURES_PATH + "container.jpg", &width, &height, &channels, 0)
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
	data = stbi.load(TEXTURES_PATH + "awesomeface.png", &width, &height, &channels, 0)
	if data != nil {
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
		stbi.image_free(data)
	} else {
		glc.crash("Bad image")
	}

	gl.Enable(gl.DEPTH_TEST)

	phong_container_model: glm.mat4 = 1

	gouraud_container_model: glm.mat4 = 1
	gouraud_container_model *= glm.mat4Translate({2.0, 0.0, 0.0})

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

		light_pos := glm.vec3{1.0, 1.0, 1.0}

		gl.BindVertexArray(vao)
		// container gouraud (view space, for no particular reason)
		glc.shader_use_program(gouraud_shader)
		glc.shader_uniform_set(gouraud_shader, "model", &phong_container_model)
		glc.shader_uniform_set(gouraud_shader, "view", &view)
		glc.shader_uniform_set(gouraud_shader, "projection", &proj)
		glc.shader_uniform_set(gouraud_shader, "objectColor", glm.vec3{1.0, 0.5, 0.31})
		glc.shader_uniform_set(gouraud_shader, "lightColor", glm.vec3{1.0, 1.0, 1.0})
		glc.shader_uniform_set(gouraud_shader, "lightPos", light_pos)
		glc.shader_uniform_set(gouraud_shader, "ambient_strength", g_state.rendering.ambient)
		glc.shader_uniform_set(gouraud_shader, "diffuse_strength", g_state.rendering.diffuse)
		glc.shader_uniform_set(gouraud_shader, "specular_strength", g_state.rendering.specular)
		glc.shader_uniform_set(gouraud_shader, "shininess", g_state.rendering.shinnines)
		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		// container phong (world space)
		glc.shader_use_program(phong_shader)
		glc.shader_uniform_set(phong_shader, "model", &gouraud_container_model)
		glc.shader_uniform_set(phong_shader, "view", &view)
		glc.shader_uniform_set(phong_shader, "projection", &proj)
		glc.shader_uniform_set(phong_shader, "objectColor", glm.vec3{1.0, 0.5, 0.31})
		glc.shader_uniform_set(phong_shader, "lightColor", glm.vec3{1.0, 1.0, 1.0})
		glc.shader_uniform_set(phong_shader, "lightPos", light_pos)
		glc.shader_uniform_set(phong_shader, "viewPos", g_state.camera.position)
		glc.shader_uniform_set(phong_shader, "ambient_strength", g_state.rendering.ambient)
		glc.shader_uniform_set(phong_shader, "diffuse_strength", g_state.rendering.diffuse)
		glc.shader_uniform_set(phong_shader, "specular_strength", g_state.rendering.specular)
		glc.shader_uniform_set(phong_shader, "shininess", g_state.rendering.shinnines)
		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		light_cube_model := glm.mat4Translate(light_pos)
		light_cube_model *= glm.mat4Scale(0.2)

		gl.BindVertexArray(light_vao)
		// light
		glc.shader_use_program(light_cube_shader)
		glc.shader_uniform_set(light_cube_shader, "model", &light_cube_model)
		glc.shader_uniform_set(light_cube_shader, "view", &view)
		glc.shader_uniform_set(light_cube_shader, "projection", &proj)
		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		if (g_state.show_ui) {
			devui.render_ui("Learning OpenGL", ui_render, ui_render_shortcuts)
		}

		sdl.GL_SwapWindow(g_state.window)
	}
}

ui_render :: proc() {
	glc.camera_dev_ui_frame(&g_state.camera)

	im.SliderFloat("Ambient strength", &g_state.rendering.ambient, 0.0, 1.0)
	im.SliderFloat("Diffuse strength", &g_state.rendering.diffuse, 0.0, 1.0)
	im.SliderFloat("Specular strength", &g_state.rendering.specular, 0.0, 1.0)
	im.SliderInt("Shininess", &g_state.rendering.shinnines, 32, 256)
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
