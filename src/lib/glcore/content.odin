package glcore

import "base:runtime"
import "core:log"
import "core:os"
import "core:strings"

OPENGL_EXERCISES_PATH :: #config(OPENGL_EXERCISES_PATH, "")

CONTENT_BASE_PATH :: "content/" when OPENGL_EXERCISES_PATH == "" else OPENGL_EXERCISES_PATH
CONTENT_SHADER_PATH ::
	CONTENT_BASE_PATH + "shaders/" when OPENGL_EXERCISES_PATH == "" else OPENGL_EXERCISES_PATH

VERTEX_SHADER_EXT :: ".vert"
FRAGMENT_SHADER_EXT :: ".frag"

Shader_Code :: distinct cstring

content_read_shader_code :: proc(
	shader_name: string,
	shader_type: Shader_Type,
	allocator: runtime.Allocator,
) -> (
	content: Shader_Code,
	ok: bool,
) {
	extension := VERTEX_SHADER_EXT if shader_type == .Vertex else FRAGMENT_SHADER_EXT
	shader_file_path := strings.concatenate({CONTENT_SHADER_PATH, shader_name, extension}, allocator)
	defer delete(shader_file_path)

	file_content := cast(string)_content_read_bytes(shader_file_path, allocator) or_return
	defer delete(file_content)

	shader_code := cast(Shader_Code)strings.clone_to_cstring(file_content, allocator)

	return shader_code, true
}

content_delete_shader_code :: proc(content: Shader_Code) {
	delete(cast(string)content)
}

_content_read_bytes :: proc(
	path: string,
	allocator: runtime.Allocator,
) -> (
	data: []byte,
	ok: bool,
) {
	content, error := os.read_entire_file(path, allocator)

	if error != nil {
		log.errorf("Failed to load content '%s': %v", path, error)
		return
	}

	return content, true
}
