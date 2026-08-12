package glcore

import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"

Cubemap_Vertex :: glm.vec3

Cubemap :: struct {
	vao, vbo: u32,
	texture:  u32,
}

cubemap_load :: proc(name: string) -> (cubemap: Cubemap, ok: bool) {
	// texture
	gl.GenTextures(1, &cubemap.texture)
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, cubemap.texture)

	cubemap_images := content_load_cubemap_images(name) or_return
	defer content_destroy_cubemap_images(cubemap_images)

	for image, i in cubemap_images {
		image_format: u32 = image.channels == 4 ? gl.RGBA : gl.RGB

		gl.TexImage2D(
			gl.TEXTURE_CUBE_MAP_POSITIVE_X + cast(u32)i,
			0,
			cast(i32)image_format,
			cast(i32)image.width,
			cast(i32)image.height,
			0,
			image_format,
			gl.UNSIGNED_BYTE,
			raw_data(image.pixels.buf),
		)
	}
	ok = true

	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	// vertex data
	gl.GenVertexArrays(1, &cubemap.vao)
	gl.GenBuffers(1, &cubemap.vbo)
	gl.BindVertexArray(cubemap.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, cubemap.vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		cast(int)len(CUBEMAP_VERTICES) * size_of(Cubemap_Vertex),
		&CUBEMAP_VERTICES,
		gl.STATIC_DRAW,
	)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Cubemap_Vertex), 0)
	gl.BindVertexArray(0)

	return
}

cubemap_destroy :: proc(cubemap: ^Cubemap) {
	gl.DeleteVertexArrays(1, &cubemap.vao)
	gl.DeleteBuffers(1, &cubemap.vbo)
	gl.DeleteTextures(1, &cubemap.texture)
}

cubemap_draw :: proc(
	cubemap: Cubemap,
	skybox_shader: Shader_Program_Handle,
	view_matrix: ^glm.mat4,
	projection_matrix: ^glm.mat4,
) {
	gl.DepthFunc(gl.LEQUAL)
	defer gl.DepthFunc(gl.LESS)

	// remove the translation part from the view
	cubemap_view_matrix := glm.mat4(glm.mat3(view_matrix^))

	shader_use_program(skybox_shader)
	shader_uniform_set(skybox_shader, "u_view", &cubemap_view_matrix)
	shader_uniform_set(skybox_shader, "u_projection", projection_matrix)

	gl.BindVertexArray(cubemap.vao)
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, cubemap.texture)
	gl.DrawArrays(gl.TRIANGLES, 0, len(CUBE_VERTICES))
	gl.BindVertexArray(0)
}

// odinfmt: disable
@rodata
CUBEMAP_VERTICES := [?]Cubemap_Vertex{
	// positions
	{-1.0,  1.0, -1.0},
    {-1.0, -1.0, -1.0},
    { 1.0, -1.0, -1.0},
    { 1.0, -1.0, -1.0},
    { 1.0,  1.0, -1.0},
    {-1.0,  1.0, -1.0},

    {-1.0, -1.0,  1.0},
    {-1.0, -1.0, -1.0},
    {-1.0,  1.0, -1.0},
    {-1.0,  1.0, -1.0},
    {-1.0,  1.0,  1.0},
    {-1.0, -1.0,  1.0},

    { 1.0, -1.0, -1.0},
    { 1.0, -1.0,  1.0},
    { 1.0,  1.0,  1.0},
    { 1.0,  1.0,  1.0},
    { 1.0,  1.0, -1.0},
    { 1.0, -1.0, -1.0},

    {-1.0, -1.0,  1.0},
    {-1.0,  1.0,  1.0},
    { 1.0,  1.0,  1.0},
    { 1.0,  1.0,  1.0},
    { 1.0, -1.0,  1.0},
    {-1.0, -1.0,  1.0},

    {-1.0,  1.0, -1.0},
    { 1.0,  1.0, -1.0},
    { 1.0,  1.0,  1.0},
    { 1.0,  1.0,  1.0},
    {-1.0,  1.0,  1.0},
    {-1.0,  1.0, -1.0},

    {-1.0, -1.0, -1.0},
    {-1.0, -1.0,  1.0},
    { 1.0, -1.0, -1.0},
    { 1.0, -1.0, -1.0},
    {-1.0, -1.0,  1.0},
    { 1.0, -1.0,  1.0},
}
// odinfmt: enable
