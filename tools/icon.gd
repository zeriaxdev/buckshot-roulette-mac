# Makes a macOS-style app icon from the game's own icon, read from the owner's copy:
#   godot --headless --script icon.gd -- GAME.exe OUT.png
# 1024x1024 canvas, rounded square body of 824 px with ~185 px corners (Apple's icon grid).
extends SceneTree

const SIZE := 1024
const BODY := 824
const RADIUS := 185.0

func _initialize():
	var a := OS.get_cmdline_user_args()
	if not ProjectSettings.load_resource_pack(a[0]):
		printerr("ICON ERROR: no game data"); quit(1); return
	var tex: Texture2D = load("res://misc/icon1.png")
	if tex == null:
		printerr("ICON ERROR: game icon not found"); quit(1); return
	var art := tex.get_image()
	art.decompress()
	art.convert(Image.FORMAT_RGBA8)
	var inset := int(BODY * 0.9)  # small black margin around the shell, like the hand-made icon
	art.resize(inset, inset, Image.INTERPOLATE_LANCZOS)
	var body := Image.create(BODY, BODY, false, Image.FORMAT_RGBA8)
	body.fill(Color.BLACK)
	body.blend_rect(art, Rect2i(0, 0, inset, inset), Vector2i((BODY - inset) / 2, (BODY - inset) / 2))
	art = body
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var off := (SIZE - BODY) / 2
	var half := BODY / 2.0
	var inner := half - RADIUS
	for y in BODY:
		for x in BODY:
			# signed distance to the rounded square, for an anti-aliased edge
			var dx: float = max(abs(x + 0.5 - half) - inner, 0.0)
			var dy: float = max(abs(y + 0.5 - half) - inner, 0.0)
			var alpha: float = clamp(RADIUS - sqrt(dx * dx + dy * dy) + 0.5, 0.0, 1.0)
			if alpha > 0.0:
				var c := art.get_pixel(x, y)
				c.a *= alpha
				out.set_pixel(off + x, off + y, c)
	out.save_png(a[1])
	print("ICON OK")
	quit()
