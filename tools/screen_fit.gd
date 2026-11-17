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


func set_fill(value: bool) -> void:
	fill = value
	var out := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify({"fill_screen": fill}))
		out.close()
	_apply()


func _apply() -> void:
	var root := get_tree().root
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if fill else Window.CONTENT_SCALE_ASPECT_KEEP
	var visible := root.get_visible_rect().size
	_top = 0.0
	if fill and root.mode >= Window.MODE_FULLSCREEN:
		# On a notched MacBook the fullscreen window includes the notch row, where the
		# menu bar shows through. Keep that row black and centre the game below it.
		var screen := root.current_screen
		var safe := DisplayServer.get_display_safe_area()
		var top_px := float(safe.position.y - DisplayServer.screen_get_position(screen).y)
		_top = maxf(0.0, top_px * visible.y / float(root.size.y))
	_shift = maxf(0.0, _top + (visible.y - _top - BASE.y) / 2.0) if fill else 0.0
	if OS.has_environment("MAC_SCREEN_DEBUG"):
		var f := FileAccess.open("user://mac_screen_debug.txt", FileAccess.WRITE)
		f.store_line("mode=%d window=%s visible=%s screen=%s safe=%s title_margins=%s top=%.1f shift=%.1f scale=%.3f" % [
			root.mode, root.size, visible, DisplayServer.screen_get_size(root.current_screen),
			DisplayServer.get_display_safe_area(), DisplayServer.window_get_safe_title_margins(),
			_top, _shift, DisplayServer.screen_get_scale(root.current_screen)])
		f.close()
	_bar.size = Vector2(visible.x, _top)
	_bar.visible = _top > 0.0
	root.canvas_transform = Transform2D(0.0, Vector2(0, _shift))
	_walk(root)


func _walk(node: Node) -> void:
	_fit(node)
	if node.name == "options_audio video":
		_add_toggle.call_deferred(node)  # the first menu loads before this helper starts
	for child in node.get_children():
		_walk(child)


func _on_node_added(node: Node) -> void:
	_fit(node)
	if node.name == "options_audio video":
		_add_toggle.call_deferred(node)


func _fit(node: Node) -> void:
	if node is CanvasLayer and not node.has_meta("mac_own"):
		if not node.has_meta("mac_offset"):
			node.set_meta("mac_offset", node.offset)
		node.offset = node.get_meta("mac_offset") + Vector2(0, _shift)
	elif node is Control:
		_fit_overlay.call_deferred(node)  # after the game has laid it out


func _fit_overlay(node: Control) -> void:
	# Plain full-screen colour or shader layers (fades, darkening, the posterize post-process,
	# VHS grain) only cover the 16:9 band. Stretch them over the whole screen. Images and
	# containers with buttons or text keep their 16:9 layout.
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if not node.has_meta("mac_overlay"):
		var r := node.get_global_rect()
		var plain := (node is ColorRect or node is Panel) and node.get_children().all(func(c): return not (c is Control))
		var covers := r.position.x <= 1.0 and r.position.y <= 1.0 and r.end.x >= BASE.x - 1.0 and r.end.y >= BASE.y - 1.0
		node.set_meta("mac_overlay", [r.position, r.size] if plain and covers else null)
	var saved = node.get_meta("mac_overlay")
	if saved == null:
		return
	var extra := get_tree().root.get_visible_rect().size.y - BASE.y
	if fill:
		node.global_position = Vector2(saved[0].x, saved[0].y - _shift)
		node.size = Vector2(saved[1].x, saved[1].y + extra)
	else:
		node.global_position = saved[0]
		node.size = saved[1]


func _process(_delta: float) -> void:
	# The game's camera angles are vertical (Keep Height). For a taller screen, keep the
	# horizontal view of the 16:9 game and show more above and below instead. Done every
	# frame because some scenes animate the camera's angle.
	var cam := get_tree().root.get_camera_3d()
	if cam == null:
		return
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


func _add_toggle(page: Node) -> void:
	# Adds "FILL SCREEN 16:10 (EXPERIMENTAL)" to the game's Audio/Video options, one row above
	# COLOR BLIND MODE, built from copies of the GREYSCALE DEATH row so it looks and
	# behaves like the game's own checkboxes. Mouse only for now.
	if not is_instance_valid(page) or page.has_node("mac_text_fill"):
		return
	var src_text := page.get_node_or_null("text_greyscale death") as Label
	var src_check := page.get_node_or_null("checkmark_greyscale") as TextureRect
	var src_bracket := page.get_node_or_null("bracket selection_greyscale death") as CanvasItem
	var src_button := page.get_node_or_null("true button_greyscale death") as Button
	if not (src_text and src_check and src_bracket and src_button):
		return
	var dy := -50.0  # greyscale row is at y 83, colour blind at 58: this row goes at 33
	var text := src_text.duplicate() as Label
	text.name = "mac_text_fill"
	text.text = "FILL SCREEN 16:10 (EXPERIMENTAL)"
	text.position.y += dy
	var check := src_check.duplicate() as TextureRect
	check.name = "mac_check_fill"
	check.position.y += dy
	var bracket := src_bracket.duplicate() as CanvasItem
	bracket.name = "mac_bracket_fill"
	bracket.position.y += dy
	var button := src_button.duplicate() as Button
	button.name = "mac_button_fill"
	button.position.y += dy
	for n in [text, check, bracket, button]:
		page.add_child(n)
	var branch := check.get_child(0)
	branch.ui = check  # the copy still pointed at the greyscale checkmark
	var bc := button.get_child(0)
	bc.ui = bracket
	branch.UpdateCheckmark(fill)
	if OS.has_environment("MAC_SCREEN_DEBUG"):
		var f := FileAccess.open("user://mac_screen_toggle.txt", FileAccess.WRITE)
		f.store_line("toggle added to %s visible=%s" % [page.get_path(), text.is_visible_in_tree()])
		f.close()
	bc.is_pressed.connect(func():
		set_fill(not fill)
		branch.UpdateCheckmark(fill))
