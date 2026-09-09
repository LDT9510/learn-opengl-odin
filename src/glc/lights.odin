package glc

import im "extern:imgui"

import "core:fmt"
import glm "core:math/linalg/glsl"

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
	directional: Directional_Light,
	point:       [MAX_POINT_LIGHTS]Point_Light,
	spot:        Spot_Light,
}

lights_default :: proc "contextless" () -> Lights {
	return {
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
	if im.CollapsingHeader("Lights") {

		if im.TreeNode("Directional") {
			defer im.TreePop()

			dir_light := &lights.directional
			im.DragFloat3("Direction", &dir_light.direction, 0.1, -4.0, 4.0)
			props_render(&dir_light.props)
		}
		if im.TreeNode("Points") {
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
		if im.TreeNode("Spot") {
			defer im.TreePop()

			spot_light := &lights.spot
			im.SliderAngle("Cutoff Angle", &spot_light.cutoff_rad, 12.0, 16.0)
			im.SliderAngle("Outer Cutoff Angle", &spot_light.outer_cutoff_rad, 17.0, 25.0)

			props_render(&spot_light.props)
			att_render(&spot_light.att)
		}
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
