package learn_opengl

import glm "core:math/linalg/glsl"

import gl "vendor:OpenGL"

import glc "lib:glcore"

@(rodata)
SCENES := [?]Scene {
	{"Empty", proc() {}},
	{"Outlined cubes, backpack and cubemap", scene_outlined_cubes_and_backpack},
}

Scene :: struct {
	name:      cstring,
	procedure: proc(),
}

scene_outlined_cubes_and_backpack :: proc() {
	view := glc.camera_get_view_matrix(g_state.camera)
	proj := glm.mat4Perspective(
		glm.radians(g_state.camera.zoom),
		glc.window_get_aspect_ratio(g_state.window),
		g_state.frustrum.near,
		g_state.frustrum.far,
	)

	// rendering
	glc.shader_use_program(g_state.shaders.main)
	glc.shader_uniform_set(g_state.shaders.main, "u_view", &view)
	glc.shader_uniform_set(g_state.shaders.main, "u_projection", &proj)

	glc.shader_use_program(g_state.shaders.model)
	glc.shader_uniform_set(g_state.shaders.model, "u_view", &view)
	glc.shader_uniform_set(g_state.shaders.model, "u_projection", &proj)

	if g_state.depth.see_buffer {
		glc.shader_uniform_set(g_state.shaders.main, "u_near", g_state.frustrum.near)
		glc.shader_uniform_set(g_state.shaders.main, "u_far", g_state.frustrum.far)
	}

	// floor
	// gl.StencilMask(0x00)
	// gl.Disable(gl.CULL_FACE)
	// glc.primitive_draw(g_state.objects.plane, g_state.shaders.model, 0.0)

	// cubes
	gl.StencilMask(0xff)
	gl.Disable(gl.CULL_FACE)
	glc.primitive_draw(
		g_state.objects.cube,
		g_state.shaders.main,
		{2.0, 0.01, 0.0},
		camera_pos = g_state.camera.position,
	)
	glc.primitive_draw(
		g_state.objects.cube,
		g_state.shaders.main,
		{-1.0, 0.01, -1.0},
		camera_pos = g_state.camera.position,
	)

	// backpack
	gl.StencilMask(0x00)
	gl.Disable(gl.CULL_FACE)
	glc.model_draw(g_state.objects.backpack, g_state.shaders.main, {0.0, 2.0, 0.0}, 0.4)

	// cubes outlines
	if g_state.stencil.should_draw_border & !g_state.use_wireframe {
		gl.StencilMask(0x00)
		gl.StencilFunc(gl.NOTEQUAL, 1, 0xff)
		defer gl.StencilFunc(gl.ALWAYS, 1, 0xff)

		glc.shader_use_program(g_state.shaders.border)
		glc.shader_uniform_set(g_state.shaders.border, "u_view", &view)
		glc.shader_uniform_set(g_state.shaders.border, "u_projection", &proj)
		glc.shader_uniform_set(
			g_state.shaders.border,
			"u_border_color",
			g_state.stencil.border_color,
		)
		glc.primitive_draw(
			g_state.objects.cube,
			g_state.shaders.border,
			{-1.0, 0.01, -1.0},
			1.0 + g_state.stencil.border_size,
		)
		glc.primitive_draw(
			g_state.objects.cube,
			g_state.shaders.border,
			{2.0, 0.01, 0.0},
			1.0 + g_state.stencil.border_size,
		)
	}

	// render the skybox last
	if g_state.background.type == .Skybox {
		glc.cubemap_draw(g_state.background.skybox, g_state.shaders.skybox, &view, &proj)
	}
}

scene_prefix :: proc() {
	// depth setup
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LESS)

	// stencil setup
	gl.Enable(gl.STENCIL_TEST)
	gl.StencilFunc(gl.ALWAYS, 1, 0xff)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.REPLACE)
	gl.StencilMask(0xff)

	// blending setup
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	// the vertex data must support this, 3D applications consistently
	// use CCW winding order, do keep track of objects that shouln't be culled,
	// like flat quads (the grass)
	// face culling setup
	gl.Enable(gl.CULL_FACE)
	gl.CullFace(gl.BACK) // default
	gl.FrontFace(gl.CCW) // default

	gl.PolygonMode(gl.FRONT_AND_BACK, g_state.use_wireframe ? gl.LINE : gl.FILL)

	if g_state.use_wireframe {
		// force the background as solid color,
		// NOTE: this will make the skybox unselectable in the devUI
		g_state.background.type = .Solid_Color
	} else {
		g_state.background.type = .Skybox
	}
	// show the wireframe for the main scene only, not the render texture
	defer gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)

	gl.ClearColor(**g_state.background.color, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)


}
