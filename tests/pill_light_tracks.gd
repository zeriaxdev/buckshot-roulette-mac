extends SceneTree

const RANGE := ^"../backroom main parent/light main door3 LS:omni_range"
const CAMERA := ^"../Camera:fov"


func add_value_track(animation: Animation, path: NodePath, value: float) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.track_insert_key(track, 0, value)


func _initialize() -> void:
	var helper = load(OS.get_cmdline_user_args()[0]).new()
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	var close_up := Animation.new()
	add_value_track(close_up, RANGE, 5.0)
	add_value_track(close_up, CAMERA, 60.0)
	add_value_track(close_up, RANGE, 25.0)
	add_value_track(close_up, CAMERA, 70.0)
	var other := close_up.duplicate() as Animation
	library.add_animation("camera check pills", close_up)
	library.add_animation("another animation", other)
	player.add_animation_library("", library)

	helper._fit(player)
	helper._fit(player)
	var passed: bool = close_up.get_track_count() == 3 and close_up.track_get_path(0) == CAMERA \
		and close_up.track_get_path(1) == RANGE and close_up.track_get_key_value(1, 0) == 25.0 \
		and close_up.track_get_path(2) == CAMERA and other.get_track_count() == 4
	player.free()
	helper.free()
	if not passed:
		printerr("FAIL pill light: expected only the first close-up range track removed")
		quit(1)
		return
	print("PASS pill light: last range track retained; other tracks unchanged")
	quit()
