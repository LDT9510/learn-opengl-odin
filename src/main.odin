package learn_opengl

@(require) import "core:mem"
import "core:fmt"
import "core:log"
import "core:sys/windows"
import glm "core:math/linalg/glsl"

import im "extern:imgui"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

import "lib:devui"
import glc "lib:glcore"

@(require) import ai "extern:assimp"

MAX_POINT_LIGHTS :: 4

Light_Props :: struct {
	color:    glm.vec3,
	ambient:  f32,
	diffuse:  f32,
	specular: f32,
}

get_ambient :: proc(props: Light_Props) -> glm.vec3 {
	return props.ambient * props.color
}

get_diffuse :: proc(props: Light_Props) -> glm.vec3 {
	return props.diffuse * props.color
}

get_specular :: proc(props: Light_Props) -> glm.vec3 {
	return props.specular * props.color
}

Light_Attenuation :: struct {
	constant:  f32,
	linear:    f32,
	quadratic: f32,
}

Directional_Light :: struct {
	direction: glm.vec3,
	props:     Light_Props,
}

Point_Light :: struct {
	position: glm.vec3,
	att:      Light_Attenuation,
	props:    Light_Props,
}

Spot_Light :: struct {
	att:              Light_Attenuation,
	props:            Light_Props,
	cutoff_rad:       f32,
	outer_cutoff_rad: f32,
}

Lights :: struct {
	background_color: glm.vec3,
	directional:      Directional_Light,
	point:            [MAX_POINT_LIGHTS]Point_Light,
	spot:             Spot_Light,
}

State :: struct {
	use_wireframe:         bool,
	program_should_close:  bool,
	camera:                glc.Camera,
	window:                ^sdl.Window,
	is_capturing_mouse:    bool,
	should_reload_shaders: bool,
	show_ui:               bool,
	lights:                Lights,
}
g_state: State

// odinfmt: disable
@rodata
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

@rodata
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

