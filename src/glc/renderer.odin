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
	Points,
	Depth,
}

Post_Draw_Effect :: enum {
	None,
	Outline,
	Normals,
}

renderer_is_debug_view_mode :: proc(vm: Render_View_Mode) -> bool {
	return vm == .Wireframe || vm == .Depth || vm == .Points
}

Render_State :: struct {
	previous_view_mode: Maybe(Render_View_Mode),
	view_mode:          Render_View_Mode,
	view, projection:   glm.mat4,
	clear_color:        glm.vec3,
	post_process:       struct {
		should_use: bool,
		idx:        i32,
		fb:         Framebuffer,
	},
	frustrum:           struct {
		near: f32,
		far:  f32,
	},
	ubo:                struct {
		matrices: u32,
	},
	features:           struct {
		depth_test:         bool,
		stencil_test:       bool,
		blending:           bool,
		cull_face:          bool,
		program_point_size: bool,
		anti_aliasing_msaa: bool,
	},
}

Draw_Params :: struct {
	state:         ^Render_State,
	shader:        Shader_Program,
	translation:   glm.vec3,
	scale:         glm.vec3,
	model_matrix:  Maybe(glm.mat4),
	effect:        Post_Draw_Effect,
	num_instances: int,
}

dpd :: proc(rs: ^Render_State) -> Draw_Params {
	return {translation = 0, scale = 1, state = rs}
}

renderer_log_info :: proc() {
	loaded_renderer := gl.GetString(gl.RENDERER)
	log.infof("OpenGL: renderer %s", loaded_renderer)

	glsl_version := gl.GetString(gl.SHADING_LANGUAGE_VERSION)
	log.infof("OpenGL: GLSL version %s", glsl_version)

	max_attrs: i32
	gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &max_attrs)
	log.infof("OpenGL: Maximum number of vertex attributes supported: %d", max_attrs)

	max_uniforms: i32
	gl.GetIntegerv(gl.MAX_VERTEX_UNIFORM_COMPONENTS, &max_uniforms)
	log.infof("OpenGL: Maximum number of vertex uniform data supported: %d", max_uniforms)
}

renderer_setup_ubos :: proc(rs: ^Render_State) {
	gl.GenBuffers(1, &rs.ubo.matrices)
	gl.BindBuffer(gl.UNIFORM_BUFFER, rs.ubo.matrices)
	// reserve memory
	gl.BufferData(gl.UNIFORM_BUFFER, 2 * size_of(glm.mat4), nil, gl.STATIC_DRAW)
	// bind to bind point
	gl.BindBufferRange(gl.UNIFORM_BUFFER, 0, rs.ubo.matrices, 0, 2 * size_of(glm.mat4))

	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
}

renderer_update_ubos :: proc(rs: ^Render_State) {
	gl.BindBuffer(gl.UNIFORM_BUFFER, rs.ubo.matrices)
	// fill the buffers
	// projection (could be done in setup if we forfeit the camera zoom, as the
	// matrix never changes)
	gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(glm.mat4), &rs.projection[0][0])
	// view
	gl.BufferSubData(gl.UNIFORM_BUFFER, size_of(glm.mat4), size_of(glm.mat4), &rs.view[0][0])

	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
}

