package glcore

import "core:log"
import "core:os"
import "core:strings"

OPENGL_EXERCISES_MODE :: #config(OPENGL_EXERCISES_MODE, false)

CONTENT_BASE_PATH :: "content/" when !OPENGL_EXERCISES_MODE else "exercises/_content/"
CONTENT_SHADER_PATH :: CONTENT_BASE_PATH + "shaders/"

File_Content :: distinct string

content_shader_read :: proc(shader_name: string) -> (content: File_Content, ok: bool) {
	shader_file_path := strings.concatenate({CONTENT_SHADER_PATH, shader_name, ".glsl"})
	defer delete(shader_file_path)

	file_content := content_read_bytes(shader_file_path) or_return

	return cast(File_Content)file_content, true
}

content_delete :: proc(content: File_Content) {
	delete(cast(string)content)
}

content_read_bytes :: proc(path: string) -> (data: []byte, ok: bool) {
	content, error := os.read_entire_file(path, context.allocator)

	if error != nil {
		log.errorf("Failed to load content '%s': %v", path, error)
		return 
	}

	return content, true
}
