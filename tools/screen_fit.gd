# Mac helper: repair legacy table geometry and provide experimental 16:10 screen fill.
# The game is laid out for 960x540 (16:9) and adds black bars on a 16:10 screen.
# When on: the view grows to fill the screen (960x600 on 16:10), cameras keep their
# width so you see a little more above and below, and every 2D element is moved down
# so the original 16:9 layout stays centred. Full-screen overlays are stretched to cover.
extends Node

const SETTINGS := "user://mac_screen.json"
const BASE := Vector2(960, 540)

var fill := false
var _shift := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000  # after the game's own animations have moved the camera
	if FileAccess.file_exists(SETTINGS):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if parsed is Dictionary:
			fill = bool(parsed.get("fill_screen", false))
	if "--fill-screen" in OS.get_cmdline_user_args() or "--fill-screen" in OS.get_cmdline_args():
		fill = true
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_apply)
	_apply()
	print("mac screen fit: ", "on" if fill else "off", " view ", get_tree().root.get_visible_rect().size)


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
	_shift = maxf(0.0, (visible.y - BASE.y) / 2.0) if fill else 0.0
	root.canvas_transform = Transform2D(0.0, Vector2(0, _shift))
	_walk(root)


func _walk(node: Node) -> void:
	_fit(node)
	for child in node.get_children():
		_walk(child)


func _on_node_added(node: Node) -> void:
	_fit(node)


func _fit(node: Node) -> void:
	if node is MeshInstance3D:
		_repair_table_mesh(node)
	elif node is CanvasLayer:
		if not node.has_meta("mac_offset"):
			node.set_meta("mac_offset", node.offset)
		node.offset = node.get_meta("mac_offset") + Vector2(0, _shift)
	elif node is Control and node.anchor_bottom == 1.0 and node.anchor_top == 0.0 and _is_top_control(node):
		# full-height overlays (fades, blockers, grain): cover the whole screen, not just the centre
		if not node.has_meta("mac_offsets"):
			node.set_meta("mac_offsets", Vector2(node.offset_top, node.offset_bottom))
		var base: Vector2 = node.get_meta("mac_offsets")
		node.offset_top = base.x - _shift
		node.offset_bottom = base.y - _shift


func _repair_table_mesh(node: MeshInstance3D) -> void:
	var parent := node.get_parent()
	if parent == null or not node.mesh is ArrayMesh or node.mesh.has_meta("mac_table_mesh"):
		return
	var base := parent.name == "tabletop parent" and node.name in ["main tabletop", "main tabletop2"]
	var detail := parent.name == "main tabletop" and (str(node.name).begins_with("Plane_03") or node.name in ["health counter", "compartment_shells"])
	var compartment := parent.name == "compartments parent" and str(node.name).begins_with("compartment")
	if not (base or detail or compartment):
		return
	var source: ArrayMesh = node.mesh
	# shortcut: only static table parts; extend for animated meshes after checking a newer game build.
	if node.skin != null or source.get_blend_shape_count() != 0:
		push_warning("Mac table fix skipped: animated mesh " + str(node.name))
		return
	# Re-upload the legacy arrays: automatic conversion leaves seams and dark wedges in 4.4+.
	var rebuilt := ArrayMesh.new()
	rebuilt.resource_name = source.resource_name
	rebuilt.custom_aabb = source.custom_aabb
	rebuilt.shadow_mesh = source.shadow_mesh
	rebuilt.lightmap_size_hint = source.lightmap_size_hint
	for i in range(source.get_surface_count()):
		rebuilt.add_surface_from_arrays(source.surface_get_primitive_type(i), source.surface_get_arrays(i))
		rebuilt.surface_set_material(i, source.surface_get_material(i))
		rebuilt.surface_set_name(i, source.surface_get_name(i))
	# Godot 4.4 exposes LOD data only through serialized surfaces; retain the original indices.
	var original_surfaces: Array = source.get("_surfaces")
	var rebuilt_surfaces: Array = rebuilt.get("_surfaces")
	for i in range(original_surfaces.size()):
		if original_surfaces[i].has("lods"):
			rebuilt_surfaces[i]["lods"] = original_surfaces[i]["lods"]
	rebuilt.set("_surfaces", rebuilt_surfaces)
	rebuilt.set_meta("mac_table_mesh", true)
	node.mesh = rebuilt


func _is_top_control(node: Control) -> bool:
	# only controls laid out against the screen, not ones inside another control
	return not (node.get_parent() is Control)


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
