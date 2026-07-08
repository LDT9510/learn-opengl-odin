package devui

import im "extern:imgui"

MainUIProc :: #type proc()
ShortcutsProc :: #type proc()

render_shortcuts :: proc(shortcuts_ui_proc: ShortcutsProc) {
	if im.CollapsingHeader("Global Shortcuts") {
		TABLE_FLAGS :: im.TableFlags_RowBg | im.TableFlags_Borders
		if im.BeginTable("shortcuts", 2, TABLE_FLAGS) {
			defer im.EndTable()
			im.TableSetupColumn("Key", {.WidthFixed}, 120.0)
			im.TableSetupColumn("Description", {.WidthStretch})
			im.TableHeadersRow()
			im.TableNextRow()
			im.TableNextColumn()

			shortcuts_ui_proc()
		}
	}
}

render_ui :: proc(title: cstring, main_ui_proc: MainUIProc, shortcuts_ui_proc: ShortcutsProc) {
	begin_frame()
	defer render_frame()

	im.Begin(title)
	defer im.End()
	im.PushItemWidth(170.0)
	defer im.PopItemWidth()

	render_shortcuts(shortcuts_ui_proc)
	main_ui_proc()
}

shortcut :: proc(name: cstring, description: cstring) {
	YELLOW :: im.Vec4{1, 1, 0, 1}

	im.TextColored(YELLOW, name)
	im.TableNextColumn()
	im.Text(description)
	im.TableNextColumn()
}
