package modules

import "main:devui"

import "core:c"
import "core:mem"
import sdl "vendor:sdl3"

// this is missing from the bindings
MAX_SDL_SCANCODES :: 512

Key_Input_Handler_Proc :: #type proc(state: rawptr)
Events_Handler_Proc :: #type proc(event: sdl.Event, state: rawptr)

_g_previous_keyboard_state: [MAX_SDL_SCANCODES]bool
_g_current_keyboard_state: [^]bool

events_is_key_pressed :: proc(key: sdl.Scancode) -> bool {
	return _g_current_keyboard_state[key]
}

events_is_key_just_pressed :: proc(key: sdl.Scancode) -> bool {
	return _g_current_keyboard_state[key] && !_g_previous_keyboard_state[key]
}

events_is_mouse_button_pressed :: proc(button: sdl.MouseButtonFlags) -> bool {
	button_flag := sdl.GetMouseState(nil, nil)
	return button_flag == button
}

events_handle :: proc(kih: Key_Input_Handler_Proc, eh: Events_Handler_Proc, state: rawptr) {
	if !devui.wants_keyboard_input() {
		num_keys: c.int
		keyboard_state := sdl.GetKeyboardState(&num_keys)
		mem.copy(&_g_previous_keyboard_state, keyboard_state, cast(int)num_keys)

		sdl.PumpEvents()

		_g_current_keyboard_state = sdl.GetKeyboardState(&num_keys)

		kih(state)
	}

	e: sdl.Event = ---
	for sdl.PollEvent(&e) {
		devui.process_event(&e)

		if !devui.wants_mouse_input() {
			eh(e, state)
		}
	}
}
