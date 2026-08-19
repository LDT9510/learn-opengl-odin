package app

import im "extern:imgui"

import glm "core:math/linalg/glsl"

Camera :: struct {
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
	zoom_speed:     f32,
	frustrum_near:  f32,
	frustrum_far:   f32,
}

DEG90_RAD :: -90 * glm.TAU / 360.0

CAMERA_DEFAULT :: Camera {
	position       = 0,
	front          = {0, 0, -1},
	up             = {0, 1, 0},
	right          = 0,
	world_up       = 0,
	yaw            = DEG90_RAD,
	pitch          = 0,
	movement_speed = 2.5,
	sprint_factor  = 5,
	sensitivity    = 0.1,
	zoom           = 45.0,
	zoom_speed     = 1.0,
	frustrum_near  = 0.1,
	frustrum_far   = 100,
}

camera_create :: proc "contextless" (
	pos: glm.vec3,
	up: glm.vec3 = CAMERA_DEFAULT.up,
	yaw: f32 = CAMERA_DEFAULT.yaw,
	pitch: f32 = CAMERA_DEFAULT.pitch,
) -> Camera {
	cam := CAMERA_DEFAULT
	cam.position = pos
	cam.world_up = up
	cam.yaw = glm.radians_f32(yaw)
	cam.pitch = glm.radians_f32(pitch)

	_camera_update_vectors(&cam)

	return cam
}

camera_get_view_matrix :: proc(c: Camera) -> glm.mat4 {
	return glm.mat4LookAt(c.position, c.position + c.front, c.up)
}

camera_handle_input :: proc(c: ^Camera, delta_time: f32) {
	speed := c.movement_speed
	if events_is_key_pressed(.LSHIFT) {
		speed *= cast(f32)c.sprint_factor
	}

	velocity := speed * delta_time

	if events_is_key_pressed(.W) {
		c.position += c.front * velocity
	}
	if events_is_key_pressed(.S) {
		c.position -= c.front * velocity
	}
	if events_is_key_pressed(.A) {
		c.position -= c.right * velocity
	}
	if events_is_key_pressed(.D) {
		c.position += c.right * velocity
	}
}

camera_on_mouse_move :: proc(c: ^Camera, x, y: f32, constrain_pitch: bool) {
	c.yaw += glm.radians(x * c.sensitivity)
	c.pitch += glm.radians(y * c.sensitivity)

	if constrain_pitch {
		c.pitch = glm.clamp(c.pitch, glm.radians_f32(-89), glm.radians_f32(89))
	}

	_camera_update_vectors(c)
}

camera_on_mouse_wheel_scroll :: proc(c: ^Camera, mouse_wheel_direction: f32) {
	c.zoom -= c.zoom_speed * mouse_wheel_direction
	c.zoom = glm.clamp(c.zoom, 1.0, 45.0)
}

camera_dev_ui_frame :: proc(c: ^Camera) {
	if im.CollapsingHeader("Camera") {
		im.SliderFloat("FOV", &c.zoom, 10.0, 120.0, "%.0f deg")
		im.SliderFloat("Speed", &c.movement_speed, 1.0, 50.0, "%.1f")
		im.DragFloat3("Position", &c.position, 0.1)

		yaw_changed := im.SliderAngle("Yaw", &c.yaw)
		pitch_changed := im.SliderAngle("Pitch", &c.pitch, -90.0, 90.0)
		if yaw_changed || pitch_changed {
			_camera_update_vectors(c)
		}

		im.SliderInt("Sprint factor", &c.sprint_factor, 2, 10)
		im.DragFloat("Near Plane", &c.frustrum_near, 0.01, 0.1, 99.9)
		im.DragFloat("Far Plane", &c.frustrum_far, 1.0, 50.0, 150.0)
	}
}

_camera_update_vectors :: proc "contextless" (c: ^Camera) {
	front := glm.vec3 {
		glm.cos(c.yaw) * glm.cos(c.pitch),
		glm.sin(c.pitch),
		glm.sin(c.yaw) * glm.cos(c.pitch),
	}

	c.front = glm.normalize(front)
	c.right = glm.normalize(glm.cross(front, c.world_up))
	c.up = glm.normalize(glm.cross(c.right, front))
}
