# Asset-free native display test, launched by scripts/test_native_window.py.
extends SceneTree
func _initialize():
    var args := OS.get_cmdline_user_args()
    if args.size() < 2 or not args[1].begins_with("buckshot-native-") or OS.get_user_data_dir().get_file() != args[1]:
        printerr("Refusing non-test saves");quit(1);return
    FileAccess.open("res://probe.pid",FileAccess.WRITE).store_string(str(OS.get_process_id()))
    _run.call_deferred()
func _run():
    var color := ColorRect.new();color.color=Color(.1,.35,.8);color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(color)
    root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,540)
    var original_size=root.size
    print("ORIGINAL SIZE ",original_size)
    var helper=load(OS.get_cmdline_user_args()[0]).new()
    root.add_child(helper)
    helper.fill=true;helper.include_notch=true;helper.fps_limit=60
    helper.set_game_windowed(false);helper._save()
    if not await wait_for_mode(true):return
    await create_timer(.2).timeout
    var image=root.get_texture().get_image()
    print("INCLUDED TOP PIXELS ",image.get_pixel(100,10)," ",image.get_pixel(image.get_width()-100,10))
    if image.get_pixel(100,10).b<.5 or image.get_pixel(image.get_width()-100,10).b<.5:printerr("Top row not drawn");quit(1);return
    helper.include_notch=false;helper._save()
    if not await wait_for_mode(false):return
    helper.include_notch=true;helper._save()
    if not await wait_for_mode(true):return
    helper.set_game_windowed(true)
    for _i in 20:
        await create_timer(.1).timeout
        if root.mode==Window.MODE_WINDOWED and not root.borderless and root.size==original_size:break
    if root.borderless or root.size!=original_size:printerr("Windowed mode did not restore actual=",root.size," expected=",original_size," saved=",helper._windowed_rect," mode=",root.mode," borderless=",root.borderless);quit(1);return
    helper.set_game_windowed(false)
    helper.include_notch=false;helper._save()
    await create_timer(.05).timeout
    helper.include_notch=true;helper._save()
    if not await wait_for_mode(true):return
    helper.set_game_windowed(true)
    for _i in 20:
        await create_timer(.1).timeout
        if root.mode==Window.MODE_WINDOWED and not root.borderless and root.size==original_size:break
    if root.borderless or root.size!=original_size:printerr("Windowed mode failed after rapid toggles");quit(1);return
    helper.queue_free()
    await process_frame
    root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN
    helper=load(OS.get_cmdline_user_args()[0]).new()
    root.add_child(helper)
    if not await wait_for_mode(true):return
    helper.set_game_windowed(true)
    for _i in 20:
        await create_timer(.1).timeout
        if root.mode==Window.MODE_WINDOWED and not root.borderless and root.size==original_size:break
    if root.borderless or root.size!=original_size:printerr("Windowed mode failed after helper startup");quit(1);return
    print("PASS NOTCH on/off/on, rapid toggles, helper startup, top pixels and original Windowed size ",root.size)
    quit()
func wait_for_mode(included):
    for _i in 35:
        await create_timer(.1,true,false,true).timeout
        var helper=root.get_node("MacScreenFit")
        if helper._switching_window:continue
        if included and root.borderless and root.position==DisplayServer.screen_get_position(root.current_screen) and root.size==DisplayServer.screen_get_size(root.current_screen):
            print("INCLUDED position=",root.position," size=",root.size," saved=",helper._windowed_rect);return true
        # AppKit's fullscreen separator can add one point beyond the reported safe area.
        var safe_size=DisplayServer.get_display_safe_area().size
        var separator=maxi(1,int(DisplayServer.screen_get_scale(root.current_screen)))
        if not included and root.mode>=Window.MODE_FULLSCREEN and not root.borderless and root.size.x==safe_size.x and absi(root.size.y-safe_size.y)<=separator:
            print("EXCLUDED position=",root.position," size=",root.size);return true
    printerr("Expected notch mode not reached included=",included," position=",root.position," size=",root.size," mode=",root.mode," borderless=",root.borderless," safe=",DisplayServer.get_display_safe_area()," switching=",root.get_node("MacScreenFit")._switching_window," native_transition=",OS.has_environment("BUCKSHOT_WINDOW_TRANSITION"))
    quit(1);return false