@rodata
POINT_LIGHTS_POSITIONS := [?]glm.vec3 {
	{ 0.7,  0.2,  2.0},
	{ 2.3, -3.3, -4.0},
	{-4.0,  2.0, -12.0},
	{ 0.0,  0.0, -3.0},
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
		lights = {
			background_color = {0.1, 0.1, 0.1},
			directional = {
				direction = {-0.2, -1.0, -0.3},
				props = {color = 1.0, ambient = 0.2, diffuse = 0.5, specular = 1.0},
			},
			spot = {
				att = {constant = 1.0, linear = 0.09, quadratic = 0.032},
				props = {color = 1.0, ambient = 0.1, diffuse = 0.8, specular = 1.0},
				cutoff_rad = glm.radians_f32(12.0),
				outer_cutoff_rad = glm.radians_f32(17.0),
			},
		},
	}

	for i in 0 ..< MAX_POINT_LIGHTS {
		g_state.lights.point[i] = {
			position = POINT_LIGHTS_POSITIONS[i],
			props = {color = 1.0, ambient = 0.2, diffuse = 0.5, specular = 1.0},
			att = {constant = 1.0, linear = 0.09, quadratic = 0.032},
		}
	}

	gl_ctx: sdl.GLContext
	g_state.window, gl_ctx = glc.create_opengl_window()
	defer glc.destroy_opengl_window(g_state.window, gl_ctx)

	devui.init_for_sdl_window(g_state.window, gl_ctx)
	defer devui.destroy()

	main_shader, light_cube_shader := load_shaders()
	defer delete_shaders(main_shader, light_cube_shader)

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

	free_all(context.temp_allocator)

	for !g_state.program_should_close {
		glc.events_handle(process_events, process_key_input)
		glc.timing_update_delta_time()

		gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

		r, g, b := expand_values(g_state.lights.background_color)
		gl.ClearColor(r, g, b, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		if g_state.should_reload_shaders {
			log.info("Reloading shaders...")
			defer log.info("Done!")

			g_state.should_reload_shaders = false
			delete_shaders(main_shader, light_cube_shader)
			main_shader, light_cube_shader = load_shaders()
		}

		view := glc.camera_get_view_matrix(g_state.camera)
		proj := glm.mat4Perspective(
			glm.radians(g_state.camera.zoom),
			glc.window_get_aspect_ratio(g_state.window),
			0.1,
			100.0,
		)

		// main shader
		glc.shader_use_program(main_shader)
		glc.shader_uniform_set(main_shader, "u_view", &view)
		glc.shader_uniform_set(main_shader, "u_projection", &proj)
		glc.shader_uniform_set(main_shader, "u_view_pos", g_state.camera.position)

		// materials
		glc.shader_use_program(main_shader)
		glc.shader_texture_sampler_set(main_shader, "u_material.diffuse", diffuse_map, 0)
		glc.shader_texture_sampler_set(main_shader, "u_material.specular", specular_map, 1)
		glc.shader_uniform_set(main_shader, "u_material.shininess", 32.0)

		// directional light
		dir_light := &g_state.lights.directional
		glc.shader_use_program(main_shader)
		glc.shader_uniform_set(main_shader, "u_dir_light.direction", dir_light.direction)
		glc.shader_uniform_set(main_shader, "u_dir_light.ambient", get_ambient(dir_light.props))
		glc.shader_uniform_set(main_shader, "u_dir_light.diffuse", get_diffuse(dir_light.props))
		glc.shader_uniform_set(main_shader, "u_dir_light.specular", get_specular(dir_light.props))

		// point lights
		for i in 0 ..< MAX_POINT_LIGHTS {
			u_position := fmt.ctprintf("u_point_lights[%d].position", i)
			u_constant := fmt.ctprintf("u_point_lights[%d].constant", i)
			u_linear := fmt.ctprintf("u_point_lights[%d].linear", i)
			u_quadratic := fmt.ctprintf("u_point_lights[%d].quadratic", i)
			u_ambient := fmt.ctprintf("u_point_lights[%d].ambient", i)
			u_diffuse := fmt.ctprintf("u_point_lights[%d].diffuse", i)
			u_specular := fmt.ctprintf("u_point_lights[%d].specular", i)
			point_light := &g_state.lights.point[i]

			glc.shader_use_program(main_shader)
			glc.shader_uniform_set(main_shader, u_position, point_light.position)
			glc.shader_uniform_set(main_shader, u_constant, point_light.att.constant)
			glc.shader_uniform_set(main_shader, u_linear, point_light.att.linear)
			glc.shader_uniform_set(main_shader, u_quadratic, point_light.att.quadratic)
			glc.shader_uniform_set(main_shader, u_ambient, get_ambient(point_light.props))
			glc.shader_uniform_set(main_shader, u_diffuse, get_diffuse(point_light.props))
			glc.shader_uniform_set(main_shader, u_specular, get_specular(point_light.props))

			// render cubes at light positions
			light_cube_model := glm.mat4Translate(point_light.position)
			light_cube_model *= glm.mat4Scale(0.2)
			glc.shader_use_program(light_cube_shader)
			glc.shader_uniform_set(light_cube_shader, "u_projection", &proj)
			glc.shader_uniform_set(light_cube_shader, "u_view", &view)
			glc.shader_uniform_set(light_cube_shader, "u_model", &light_cube_model)
			glc.shader_uniform_set(light_cube_shader, "u_color", point_light.props.color)
			gl.BindVertexArray(light_vao)
			gl.DrawArrays(gl.TRIANGLES, 0, 36)
		}

		// spot light
		spot_light := &g_state.lights.spot
		glc.shader_use_program(main_shader)
		glc.shader_uniform_set(main_shader, "u_spot_light.position", g_state.camera.position)
		glc.shader_uniform_set(main_shader, "u_spot_light.direction", g_state.camera.front)
		glc.shader_uniform_set(main_shader, "u_spot_light.cutoff", glm.cos(spot_light.cutoff_rad))
		glc.shader_uniform_set(
			main_shader,
			"u_spot_light.outer_cutoff",
			glm.cos(spot_light.outer_cutoff_rad),
		)
		glc.shader_uniform_set(main_shader, "u_spot_light.constant", spot_light.att.constant)
		glc.shader_uniform_set(main_shader, "u_spot_light.linear", spot_light.att.linear)
		glc.shader_uniform_set(main_shader, "u_spot_light.quadratic", spot_light.att.quadratic)
		glc.shader_uniform_set(main_shader, "u_spot_light.ambient", get_ambient(spot_light.props))
		glc.shader_uniform_set(main_shader, "u_spot_light.diffuse", get_diffuse(spot_light.props))
		glc.shader_uniform_set(
			main_shader,
			"u_spot_light.specular",
			get_specular(spot_light.props),
		)

		// render scene cubes
		for i in 0 ..< 10 {
			model := glm.mat4(1)
			model *= glm.mat4Translate(CUBE_POSITIONS[i])
			angle := f32(20.0) * 1
			model *= glm.mat4Rotate({1.0, 0.3, 0.5}, glm.radians_f32(angle))
			glc.shader_use_program(main_shader)
			glc.shader_uniform_set(main_shader, "u_model", &model)
			gl.BindVertexArray(vao)
			gl.DrawArrays(gl.TRIANGLES, 0, 36)
		}

		if g_state.show_ui {
			devui.render_ui("Learning OpenGL", ui_render, ui_render_shortcuts)
		}

		sdl.GL_SwapWindow(g_state.window)

		free_all(context.temp_allocator)
	}
}

