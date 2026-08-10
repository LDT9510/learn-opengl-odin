package glcore

import "core:image"

import gl "vendor:OpenGL"

Texture_Id :: distinct u32

texture_load :: proc {
	texture_load_from_content,
	texture_load_from_file_and_dir,
	texture_load_from_image_data,
}

texture_load_from_file_and_dir :: proc(
	dir, file: string,
	flip_vertically := false,
	transparent := false,
) -> (
	texture_id: Texture_Id,
	ok: bool,
) {
	image_data := content_load_image(file, dir) or_return
	defer content_destroy_image(image_data)

	if flip_vertically {
		flip_image_vertically_inplace(image_data)
	}

	return texture_load_from_image_data(image_data, transparent)
}

texture_load_from_content :: proc(
	image_name: string,
	flip_vertically := false,
	transparent := false,
) -> (
	texture_id: Texture_Id,
	ok: bool,
) {
	image_data := content_load_image(image_name) or_return
	defer content_destroy_image(image_data)

	if flip_vertically {
		flip_image_vertically_inplace(image_data)
	}

	return texture_load_from_image_data(image_data, transparent)
}

texture_load_from_image_data :: proc(
	image_data: ^image.Image,
	transparent := false
) -> (
	texture_id: Texture_Id,
	ok: bool,
) {
	tex_id: u32
	gl.GenTextures(1, &tex_id)

	image_format: u32 = image_data.channels == 4 ? gl.RGBA : gl.RGB

	gl.BindTexture(gl.TEXTURE_2D, tex_id)
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		cast(i32)image_format,
		cast(i32)image_data.width,
		cast(i32)image_data.height,
		0,
		image_format,
		gl.UNSIGNED_BYTE,
		raw_data(image_data.pixels.buf),
	)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	// basically a hack
	wrap_parameter : i32 = transparent ? gl.CLAMP_TO_EDGE : gl.REPEAT
	
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap_parameter)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap_parameter)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	return cast(Texture_Id)tex_id, true
}

texture_destroy :: proc(texture_id: Texture_Id) {
	texture_id := cast(u32)texture_id
	gl.DeleteTextures(1, &texture_id)
}
