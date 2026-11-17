extends SceneTree

func _initialize():
	var args := OS.get_cmdline_user_args()
	if OS.get_user_data_dir().get_file() != args[0]:
		printerr("Refusing to use non-test saves"); quit(1); return
	seed(42)
	_run.call_deferred()

func _run():
	var args := OS.get_cmdline_user_args()
	# Startup still checks the owner's Steam licence; scripted deaths must not award achievements.
	root.get_node("GlobalVariables").using_steam = false
	# A placeholder keeps the game's scene-notification script valid during _ready.
	var placeholder := Node.new()
	root.add_child(placeholder)
	current_scene = placeholder
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	placeholder.queue_free()
	var rm = scene.get_node("standalone managers/round manager")
	rm.health_player = int(args[2])
	rm.health_opponent = 4
	rm.currentShotgunDamage = int(args[3])
	rm.wireIsCut_player = args[1] == "heaven"
	rm.playerData.currentBatchIndex = 2
	rm.shellSpawner.sequenceArray.assign(["live"])
	print("SCENARIO shot health=", rm.health_player, " damage=", rm.currentShotgunDamage, " target=",args[1])
	rm.dealerAI.Shoot("player")
	await create_timer(8).timeout
	var expected := "res://scenes/heaven.tscn" if args[1] == "heaven" else "res://scenes/main.tscn"
	if current_scene == null or current_scene.scene_file_path != expected:
		printerr("Wrong scene after lethal shot"); quit(1); return
	print("SCENARIO PASS ", args[1])
	quit()
