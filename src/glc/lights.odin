package glc

import mod "main:modules"

import "core:fmt"
import glm "core:math/linalg/glsl"

import im "extern:imgui"

// must match the shader
MAX_POINT_LIGHTS :: 4

Light_Props :: struct {
	color:    glm.vec3,
	ambient:  f32,
	diffuse:  f32,
	specular: f32,
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
	directional:               Directional_Light,
	point:                     [MAX_POINT_LIGHTS]Point_Light,
	spot:                      Spot_Light,
	dir_on, point_on, spot_on: bool,
}

lights_default :: proc "contextless" (point_lights_pos: ^[MAX_POINT_LIGHTS]glm.vec3) -> Lights {
	lights := Lights {
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
	}

	for i in 0 ..< MAX_POINT_LIGHTS {
		lights.point[i] = {
			position = point_lights_pos[i],
			props = {color = 1.0, ambient = 0.2, diffuse = 0.5, specular = 1.0},
			att = {constant = 1.0, linear = 0.09, quadratic = 0.032},
		}
	}

	lights.dir_on = true
	lights.point_on = true
	lights.spot_on = true

	return lights
}

lights_set_uniforms :: proc(
	lights: Lights,
	program: Shader_Program,
	camera: mod.Camera,
	blinn: bool,
) {
	shader_use_program(program)

	// global
	shader_uniform_set(program, "u_view_pos", camera.position)
	shader_uniform_set(program, "u_blinn", blinn)

	// directional
	shader_uniform_set(program, "u_dir_on", lights.dir_on)
	if lights.dir_on {
		shader_uniform_set(program, "u_dir_light.direction", lights.directional.direction)
		shader_uniform_set(
			program,
			"u_dir_light.ambient",
			lights_get_ambient(lights.directional.props),
		)
		shader_uniform_set(
			program,
			"u_dir_light.diffuse",
			lights_get_diffuse(lights.directional.props),
		)
		shader_uniform_set(
			program,
			"u_dir_light.specular",
			lights_get_specular(lights.directional.props),
		)
	}

	// point
	shader_uniform_set(program, "u_point_on", lights.point_on)
	if lights.point_on {
		for i in 0 ..< MAX_POINT_LIGHTS {
			u_position := fmt.ctprintf("u_point_lights[%d].position", i)
			u_constant := fmt.ctprintf("u_point_lights[%d].constant", i)
			u_linear := fmt.ctprintf("u_point_lights[%d].linear", i)
			u_quadratic := fmt.ctprintf("u_point_lights[%d].quadratic", i)
			u_ambient := fmt.ctprintf("u_point_lights[%d].ambient", i)
			u_diffuse := fmt.ctprintf("u_point_lights[%d].diffuse", i)
			u_specular := fmt.ctprintf("u_point_lights[%d].specular", i)

			shader_uniform_set(program, u_position, lights.point[i].position)
			shader_uniform_set(program, u_constant, lights.point[i].att.constant)
			shader_uniform_set(program, u_linear, lights.point[i].att.linear)
			shader_uniform_set(program, u_quadratic, lights.point[i].att.quadratic)
			shader_uniform_set(program, u_ambient, lights_get_ambient(lights.point[i].props))
			shader_uniform_set(program, u_diffuse, lights_get_diffuse(lights.point[i].props))
			shader_uniform_set(program, u_specular, lights_get_specular(lights.point[i].props))
		}
	}

	// spot
	shader_uniform_set(program, "u_spot_on", lights.spot_on)
	if lights.spot_on {
		shader_uniform_set(program, "u_spot_light.position", camera.position)
		shader_uniform_set(program, "u_spot_light.direction", camera.front)
		shader_uniform_set(program, "u_spot_light.cutoff", glm.cos(lights.spot.cutoff_rad))
		shader_uniform_set(
			program,
			"u_spot_light.outer_cutoff",
			glm.cos(lights.spot.outer_cutoff_rad),
		)
		shader_uniform_set(program, "u_spot_light.constant", lights.spot.att.constant)
		shader_uniform_set(program, "u_spot_light.linear", lights.spot.att.linear)
		shader_uniform_set(program, "u_spot_light.quadratic", lights.spot.att.quadratic)
		shader_uniform_set(program, "u_spot_light.ambient", lights_get_ambient(lights.spot.props))
		shader_uniform_set(program, "u_spot_light.diffuse", lights_get_diffuse(lights.spot.props))
		shader_uniform_set(
			program,
			"u_spot_light.specular",
			lights_get_specular(lights.spot.props),
		)
	}
}

lights_render_point_lights :: proc(lights: Lights, primitive: Primitive, rs: ^Render_State) {
	if !lights.point_on {
		return
	}

	dp := dpd(rs)
	dp.shader = shader_program_resource(.Light_Cube)
	shader_use_program(dp.shader)

	for i in 0 ..< MAX_POINT_LIGHTS {
		dp.translation = lights.point[i].position
		dp.scale = 0.2
		shader_uniform_set(dp.shader, "u_color", lights.point[i].props.color)
		draw(primitive, &dp)
	}
}

lights_get_ambient :: proc(props: Light_Props) -> glm.vec3 {
	return props.ambient * props.color
}

lights_get_diffuse :: proc(props: Light_Props) -> glm.vec3 {
	return props.diffuse * props.color
}

lights_get_specular :: proc(props: Light_Props) -> glm.vec3 {
	return props.specular * props.color
}

lights_dev_ui :: proc(lights: ^Lights) {
	im.Checkbox("Directional", &lights.dir_on)
	im.SameLine()
	im.Checkbox("Points", &lights.point_on)
	im.SameLine()
	im.Checkbox("Spot", &lights.spot_on)


	if im.TreeNode("Directional Light") {
		defer im.TreePop()

		dir_light := &lights.directional
		im.DragFloat3("Direction", &dir_light.direction, 0.1, -4.0, 4.0)
		props_render(&dir_light.props)
	}
	if im.TreeNode("Points Lights") {
		defer im.TreePop()
		for i in 0 ..< MAX_POINT_LIGHTS {
			if im.TreeNode(fmt.ctprintf("Point %d", i)) {
				defer im.TreePop()

				point_light := &lights.point[i]
				im.DragFloat3("Position", &point_light.position, 0.1, -4.0, 4.0)
				props_render(&point_light.props)
				att_render(&point_light.att)
			}
		}
	}
	if im.TreeNode("Spot Light") {
		defer im.TreePop()

		spot_light := &lights.spot
		im.SliderAngle("Cutoff Angle", &spot_light.cutoff_rad, 12.0, 16.0)
		im.SliderAngle("Outer Cutoff Angle", &spot_light.outer_cutoff_rad, 17.0, 25.0)

		props_render(&spot_light.props)
		att_render(&spot_light.att)
	}

	// ----------------- Helpers ---------------------------
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