ui_render :: proc() {
	glc.camera_dev_ui_frame(&g_state.camera)

	if im.CollapsingHeader("Lights") {
		im.ColorEdit3("Background", &g_state.lights.background_color)

		if im.TreeNode("Directional") {
			defer im.TreePop()

			dir_light := &g_state.lights.directional
			im.DragFloat3("Direction", &dir_light.direction, 0.1, -4.0, 4.0)
			props_render(&dir_light.props)
		}
		if im.TreeNode("Points") {
			defer im.TreePop()
			for i in 0 ..< MAX_POINT_LIGHTS {
				if im.TreeNode(fmt.ctprintf("Point %d", i)) {
					defer im.TreePop()

					point_light := &g_state.lights.point[i]
					im.DragFloat3("Position", &point_light.position, 0.1, -4.0, 4.0)
					props_render(&point_light.props)
					att_render(&point_light.att)
				}
			}
		}
		if im.TreeNode("Spot") {
			defer im.TreePop()

			spot_light := &g_state.lights.spot
			im.SliderAngle("Cutoff Angle", &spot_light.cutoff_rad, 12.0, 16.0)
			im.SliderAngle("Outer Cutoff Angle", &spot_light.outer_cutoff_rad, 17.0, 25.0)

			props_render(&spot_light.props)
			att_render(&spot_light.att)
		}
	}

	if im.Button("Reload Shaders") {
		g_state.should_reload_shaders = true
	}

	// ----------------- UI helpers ---------------------------
	props_render :: proc(props: ^Light_Props) {
		im.ColorEdit3("Color", &props.color)
		im.DragFloat("Ambient", &props.ambient, 0.01, 0.0, 1.0)
		im.DragFloat("Diffuse", &props.diffuse, 0.01, 0.0, 1.0)
		im.DragFloat("Specular", &props.specular, 0.01, 0.0, 1.0)
	}

	att_render :: proc(att: ^Light_Attenuation) {
		im.DragFloat("Constant", &att.constant, 0.01, 0.01, 1.0)
		im.DragFloat("Linear", &att.linear, 0.01, 0.01, 1.0)
		im.DragFloat("Quadratic", &att.quadratic, 0.01, 0.01, 1.0)
	}
}


load_shaders :: proc(
) -> (
	lighting_shader: glc.Shader_Program_Handle,
	light_cube_shader: glc.Shader_Program_Handle,
) {
	lighting_shader = load_single("main")
	light_cube_shader = load_single("light_cube")
	return

	load_single :: proc(name: string) -> glc.Shader_Program_Handle {
		shader, ok := glc.shader_load_from_files(name)
		if !ok {
			log.errorf("Error loading shader: \"%s\"", name)
		}

		return shader
	}
}

delete_shaders :: proc(shaders: ..glc.Shader_Program_Handle) {
	for shader in shaders {
		glc.shader_delete_program(shader)
	}
}

process_events :: proc(event: sdl.Event) {
	g_state.is_capturing_mouse = glc.events_is_mouse_button_pressed({.RIGHT})
	_ = sdl.SetWindowRelativeMouseMode(g_state.window, g_state.is_capturing_mouse)

	#partial switch event.type {
	case .QUIT:
		g_state.program_should_close = true
	case .WINDOW_PIXEL_SIZE_CHANGED:
		gl.Viewport(0, 0, event.window.data1, event.window.data2)
	case .MOUSE_WHEEL:
		glc.camera_on_mouse_wheel_scroll(&g_state.camera, event.wheel.y)
	case .MOUSE_MOTION:
		if g_state.is_capturing_mouse {
			glc.camera_on_mouse_move(&g_state.camera, event.motion.xrel, -event.motion.yrel, true)
		}
	}
}

ui_render_shortcuts :: proc() {
	devui.shortcut("ESC", "Close program")
	devui.shortcut("U", "Enables wireframe mode")
	devui.shortcut("I", "Toggle UI")
	devui.shortcut("R", "Reload shaders")
	devui.shortcut("(Shift +)WASD", "(Sprint) Camera move")
	devui.shortcut("Right click (hold)", "Look around")
}

process_key_input :: proc() {
	switch {
	case glc.events_is_key_just_pressed(.ESCAPE):
		g_state.program_should_close = true
	case glc.events_is_key_just_pressed(.U):
		g_state.use_wireframe = !g_state.use_wireframe
	case glc.events_is_key_just_pressed(.I):
		g_state.show_ui = !g_state.show_ui
	case glc.events_is_key_just_pressed(.R):
		g_state.should_reload_shaders = true
	}

	glc.camera_handle_input(&g_state.camera)
}
