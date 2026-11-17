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
	if packer.pck_start(a[0]) != OK: return fail("cannot create " + a[0])
	walk("res://", "", true)
	walk(extras, "", false)
	var err := packer.flush()
	if err != OK: return fail("flush failed: %d" % err)
	print("REPACK OK files=", count)
	quit()
