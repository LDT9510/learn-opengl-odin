package glc

@(require) import "core:image/png"
@(require) import "core:image/jpeg"
import "core:image"
import "core:log"
import "core:os"
import "core:strings"

CONTENT_ROOT :: #config(CONTENT_ROOT, "./")

CONTENT_BASE_PATH :: CONTENT_ROOT + "content/"
CONTENT_VERTEX_SHADER_PATH :: CONTENT_BASE_PATH + "shaders/vertex/"
CONTENT_FRAGMENT_SHADER_PATH :: CONTENT_BASE_PATH + "shaders/fragment/"
CONTENT_IMAGE_PATH :: CONTENT_BASE_PATH + "images/"
CONTENT_CUBEMAP_PATH :: CONTENT_BASE_PATH + "cubemaps/"
CONTENT_MODEL_PATH :: CONTENT_BASE_PATH + "models/"

Content_Shader_Data :: struct {
	name: string,
	code:      cstring,
}

// NOTE: without some kind of descriptor, we need to hardcode this
// order matters!
@(private, rodata)
CUBEMAP_FACES := [?]string {
	"right.jpg",
	"left.jpg",
	"top.jpg",
	"bottom.jpg",
	"front.jpg",
	"back.jpg",
}
Content_Cubemap_Images :: [6]^image.Image

Content_Image :: image.Image

Content_Model_Full_Path :: string

content_load_image_from_model :: proc(
	model_name: string,
	image_name: string,
) -> (
	image_data: ^image.Image,
	ok: bool,
) {
	image_path := strings.concatenate({CONTENT_MODEL_PATH, model_name, "/", image_name})
	defer delete(image_path)

	data, err := image.load(image_path)
	if err != nil {
		log.errorf("Failed to load model image '%s': %v", image_path, err)
		return
	}
	ok = true
	image_data = data

	return
}

content_load_image :: proc(
	image_name: string,
) -> (
	image_data: ^image.Image,
	ok: bool,
) {
	image_path := strings.concatenate({CONTENT_IMAGE_PATH, image_name})
	defer delete(image_path)

	data, err := image.load(image_path)
	if err != nil {
		log.errorf("Failed to load image '%s': %v", image_path, err)
		return
	}
	ok = true
	image_data = data

	return
}

content_load_cubemap_images :: proc(
	cubemap_name: string,
) -> (
	cubemap_images: Content_Cubemap_Images,
	ok: bool,
) {
	for face, i in CUBEMAP_FACES {
		image_path := strings.concatenate({CONTENT_CUBEMAP_PATH, cubemap_name, "/", face})
		defer delete(image_path)

		image_data, err := image.load(image_path)
		if err != nil {
			log.errorf("Failed to load cubemap image '%s': %v", image_path, err)
			return
		}

		cubemap_images[i] = image_data
	}
	ok = true

	return
}

content_get_model_full_path :: proc(
	model_name: string,
	format := Model_Format.Wavefront,
) -> Content_Model_Full_Path {
	extension: string
	switch format {
	case .Wavefront:
		extension = ".obj"
	}

	return strings.concatenate({CONTENT_MODEL_PATH, model_name, "/", model_name, extension})
}

content_load_shader_code :: proc(
	shader_name: string,
	shader_type: Shader_Type,
) -> (
	shader_data: Content_Shader_Data,
	ok: bool,
) {
	extension, base_path: string
	switch shader_type {
	case .Vertex:
		extension, base_path = ".vert", CONTENT_VERTEX_SHADER_PATH
	case .Fragment:
		extension, base_path = ".frag", CONTENT_FRAGMENT_SHADER_PATH
	}

	file_path := strings.concatenate({base_path, shader_name, extension})
	defer delete(file_path)

	file_content := cast(string)_read_file_bytes(file_path) or_return
	defer delete(file_content)

	shader_data.name = shader_name
	shader_data.code = strings.clone_to_cstring(file_content)

	ok = true

	return
}

content_destroy_model_full_path :: proc(full_path: Content_Model_Full_Path) {
	delete(full_path)
}

content_destroy_cubemap_images :: proc(cubemap_images: Content_Cubemap_Images) {
	for image_data in cubemap_images {
		image.destroy(image_data)
	}
}

content_destroy_image :: proc(image_data: ^Content_Image) {
	image.destroy(image_data)
}

content_destroy_shader_data :: proc(shader_data: Content_Shader_Data) {
	delete(shader_data.code)
}

@(private)
_read_file_bytes :: proc(path: string) -> (data: []byte, ok: bool) {
	content, error := os.read_entire_file(path, context.allocator)

	if error != nil {
		log.errorf("Failed to load content '%s': %v", path, error)
		return
	}

	return content, true
}
