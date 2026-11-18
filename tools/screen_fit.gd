# Mac helper, started by the patched Steam.gd: sets the Dock icon, and runs the
# experimental "fill the screen" for 16:10 Macs (off by default).
# The game is laid out for 960x540 (16:9) and adds black bars on a 16:10 screen.
# When on: the view grows to fill the screen (960x600 on 16:10), cameras keep their
# width so you see a little more above and below, and every 2D element is moved down
# so the original 16:9 layout stays centred. Full-screen overlays are stretched to cover.
extends Node

const SETTINGS := "user://mac_screen.json"
const BASE := Vector2(960, 540)
const COPY_FLAGS := Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS

var fill := false
var fps_limit := 0  # 0 = unlimited (the game's default)
var show_fps := false
var _fps_label: Label
var _fps_time := 0.0
var _shift := 0.0
var _top := 0.0  # notch row, in game pixels, kept black
var _bar: ColorRect
var _candidates := []  # plain colour/image layers not yet matched as full-screen
var _recheck := 0.0


func _test_scene() -> void:
	# test only: MAC_SCREEN_SCENE=res://scenes/death.tscn opens that scene after start-up
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file(OS.get_environment("MAC_SCREEN_SCENE"))


func _enter_tree() -> void:
	name = "MacScreenFit"  # the patched MouseRaycast.gd finds this helper by name


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000  # after the game's own animations have moved the camera
	if FileAccess.file_exists("res://mac_icon.icns"):
		DisplayServer.set_native_icon("res://mac_icon.icns")  # the game would set its raw PNG icon
	var layer := CanvasLayer.new()
	layer.layer = 128
	layer.set_meta("mac_own", true)
	_bar = ColorRect.new()
	_bar.color = Color.BLACK
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bar)
	_fps_label = Label.new()  # small counter in the top-right corner
	_fps_label.add_theme_font_size_override("font_size", 12)
	_fps_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fps_label)
	add_child(layer)
	if FileAccess.file_exists(SETTINGS):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if parsed is Dictionary:
			fill = bool(parsed.get("fill_screen", false))
			fps_limit = int(parsed.get("fps_limit", 0))
			show_fps = bool(parsed.get("show_fps", false))
	if "--fill-screen" in OS.get_cmdline_user_args() or "--fill-screen" in OS.get_cmdline_args():
		fill = true
	if OS.has_environment("MAC_SCREEN_SCENE"):
		_test_scene()
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_apply)
	_apply()


func _save() -> void:
	var out := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify({"fill_screen": fill, "fps_limit": fps_limit, "show_fps": show_fps}))
		out.close()
	_apply()


