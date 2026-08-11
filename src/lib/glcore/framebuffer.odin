package glcore

import glc "lib:glcore"

import gl "vendor:OpenGL"

Framebuffer :: struct {
	id:            u32,
	texture:       Texture_Id,
	render_buffer: u32,
	primitive:     Primitive,
}

framebuffer_create :: proc(
	primitive_type: Primitive_Type,
	width, height: i32,
) -> (
	fb: Framebuffer,
) {
	// create
	gl.GenFramebuffers(1, &fb.id)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fb.id)

	// bind render texture, as we need to read from it
	fb.texture = texture_load(width, height)
	fb.primitive = primitive_create(primitive_type, fb.texture)
	gl.BindTexture(gl.TEXTURE_2D, cast(u32)fb.texture)
	gl.FramebufferTexture2D(
		gl.FRAMEBUFFER,
		gl.COLOR_ATTACHMENT0,
		gl.TEXTURE_2D,
		cast(u32)fb.texture,
		0,
	)

	// use a renderbuffer object for depth and stencil as there is no need to read back
	gl.GenRenderbuffers(1, &fb.render_buffer)
	gl.BindRenderbuffer(gl.RENDERBUFFER, fb.render_buffer)
	gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, width, height)
	// attach to framebuffer
	gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, fb.render_buffer)

	// check
	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
		glc.crash("Framebuffer is not complete!")
	}
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

	return
}

framebuffer_use :: proc(fb: Framebuffer) {
	gl.BindFramebuffer(gl.FRAMEBUFFER, fb.id)
}

framebuffer_draw :: proc(fb: Framebuffer, shader: Shader_Program_Handle, clear := false) {
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	if clear {
		gl.ClearColor(1.0, 1.0, 1.0, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)
		gl.Disable(gl.DEPTH_TEST)
	}
	primitive_draw(fb.primitive, shader)
}

framebuffer_destroy :: proc(fb: ^Framebuffer) {
	texture_destroy(fb.texture)
	primitive_destroy(&fb.primitive)
	gl.DeleteRenderbuffers(1, &fb.render_buffer)
	gl.DeleteFramebuffers(1, &fb.id)
}
