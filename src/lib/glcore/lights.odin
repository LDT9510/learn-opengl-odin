package glcore

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
	background_color: glm.vec3,
	directional:      Directional_Light,
	point:            [MAX_POINT_LIGHTS]Point_Light,
	spot:             Spot_Light,
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
