package glc

import ai "extern:assimp"

import "core:mem"
import "core:log"

Model_Format :: enum {
	Wavefront,
}

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
	name:   string,
}


model_load :: proc(model_name: string) -> (model: Model, ok: bool) {
	full_path := content_get_model_full_path(model_name)
	defer content_destroy_model_full_path(full_path)

	flags := ai.PostProcessSteps.Triangulate
	scene := ai.import_file(full_path, cast(u32)flags)

	if scene == nil ||
	   scene.mFlags & cast(u32)ai.SceneFlags.INCOMPLETE == 1 ||
	   scene.mRootNode == nil {
		log.errorf("Error importing model: %s", ai.get_error_string())
		return
	}

	model.name = model_name
	process_node(&model, scene.mRootNode, scene)

	return model, true
}

model_delete :: proc(model: ^Model) {
	for &mesh in model.meshes {
		mesh_delete(&mesh)
	}
	delete(model.meshes)
}


@(private)
process_node :: proc(model: ^Model, node: ^ai.Node, scene: ^ai.Scene) {
	for i in 0 ..< node.mNumMeshes {
		mesh := scene.mMeshes[node.mMeshes[i]]
		append(&model.meshes, process(mesh, scene, model.name))
	}

	for i in 0 ..< node.mNumChildren {
		process_node(model, node.mChildren[i], scene)
	}
}

@(private)
process :: proc(in_mesh: ^ai.Mesh, scene: ^ai.Scene, model_name: string) -> (mesh: Mesh) {
	// vertex data
	for i in 0 ..< in_mesh.mNumVertices {
		vertex := Vertex {
			position   = in_mesh.mVertices[i],
			normal     = in_mesh.mNormals[i],
		}
		if (in_mesh.mTextureCoords[0] != nil) {
			vertex.tex_coords = in_mesh.mTextureCoords[0][i].xy
		}
		append(&mesh.vertices, vertex)
	}

	// indices
	for i in 0 ..< in_mesh.mNumFaces {
		face := in_mesh.mFaces[i]
		for j in 0 ..< face.mNumIndices {
			append(&mesh.indices, face.mIndices[j])
		}
	}

	if (in_mesh.mMaterialIndex <= scene.mNumMaterials) {
		material := scene.mMaterials[in_mesh.mMaterialIndex]
		load_material_textures(material, .DIFFUSE, model_name, &mesh.textures)
		load_material_textures(material, .SPECULAR, model_name, &mesh.textures)
	}

	mesh_init(&mesh)

	return mesh
}

@(private)
load_material_textures :: proc(
	mat: ^ai.Material,
	type: ai.TextureType,
	model_name: string,
	out_textures: ^[dynamic]Model_Texture,
) {
	// practicing with stack allocator
	buf: [2048]byte = ---
	stack := mem.Stack{}
	mem.stack_init(&stack, buf[:])
	allocator := mem.stack_allocator(&stack)

	for i in 0 ..< ai.get_material_textureCount(mat, type) {
		ai_str_path := ai.String{}
		get_material_texture(mat, type, i, &ai_str_path)

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

			texture_id, ok := texture_load_from_model(model_name, path)
			if ok {
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
}

@(private)
get_material_texture :: proc(
	mat: ^ai.Material,
	type: ai.TextureType,
	idx: u32,
	out_path: ^ai.String,
) {
	ai.get_material_texture(mat, type, idx, out_path, nil, nil, nil, nil, nil)
}
