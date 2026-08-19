package glc

import "core:os"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:path/filepath"

@(private = "file")
g_registry: [dynamic]Resource(Post_Process_Effect)

Post_Process_Effect :: struct {
	display_name: cstring,
	path:         string,
	shader:       Shader_Program,
}

post_process_effect :: proc(index: i32) -> Shader_Program {
	effect := g_registry[index].value

	if !g_registry[index].is_loaded {
		log.debugf("Loading post-processing effect: '%s'", effect.path)

		program, ok := shader_create_program("quad", effect.path)
		if !ok {
			log.panicf("Cannot load post-processing effect: '%s'", effect.path)
		}

		program.name = effect.path
		g_registry[index].value.shader = program
		g_registry[index].is_loaded = true
	}

	return effect.shader
}

post_process_effect_is_active :: proc(rs: Render_State) -> bool {
	return rs.post_process.should_use && rs.post_process.idx != 0 // None
}

post_process_effects_get_all :: proc "c" () -> []Resource(Post_Process_Effect) {
	return g_registry[:]
}

post_process_effects_load_count :: proc() -> int {
	return len(g_registry)
}

post_process_effects_reload_all :: proc() {
	for &ppe_res in g_registry {
		if ppe_res.is_loaded && ppe_res.value.display_name != "None" {
			old := ppe_res.value.shader
			v, f := old.vertex_name, old.fragment_name
			program, ok := shader_create_program(v, f)
			if ok {
				program.name = old.name
				shader_delete_program(old)
				ppe_res.value.shader = program
				log.infof("Post-process effect '%s' reloaded sucessfully.", program.name)
			} else {
				log.errorf("Cannot reload Post-process effect: %s", program.name)
			}
		}
	}
}

destroy_all_post_process_effects_resources :: proc() {
	for resource in g_registry {
		effect := resource.value
		delete(effect.display_name)
		delete(effect.path)
		shader_delete_program(effect.shader)
	}

	delete(g_registry)
}

post_process_effects_get_available :: proc() {
	f, oerr := os.open(CONTENT_FRAGMENT_SHADER_PATH + "post/")
	ensure(oerr == nil)
	defer os.close(f)

	it := os.read_directory_iterator_create(f)
	defer os.read_directory_iterator_destroy(&it)

	effect_none := Resource(Post_Process_Effect) {
		value = {display_name = fmt.caprint("None")},
		is_loaded = true,
	}
	append(&g_registry, effect_none)

	log.info("Loading post processing effects...")
	for info in os.read_directory_iterator(&it) {
		file_path := strings.concatenate({"post/", filepath.stem(info.name)})

		capitalized_name := strings.to_pascal_case(filepath.stem(info.name))
		defer delete(capitalized_name)

		effect_resource := Resource(Post_Process_Effect) {
			value = {display_name = fmt.caprint(capitalized_name), path = file_path},
		}

		append(&g_registry, effect_resource)
	}

	log.infof("%d available post-process effects", len(g_registry) - 1)
}
