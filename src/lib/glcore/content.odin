package glcore

@(require) import "core:image/png"
@(require) import "core:image/jpeg"
import "core:image"
import "core:log"
import "core:os"
import "core:strings"

OPENGL_EXERCISES_PATH :: #config(OPENGL_EXERCISES_PATH, "")

CONTENT_BASE_PATH :: "content/" when OPENGL_EXERCISES_PATH == "" else OPENGL_EXERCISES_PATH

CONTENT_SHADER_PATH ::
	CONTENT_BASE_PATH + "shaders/" when OPENGL_EXERCISES_PATH == "" else OPENGL_EXERCISES_PATH

CONTENT_IMAGE_PATH ::
	CONTENT_BASE_PATH + "images/" when OPENGL_EXERCISES_PATH == "" else OPENGL_EXERCISES_PATH

VERTEX_SHADER_EXT :: ".vert"
FRAGMENT_SHADER_EXT :: ".frag"

Shader_Code :: distinct cstring
Image_Data :: ^image.Image

content_load_image :: proc(image_name: string) -> (content: Image_Data, ok: bool) {
	image_path := strings.concatenate({CONTENT_IMAGE_PATH, image_name})
	defer delete(image_path)

	image_data, err := image.load(image_path)
	if err != nil {
		log.errorf("Failed to load image '%s': %v", image_path, err)
		return
	}

	return image_data, true
}

content_destroy_image :: proc(image_data: Image_Data) {
	image.destroy(image_data)
}

content_load_shader_code :: proc(
	shader_name: string,
	shader_type: Shader_Type,
) -> (
	content: Shader_Code,
	ok: bool,
) {
	extension := VERTEX_SHADER_EXT if shader_type == .Vertex else FRAGMENT_SHADER_EXT
	shader_file_path := strings.concatenate({CONTENT_SHADER_PATH, shader_name, extension})
	defer delete(shader_file_path)

	file_content := cast(string)_content_read_bytes(shader_file_path) or_return
	defer delete(file_content)

	shader_code := cast(Shader_Code)strings.clone_to_cstring(file_content)

	return shader_code, true
}

content_destroy_shader_code :: proc(content: Shader_Code) {
	delete(cast(string)content)
}

_content_read_bytes :: proc(path: string) -> (data: []byte, ok: bool) {
	content, error := os.read_entire_file(path, context.allocator)

	if error != nil {
		log.errorf("Failed to load content '%s': %v", path, error)
		return
	}

	return content, true
}
