package learn_opengl

import "core:log"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:sys/windows"

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

import im "extern:imgui"
import "lib:devui"
import glc "lib:glcore"

// avoids unused import error when ODIN_DEBUG is 0
_ :: mem

Directional_Light :: struct {
	direction: glm.vec3,
}

Point_Light :: struct {
	position:  glm.vec3,
	constant:  f32,
	linear:    f32,
	quadratic: f32,
}

Spot_Light :: struct {
	constant:           f32,
	linear:             f32,
	quadratic:          f32,
	cutoff_angle:       f32,
	outer_cutoff_angle: f32,
}

Light_Type :: enum {
	Directional,
	Point,
	Spot,
}

State :: struct {
	use_wireframe:        bool,
	program_should_close: bool,
	camera:               glc.Camera,
	window:               ^sdl.Window,
	is_capturing_mouse:   bool,
	show_ui:              bool,
	light_type:           Light_Type,
	directional_light:    Directional_Light,
	point_light:          Point_Light,
	spot_light:           Spot_Light,
}
g_state: State

// odinfmt: disable
@(rodata)
CUBE_VERTICES := [?]f32 {
	 // positions         // normals           // textures coords
    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,
     0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 0.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
    -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 1.0,
    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,

    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 0.0,
     0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 0.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
    -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 1.0,
    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 0.0,

    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,
    -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0, 1.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
    -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0, 0.0,
    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,

     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0, 1.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
     0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0, 0.0,
     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,

    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,
     0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0, 1.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
    -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0, 0.0,
    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,

    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0,
     0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0, 1.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
    -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0, 0.0,
    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0,
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
// odinfmt: enable

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
		camera = glc.camera_create(pos = {-6, -0.5, 7}, yaw = 315, pitch = 0),
		is_capturing_mouse = false,
		show_ui = true,
		light_type = .Spot,
		directional_light = {direction = {-0.2, -1.0, -0.3}},
		point_light = {
			position = {1.2, 1.0, 2.0},
			constant = 1.0,
			linear = 0.09,
			quadratic = 0.032,
		},
		spot_light = {
			cutoff_angle = glm.radians_f32(12.5),
			outer_cutoff_angle = glm.radians_f32(17.5),
			constant = 1.0,
			linear = 0.09,
			quadratic = 0.032,
		},
	}

	gl_ctx: sdl.GLContext
	g_state.window, gl_ctx = glc.create_opengl_window()
	defer glc.destroy_opengl_window(g_state.window, gl_ctx)

	devui.init_for_sdl_window(g_state.window, gl_ctx)
	defer devui.destroy()

	directional_light_shader :=
		glc.shader_load_from_files("main", "directional_light") or_else glc.crash(
			"Error loading shaders",
		)
	defer glc.shader_delete_program(directional_light_shader)

	point_light_shader :=
		glc.shader_load_from_files("main", "point_light") or_else glc.crash(
			"Error loading shaders",
		)
	defer glc.shader_delete_program(point_light_shader)

	spot_light_shader :=
		glc.shader_load_from_files("main", "spot_light") or_else glc.crash("Error loading shaders")
	defer glc.shader_delete_program(spot_light_shader)

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
	// positions
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)
	// normals
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 3 * size_of(f32))
	gl.EnableVertexAttribArray(1)
	// textures coords
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 6 * size_of(f32))
	gl.EnableVertexAttribArray(2)

	gl.BindVertexArray(0)

	gl.GenVertexArrays(1, &light_vao)
	defer gl.DeleteVertexArrays(1, &light_vao)
	gl.BindVertexArray(light_vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	// position
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	diffuse_map := glc.texture_load("crate_diffuse.png") or_else glc.crash("Error loading image")
	defer glc.texture_destroy(diffuse_map)
	specular_map := glc.texture_load("crate_specular.png") or_else glc.crash("Error loading image")
	defer glc.texture_destroy(specular_map)

	gl.Enable(gl.DEPTH_TEST)

	free_all(context.allocator)

	current_shader: glc.Shader_Program_Handle

	for !g_state.program_should_close {
		glc.events_handle(process_events, process_key_input)
		glc.timing_update_delta_time()

		gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

		gl.ClearColor(0.1, 0.1, 0.1, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		view := glc.camera_get_view_matrix(g_state.camera)
		proj := glm.mat4Perspective(
			glm.radians(g_state.camera.zoom),
			glc.window_get_aspect_ratio(g_state.window),
			0.1,
			100.0,
		)

		switch g_state.light_type {
		case .Directional:
			current_shader = directional_light_shader
		case .Point:
			current_shader = point_light_shader
		case .Spot:
			current_shader = spot_light_shader
		}

		glc.shader_use_program(current_shader)
		glc.shader_uniform_set(current_shader, "view", &view)
		glc.shader_uniform_set(current_shader, "projection", &proj)
		glc.shader_uniform_set(current_shader, "viewPos", g_state.camera.position)
		glc.shader_texture_sampler_set(current_shader, "u_material.diffuse", diffuse_map, 0)
		glc.shader_texture_sampler_set(current_shader, "u_material.specular", specular_map, 1)
		glc.shader_uniform_set(current_shader, "material.shininess", 32.0)
		glc.shader_uniform_set(current_shader, "light.ambient", 0.2, 0.2, 0.2)
		glc.shader_uniform_set(current_shader, "light.diffuse", 0.5, 0.5, 0.5)
		glc.shader_uniform_set(current_shader, "light.specular", 1.0, 1.0, 1.0)

		switch g_state.light_type {
		case .Directional:
			glc.shader_uniform_set(
				current_shader,
				"light.direction",
				g_state.directional_light.direction,
			)
		case .Point:
			glc.shader_uniform_set(current_shader, "light.position", g_state.point_light.position)
			glc.shader_uniform_set(current_shader, "light.constant", g_state.point_light.constant)
			glc.shader_uniform_set(current_shader, "light.linear", g_state.point_light.linear)
			glc.shader_uniform_set(
				current_shader,
				"light.quadratic",
				g_state.point_light.quadratic,
			)
		case .Spot:
			glc.shader_uniform_set(current_shader, "light.position", g_state.camera.position)
			glc.shader_uniform_set(current_shader, "light.direction", g_state.camera.front)
			glc.shader_uniform_set(current_shader, "light.constant", g_state.spot_light.constant)
			glc.shader_uniform_set(current_shader, "light.linear", g_state.spot_light.linear)
			glc.shader_uniform_set(current_shader, "light.quadratic", g_state.spot_light.quadratic)
			glc.shader_uniform_set(
				current_shader,
				"light.cutoff",
				glm.cos(g_state.spot_light.cutoff_angle),
			)
			glc.shader_uniform_set(
				current_shader,
				"light.outer_cutoff",
				glm.cos(g_state.spot_light.outer_cutoff_angle),
			)
		}

		for i in 0 ..< 10 {
			model := glm.mat4(1)
			model *= glm.mat4Translate(CUBE_POSITIONS[i])
			angle := f32(20.0) * 1
			model *= glm.mat4Rotate({1.0, 0.3, 0.5}, glm.radians_f32(angle))
			glc.shader_uniform_set(current_shader, "model", &model)
			gl.BindVertexArray(vao)
			gl.DrawArrays(gl.TRIANGLES, 0, 36)
		}

		if (g_state.light_type == .Point) {
			light_cube_model := glm.mat4Translate(g_state.point_light.position)
			light_cube_model *= glm.mat4Scale(0.2)
			glc.shader_use_program(light_cube_shader)
			glc.shader_uniform_set(light_cube_shader, "model", &light_cube_model)
			glc.shader_uniform_set(light_cube_shader, "view", &view)
			glc.shader_uniform_set(light_cube_shader, "projection", &proj)
			gl.BindVertexArray(light_vao)
			gl.DrawArrays(gl.TRIANGLES, 0, 36)
		}

		if (g_state.show_ui) {
			devui.render_ui("Learning OpenGL", ui_render, ui_render_shortcuts)
		}

		sdl.GL_SwapWindow(g_state.window)

		free_all(context.allocator)
	}
}

ui_render :: proc() {
	glc.camera_dev_ui_frame(&g_state.camera)

	if (im.CollapsingHeader("Light", {.DefaultOpen})) {
		light_type_int := cast(i32)g_state.light_type
		if (im.Combo("Light Type", &light_type_int, "Directional\x00Point\x00Spot\x00")) {
			g_state.light_type = cast(Light_Type)light_type_int
		}

		switch g_state.light_type {
		case .Directional:
			im.SliderFloat3("Direction", &g_state.directional_light.direction, -4.0, 4.0)
		case .Point:
			im.SliderFloat3("Position", &g_state.point_light.position, -4.0, 4.0)
			im.SliderFloat("Constant term", &g_state.point_light.constant, 0.1, 1.0)
			im.SliderFloat("Linear term", &g_state.point_light.linear, 0.01, 1.0)
			im.SliderFloat("Quadratic term", &g_state.point_light.quadratic, 0.001, 1.0)
		case .Spot:
			im.SliderAngle("Cutoff Angle", &g_state.spot_light.cutoff_angle, 12.5, 17.4)
			im.SliderAngle(
				"Outer Cutoff Angle",
				&g_state.spot_light.outer_cutoff_angle,
				17.5,
				25.5,
			)
			im.SliderFloat("Constant term", &g_state.spot_light.constant, 0.1, 1.0)
			im.SliderFloat("Linear term", &g_state.spot_light.linear, 0.01, 1.0)
			im.SliderFloat("Quadratic term", &g_state.spot_light.quadratic, 0.001, 1.0)
		}
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
