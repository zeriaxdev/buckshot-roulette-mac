# Mac helper, started by the patched Steam.gd: sets the Dock icon, and runs the
# experimental "fill the screen" for 16:10 Macs (off by default).
# The game is laid out for 960x540 (16:9) and adds black bars on a 16:10 screen.
# When on: the view grows to fill the screen (960x600 on 16:10), cameras keep their
# width so you see a little more above and below, and every 2D element is moved down
# so the original 16:9 layout stays centred. Full-screen overlays are stretched to cover.
extends Node

const SETTINGS := "user://mac_screen.json"
const BASE := Vector2(960, 540)

var fill := false
var _shift := 0.0
var _top := 0.0  # notch row, in game pixels, kept black
var _bar: ColorRect
var _candidates: Array[Control] = []  # plain colour/image layers not yet matched as full-screen
var _recheck := 0.0


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
	add_child(layer)
	if FileAccess.file_exists(SETTINGS):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if parsed is Dictionary:
			fill = bool(parsed.get("fill_screen", false))
	if "--fill-screen" in OS.get_cmdline_user_args() or "--fill-screen" in OS.get_cmdline_args():
		fill = true
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_apply)
	_apply()


func _save() -> void:
	var out := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify({"fill_screen": fill}))
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
	_bar.size = Vector2(visible.x, _top)
	_bar.visible = _top > 0.0
	root.canvas_transform = Transform2D(0.0, Vector2(0, _shift))
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


func _fit_overlay(node: Control) -> void:
	# Plain full-screen colour or shader layers (fades, darkening, the posterize post-process,
	# VHS grain) only cover the 16:9 band: stretch them over the whole screen. Full-screen
	# images (loading screen, death screen) keep their shape and get black behind them.
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if not node.has_meta("mac_overlay"):
		# not cached when it doesn't match: intro animations can move a layer into place later
		var r := node.get_global_rect()
		var covers := r.position.x <= 1.0 and r.position.y <= 1.0 and r.end.x >= BASE.x - 1.0 and r.end.y >= BASE.y - 1.0
		if not covers:
			return
		node.set_meta("mac_overlay", [r.position, r.size, "backfill" if node is TextureRect else "stretch"])
		_candidates.erase(node)
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
	var scale := node.get_global_transform().get_scale()  # some layers are scaled; size is unscaled
	if fill:
		node.global_position = Vector2(saved[0].x, saved[0].y - _shift)
		node.size = Vector2(saved[1].x, saved[1].y + extra) / scale
	else:
		node.global_position = saved[0]
		node.size = saved[1] / scale


var _dump := 0.0
func _process(delta: float) -> void:
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
		for node in _candidates.duplicate():
			if not is_instance_valid(node) or not node.is_inside_tree():
				_candidates.erase(node)
			elif node.is_visible_in_tree():
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
	_add_row(av, page, "fill", "FILL SCREEN 16:10 *", 58.0 - 83.0,
		func(): return fill, func(): fill = not fill)
	var note := av.get_node("text_greyscale death").duplicate() as Label
	note.text = "* EXPERIMENTAL"
	note.position.y += 400.0 - 83.0
	note.modulate.a = 0.6
	page.add_child(note)
	var back := _clone_button(av.get_node("button_exit options"), av.get_node("true button_return audio video"), page, "RETURN", 0.0)
	back.is_pressed.connect(func(): menu.Show("sub options"))
	# the MAC entry takes AUDIO/VIDEO's place; the game's entries move down one row
	for n in sub.get_children():
		if n is Control:
			n.position.y += 25.0
	var entry := _clone_button(sub.get_node("button_audio video"), sub.get_node("true button_audio video"), sub, "MAC", -25.0)
	entry.get_parent().name = "mac_entry"
	entry.is_pressed.connect(func():
		menu.Show("mac")
		page.visible = true)


func _clone_button(label: Label, button: Button, parent: Node, text: String, dy: float) -> Node:
	var l := label.duplicate() as Label
	l.text = text
	l.position.y += dy
	var b := button.duplicate() as Button
	b.position.y += dy
	parent.add_child(l)
	parent.add_child(b)
	var bc := b.get_child(0)
	bc.ui = l
	if bc.isDynamic:
		l.modulate.a = bc.ui_opacity_inactive
	return bc


func _add_row(src: Node, parent: Node, id: String, label: String, dy: float, get_value: Callable, flip: Callable) -> void:
	# a checkbox row copied from the game's GREYSCALE DEATH row
	var src_text := src.get_node_or_null("text_greyscale death") as Label
	var src_check := src.get_node_or_null("checkmark_greyscale") as TextureRect
	var src_bracket := src.get_node_or_null("bracket selection_greyscale death") as CanvasItem
	var src_button := src.get_node_or_null("true button_greyscale death") as Button
	if not (src_text and src_check and src_bracket and src_button):
		return
	var text := src_text.duplicate() as Label
	text.text = label
	var check := src_check.duplicate() as TextureRect
	var bracket := src_bracket.duplicate() as CanvasItem
	var button := src_button.duplicate() as Button
	for n in [text, check, bracket, button]:
		n.position.y += dy
		parent.add_child(n)
	var branch := check.get_child(0)
	branch.ui = check  # the copy still pointed at the greyscale checkmark
	var bc := button.get_child(0)
	bc.ui = bracket
	if bc.isDynamic:
		bracket.modulate.a = bc.ui_opacity_inactive  # the copy's _ready hid the original's bracket, not this one
	branch.UpdateCheckmark(get_value.call())
	bc.is_pressed.connect(func():
		flip.call()
		_save()
		branch.UpdateCheckmark(get_value.call()))
