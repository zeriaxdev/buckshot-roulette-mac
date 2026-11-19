# Asset-free resize regression: loading/death images must conceal the menu after notch toggles.
extends SceneTree

func _initialize():
	_run.call_deferred()

func _run():
	root.content_scale_size = Vector2i(960, 540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(960, 602)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var image := Image.create(960, 540, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	var overlay := TextureRect.new()
	overlay.texture = ImageTexture.create_from_image(image)
	overlay.size = Vector2(960, 540)
	layer.add_child(overlay)
	var helper = load(OS.get_cmdline_user_args()[0]).new()
	root.add_child(helper)
	helper.set_process(false)
	helper.fill = true
	for height in [602, 624, 600, 624]:
		root.size = Vector2i(960, height)
		helper._apply()
		for _i in 3: await process_frame
		var top := overlay.get_node("mac_band0") as ColorRect
		var bottom := overlay.get_node("mac_band1") as ColorRect
		var top_rect := top.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, top.size)
		var bottom_rect := bottom.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, bottom.size)
		var picture := overlay.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, overlay.size)
		var visible := root.get_visible_rect().size
		if not is_zero_approx(top_rect.position.y) or not is_equal_approx(top_rect.end.y, picture.position.y) or not is_equal_approx(bottom_rect.position.y, picture.end.y) or not is_equal_approx(bottom_rect.end.y, visible.y):
			printerr("FAIL overlay coverage height=", height, " top=",top_rect," image=",picture," bottom=",bottom_rect," viewport=",visible)
			quit(1); return
		if overlay.size != Vector2(960, 540):
			printerr("Loading image was stretched"); quit(1); return
	helper.fill = false
	helper._apply()
	for _i in 3: await process_frame
	if overlay.get_node("mac_band0").visible or overlay.get_node("mac_band1").visible:
		printerr("Black filler remains after Fill Screen is off"); quit(1); return
	print("PASS fullscreen image coverage across four resizes and Fill Screen off")
	quit()
