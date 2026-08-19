package glc

import "core:log"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

OUTLINE_DEFAULT_COLOR :: glm.vec3{0.04, 0.28, 0.26}
OUTLINE_DEFAULT_SIZE :: 0.1

Render_View_Mode :: enum {
	Normal,
	Post_Process,
	Wireframe,
	Depth,
}

Render_State :: struct {
	previous_view_mode: Maybe(Render_View_Mode),
	view_mode:          Render_View_Mode,
	view, projection:   glm.mat4,
	clear_color:        glm.vec3,
	post_process:       struct {
		should_use:          bool,
		idx:                 i32,
		fb:                  Framebuffer,
	},
	frustrum:           struct {
		near: f32,
		far:  f32,
	},
}

Draw_Params :: struct {
	state:       ^Render_State,
	shader:      Shader_Program,
	translation: glm.vec3,
	scale:       glm.vec3,
	outline:     struct {
		use:   bool,
		color: glm.vec3,
		size:  f32,
	},
}

draw_params_default :: proc(rs: ^Render_State) -> (dp: Draw_Params) {
	dp.translation = 0
	dp.scale = 1
	dp.outline.color = OUTLINE_DEFAULT_COLOR
	dp.outline.size = OUTLINE_DEFAULT_SIZE
	dp.state = rs

	return
}

renderer_begin_drawing :: proc(rs: ^Render_State) {
	// post processing
	if post_process_effect_is_active(rs^) {
		framebuffer_use(rs.post_process.fb)
	}

	// depth setup
	gl.Enable(gl.DEPTH_TEST)

	// stencil setup
	gl.Enable(gl.STENCIL_TEST)
	gl.StencilOp(gl.KEEP, gl.KEEP, gl.REPLACE)

	// blending setup
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	// the vertex data must support this, 3D applications consistently
	// use CCW (OpenGL default) winding order, do keep track of objects
	// that shouln't be culled, like flat quads
	gl.Enable(gl.CULL_FACE)

	if rs.view_mode == .Wireframe {
		gl.ClearColor(0.0, 0.0, 0.0, 1.0)
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	} else {
		gl.ClearColor(**rs.clear_color, 1.0)
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	}

	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)
}

renderer_end_drawing :: proc(rs: ^Render_State) {
	if post_process_effect_is_active(rs^) {
		if rs.view_mode == .Wireframe {
			gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
		}

		dp := draw_params_default(rs)
		dp.shader = post_process_effect(rs.post_process.idx)
		framebuffer_draw(rs.post_process.fb, &dp, clear = true)
	}
}

renderer_state_toggle_normal :: proc(rs: ^Render_State, new_mode: Render_View_Mode) {
	if rs.view_mode == new_mode {
		rs.view_mode = .Normal
	} else {
		rs.view_mode = new_mode
	}
}

renderer_handle_viewport_changed :: proc(rs: ^Render_State, width, height: i32) {
	log.infof("Resizing main viewport. New Size: %d x %d", width, height)
	gl.Viewport(0, 0, width, height)

	log.infof("Recreating post-process effects framebuffer")
	framebuffer_destroy(&rs.post_process.fb)
	rs.post_process.fb = framebuffer_create(.Full_Quad, width, height)
}

draw :: proc {
	model_draw,
	mesh_draw,
	primitive_draw,
	cubemap_draw,
}

model_draw :: proc(model: Model, dp: ^Draw_Params) {
	for &mesh in model.meshes {
		mesh_draw(mesh, dp)
	}
}

mesh_draw :: proc(mesh: Mesh, dp: ^Draw_Params) {
	pre_draw(dp)

	diffuse_num := 1
	specular_num := 1

	for i in 0 ..< len(mesh.textures) {
		gl.ActiveTexture(gl.TEXTURE0 + cast(u32)i)

		texture := mesh.textures[i]
		name: string
		binding_num: int
		#partial switch texture.type {
		case .DIFFUSE:
			name = "diffuse"
			binding_num = diffuse_num
			diffuse_num += 1
		case .SPECULAR:
			name = "specular"
			binding_num = specular_num
			specular_num += 1
		}

		shader_uniform_set(dp.shader, fmt.ctprint("u_texture_%s%d", name, binding_num), cast(i32)i)

		gl.BindTexture(gl.TEXTURE_2D, cast(u32)texture.id)
	}
	gl.ActiveTexture(gl.TEXTURE0)

	shader_use_program(dp.shader)
	model_matrix := glm.mat4Translate(dp.translation)
	model_matrix *= glm.mat4Scale(dp.scale)
	shader_uniform_set(dp.shader, "u_model", &model_matrix)

	gl.BindVertexArray(mesh.vao)
	gl.DrawElements(gl.TRIANGLES, cast(i32)len(mesh.indices) - 1, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)

	post_draw(mesh, dp)
}

