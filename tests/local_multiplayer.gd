# Runs only inside the owner's disposable, SDK-disabled multiplayer fixture.
extends SceneTree

func _initialize():
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].begins_with("buckshot-local-mp-") or OS.get_user_data_dir().get_file() != args[0]:
		printerr("Refusing non-test saves"); quit(1); return
	_run.call_deferred()

func _run():
	var smoke := "smoke" in OS.get_cmdline_user_args()
	seed(42)
	Engine.max_fps = 60
	if smoke: Engine.time_scale = 3.0
	var globals = root.get_node("GlobalVariables")
	globals.mp_debugging = true
	globals.mp_debug_keys_enabled = false
	TranslationServer.set_locale("EN")
	for key in ["MP_REMOTE", "MP_JAMMER", "MP_SHOTGUN DESC", "MP_UI MATCH RESULTS", "MP_UI EXITING IN"]:
		if tr(key) == key:
			printerr("Missing multiplayer translation: ", key); quit(1); return
	globals.skipping_intro = true
	globals.printing_packets = false
	globals.active_match_customization_dictionary = globals.debug_match_customization.duplicate(true)
	for round_data in globals.active_match_customization_dictionary.round_property_array:
		round_data.starting_health = 1 if smoke else 2
		for sequence in round_data.shell_load_properties:
			sequence.number_of_items = 1
			sequence.number_of_lives = 2
			sequence.number_of_blanks = 0 if smoke else 1
	root.get_node("GlobalSteam").STEAM_ID = 1234
	var scene = load("res://multiplayer/scenes/mp_main.tscn").instantiate()
	root.add_child.call_deferred(scene)
	await scene.ready
	current_scene = scene
	root.mode = Window.MODE_WINDOWED
	root.title = "Buckshot Local Multiplayer Test"
	var helper = load("res://mac/screen_fit.gd").new()
	root.add_child(helper)
	if helper.has_method("_apply"):
		helper.fps_limit = 60; helper._apply()
	Engine.max_fps = 60
	var handler
	for node in scene.find_children("*", "Node", true, false):
		if node.has_method("SetupInstances_test"): handler = node; break
	if handler == null or handler.instance_property_array.size() != 4:
		printerr("Local test did not create four seats"); quit(1); return
	var layer := CanvasLayer.new()
	layer.layer = 250; layer.set_meta("mac_own", true)
	var label := Label.new()
	label.text = "LOCAL TEST: your seat is MIKE; other seats act automatically. No Steam network or achievements."
	label.position = Vector2(10, 8)
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label); root.add_child(layer)
	print("LOCAL TEST READY: four seats; isolated saves; Steam transport disabled")
	var cooldown := {}
	var shot_at := -10.0
	var shots := 0
	var started := Time.get_ticks_msec()
	while is_instance_valid(scene) and scene.is_inside_tree():
		await create_timer(0.25, true, false, true).timeout
		if not is_instance_valid(scene) or not scene.is_inside_tree(): break
		var now := Time.get_ticks_msec() / 1000.0
		for player in handler.instance_property_array:
			if player.is_active and not smoke: continue
			var socket = player.socket_number
			if player.is_grabbing_items and now - cooldown.get(socket, -10.0) > 1.8:
				cooldown[socket] = now
				if not player.is_holding_item_to_place:
					player.item_manager.GrabItemRequest()
				else:
					for grid in 8:
						if player.intermediary.game_state.MAIN_inventory_by_socket[socket][grid] == {}:
							player.item_manager.PlaceItemRequest(grid); break
		var state = handler.intermediary.game_state
		for player in handler.instance_property_array:
			if player.is_active and not smoke: continue
			if state.MAIN_running_win_routine: continue
			if player.health_current > 0 and state.MAIN_active_current_turn_socket == player.socket_number and player.has_turn and not player.is_holding_shotgun and now - shot_at > 9.0:
				shot_at = now; shots += 1
				await _shoot_bot(player, handler, state)
				if not is_instance_valid(scene) or not scene.is_inside_tree(): break
		if not is_instance_valid(scene) or not scene.is_inside_tree(): break
		var health := []
		for player in handler.instance_property_array: health.append(player.health_current)
		if smoke and shots >= 3 and health.count(0) >= 3:
			print("PASS LOCAL MULTIPLAYER four seats, item distribution, shots, turns and death; health=", health)
			quit(); return
		if smoke and Time.get_ticks_msec() - started > 115000:
			printerr("FAIL LOCAL MULTIPLAYER deadline; shots=", shots); quit(1); return
	quit()


static func _live_targets(players: Array) -> Array:
	return players.filter(func(player): return is_instance_valid(player) and player.health_current > 0)


func _shoot_bot(player, handler, state) -> void:
	player.shotgun.PickupShotgun()
	await create_timer(4.0).timeout
	if not is_instance_valid(player) or not player.is_inside_tree() or not is_instance_valid(state): return
	if player.health_current <= 0 or not player.has_turn or not player.is_holding_shotgun: return
	if state.MAIN_running_win_routine or state.MAIN_active_current_turn_socket != player.socket_number: return
	var targets := _live_targets(handler.instance_property_array)
	if targets.is_empty(): return
	var target = targets[randi_range(0, targets.size() - 1)]
	print("LOCAL_SHOT ", JSON.stringify({"unix_time": Time.get_unix_time_from_system(),
		"from_socket": player.socket_number, "target_socket": target.socket_number,
		"target_health": target.health_current, "alive_sockets": targets.map(func(p): return p.socket_number)}))
	player.shotgun.Shoot(null, target.socket_number)
