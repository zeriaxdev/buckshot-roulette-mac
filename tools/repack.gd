# Copies the owner's game data from their Windows exe into a new PCK, adds the
# GodotSteam extension files and an ownership check. Run by build.py:
#   godot --headless --script repack.gd -- OUT.pck GAME.exe EXTRAS_DIR
extends SceneTree

const STEAM_GD := "scripts/Steam.gd"
const ANCHOR := "\tInitializeSteam()\n"
const CHECK := "\tInitializeSteam()\n\tif not (Steam.loggedOn() and Steam.isSubscribedApp(appid)):\n\t\tOS.alert(\"Buckshot Roulette must be owned on Steam, and Steam must be running and signed in.\", \"Buckshot Roulette\")\n\t\tget_tree().quit()\n\t\treturn\n\tif ResourceLoader.exists(\"res://mac/screen_fit.gd\"):\n\t\tget_tree().root.add_child.call_deferred(load(\"res://mac/screen_fit.gd\").new())\n"

var packer := PCKPacker.new()
var count := 0
var skip := {}

func walk(base: String, rel: String, from_pack: bool):
	var da := DirAccess.open(base.path_join(rel))
	da.include_hidden = true
	for f in da.get_files():
		var r := rel.path_join(f) if rel != "" else f
		if from_pack and skip.has(r):
			continue
		if packer.add_file("res://" + r, base.path_join(r)) != OK:
			push_error("add_file failed: " + r)
			quit(1)
		count += 1
	for d in da.get_directories():
		walk(base, rel.path_join(d) if rel != "" else d, from_pack)

func write(base: String, rel: String, text: String):
	DirAccess.make_dir_recursive_absolute(base.path_join(rel).get_base_dir())
	var f := FileAccess.open(base.path_join(rel), FileAccess.WRITE)
	f.store_string(text)
	f.close()

func fail(msg: String):
	printerr("REPACK ERROR: " + msg)
	quit(1)

static func patch_window_modes(text: String) -> String:
	if text.count("DisplayServer.window_set_mode(") != 2 or text.contains("func _mac_window_mode"):
		return ""
	return text.replace("DisplayServer.window_set_mode(", "_mac_window_mode(") + "\nfunc _mac_window_mode(mode):\n\tvar helper = get_node_or_null(\"/root/MacScreenFit\")\n\tif helper: helper.set_game_windowed(mode == DisplayServer.WINDOW_MODE_WINDOWED)\n\telse: DisplayServer.window_set_mode(mode)\n"

func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() != 3: return fail("usage: OUT.pck GAME.exe EXTRAS_DIR")
	if not ProjectSettings.load_resource_pack(a[1]): return fail("no game data found in " + a[1])
	if not FileAccess.file_exists("res://" + STEAM_GD): return fail("not Buckshot Roulette: scripts/Steam.gd missing")
	var src := FileAccess.get_file_as_string("res://" + STEAM_GD)
	if not src.contains("var appid : int = 2835570"): return fail("not Buckshot Roulette (wrong Steam app id)")
	if src.count(ANCHOR) != 1: return fail("this game version differs from the one the ownership patch targets")
	var extras := a[2]
	var out := FileAccess.open(extras.path_join(STEAM_GD), FileAccess.WRITE)
	if out == null:
		DirAccess.make_dir_recursive_absolute(extras.path_join("scripts"))
		out = FileAccess.open(extras.path_join(STEAM_GD), FileAccess.WRITE)
	out.store_string(src.replace(ANCHOR, CHECK))
	out.close()
	# files in extras replace the originals
	var da := DirAccess.open(extras)
	var stack := [""]
	while stack:
		var rel: String = stack.pop_back()
		var d := DirAccess.open(extras.path_join(rel)); d.include_hidden = true
		for f in d.get_files(): skip[rel.path_join(f) if rel != "" else f] = true
		for s in d.get_directories(): stack.append(rel.path_join(s) if rel != "" else s)
	# Godot 4.4+ compatibility: Resources may not export Node fields (these are never set),
	# and the global class list needs the is_abstract/is_tool keys.
	var item := "multiplayer/scripts/user scripts/MP_ItemResource_User.gd"
	var item_src := FileAccess.get_file_as_string("res://" + item)
	for field in ["R_assigned_hand", "R_assigned_mesh", "L_assigned_hand", "L_assigned_mesh"]:
		item_src = item_src.replace("@export var %s : Node3D" % field, "var %s : Node3D" % field)
	write(extras, item, item_src)
	var cache := FileAccess.get_file_as_string("res://.godot/global_script_class_cache.cfg")
	if not cache.contains("is_tool"):
		cache = cache.replace('"icon": "",', '"icon": "",\n"is_abstract": false,\n"is_tool": false,')
	write(extras, ".godot/global_script_class_cache.cfg", cache)
	for f in [item, ".godot/global_script_class_cache.cfg"]: skip[f] = true
	var options_path := "scripts/OptionsManager.gd"
	var options := patch_window_modes(FileAccess.get_file_as_string("res://" + options_path))
	if options.is_empty(): return fail("unsupported window settings: " + options_path)
	write(extras, options_path, options)
	skip[options_path] = true
	# Fill Screen: the mouse ray must use the same camera angle the picture uses, and the
	# camera transitions must start from the game's own angle, not the converted one.
	var ray_anchor := "\tvar start = project_ray_origin(mouse)\n\tvar end = project_position(mouse, 20000)\n"
	var ray_fix := "\tvar mac = get_node_or_null(\"/root/MacScreenFit\") if is_inside_tree() else null\n\tvar ray_mouse = mouse\n\tif mac:\n\t\tmac._fit_camera(self)\n\t\tif controller_overriding: ray_mouse = mac.controller_ray_position(mouse, get_viewport().get_visible_rect().size)\n\tvar start = project_ray_origin(ray_mouse)\n\tvar end = project_position(ray_mouse, 20000)\n"
	var patches := [
		["scripts/MouseRaycast.gd", ray_anchor, ray_fix, 1],
		["multiplayer/scripts/user scripts/MP_MouseRaycast.gd", ray_anchor, ray_fix, 1],
		["scripts/CameraManager.gd", "currentFov = cam.fov", "currentFov = cam.get_meta(\"mac_fov\", cam.fov)", 3],
		["multiplayer/scripts/user scripts/MP_CameraManager.gd", "currentFov = cam.fov", "currentFov = cam.get_meta(\"mac_fov\", cam.fov)", 1],
	]
	for p in patches:
		var text := FileAccess.get_file_as_string("res://" + p[0])
		if text.count(p[1]) != p[3]: return fail("this game version differs from the one the Fill Screen patch targets: " + p[0])
		write(extras, p[0], text.replace(p[1], p[2]))
		skip[p[0]] = true
	if packer.pck_start(a[0]) != OK: return fail("cannot create " + a[0])
	walk("res://", "", true)
	walk(extras, "", false)
	var err := packer.flush()
	if err != OK: return fail("flush failed: %d" % err)
	print("REPACK OK files=", count)
	quit()
