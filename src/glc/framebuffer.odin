package glc

import gl "vendor:OpenGL"

Framebuffer :: struct {
	id:            u32,
	texture:       Texture_Id,
	render_buffer: u32,
	primitive:     Primitive,
}

framebuffer_create :: proc(primitive_type: Primitive_Type, width, height: i32, gamma_corrected: bool) -> Framebuffer {
	fb: Framebuffer

	// create
	gl.GenFramebuffers(1, &fb.id)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fb.id)

	// bind render texture, as we need to read from it
	fb.texture = texture_load(width, height, gamma_corrected)
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
	gl.FramebufferRenderbuffer(
		gl.FRAMEBUFFER,
		gl.DEPTH_STENCIL_ATTACHMENT,
		gl.RENDERBUFFER,
		fb.render_buffer,
	)

	// check
	assert(gl.CheckFramebufferStatus(gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE)
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

	return fb
}

framebuffer_use :: proc(fb: Framebuffer) {
	gl.BindFramebuffer(gl.FRAMEBUFFER, fb.id)
}

framebuffer_destroy :: proc(fb: ^Framebuffer) {
	texture_destroy(fb.texture)
	primitive_destroy(&fb.primitive)
	gl.DeleteRenderbuffers(1, &fb.render_buffer)
	gl.DeleteFramebuffers(1, &fb.id)
}