func _apply() -> void:
	var root := get_tree().root
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if fill else Window.CONTENT_SCALE_ASPECT_KEEP
	# the scaled view rarely matches the window to the pixel (960x602 -> 1896 of 1898 px):
	# the leftover row shows the clear colour, the game's grey, as a thin line
	RenderingServer.set_default_clear_color(Color.BLACK if fill else ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"))
	var visible := root.get_visible_rect().size
	_top = 0.0
	if fill and root.mode >= Window.MODE_FULLSCREEN:
		# On a notched MacBook the fullscreen window includes the notch row: keep that
		# row black and centre the game below it.
		# only the part of the notch row that actually overlaps the window (macOS usually
		# places fullscreen windows below the notch already, then this is 0)
		var safe := DisplayServer.get_display_safe_area()
		var top_px := float(safe.position.y - root.position.y)
		_top = ceilf(maxf(0.0, top_px * visible.y / float(root.size.y)))  # whole pixels: no half-covered line
	_shift = maxf(0.0, _top + (visible.y - _top - BASE.y) / 2.0) if fill else 0.0
	if OS.has_environment("MAC_SCREEN_DEBUG"):
		var f := FileAccess.open("user://mac_screen_debug.txt", FileAccess.WRITE)
		f.store_line("winpos=%s mode=%d window=%s visible=%s screen=%s safe=%s title_margins=%s top=%.1f shift=%.1f scale=%.3f" % [
			root.position, root.mode, root.size, visible, DisplayServer.screen_get_size(root.current_screen),
			DisplayServer.get_display_safe_area(), DisplayServer.window_get_safe_title_margins(),
			_top, _shift, DisplayServer.screen_get_scale(root.current_screen)])
		f.close()
	# with fill on, the game's own top pixel row shows a grey edge line from its post-process
	# effects (in 16:9 it falls inside the black bars): keep that one row black
	_bar.size = Vector2(visible.x, maxf(_top, 1.0))
	_bar.visible = fill
	root.canvas_transform = Transform2D(0.0, Vector2(0, _shift))
	Engine.max_fps = fps_limit
	_fps_label.visible = show_fps
	_fps_label.position = Vector2(visible.x - 60, maxf(_top, 1.0) + 4)
	_walk(root)


func _walk(node: Node) -> void:
	_fit(node)
	if node.name == "sub options select":
		_add_mac_page.call_deferred(node)  # the first menu loads before this helper starts
	for child in node.get_children():
		_walk(child)


func _on_node_added(node: Node) -> void:
	_fit(node)
	if node.name == "sub options select":
		_add_mac_page.call_deferred(node)


func _fit(node: Node) -> void:
	if node is CanvasLayer and not node.has_meta("mac_own"):
		if not node.has_meta("mac_offset"):
			node.set_meta("mac_offset", node.offset)
		node.offset = node.get_meta("mac_offset") + Vector2(0, _shift)
	elif (node is ColorRect or node is Panel or node is TextureRect) and not node.get_children().any(func(c): return c is Control):
		if not node in _candidates:
			_candidates.append(node)
		_fit_overlay.call_deferred(node)  # after the game has laid it out


func _fit_overlay(node) -> void:  # untyped: a deferred call may arrive after the node was freed
	# Plain full-screen colour or shader layers (fades, darkening, the posterize post-process,
	# VHS grain) only cover the 16:9 band: stretch them over the whole screen. Full-screen
	# images (loading screen, death screen) keep their shape and get black behind them.
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if not node.has_meta("mac_overlay"):
		# not cached when it doesn't match: intro animations can move a layer into place later
		var r: Rect2 = node.get_global_rect()
		var covers: bool = r.position.x <= 1.0 and r.position.y <= 1.0 and r.end.x >= BASE.x - 1.0 and r.end.y >= BASE.y - 1.0
		if not covers:
			return
		node.set_meta("mac_overlay", [r.position, r.size, "backfill" if node is TextureRect else "stretch"])
	var saved = node.get_meta("mac_overlay")
	var visible := get_tree().root.get_visible_rect().size
	if saved[2] == "backfill":
		# black only above and below the image, so fades stay even across the screen
		var bands := [[-_shift, saved[0].y], [saved[0].y + saved[1].y, visible.y - _shift]]
		for i in 2:
			var band := node.get_node_or_null("mac_band%d" % i) as ColorRect
			if band == null:
				band = ColorRect.new()
				band.name = "mac_band%d" % i
				band.color = Color.BLACK
				band.mouse_filter = Control.MOUSE_FILTER_IGNORE
				node.add_child(band)
			band.visible = fill
			band.global_position = Vector2(0, bands[i][0])
			band.size = Vector2(maxf(visible.x, BASE.x), maxf(0.0, bands[i][1] - bands[i][0])) / node.get_global_transform().get_scale()
		return
	var extra := visible.y - BASE.y
	var scale: Vector2 = node.get_global_transform().get_scale()  # some layers are scaled; size is unscaled
	if fill:
		node.global_position = Vector2(saved[0].x, saved[0].y - _shift)
		node.size = Vector2(saved[1].x, saved[1].y + extra) / scale
	else:
		node.global_position = saved[0]
		node.size = saved[1] / scale


var _dump := 0.0
func _process(delta: float) -> void:
	if show_fps:
		_fps_time += delta
		if _fps_time > 0.5:
			_fps_time = 0.0
			_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if OS.has_environment("MAC_SCREEN_DEBUG"):
		_dump += delta
		if _dump > 1.0:
			_dump = 0.0
			var f := FileAccess.open("user://mac_screen_layers.txt", FileAccess.READ_WRITE if FileAccess.file_exists("user://mac_screen_layers.txt") else FileAccess.WRITE)
			f.seek_end()
			f.store_line("--- t=%d" % Time.get_ticks_msec())
			for n in get_tree().root.find_children("*", "Control", true, false):
				if n.is_visible_in_tree() and (n is ColorRect or n is TextureRect or n is Panel):
					var r: Rect2 = n.get_global_rect()
					if r.size.x > 600 and r.size.y > 300:
						f.store_line("%s %s rect=%s mod=%.2f meta=%s" % [n.get_path(), n.get_class(), r, n.modulate.a * n.self_modulate.a, n.get_meta("mac_overlay", "none")])
			f.close()
	_recheck += delta
	if _recheck > 0.2:
		_recheck = 0.0
		# drop freed layers by filtering: erasing a freed object from an array crashes Godot 4.4
		_candidates = _candidates.filter(func(n): return is_instance_valid(n) and n.is_inside_tree() and not n.has_meta("mac_overlay"))
		for node in _candidates:
			if node.is_visible_in_tree():
				_fit_overlay(node)
	# The game's camera angles are vertical (Keep Height). For a taller screen, keep the
	# horizontal view of the 16:9 game and show more above and below instead. Every camera
	# of the main view gets this, not only the visible one: the game aims mouse clicks with
	# a second camera (MouseRaycast), and both must project the same way. Done every frame
	# because some scenes animate the camera's angle.
	var root := get_tree().root
	for cam in root.find_children("*", "Camera3D", true, false):
		if cam.get_viewport() != root:
			continue  # e.g. the globe in the lobby renders in its own viewport
		_fit_camera(cam)


func controller_ray_position(point: Vector2, visible: Vector2) -> Vector2:
	# Controller slots are stored in the original 960x540 camera projection.
	return (point - BASE / 2.0) * visible.x / BASE.x + visible / 2.0 if fill else point


func _fit_camera(cam: Camera3D) -> void:
	if not fill:
		if cam.has_meta("mac_fov"):
			cam.keep_aspect = Camera3D.KEEP_HEIGHT
			cam.fov = cam.get_meta("mac_fov")
			cam.remove_meta("mac_fov")
			cam.remove_meta("mac_set")
		return
	if not cam.has_meta("mac_set") or not is_equal_approx(cam.fov, cam.get_meta("mac_set")):
		cam.set_meta("mac_fov", cam.fov)  # the game set a new angle since our last frame
	var vertical: float = cam.get_meta("mac_fov")
	var horizontal := rad_to_deg(2.0 * atan(tan(deg_to_rad(vertical) / 2.0) * BASE.x / BASE.y))
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = horizontal
	cam.set_meta("mac_set", horizontal)


func _add_mac_page(sub: Control) -> void:
	# Options gets a MAC entry above AUDIO/VIDEO that opens its own page, built from
	# copies of the game's own labels, checkboxes and buttons. The game's own pages stay
	# exactly as they are.
	if not is_instance_valid(sub) or sub.has_node("mac_entry"):
		return
	var ui := sub.get_parent()
	var av := ui.get_node_or_null("options_audio video")
	var menu: Node = null
	for n in get_tree().root.find_children("*", "Node", true, false):
		if n.has_method("Options_AudioVideo"):
			menu = n
			break
	if av == null or menu == null:
		return
	# the page
	var page := Control.new()
	page.name = "options_mac"
	page.visible = false
	ui.add_child(page)
	ui.move_child(page, sub.get_index() + 1)
	menu.screens.append(page)  # the game hides it along with its other pages
	# Start at the same top row as Audio/Video, with one left-aligned text column.
	var main := ui.get_node_or_null("main screen")
	if main == null:
		return
	var src_text := av.get_node("text_greyscale death") as Label
	var top: float = av.get_node("text_color blind mode").position.y
	var bracket := _add_row(av, page, "fill", "FILL SCREEN 16:10 *", top - src_text.position.y,
		func(): return fill, func(): fill = not fill)
	var fps_label := src_text.duplicate(COPY_FLAGS) as Label
	fps_label.name = "fps_limit_label"
	fps_label.text = _fps_text()
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fps_label.pivot_offset = Vector2.ZERO
	fps_label.position = Vector2(335.0, top + 38.0)
	page.add_child(fps_label)
	var fps_button := av.get_node("true button_greyscale death").duplicate(COPY_FLAGS) as Button
	fps_button.name = "fps_limit_button"
	fps_button.pivot_offset = Vector2.ZERO
	var fps_bc := fps_button.get_child(0)
	fps_bc.ui = fps_label
	fps_bc.ui_opacity_inactive = 1.0
	fps_bc.ui_opacity_active = 0.78
	page.add_child(fps_button)
	var fit_hit := func():  # keep the click area over the full current text
		var font := fps_label.get_theme_font("font")
		var w: float = font.get_string_size(fps_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fps_label.get_theme_font_size("font_size")).x * fps_label.scale.x
		fps_button.scale = Vector2(w / 8.0, 3.0)
		fps_button.position = Vector2(fps_label.position.x, fps_label.position.y + 6.0)
	fit_hit.call()
	fps_bc.is_pressed.connect(func():
		fps_limit = {0: 60, 60: 120}.get(fps_limit, 0)
		fps_label.text = _fps_text()
		fit_hit.call()
		_save())
	var bracket2 := _add_row(av, page, "fps", "SHOW FPS", top + 76.0 - src_text.position.y,
		func(): return show_fps, func(): show_fps = not show_fps)
	for br in [bracket, bracket2]:
		if br:
			# the game shows option brackets only while a controller is in use
			menu.controller.brackets.append(br)
			br.visible = menu.cursor.controller_active
	var note := src_text.duplicate(COPY_FLAGS) as Label
	note.text = "* EXPERIMENTAL\nNOTCH AREA KEPT CLEAR AUTOMATICALLY"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.pivot_offset = Vector2.ZERO
	note.position = Vector2(335.0, top + 119.0)
	note.add_theme_font_size_override("font_size", int(src_text.get_theme_font_size("font_size") * 0.7))
	note.modulate.a = 0.6
	page.add_child(note)
	# the counter uses the game's font, at its own small size
	_fps_label.add_theme_font_override("font", src_text.get_theme_font("font"))
	var back := _clone_button(av.get_node("button_exit options"), av.get_node("true button_return audio video"), page, "RETURN", 0.0)
	back.is_pressed.connect(func(): menu.Show("sub options"))
	# the MAC entry goes first; then all five rows take the main menu's exact positions
	# (START..EXIT), so both lists line up pixel for pixel
	var entry := _clone_button(sub.get_node("button_audio video"), sub.get_node("true button_audio video"), sub, "MAC", 0.0)
	entry.get_parent().name = "mac_entry"
	if main:
		var rows := [[entry.ui, entry.get_parent()],
			[sub.get_node("button_audio video"), sub.get_node("true button_audio video")],
			[sub.get_node("button_language"), sub.get_node("true button_language")],
			[sub.get_node("button_controller"), sub.get_node("true button_controller")],
			[sub.get_node("button_return"), sub.get_node("true button_exit sub options")]]
		var targets := ["button_start", "button_multiplayer", "button_options", "button_credits", "button_exit"]
		for i in rows.size():
			var target := main.get_node(targets[i]) as Label
			var label: Label = rows[i][0]
			var button: Control = rows[i][1]
			var hit := button.position.y - label.position.y  # keep each click area on its word
			label.position.y = target.position.y
			label.size.y = target.size.y
			button.position.y = target.position.y + hit
	menu.firstFocus_subOptions = entry.get_parent()
	_wire_focus([entry.get_parent(), sub.get_node("true button_audio video"), sub.get_node("true button_language"),
		sub.get_node("true button_controller"), sub.get_node("true button_exit sub options")])
	var first := page.get_node("fill_button") as Button
	_wire_focus([first, fps_button, page.get_node("fps_button"), back.get_parent()])
	entry.is_pressed.connect(func():
		# MenuManager has no MAC case; use its known screen first, then set our page/focus.
		menu.Show("sub options")
		sub.visible = false
		menu.title.visible = false
		menu.lastScreen = "sub options"
		menu.currentScreen = "mac"
		page.visible = true
		if menu.cursor.controller_active: first.grab_focus()
		menu.controller.previousFocus = first)


func _wire_focus(buttons: Array) -> void:
	for i in buttons.size():
		var button: Button = buttons[i]
		var previous: NodePath = button.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		var next: NodePath = button.get_path_to(buttons[(i + 1) % buttons.size()])
		button.focus_neighbor_top = previous
		button.focus_previous = previous
		button.focus_neighbor_bottom = next
		button.focus_next = next
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)


