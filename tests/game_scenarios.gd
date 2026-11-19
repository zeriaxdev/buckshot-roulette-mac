extends SceneTree

func _initialize():
	var args := OS.get_cmdline_user_args()
	if OS.get_user_data_dir().get_file() != args[0]:
		printerr("Refusing to use non-test saves"); quit(1); return
	Engine.max_fps = 120
	seed(42)
	_run.call_deferred()

func _run():
	var args := OS.get_cmdline_user_args()
	if "mute" in args: AudioServer.set_bus_mute(0, true)
	# The extracted fixture has SDK startup disabled; the installed app is untouched.
	root.get_node("GlobalVariables").using_steam = false
	TranslationServer.set_locale("EN")
	var placeholder := Node.new()
	root.add_child(placeholder); current_scene = placeholder
	var scene = load("res://scenes/main.tscn").instantiate()
	var rm = scene.get_node("standalone managers/round manager")
	# Start with fresh test state, then exercise the real intro and round setup.
	for node in scene.find_children("*", "Node", true, false):
		if node.has_method("LoadGame") and node.has_method("SaveGame"): node.isMainMenu = true
	rm.playerData.hasSignedWaiver = true
	rm.playerData.hasReadIntroduction = true
	rm.playerData.hasReadItemDistributionIntro = true
	rm.playerData.hasReadItemDistributionIntro2 = true
	rm.playerData.seenHint = true
	rm.playerData.currentBatchIndex = 0
	rm.playerData.playerEnteringFromDeath = false
	rm.playerData.enteringFromTrueDeath = false
	root.add_child.call_deferred(scene)
	await scene.ready
	current_scene = scene; placeholder.queue_free()
	Engine.time_scale = 4
	var intro
	for node in scene.find_children("*", "Node", true, false):
		if node.has_method("Interaction_BackroomDoor"): intro = node
	await create_timer(6, false).timeout
	intro.Interaction_BathroomDoor()
	await create_timer(5.5, false).timeout
	intro.Interaction_BackroomDoor()
	var playable := false
	for _i in range(600):
		await create_timer(.1, false).timeout
		if rm.roundArray.size() == 0 or rm.shellSpawner.sequenceArray.size() < 2 or rm.camera.activeSocket != "home": continue
		for branch in rm.perm.interactionBranchArray:
			if branch.interactionAlias == "shotgun" and branch.interactionAllowed: playable = true
		if playable: break
	if not playable: return fail("Game did not reach a playable turn")
	var original_id = scene.get_instance_id()
	rm.health_player = int(args[2])
	rm.health_opponent = 4
	rm.currentShotgunDamage = int(args[3])
	rm.wireIsCut_player = args[1] == "heaven"
	rm.playerData.currentBatchIndex = 2 if args[1] == "heaven" else 0
	rm.shellSpawner.sequenceArray[0] = "live"
	rm.cursor.SetCursor(false, false)
	rm.perm.SetInteractionPermissions(false)
	await rm.dealerAI.GrabShotgun()
	print("SCENARIO shot health=", rm.health_player, " damage=", rm.currentShotgunDamage, " target=", args[1])
	rm.dealerAI.Shoot("player")
	if args[1] == "escape": Input.action_press("exit game")
	var matched := false
	for _i in range(300):
		await create_timer(.1).timeout
		if current_scene == null: continue
		var path = current_scene.scene_file_path
		if args[1] == "heaven": matched = path == "res://scenes/heaven.tscn"
		elif args[1] == "death": matched = path == "res://scenes/main.tscn" and current_scene.get_instance_id() != original_id
		elif args[1] == "escape": matched = path == "res://scenes/menu.tscn"
		elif args[1] == "alive" and current_scene.get_instance_id() == original_id:
			matched = rm.health_player == maxi(0, int(args[2]) - int(args[3])) and rm.cursor.cursor_visible and not rm.dealerAI.dealerHoldingShotgun
		if matched: break
	Input.action_release("exit game")
	if not matched: return fail("Expected outcome not reached: " + args[1])
	await create_timer(.5).timeout
	print("SCENARIO PASS ", args[1])
	quit()

func fail(message: String):
	printerr(message)
	quit(1)
