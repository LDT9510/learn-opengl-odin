package glc

import "core:image"
import "core:log"
import gl "vendor:OpenGL"

Texture_Id :: distinct u32

texture_load :: proc {
	texture_load_from_content,
	texture_load_from_image_data,
	texture_load_empty,
}

texture_load_empty :: proc(width, height: i32) -> Texture_Id {
	texture_id: u32
	gl.GenTextures(1, &texture_id)
	gl.BindTexture(gl.TEXTURE_2D, texture_id)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)

	return cast(Texture_Id)texture_id
}

texture_load_from_model :: proc(
	model_name: string,
	image_name: string,
) -> (
	texture_id: Texture_Id,
	ok: bool,
) {
	image_data := content_load_image_from_model(model_name, image_name) or_return
	defer content_destroy_image(image_data)

	return texture_load_from_image_data(image_data, false)
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
	transparent := false,
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
	wrap_parameter: i32 = transparent ? gl.CLAMP_TO_EDGE : gl.REPEAT

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

@(private = "file")
g_registry: [Texture_Resource_Index]Resource(Texture_Id)

Texture_Resource_Index :: enum {
	Container,
	Create_Diffuse,
	Crate_Specular,
	Grass,
	Marble,
	Metal,
	Transparent_Window,
}
texture_resource :: proc(index: Texture_Resource_Index) -> Texture_Id {
	Params :: struct {
		name:        string,
		flip:        bool,
		transparent: bool,
	}
	@(static, rodata)
	LOCATION := [Texture_Resource_Index]Params {
		.Container = {name = "container.jpg"},
		.Create_Diffuse = {name = "crate_diffuse.png"},
		.Crate_Specular = {name = "crate_specular.png"},
		.Grass = {"grass.png", true, true},
		.Marble = {name = "marble.jpg"},
		.Metal = {name = "metal.png"},
		.Transparent_Window = {name = "blending_transparent_window.png", transparent = true},
	}

	if !g_registry[index].is_loaded {
		location := LOCATION[index]
		log.debugf("Loading image: '%s'", location.name)
		resource, ok := texture_load(location.name, location.flip, location.transparent)
		if !ok {
			log.errorf("Cannot load image: %s", location.name)
		} else {
			g_registry[index].value = resource
			g_registry[index].is_loaded = true
		}
	}

	return g_registry[index].value
}

destroy_all_textures_resources :: proc() {
	for resource in g_registry {
		texture_destroy(resource.value)
	}
}
