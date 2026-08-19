package glc

import "core:log"

destroy_all :: proc() {
	destroy_all_cubemaps_resources()
	destroy_all_primitives_resources()
	destroy_all_shaders_resources()
	destroy_all_textures_resources()
	destroy_all_models_resources()
	destroy_all_post_process_effects_resources()
}

@(private)
Resource :: struct($T: typeid) {
	value:     T,
	is_loaded: bool,
}

@(private)
resource_indexer :: proc(
	type_name: string,
	index: $TIndex,
	loader: proc(_: string) -> ($TReturn, bool),
	location: $TLocation,
	registry: ^[TIndex]Resource(TReturn),
) -> TReturn {
	if !registry[index].is_loaded {
		location := location[index]
		log.debugf("Loading %s: '%s'", type_name, location)
		resource, ok := loader(location)
		if !ok {
			log.panicf("Cannot load %s: %s", type_name, location)
		}
		registry[index].value = resource
		registry[index].is_loaded = true
	}

	return registry[index].value
}
