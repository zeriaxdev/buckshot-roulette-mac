# Runs against a private extracted fixture; never against the player's normal save directory.
extends SceneTree

func _initialize():
	if not OS.get_user_data_dir().get_file().begins_with("buckshot-"):
		printerr("Refusing non-test saves"); quit(1); return
	Engine.max_fps = 60
	root.unfocusable = true
	_run.call_deferred()

func _run():
	root.get_node("GlobalVariables").using_steam = false
	TranslationServer.set_locale("EN")
	var placeholder := Node.new()
	root.add_child(placeholder); current_scene = placeholder
	var scene = load("res://scenes/menu.tscn").instantiate()
	root.add_child.call_deferred(scene)
	await scene.ready
	current_scene = scene; placeholder.queue_free()
	await process_frame
	var menu
	for node in scene.find_children("*", "Node", true, false):
		if node.has_method("Options_AudioVideo"): menu = node; break
	if menu == null: return fail("Menu manager missing")
	menu.SkipIntro()
	if OS.get_cmdline_user_args().size() > 1:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(960, 600)
		root.position = Vector2i(10000, 10000)
	var native_greyscale: bool = menu.optionmanager.setting_greyscale_death
	var native_text: Label = menu.parent_audiovideo.get_node("text_greyscale death")
	var original_position := native_text.position
	var original_alpha := native_text.modulate.a
	var helper = load(OS.get_cmdline_user_args()[0]).new()
	root.add_child.call_deferred(helper)
	await helper.ready
	for _i in 4: await process_frame
	menu.assigningFocus = true
	menu.cursor.controller_active = true
	menu.Show("sub options")
	var entry = menu.parent_suboptions.get_node("mac_entry")
	if root.gui_get_focus_owner() != entry: return fail("Options does not start at MAC")
	entry.pressed.emit()
	var page = menu.parent_suboptions.get_parent().get_node("options_mac")
	var first = page.get_node("fill_button")
	if not page.is_visible_in_tree() or root.gui_get_focus_owner() != first or menu.currentScreen != "mac":
		return fail("MAC did not open with controller focus")
	if native_text.position != original_position or native_text.modulate.a != original_alpha:
		return fail("Cloning changed the original Audio/Video label")
	var focus = first
	var visited := []
	while focus not in visited:
		if focus == null or not page.is_ancestor_of(focus): return fail("Focus escaped the MAC page")
		visited.append(focus)
		focus = focus.find_valid_focus_neighbor(SIDE_BOTTOM)
	if visited.size() != 5 or focus != first: return fail("Not all five MAC controls are reachable")
	var fill_before: bool = helper.fill
	first.pressed.emit()
	var notch_before: bool = helper.include_notch
	page.get_node("notch_button").pressed.emit()
	if helper.include_notch == notch_before: return fail("Notch checkbox did not toggle exactly once")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(helper.SETTINGS))
	if not saved is Dictionary or saved.get("include_notch") != helper.include_notch:
		return fail("Notch preference was not saved")
	page.get_node("notch_button").pressed.emit()
	if helper.fill == fill_before: return fail("Fill checkbox did not toggle exactly once")
	first.pressed.emit()
	var fps_before: int = helper.fps_limit
	page.get_node("fps_limit_button").pressed.emit()
	if helper.fps_limit != {0: 60, 60: 120}.get(fps_before, 0): return fail("FPS limit did not advance once")
	var show_before: bool = helper.show_fps
	page.get_node("fps_button").pressed.emit()
	if helper.show_fps == show_before: return fail("Show FPS checkbox did not toggle")
	if menu.optionmanager.setting_greyscale_death != native_greyscale:
		return fail("Mac settings also triggered the original greyscale action")
	for name in ["fill_label", "notch_label", "fps_limit_label", "fps_label"]:
		var label = page.get_node(name)
		if not is_equal_approx(label.get_global_rect().position.x, 335.0) or label.position.y > 175.0 or label.horizontal_alignment != HORIZONTAL_ALIGNMENT_LEFT:
			return fail("Mac settings are not aligned at the top")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"; cancel.pressed = true
	menu._input(cancel)
	if page.visible or menu.currentScreen != "sub options": return fail("Cancel did not return to Options")
	entry.pressed.emit()
	visited.back().pressed.emit()
	if page.visible or menu.currentScreen != "sub options": return fail("Return did not return to Options")
	if OS.get_cmdline_user_args().size() > 1:
		entry.pressed.emit()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
	print("PASS Mac menu: top alignment, five controls, saved notch toggle, native settings isolation, controller focus and both returns")
	scene.queue_free(); helper.queue_free()
	await process_frame
	await process_frame
	quit()

func fail(message: String):
	printerr(message)
	quit(1)
