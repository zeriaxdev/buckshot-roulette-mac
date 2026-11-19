extends SceneTree
func _initialize():
	_run.call_deferred()
func _run():
	var helper = load(OS.get_cmdline_user_args()[0]).new()
	helper.fill = true
	var reference := SubViewport.new()
	reference.size = Vector2i(960, 540)
	var camera := Camera3D.new()
	camera.fov = 75
	reference.add_child(camera); root.add_child(reference)
	var expanded := SubViewport.new()
	var fitted := Camera3D.new()
	fitted.fov = 75
	expanded.add_child(fitted); root.add_child(expanded)
	var comparisons := 0
	for size in [Vector2i(960, 540), Vector2i(960, 600), Vector2i(960, 624), Vector2i(1200, 600)]:
		expanded.size = size
		helper._fit_camera(fitted)
		for point in [Vector2(240, 400), Vector2(720, 400), Vector2(480, 270), Vector2(100, 80)]:
			var mapped = helper.controller_ray_position(point, Vector2(size)) if helper.has_method("controller_ray_position") else point
			if camera.project_ray_normal(point).distance_to(fitted.project_ray_normal(mapped)) > 0.00001:
				printerr("FAIL controller ray ",size," point=",point); quit(1); return
			comparisons += 1
	helper.free()
	print("PASS controller ray comparisons=",comparisons)
	quit()
