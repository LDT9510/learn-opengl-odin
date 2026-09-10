package glc

import "core:image"
import gl "vendor:OpenGL"

Texture_Id :: distinct u32

texture_load :: proc {
	texture_load_from_content,
	texture_load_from_image_data,
	texture_load_from_model,
	texture_load_empty,
}

texture_load_empty :: proc(width, height: i32, gamma_corrected := false) -> Texture_Id {
	texture_id: u32
	gl.GenTextures(1, &texture_id)
	gl.BindTexture(gl.TEXTURE_2D, texture_id)
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gamma_corrected ? gl.SRGB : gl.RGB,
		width,
		height,
		0,
		gl.RGB,
		gl.UNSIGNED_BYTE,
		nil,
	)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)

	return cast(Texture_Id)texture_id
}

texture_load_from_model :: proc(
	model_name: string,
	image_name: string,
	gamma_corrected := false,
) -> (
	texture_id: Texture_Id,
	ok: bool,
) {
	image_data := content_load_image_from_model(model_name, image_name) or_return
	defer content_destroy_image(image_data)

	return texture_load_from_image_data(image_data, false, gamma_corrected), true
}

texture_load_from_content :: proc(
	image_name: string,
	flip_vertically := false,
	transparent := false,
	gamma_corrected := false,
) -> (
	texture_id: Texture_Id,
	ok: bool,
) {
	image_data := content_load_image(image_name) or_return
	defer content_destroy_image(image_data)

	if flip_vertically {
		flip_image_vertically_inplace(image_data)
	}

	return texture_load_from_image_data(image_data, transparent, gamma_corrected), true
}

texture_load_from_image_data :: proc(
	image_data: ^image.Image,
	transparent := false,
	gamma_corrected := false,
) -> Texture_Id {
	tex_id: u32
	gl.GenTextures(1, &tex_id)

	format: u32 = image_data.channels == 4 ? gl.RGBA : gl.RGB
	internal_format: i32
	if gamma_corrected {
		internal_format = image_data.channels == 4 ? gl.SRGB_ALPHA : gl.SRGB
	} else {
		internal_format = image_data.channels == 4 ? gl.RGBA : gl.RGB
	}

	gl.BindTexture(gl.TEXTURE_2D, tex_id)
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		internal_format,
		cast(i32)image_data.width,
		cast(i32)image_data.height,
		0,
		format,
		gl.UNSIGNED_BYTE,
		raw_data(image_data.pixels.buf),
	)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	// basically a hack
	wrap_parameter: i32 = transparent ? gl.CLAMP_TO_EDGE : gl.REPEAT

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap_parameter)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap_parameter)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	return cast(Texture_Id)tex_id
}

texture_destroy :: proc(texture_id: Texture_Id) {
	texture_id := cast(u32)texture_id
	gl.DeleteTextures(1, &texture_id)
}

flip_image_vertically_inplace :: proc(image_data: ^image.Image) {
	row_size_in_bytes := (image_data.depth / 8) * image_data.width * image_data.channels
	num_rows := image_data.height
	temp_row := make([]byte, row_size_in_bytes)
	defer delete(temp_row)

	for i := 0; i < num_rows / 2; i += 1 {
		top_row := image_data.pixels.buf[i * row_size_in_bytes:][:row_size_in_bytes]
		bottom_row := image_data.pixels.buf[(num_rows - i - 1) *
		row_size_in_bytes:][:row_size_in_bytes]
		copy(temp_row[:], top_row[:])
		copy(top_row[:], bottom_row[:])
		copy(bottom_row[:], temp_row[:])
	}
}
