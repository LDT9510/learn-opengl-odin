package glcore

import gl "vendor:OpenGL"

Texture_Id :: distinct u32

Texture :: struct {
	id:   Texture_Id,
	type: enum {
		Difusse,
		Specular
	},
}

texture_load :: proc(image_name: string) -> (texture_id: Texture_Id, ok: bool) {
	image_data := content_load_image(image_name) or_return
	defer content_destroy_image(image_data)

	tex_id: u32
	gl.GenTextures(1, &tex_id)

	image_format: u32 = image_data.channels == 4 ? gl.RGBA : gl.RGB

	gl.BindTexture(gl.TEXTURE_2D, tex_id)
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RGB,
		cast(i32)image_data.width,
		cast(i32)image_data.height,
		0,
		image_format,
		gl.UNSIGNED_BYTE,
		raw_data(image_data.pixels.buf),
	)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	return cast(Texture_Id)tex_id, true
}

texture_destroy :: proc(texture_id: Texture_Id) {
	texture_id := cast(u32)texture_id
	gl.DeleteTextures(1, &texture_id)
}
