extends SceneTree

func _initialize():
	var patches = load(OS.get_cmdline_user_args()[0])
	var sample := "func settings():\n\tDisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)\n\tDisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)\n"
	var fixed: String = patches.patch_window_modes(sample)
	if fixed.is_empty() or fixed.count("_mac_window_mode(") != 3 or fixed.count("DisplayServer.window_set_mode(") != 1:
		printerr("FAIL window-mode delegation"); quit(1); return
	if not patches.patch_window_modes("changed source").is_empty() or not patches.patch_window_modes(fixed).is_empty():
		printerr("FAIL unsafe window patch accepted"); quit(1); return
	print("PASS window patch: both calls delegated; fallback retained; unknown and already-patched source rejected")
	quit()
