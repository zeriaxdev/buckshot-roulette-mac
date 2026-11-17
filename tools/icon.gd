# Makes a macOS-style app icon from the game's own 512 px icon, read from the owner's copy:
#   godot --headless --script icon.gd -- GAME.exe OUT.png
# Apple's grid: 1024 canvas, 824 px body with continuous ("squircle") corners, soft shadow
# below. The art sits 80 px inside the body edge, scaled with crisp pixels.
extends SceneTree

const SIZE := 1024
const BODY := 824
const GAP := 80
const N := 5.0  # superellipse exponent, close to Apple's continuous corners

func shape(x: float, y: float) -> float:
	# < 1 inside the body, > 1 outside; (x, y) relative to the body's top-left
	var h := BODY / 2.0
	return pow(abs(x - h) / h, N) + pow(abs(y - h) / h, N)

func coverage(x: int, y: int) -> float:
	var f := shape(x + 0.5, y + 0.5)
	if f < 0.97: return 1.0
	if f > 1.03: return 0.0
	var hits := 0
	for sy in 4:
		for sx in 4:
			if shape(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0) <= 1.0: hits += 1
	return hits / 16.0

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
	var inner := BODY - 2 * GAP
	art.resize(inner, inner, Image.INTERPOLATE_NEAREST)
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var off := (SIZE - BODY) / 2
	var h := BODY / 2.0
	# shadow: the body shape moved down 2 px, fading out over 16 px (matches macOS app icons)
	for y in range(off, SIZE):
		for x in range(off - 20, off + BODY + 20):
			var f := shape(x - off + 0.5, y - off - 2 + 0.5)
			if f <= 1.0:
				out.set_pixel(x, y, Color(0, 0, 0, 0.32))
			else:
				var d := (pow(f, 1.0 / N) - 1.0) * h
				if d < 16.0: out.set_pixel(x, y, Color(0, 0, 0, 0.32 * (1.0 - d / 16.0)))
	for y in BODY:
		for x in BODY:
			var cov := coverage(x, y)
			if cov <= 0.0: continue
			var c := Color.BLACK
			if x >= GAP and y >= GAP and x < GAP + inner and y < GAP + inner:
				c = art.get_pixel(x - GAP, y - GAP)
				c = Color.BLACK.lerp(Color(c.r, c.g, c.b), c.a)
			var under := out.get_pixel(off + x, off + y)
			out.set_pixel(off + x, off + y, under.blend(Color(c.r, c.g, c.b, cov)))
	out.save_png(a[1])
	print("ICON OK")
	quit()
