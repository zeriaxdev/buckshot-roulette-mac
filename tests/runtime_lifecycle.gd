extends SceneTree

func _initialize():
	_run.call_deferred()

func _run():
	var args := OS.get_cmdline_user_args()
	var patches = load(args[1])
	if not patches.patch_timer_loop("changed source", "delay", 2).is_empty():
		printerr("Unexpected patch acceptance"); quit(1); return
	for kind in ["BlinkerBranch", "BpmLight", "PartitionBranch"]:
		var text := FileAccess.get_file_as_string(args[0].path_join("scripts/" + kind + ".gd"))
		var expected := 1 if kind == "PartitionBranch" else 2
		var delay := "d" if kind == "PartitionBranch" else "delay"
		var guarded := "\t\tawait get_tree().create_timer(%s, false).timeout\n\t\tif not is_inside_tree(): return\n" % delay
		var already_fixed := text.count(guarded) == expected
		if args[2] == "baseline" and already_fixed:
			printerr("Baseline requires an app built before the lifecycle fixes"); quit(1); return
		if args[2] != "baseline" and not already_fixed:
			text = patches.patch_timer_loop(text, "d" if kind == "PartitionBranch" else "delay", 1 if kind == "PartitionBranch" else 2)
		if text.is_empty():
			printerr("Patch did not match"); quit(1); return
		if args[2] == "prepare":
			var file := FileAccess.open(args[0].path_join("scripts/" + kind + ".gd"), FileAccess.WRITE)
			file.store_string(text); file.close()
			continue
		var script := GDScript.new()
		script.source_code = text
		if script.reload() != OK:
			printerr("Script did not compile"); quit(1); return
		for phase in [0.01, 0.02]:
			var parent: Node3D = Label3D.new() if kind == "PartitionBranch" else MeshInstance3D.new()
			if parent is MeshInstance3D: parent.mesh = BoxMesh.new()
			var light = script.new()
			if kind == "BlinkerBranch":
				light.delay_range1 = 0.01; light.delay_range2 = 0.01
				light.mat_1 = StandardMaterial3D.new(); light.mat_2 = StandardMaterial3D.new()
			elif kind == "BpmLight":
				light.delay = 0.01
				var anim := AnimationPlayer.new()
				var lib := AnimationLibrary.new()
				lib.add_animation("hit", Animation.new())
				anim.add_animation_library("", lib)
				parent.add_child(anim); light.animator = anim
			else:
				light.d = 0.01
			parent.add_child(light)
			if kind == "PartitionBranch": parent.add_child(AudioStreamPlayer2D.new())
			# Earlier timer detaches the scene before the loop resumes in the same timer pass.
			create_timer(phase).timeout.connect(func():
				root.remove_child(parent)
				parent.call_deferred("free"))
			root.add_child(parent)
			if kind == "BpmLight": light.BeginMainLoop()
			if kind == "PartitionBranch": light.Loop(true)
			await create_timer(0.08).timeout
			print("CASE COMPLETE lifecycle ", kind, " phase=", phase)
	if args[2] == "prepare":
		for path in patches.SCENE_SWITCHES:
			var full_path := args[0].path_join(path)
			var original := FileAccess.get_file_as_string(full_path)
			var already_fixed: bool = original.count("get_tree().change_scene_to_file.call_deferred(") == patches.SCENE_SWITCHES[path] and not original.contains("get_tree().change_scene_to_file(")
			var fixed: String = original if already_fixed else patches.patch_scene_changes(original, patches.SCENE_SWITCHES[path])
			if fixed.is_empty():
				printerr("Scene patch did not match: ", path); quit(1); return
			var file := FileAccess.open(full_path, FileAccess.WRITE)
			file.store_string(fixed); file.close()
	print("SCENARIO PASS lifecycle")
	quit()