renderer_begin_drawing :: proc(rs: ^Render_State) {
	// post processing
	if post_process_effect_is_active(rs^) {
		framebuffer_use(rs.post_process.fb)
	}

	// depth setup
	if rs.features.depth_test {
		gl.Enable(gl.DEPTH_TEST)
	} else {
		gl.Disable(gl.DEPTH_TEST)
	}

	// stencil setup
	if rs.features.stencil_test {
		gl.Enable(gl.STENCIL_TEST)
		gl.StencilOp(gl.KEEP, gl.KEEP, gl.REPLACE)
	} else {
		gl.Disable(gl.STENCIL_TEST)
	}

	// blending setup
	if rs.features.blending {
		gl.Enable(gl.BLEND)
		gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	} else {
		gl.Disable(gl.BLEND)
	}

	// enable gl_PointSize in vertex shader
	if rs.features.program_point_size {
		gl.Enable(gl.PROGRAM_POINT_SIZE)
	} else {
		gl.Disable(gl.PROGRAM_POINT_SIZE)
	}

	// the vertex data must support this, 3D applications consistently
	// use CCW (OpenGL default) winding order, do keep track of objects
	// that shouln't be culled, like flat quads
	if rs.features.cull_face {
		gl.Enable(gl.CULL_FACE)
	} else {
		gl.Disable(gl.CULL_FACE)
	}
	
	// actual algorithm is implemented by the driver, multi-sample buffer
	// must be setup by the windowing system (SDL)
	if rs.features.anti_aliasing_msaa {
		gl.Enable(gl.MULTISAMPLE)
	} else {
		gl.Disable(gl.MULTISAMPLE)
	}

	#partial switch rs.view_mode {
	case .Wireframe:
		gl.ClearColor(0.0, 0.0, 0.0, 1.0)
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	case .Points:
		gl.ClearColor(0.0, 0.0, 0.0, 1.0)
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.POINT)
	case:
		gl.ClearColor(**rs.clear_color, 1.0)
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	}

	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

	// UBOs
	renderer_update_ubos(rs)
}

renderer_end_drawing :: proc(rs: ^Render_State) {
	if post_process_effect_is_active(rs^) {
		if renderer_is_debug_view_mode(rs.view_mode) {
			gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
		}

		dp := dpd(rs)
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
	points_primitive_draw,
	cubemap_draw,
}

model_draw :: proc(model: Model, dp: ^Draw_Params) {
	for &mesh in model.meshes {
		mesh_draw(mesh, dp)
	}
}

mesh_draw :: proc(mesh: Mesh, dp: ^Draw_Params) {
	pre_draw(dp)

	shader_use_program(dp.shader)

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

	if dp.num_instances > 0 {
		gl.BindVertexArray(mesh.vao)
		gl.DrawElementsInstanced(
			gl.TRIANGLES,
			cast(i32)len(mesh.indices),
			gl.UNSIGNED_INT,
			nil,
			cast(i32)dp.num_instances,
		)
	} else {
		if dp.model_matrix != nil {
			shader_uniform_set(dp.shader, "u_model", dp.model_matrix.?)
		} else {
			model_matrix := glm.mat4Translate(dp.translation)
			model_matrix *= glm.mat4Scale(dp.scale)
			shader_uniform_set(dp.shader, "u_model", model_matrix)
		}

		gl.BindVertexArray(mesh.vao)
		gl.DrawElements(gl.TRIANGLES, cast(i32)len(mesh.indices), gl.UNSIGNED_INT, nil)
	}

	gl.BindVertexArray(0)

	post_draw(mesh, dp)
}

points_primitive_draw :: proc(p: Primitive, shader: Shader_Program) {
	shader_use_program(shader)

	gl.BindVertexArray(p.vao)
	gl.DrawArrays(gl.POINTS, 0, 4)
}

primitive_draw :: proc(p: Primitive, dp: ^Draw_Params, texture_override := Texture_Id(0)) {
	pre_draw(dp)

	shader_use_program(dp.shader)

	texture := texture_override != 0 ? texture_override : p.texture

	if p.type != .Full_Quad {
		if dp.model_matrix != nil {
			shader_uniform_set(dp.shader, "u_model", dp.model_matrix.?)
		} else {
			model_matrix := glm.mat4Translate(dp.translation)
			model_matrix *= glm.mat4Scale(dp.scale)
			shader_uniform_set(dp.shader, "u_model", model_matrix)
		}
		shader_uniform_set(dp.shader, "u_texture_diffuse1", 0)
		shader_texture_sampler_set(dp.shader, "u_material.diffuse", texture, 0)
	}

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, cast(u32)texture)

	culling_enabled := dp.state.features.cull_face

	if culling_enabled && (p.type == .Plane || p.type == .Quad) {
		// flat primitives must not be culled
		gl.Disable(gl.CULL_FACE)
	}

	gl.BindVertexArray(p.vao)

	if dp.num_instances > 0 {
		gl.DrawArraysInstanced(gl.TRIANGLES, 0, cast(i32)p.vertex_size, cast(i32)dp.num_instances)
	} else {
		gl.DrawArrays(gl.TRIANGLES, 0, cast(i32)p.vertex_size)
	}

	if culling_enabled {
		gl.Enable(gl.CULL_FACE)
	}

	post_draw(p, dp)
}

