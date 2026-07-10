package custom_camera

import glm "core:math/linalg/glsl"

import im "extern:imgui"
import glc "lib:glcore"

// odinfmt: disable
CAMERA_DEFAULT_YAW           :: -90.0
CAMERA_DEFAULT_PITCH         ::   0.0
CAMERA_DEFAULT_SPEED         ::   2.5
CAMERA_DEFAULT_SPRINT_FACTOR ::   5
CAMERA_DEFAULT_ZOOM          ::  45.0
CAMERA_DEFAULT_ZOOM_SPEED    ::   1.0
CAMERA_DEFAULT_SENSITIVITY   ::   0.1
// odinfmt: enable

Camera :: struct #all_or_none {
	position:       glm.vec3,
	front:          glm.vec3,
	up:             glm.vec3,
	right:          glm.vec3,
	world_up:       glm.vec3,
	yaw:            f32,
	pitch:          f32,
	movement_speed: f32,
	sprint_factor:  i32,
	sensitivity:    f32,
	zoom:           f32,
}

camera_create :: proc(
	pos: glm.vec3,
	up: glm.vec3,
	yaw: f32 = CAMERA_DEFAULT_YAW,
	pitch: f32 = CAMERA_DEFAULT_PITCH,
) -> Camera {
	camera := Camera {
		position       = pos,
		front          = {0, 0, -1},
		up             = {},
		right          = {},
		world_up       = up,
		yaw            = glm.radians_f32(yaw),
		pitch          = glm.radians_f32(pitch),
		movement_speed = CAMERA_DEFAULT_SPEED,
		sprint_factor  = CAMERA_DEFAULT_SPRINT_FACTOR,
		sensitivity    = CAMERA_DEFAULT_SENSITIVITY,
		zoom           = CAMERA_DEFAULT_ZOOM,
	}

	_camera_update_vectors(&camera)

	return camera
}

camera_get_view_matrix :: proc(c: Camera) -> glm.mat4 {
	rx, ry, rz := expand_values(c.right)
	ux, uy, uz := expand_values(c.up)
	dx, dy, dz := expand_values(-c.front) // inverted z-axis (rotate in opposite direction)
	px, py, pz := expand_values(-c.position) // transform in opposite direction
	
	// odinfmt: disable
	rotation := glm.mat4{
		rx, ry, rz, 0,
		ux, uy, uz, 0,
		dx, dy, dz, 0,
		 0,  0,  0, 1,
	}

	translation := glm.mat4{
		1, 0, 0, px,
		0, 1, 0, py,
		0, 0, 1, pz,
		0, 0, 0,  1,
	}
	// odinfmt: enable

	return rotation * translation
}

camera_handle_input :: proc(c: ^Camera) {
	speed := c.movement_speed
	if (glc.events_is_key_pressed(.LSHIFT)) {
		speed *= cast(f32)c.sprint_factor
	}

	velocity := speed * glc.g_delta_time

	fixed_y := c.position.y

	if glc.events_is_key_pressed(.W) {
		c.position += c.front * velocity
	}
	if glc.events_is_key_pressed(.S) {
		c.position -= c.front * velocity
	}
	if glc.events_is_key_pressed(.A) {
		c.position -= c.right * velocity
	}
	if glc.events_is_key_pressed(.D) {
		c.position += c.right * velocity
	}

	c.position.y = fixed_y
}

camera_on_mouse_move :: proc(c: ^Camera, x, y: f32, constrain_pitch: bool) {
	c.yaw += glm.radians(x * c.sensitivity)
	c.pitch += glm.radians(y * c.sensitivity)

	if (constrain_pitch) {
		c.pitch = glm.clamp(c.pitch, glm.radians_f32(-89), glm.radians_f32(89))
	}

	_camera_update_vectors(c)
}

camera_on_mouse_wheel_scroll :: proc(c: ^Camera, mouse_wheel_direction: f32) {
	c.zoom -= CAMERA_DEFAULT_ZOOM_SPEED * mouse_wheel_direction
	c.zoom = glm.clamp(c.zoom, 1.0, 45.0)
}

camera_dev_ui_frame :: proc(c: ^Camera) {
	if (im.CollapsingHeader("Camera")) {
		im.SliderFloat("FOV", &c.zoom, 10.0, 120.0, "%.0f deg")
		im.SliderFloat("Speed", &c.movement_speed, 1.0, 50.0, "%.1f")
		im.DragFloat3("Position", &c.position, 0.1)

		yaw_changed := im.SliderAngle("Yaw", &c.yaw)
		pitch_changed := im.SliderAngle("Pitch", &c.pitch, -90.0, 90.0)
		if yaw_changed || pitch_changed {
			_camera_update_vectors(c)
		}

		im.SliderInt("Sprint factor", &c.sprint_factor, 1, 10)
	}
}

_camera_update_vectors :: proc(c: ^Camera) {
	front := glm.vec3 {
		glm.cos(c.yaw) * glm.cos(c.pitch),
		glm.sin(c.pitch),
		glm.sin(c.yaw) * glm.cos(c.pitch),
	}

	c.front = glm.normalize(front)
	c.right = glm.normalize(glm.cross(front, c.world_up))
	c.up = glm.normalize(glm.cross(c.right, front))
}