func _fps_text() -> String:
	return "FPS LIMIT: " + ("UNLIMITED" if fps_limit == 0 else str(fps_limit))


func _clone_button(label: Label, button: Button, parent: Node, text: String, dy: float) -> Node:
	var l := label.duplicate(COPY_FLAGS) as Label
	l.text = text
	l.position.y += dy
	var b := button.duplicate(COPY_FLAGS) as Button
	b.position.y += dy
	var bc := b.get_child(0)
	bc.ui = l  # set before _ready, so the copy cannot change the original label
	parent.add_child(l)
	parent.add_child(b)
	if bc.isDynamic:
		l.modulate.a = bc.ui_opacity_inactive
	return bc


func _add_row(src: Node, parent: Node, id: String, label: String, dy: float, get_value: Callable, flip: Callable) -> CanvasItem:
	# a checkbox row copied from the game's GREYSCALE DEATH row
	var src_text := src.get_node_or_null("text_greyscale death") as Label
	var src_check := src.get_node_or_null("checkmark_greyscale") as TextureRect
	var src_bracket := src.get_node_or_null("bracket selection_greyscale death") as CanvasItem
	var src_button := src.get_node_or_null("true button_greyscale death") as Button
	if not (src_text and src_check and src_bracket and src_button):
		return null
	var text := src_text.duplicate(COPY_FLAGS) as Label
	text.name = id + "_label"
	text.text = label
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.pivot_offset = Vector2.ZERO
	text.position.x = 335.0
	var check := src_check.duplicate(COPY_FLAGS) as TextureRect
	var bracket := src_bracket.duplicate(COPY_FLAGS) as CanvasItem
	var button := src_button.duplicate(COPY_FLAGS) as Button
	button.name = id + "_button"
	var branch := check.get_child(0)
	branch.ui = check
	var bc := button.get_child(0)
	bc.ui = bracket
	for n in [text, check, bracket, button]:
		n.position.y += dy
		parent.add_child(n)
	if bc.isDynamic:
		bracket.modulate.a = bc.ui_opacity_inactive
	branch.UpdateCheckmark(get_value.call())
	bc.is_pressed.connect(func():
		flip.call()
		_save()
		branch.UpdateCheckmark(get_value.call()))
	return bracket
