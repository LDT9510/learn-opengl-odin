package glcore

import "core:mem"
import "core:log"

import ai "extern:assimp"

Model_Texture :: struct {
	id:   Texture_Id,
	type: ai.TextureType,
	path: ai.String,
}
_g_all_loaded_textures_paths := [dynamic]Model_Texture{}

model_unload_loaded_textures_path :: proc() {
	delete(_g_all_loaded_textures_paths)
}

Model :: struct {
	meshes: [dynamic]Mesh,
	path:   Model_Path,
}

model_load :: proc(model_name: string) -> (model: Model) {
	model.path = content_get_model_path(model_name)

	flags := ai.PostProcessSteps.Triangulate | ai.PostProcessSteps.FlipUVs
	scene := ai.import_file(model.path.full_path, cast(u32)flags)

	if scene == nil ||
	   scene.mFlags & cast(u32)ai.SceneFlags.INCOMPLETE == 1 ||
	   scene.mRootNode == nil {
		log.errorf("Error importing model: %s", ai.get_error_string())
		return
	}

	_model_process_node(&model, scene.mRootNode, scene)

	return
}

model_delete :: proc(model: ^Model) {
	for &mesh in model.meshes {
		mesh_delete(&mesh)
	}
	delete(model.meshes)

	content_destroy_model_path(model.path)
}

model_draw :: proc(model: Model, shader: Shader_Program_Handle) {
	for &mesh in model.meshes {
		mesh_draw(mesh, shader)
	}
}

_model_process_node :: proc(model: ^Model, node: ^ai.Node, scene: ^ai.Scene) {
	for i in 0 ..< node.mNumMeshes {
		mesh := scene.mMeshes[node.mMeshes[i]]
		append(&model.meshes, _process_mesh(mesh, scene, model.path.directory))
	}

	for i in 0 ..< node.mNumChildren {
		_model_process_node(model, node.mChildren[i], scene)
	}
}

_process_mesh :: proc(
	in_mesh: ^ai.Mesh,
	scene: ^ai.Scene,
	model_directory: string,
) -> (
	out_mesh: Mesh,
) {
	// vertex data
	for i in 0 ..< in_mesh.mNumVertices {
		vertex := Vertex {
			position = in_mesh.mVertices[i],
			normal   = in_mesh.mNormals[i],
		}
		if (in_mesh.mTextureCoords[0] != nil) {
			vertex.tex_coords = in_mesh.mTextureCoords[0][i].xy
		}
		append(&out_mesh.vertices, vertex)
	}

	// indices
	for i in 0 ..< in_mesh.mNumFaces {
		face := in_mesh.mFaces[i]
		for j in 0 ..< face.mNumIndices {
			append(&out_mesh.indices, face.mIndices[j])
		}
	}

	if (in_mesh.mMaterialIndex >= 0) {
		material := scene.mMaterials[in_mesh.mMaterialIndex]
		_load_material_textures(material, .DIFFUSE, model_directory, &out_mesh.textures)
		_load_material_textures(material, .SPECULAR, model_directory, &out_mesh.textures)
	}

	mesh_init(&out_mesh)

	return
}

_load_material_textures :: proc(
	mat: ^ai.Material,
	type: ai.TextureType,
	model_directory: string,
	out_textures: ^[dynamic]Model_Texture,
) {
	// practicing with stack allocator
	buf: [2048]byte = ---
	stack := mem.Stack{}
	mem.stack_init(&stack, buf[:])
	allocator := mem.stack_allocator(&stack)

	for i in 0 ..< ai.get_material_textureCount(mat, type) {
		ai_str_path := ai.String{}
		_get_material_texture(mat, type, i, &ai_str_path)

		skip := false
		for &loaded_texture in _g_all_loaded_textures_paths {
			if loaded_texture.path == ai_str_path {
				append(out_textures, loaded_texture)
				skip = true
				break
			}
		}

		if !skip {
			path := ai.string_clone_from_ai_string(&ai_str_path, allocator)

			texture_id, ok := texture_load(model_directory, path)
			assert(ok) // TODO handle better

			texture := Model_Texture {
				id   = texture_id,
				type = type,
				path = ai_str_path,
			}

			append(out_textures, texture)
			append(&_g_all_loaded_textures_paths, texture)
		}
	}
}

_get_material_texture :: proc(
	mat: ^ai.Material,
	type: ai.TextureType,
	idx: u32,
	out_path: ^ai.String,
) {
	ai.get_material_texture(mat, type, idx, out_path, nil, nil, nil, nil, nil)
}