cubemap_draw :: proc(cubemap: Cubemap, dp: Draw_Params) {
	if renderer_is_debug_view_mode(dp.state.view_mode) {
		// just not consider the skybox
		return
	}

	gl.StencilMask(0x00)
	gl.DepthFunc(gl.LEQUAL)
	defer gl.DepthFunc(gl.LESS)

	// remove the translation part from the view
	cubemap_view_matrix := glm.mat4(glm.mat3(dp.state.view))

	shader_use_program(dp.shader)

	// NOTE: this could also be kept outside the UBO
	// update UBO when drawing the cubemap
	gl.BindBuffer(gl.UNIFORM_BUFFER, dp.state.ubo.matrices)
	gl.BufferSubData(
		gl.UNIFORM_BUFFER,
		size_of(glm.mat4),
		size_of(glm.mat4),
		&cubemap_view_matrix[0][0],
	)

	gl.BindVertexArray(cubemap.vao)
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, cubemap.texture)
	gl.DrawArrays(gl.TRIANGLES, 0, len(CUBE_VERTICES))
	gl.BindVertexArray(0)

	// UBO back to normal
	gl.BufferSubData(gl.UNIFORM_BUFFER, size_of(glm.mat4), size_of(glm.mat4), &dp.state.view[0][0])

	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
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

	gl.DrawArrays(gl.TRIANGLES, 0, cast(i32)fb.primitive.vertex_size)
}

pre_draw :: proc(dp: ^Draw_Params) {
	switch dp.effect {
	case .Outline:
		gl.StencilFunc(gl.ALWAYS, 1, 0xff)
		gl.StencilMask(0xff)
	case .Normals:
	case .None:
	}

	// debug modes
	#partial switch dp.state.view_mode {
	case .Points:
		fallthrough
	case .Wireframe:
		dp.shader = shader_program_resource(.Green)
		shader_use_program(dp.shader)
	case .Depth:
		dp.shader = shader_program_resource(.Depth)
		shader_use_program(dp.shader)
		shader_uniform_set(dp.shader, "u_near", dp.state.frustrum.near)
		shader_uniform_set(dp.shader, "u_far", dp.state.frustrum.far)
	}

}

post_draw :: proc(object: $T, dp: ^Draw_Params) {
	dp_copy := dp^
	effect := dp_copy.effect
	dp_copy.effect = .None

	switch effect {
	case .Outline:
		// NOTE: outlined objects must be drawn last (limitation)
		dp_copy.shader = shader_program_resource(.Outline)
		shader_use_program(dp_copy.shader)
		shader_uniform_set(dp_copy.shader, "u_border_color", OUTLINE_DEFAULT_COLOR)

		dp_copy.scale += OUTLINE_DEFAULT_SIZE

		gl.StencilMask(0x00)
		gl.StencilFunc(gl.NOTEQUAL, 1, 0xff)
		gl.Disable(gl.DEPTH_TEST)
		draw(object, &dp_copy)
		gl.Enable(gl.DEPTH_TEST)
		gl.StencilFunc(gl.ALWAYS, 1, 0xff)
		gl.StencilMask(0xff)
	case .Normals:
		dp_copy.shader = shader_program_resource(.Normals)
		draw(object, &dp_copy)
	case .None:
	}
}