primitive_draw :: proc(p: Primitive, dp: ^Draw_Params, texture_override := Texture_Id(0)) {
	pre_draw(dp)

	shader_use_program(dp.shader)

	texture := texture_override != 0 ? texture_override : p.texture

	if p.type != .Full_Quad {
		model_matrix := glm.mat4Translate(dp.translation)
		model_matrix *= glm.mat4Scale(dp.scale)
		shader_uniform_set(dp.shader, "u_model", &model_matrix)
		shader_uniform_set(dp.shader, "u_texture_diffuse1", 0)
	}

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, cast(u32)texture)

	if p.type == .Plane {
		// flat primitives must not be culled
		gl.Disable(gl.CULL_FACE)
	}

	gl.BindVertexArray(p.vao)
	gl.DrawArrays(gl.TRIANGLES, 0, p.vertex_size)

	post_draw(p, dp)
}

cubemap_draw :: proc(cubemap: Cubemap, dp: Draw_Params) {
	vm := dp.state.view_mode
	if vm == .Wireframe || vm == .Depth {
		// just not consider the skybox
		return
	}

	gl.StencilMask(0x00)
	gl.DepthFunc(gl.LEQUAL)
	defer gl.DepthFunc(gl.LESS)

	// remove the translation part from the view
	cubemap_view_matrix := glm.mat4(glm.mat3(dp.state.view))

	shader_use_program(dp.shader)
	shader_uniform_set(dp.shader, "u_view", &cubemap_view_matrix)
	shader_uniform_set(dp.shader, "u_projection", &dp.state.projection)

	gl.BindVertexArray(cubemap.vao)
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, cubemap.texture)
	gl.DrawArrays(gl.TRIANGLES, 0, len(CUBE_VERTICES))
	gl.BindVertexArray(0)
}

framebuffer_draw :: proc(fb: Framebuffer, dp: ^Draw_Params, clear := false) {
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

	gl.Disable(gl.DEPTH_TEST)
	gl.Disable(gl.CULL_FACE)

	shader_use_program(dp.shader)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, cast(u32)fb.texture)

	gl.BindVertexArray(fb.primitive.vao)

	if clear {
		gl.ClearColor(**dp.state.clear_color, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)
	}

	gl.DrawArrays(gl.TRIANGLES, 0, fb.primitive.vertex_size)
}

pre_draw :: proc(dp: ^Draw_Params) {
	if dp.outline.use {
		gl.StencilFunc(gl.ALWAYS, 1, 0xff)
		gl.StencilMask(0xff)
	} else {
		gl.StencilMask(0x00)
	}

	// debug modes
	#partial switch dp.state.view_mode {
	case .Wireframe:
		dp.shader = shader_program_resource(.Green)
		shader_use_program(dp.shader)
		shader_uniform_set(dp.shader, "u_view", &dp.state.view)
		shader_uniform_set(dp.shader, "u_projection", &dp.state.projection)
	case .Depth:
		dp.shader = shader_program_resource(.Depth)
		shader_use_program(dp.shader)
		shader_uniform_set(dp.shader, "u_view", &dp.state.view)
		shader_uniform_set(dp.shader, "u_projection", &dp.state.projection)
		shader_uniform_set(dp.shader, "u_near", dp.state.frustrum.near)
		shader_uniform_set(dp.shader, "u_far", dp.state.frustrum.far)
	}

}

post_draw :: proc(object: $T, dp: ^Draw_Params) {
	// NOTE: outlined objects must be drawn last (limitation)
	if dp.outline.use {
		dp_copy := dp^
		outline_shader := shader_program_resource(.Outline)
		shader_use_program(outline_shader)
		shader_uniform_set(outline_shader, "u_view", &dp_copy.state.view)
		shader_uniform_set(outline_shader, "u_projection", &dp_copy.state.projection)
		shader_uniform_set(outline_shader, "u_border_color", dp_copy.outline.color)

		dp_copy.scale += dp_copy.outline.size
		dp_copy.shader = outline_shader
		dp_copy.outline.use = false

		gl.StencilFunc(gl.NOTEQUAL, 1, 0xff)
		gl.StencilMask(0x00)
		gl.Disable(gl.DEPTH_TEST)
		draw(object, &dp_copy)
		gl.StencilMask(0xff)
		gl.StencilFunc(gl.ALWAYS, 1, 0xff)
		gl.Enable(gl.DEPTH_TEST)
	}
}
