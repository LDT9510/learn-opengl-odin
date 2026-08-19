package devui

import im "extern:imgui"
import im_gl "extern:imgui/imgui_impl_opengl3"
import im_sdl "extern:imgui/imgui_impl_sdl3"

import sdl "vendor:sdl3"

init_for_sdl_window :: proc(window: ^sdl.Window, gl_context: sdl.GLContext) {
	im.CHECKVERSION()
	im.CreateContext()
	im_sdl.InitForOpenGL(window, gl_context)
	im_gl.Init()

	io := im.GetIO()
	io.ConfigFlags += {.DockingEnable}

	im.FontAtlas_AddFontFromMemoryCompressedTTF(
		io.Fonts,
		&ROBOTO_FONT_COMPRESSED_DATA,
		ROBOT_MEDIUM_COMPRESSED_SIZE,
		20.0,
	)

	im.StyleColorsDark()
}

begin_frame :: proc() {
	im_gl.NewFrame()
	im_sdl.NewFrame()
	im.NewFrame()

	im.DockSpaceOverViewport(0, nil, {.PassthruCentralNode})
}

render_frame :: proc() {
	im.Render()
	im_gl.RenderDrawData(im.GetDrawData())
}

process_event :: proc(event: ^sdl.Event) {
	im_sdl.ProcessEvent(event)
}

wants_mouse_input :: proc() -> bool {
	return im.GetIO().WantCaptureMouse
}

wants_keyboard_input :: proc() -> bool {
	return im.GetIO().WantCaptureKeyboard
}

deinit :: proc() {
	im_gl.Shutdown()
	im_sdl.Shutdown()
	im.DestroyContext()
}
