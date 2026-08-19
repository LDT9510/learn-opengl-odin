package app

import "main:glc"
import "main:devui"

import im "extern:imgui"

@(private = "file")
ui_sections_render :: proc(s: ^State) {
	if im.CollapsingHeader("Scene") {
		if im.ComboCallback(
			"Scene Selection",
			cast(^i32)&s.scene.idx,
			get_scene_name,
			nil,
			len(SCENE_REGISTRY),
		) {
			s.scene.current = SCENE_REGISTRY[s.scene.idx]
		}

		im.ColorEdit3("Clear color", &s.rs.clear_color)
	}

	camera_dev_ui_frame(&s.app.camera)

	if im.CollapsingHeader("Debug") {
		vm := cast(^i32)&s.rs.view_mode

		if im.RadioButtonIntPtr("Normal", vm, cast(i32)glc.Render_View_Mode.Normal) {
			s.rs.view_mode = .Normal
		}
		if im.RadioButtonIntPtr("Wireframe (U)", vm, cast(i32)glc.Render_View_Mode.Wireframe) {
			s.rs.view_mode = .Wireframe
		}
		if im.RadioButtonIntPtr("Depth Buffer (P)", vm, cast(i32)glc.Render_View_Mode.Depth) {
			s.rs.view_mode = .Depth
		}
	}

	if im.CollapsingHeader("Post-process") {
		if im.Checkbox("Use effects", &s.rs.post_process.should_use) {
		}

		if s.rs.post_process.should_use {
			if im.ComboCallback(
				"Select effect",
				&s.rs.post_process.idx,
				get_post_process_effect_name,
				nil,
				cast(i32)glc.post_process_effects_load_count(),
			) {
			}
		}
	}

	if im.Button("Reload Shaders") {
		s.app.should_reload_shaders = true
	}

	// ===================== helpers =====================

	get_post_process_effect_name :: proc "c" (_user_data: rawptr, idx: i32) -> cstring {
		effects := glc.post_process_effects_get_all()
		return effects[idx].value.display_name
	}

	get_scene_name :: proc "c" (_user_data: rawptr, idx: i32) -> cstring {
		return SCENE_REGISTRY[Scene_Index(idx)].name
	}
}

render_main_ui_window :: proc(s: ^State) {
	devui.begin_frame()
	defer devui.render_frame()

	im.Begin("Learning OpenGL")
	defer im.End()
	im.PushItemWidth(170.0)
	defer im.PopItemWidth()

	ui_sections_render(s)
	im.Separator()

	TABLE_FLAGS :: im.TableFlags_RowBg | im.TableFlags_Borders
	if im.BeginTable("shortcuts", 2, TABLE_FLAGS) {
		defer im.EndTable()
		im.TableSetupColumn("Key", {.WidthFixed}, 120.0)
		im.TableSetupColumn("Description", {.WidthStretch})
		im.TableHeadersRow()
		im.TableNextRow()
		im.TableNextColumn()

		shortcut("(Shift +)WASD", "(Sprint) Camera move")
		shortcut("Right click (hold)", "Look around")
		shortcut("R", "Reload shaders")
		shortcut("I", "Toggle UI")
		shortcut("P", "Toggle depth buffer view")
		shortcut("U", "Toggle wireframe mode")
		shortcut("ESC", "Close program")
	}

	// helper
	shortcut :: proc(name: cstring, description: cstring) {
		YELLOW :: im.Vec4{1, 1, 0, 1}

		im.TextColored(YELLOW, name)
		im.TableNextColumn()
		im.Text(description)
		im.TableNextColumn()
	}
}
