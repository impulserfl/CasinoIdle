class_name Icons
extends RefCounted

## Unique procedural icon set (Midnight Gold).
## Every name draws its own geometric artwork at 128x128 so the browser build
## never depends on missing PNGs, and every glyph is purpose-built for this game.
## PNG files in assets/sprites still override when present.

const DIR := "res://assets/sprites/"
const SIZE := 128

static var _cache: Dictionary = {}

const GOLD := Color("f0c14b")
const GOLD_D := Color("a87820")
const GOLD_L := Color("ffe9a8")
const GREEN := Color("3dd68c")
const RED := Color("ef4a6a")
const BLUE := Color("5aa8ff")
const PURPLE := Color("b06cff")
const CYAN := Color("3de0e0")
const ORANGE := Color("ff8f3a")
const PINK := Color("ff6ba8")
const WHITE := Color("f2efe6")
const INK := Color("0c0a12")
const PANEL := Color("1a1628")
const DARK := Color("12101c")


static func tex(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	if _cache.has(icon_name):
		return _cache[icon_name]
	var path := DIR + icon_name + ".png"
	var found: Texture2D = null
	if ResourceLoader.exists(path):
		found = ResourceLoader.load(path) as Texture2D
	if found == null:
		found = _generate(icon_name)
	_cache[icon_name] = found
	return found


static func has(icon_name: String) -> bool:
	return tex(icon_name) != null


static func rect(icon_name: String, px: int, tint: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(icon_name)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	return r


static func fill(icon_name: String, tint: Color = Color.WHITE) -> TextureRect:
	var r := rect(icon_name, 0, tint)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return r


static func _generate(name: String) -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_icon(img, name)
	return ImageTexture.create_from_image(img)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.set_pixel(x, y, c)


static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	var d := img.get_pixel(x, y)
	var a := c.a + d.a * (1.0 - c.a)
	if a <= 0.0:
		return
	var out := Color(
		(c.r * c.a + d.r * d.a * (1.0 - c.a)) / a,
		(c.g * c.a + d.g * d.a * (1.0 - c.a)) / a,
		(c.b * c.a + d.b * d.a * (1.0 - c.a)) / a,
		a)
	img.set_pixel(x, y, out)


static func _fill_circle(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	var rr := r * r
	var x0 := int(cx - r) - 1
	var y0 := int(cy - r) - 1
	var x1 := int(cx + r) + 1
	var y1 := int(cy + r) + 1
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) + 0.5 - cx
			var dy := float(y) + 0.5 - cy
			var d2 := dx * dx + dy * dy
			if d2 <= rr:
				var edge := clampf((r - sqrt(d2)) * 1.5, 0.0, 1.0)
				var col := c
				col.a *= edge
				_blend(img, x, y, col)


static func _ring(img: Image, cx: float, cy: float, r: float, thickness: float, c: Color) -> void:
	var r_out := r + thickness * 0.5
	var r_in := maxf(0.0, r - thickness * 0.5)
	var x0 := int(cx - r_out) - 1
	var y0 := int(cy - r_out) - 1
	var x1 := int(cx + r_out) + 1
	var y1 := int(cy + r_out) + 1
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) + 0.5 - cx
			var dy := float(y) + 0.5 - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist >= r_in and dist <= r_out:
				var edge := 1.0 - absf(dist - r) / (thickness * 0.5 + 0.001)
				edge = clampf(edge, 0.0, 1.0)
				var col := c
				col.a *= edge
				_blend(img, x, y, col)


static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			_blend(img, x, y, c)


static func _round_rect(img: Image, x0: int, y0: int, x1: int, y1: int, rad: int, c: Color) -> void:
	_rect(img, x0 + rad, y0, x1 - rad, y1, c)
	_rect(img, x0, y0 + rad, x1, y1 - rad, c)
	_fill_circle(img, x0 + rad, y0 + rad, rad, c)
	_fill_circle(img, x1 - rad, y0 + rad, rad, c)
	_fill_circle(img, x0 + rad, y1 - rad, rad, c)
	_fill_circle(img, x1 - rad, y1 - rad, rad, c)


static func _line(img: Image, x0: float, y0: float, x1: float, y1: float, thickness: float, c: Color) -> void:
	var steps := int(maxi(1, int(Vector2(x1 - x0, y1 - y0).length())))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := lerpf(x0, x1, t)
		var y := lerpf(y0, y1, t)
		_fill_circle(img, x, y, thickness * 0.5, c)


static func _poly(img: Image, pts: Array, c: Color) -> void:
	# Simple scan-fill bounding box
	var min_x := SIZE
	var min_y := SIZE
	var max_x := 0
	var max_y := 0
	for p in pts:
		min_x = mini(min_x, int(p.x))
		min_y = mini(min_y, int(p.y))
		max_x = maxi(max_x, int(p.x))
		max_y = maxi(max_y, int(p.y))
	for y in range(min_y, max_y + 1):
		var nodes: Array[float] = []
		var n := pts.size()
		for i in range(n):
			var p1: Vector2 = pts[i]
			var p2: Vector2 = pts[(i + 1) % n]
			if (p1.y < float(y) and p2.y >= float(y)) or (p2.y < float(y) and p1.y >= float(y)):
				var t := (float(y) - p1.y) / (p2.y - p1.y + 0.0001)
				nodes.append(p1.x + t * (p2.x - p1.x))
		nodes.sort()
		var i := 0
		while i + 1 < nodes.size():
			for x in range(int(nodes[i]), int(nodes[i + 1]) + 1):
				_blend(img, x, y, c)
			i += 2


static func _star(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	var pts: Array = []
	for i in range(10):
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(Vector2(cx + cos(ang) * rad, cy + sin(ang) * rad))
	_poly(img, pts, c)


static func _draw_icon(img: Image, name: String) -> void:
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	match name:
		"chip":
			_fill_circle(img, c.x, c.y, 54, GOLD)
			_fill_circle(img, c.x, c.y, 38, PANEL)
			_fill_circle(img, c.x, c.y, 28, GOLD_L)
			for i in range(8):
				var a := float(i) * TAU / 8.0
				_line(img, c.x + cos(a) * 42, c.y + sin(a) * 42, c.x + cos(a) * 52, c.y + sin(a) * 52, 6, WHITE)
		"chip_gold":
			_fill_circle(img, c.x, c.y, 54, GOLD_L)
			_fill_circle(img, c.x, c.y, 38, GOLD_D)
			_fill_circle(img, c.x, c.y, 28, GOLD)
			for i in range(8):
				var a := float(i) * TAU / 8.0
				_line(img, c.x + cos(a) * 42, c.y + sin(a) * 42, c.x + cos(a) * 52, c.y + sin(a) * 52, 6, WHITE)
		"die_1", "die_2", "die_3", "die_4", "die_5", "die_6":
			_draw_die(img, int(name.substr(4)))
		"suit_heart":
			_fill_circle(img, 44, 50, 24, RED)
			_fill_circle(img, 84, 50, 24, RED)
			_poly(img, [Vector2(20, 55), Vector2(64, 110), Vector2(108, 55)], RED)
		"suit_diamond":
			_poly(img, [Vector2(64, 16), Vector2(108, 64), Vector2(64, 112), Vector2(20, 64)], RED)
		"suit_spade":
			_fill_circle(img, 44, 60, 22, INK)
			_fill_circle(img, 84, 60, 22, INK)
			_poly(img, [Vector2(22, 60), Vector2(64, 18), Vector2(106, 60)], INK)
			_rect(img, 58, 70, 70, 108, INK)
		"suit_club":
			_fill_circle(img, 64, 36, 20, INK)
			_fill_circle(img, 42, 64, 20, INK)
			_fill_circle(img, 86, 64, 20, INK)
			_rect(img, 58, 72, 70, 110, INK)
		"card_back":
			_round_rect(img, 18, 10, 110, 118, 10, Color("2a1450"))
			_ring(img, 64, 64, 40, 4, GOLD)
			_fill_circle(img, 64, 64, 16, GOLD)
		"game_slots":
			_round_rect(img, 16, 20, 112, 108, 12, PANEL)
			for i in range(3):
				var x := 24 + i * 30
				_round_rect(img, x, 32, x + 24, 96, 4, DARK)
				_fill_circle(img, x + 12, 58, 8, [RED, GOLD, GREEN][i])
		"game_roulette":
			_fill_circle(img, 64, 64, 54, GOLD_D)
			for i in range(16):
				var a0 := float(i) * TAU / 16.0
				var a1 := float(i + 1) * TAU / 16.0
				var col := RED if i % 2 == 0 else INK
				var pts: Array = [Vector2(64, 64)]
				for k in range(5):
					var a := lerpf(a0, a1, float(k) / 4.0)
					pts.append(Vector2(64 + cos(a) * 50, 64 + sin(a) * 50))
				_poly(img, pts, col)
			_fill_circle(img, 64, 64, 14, GOLD)
		"game_dice":
			_round_rect(img, 18, 40, 68, 90, 8, WHITE)
			_fill_circle(img, 34, 56, 5, INK)
			_fill_circle(img, 52, 74, 5, INK)
			_round_rect(img, 56, 24, 106, 74, 8, WHITE)
			_fill_circle(img, 68, 36, 5, INK)
			_fill_circle(img, 81, 49, 5, INK)
			_fill_circle(img, 94, 62, 5, INK)
		"game_scratch":
			_round_rect(img, 16, 16, 112, 112, 8, GOLD_L)
			for r in range(3):
				for col_i in range(3):
					var x := 24 + col_i * 30
					var y := 24 + r * 30
					_round_rect(img, x, y, x + 24, y + 24, 4, PANEL if (r + col_i) % 2 == 0 else GOLD)
		"game_hilo":
			_round_rect(img, 18, 28, 58, 100, 6, WHITE)
			_round_rect(img, 70, 28, 110, 100, 6, Color("321e5a"))
			_poly(img, [Vector2(90, 40), Vector2(102, 58), Vector2(78, 58)], GREEN)
			_poly(img, [Vector2(90, 88), Vector2(102, 70), Vector2(78, 70)], RED)
		"game_blackjack":
			_round_rect(img, 24, 24, 74, 96, 6, WHITE)
			_round_rect(img, 44, 34, 94, 106, 6, WHITE)
			_round_rect(img, 64, 44, 114, 116, 6, Color("321e5a"))
		"game_plinko":
			_fill_circle(img, 64, 18, 8, GOLD)
			for row in range(4):
				for col_i in range(row + 2):
					var x := 64 - (row + 1) * 12 + col_i * 24
					var y := 36 + row * 18
					_fill_circle(img, x, y, 4, WHITE)
			for i in range(7):
				_rect(img, 16 + i * 14, 104, 26 + i * 14, 120, [GOLD, ORANGE, PURPLE, GREEN, PANEL, GREEN, GOLD][i])
		"game_coinflip":
			_fill_circle(img, 64, 64, 50, GOLD)
			_fill_circle(img, 64, 64, 36, GOLD_L)
			_ring(img, 64, 64, 44, 4, GOLD_D)
		"game_wheel":
			for i in range(6):
				var a0 := float(i) * TAU / 6.0 - PI / 2.0
				var a1 := float(i + 1) * TAU / 6.0 - PI / 2.0
				var cols := [GREEN, BLUE, CYAN, PURPLE, ORANGE, GOLD]
				var pts: Array = [Vector2(64, 64)]
				for k in range(6):
					var a := lerpf(a0, a1, float(k) / 5.0)
					pts.append(Vector2(64 + cos(a) * 52, 64 + sin(a) * 52))
				_poly(img, pts, cols[i])
			_fill_circle(img, 64, 64, 12, WHITE)
		"game_crash":
			_line(img, 20, 100, 50, 80, 5, GREEN)
			_line(img, 50, 80, 80, 70, 5, GREEN)
			_line(img, 80, 70, 100, 40, 5, GREEN)
			_poly(img, [Vector2(100, 40), Vector2(112, 55), Vector2(95, 52)], RED)
			_line(img, 18, 18, 18, 110, 3, WHITE)
			_line(img, 18, 110, 110, 110, 3, WHITE)
		"game_keno":
			_round_rect(img, 14, 20, 114, 108, 8, PANEL)
			for i in range(16):
				var r := i / 4
				var col_i := i % 4
				var on := i in [1, 5, 8, 11, 14]
				_fill_circle(img, 30 + col_i * 24, 36 + r * 20, 8, GOLD if on else DARK)
		"game_baccarat":
			_fill_circle(img, 64, 64, 50, Color("0e2e22"))
			_ring(img, 64, 64, 50, 5, GOLD)
			_rect(img, 30, 56, 50, 76, WHITE)
			_rect(img, 78, 56, 98, 76, RED)
		"game_videopoker":
			for i in range(5):
				var x := 10 + i * 22
				_round_rect(img, x, 28, x + 18, 100, 3, WHITE)
		"game_war":
			_round_rect(img, 18, 24, 58, 100, 6, WHITE)
			_round_rect(img, 70, 24, 110, 100, 6, WHITE)
			_star(img, 64, 18, 12, GOLD)
		"game_pusher":
			_rect(img, 20, 20, 108, 40, PANEL)
			for i in range(5):
				_fill_circle(img, 32 + i * 16, 60, 8, GOLD)
			_rect(img, 20, 88, 108, 110, DARK)
			for i in range(3):
				_fill_circle(img, 44 + i * 18, 99, 6, GOLD_L)
		"game_claw":
			_rect(img, 58, 10, 70, 40, CYAN)
			_poly(img, [Vector2(40, 40), Vector2(64, 55), Vector2(88, 40), Vector2(78, 70), Vector2(64, 62), Vector2(50, 70)], WHITE)
			_fill_circle(img, 64, 95, 16, PINK)
		"game_darts":
			_fill_circle(img, 64, 64, 54, RED)
			_fill_circle(img, 64, 64, 42, WHITE)
			_fill_circle(img, 64, 64, 30, RED)
			_fill_circle(img, 64, 64, 18, GREEN)
			_fill_circle(img, 64, 64, 8, GOLD)
			_line(img, 64, 64, 100, 28, 3, CYAN)
		"game_fishing":
			_rect(img, 14, 72, 114, 114, Color("1e5a8c"))
			_line(img, 30, 20, 30, 72, 4, GOLD_D)
			_line(img, 30, 20, 90, 50, 2, WHITE)
			_poly(img, [Vector2(70, 80), Vector2(100, 92), Vector2(70, 104), Vector2(78, 92)], ORANGE)
		"save":
			_round_rect(img, 24, 20, 104, 108, 8, BLUE)
			_rect(img, 44, 20, 84, 48, PANEL)
			_fill_circle(img, 64, 76, 16, WHITE)
		"settings":
			_fill_circle(img, 64, 64, 22, GOLD)
			for i in range(8):
				var a := float(i) * TAU / 8.0
				_line(img, 64 + cos(a) * 28, 64 + sin(a) * 28, 64 + cos(a) * 48, 64 + sin(a) * 48, 10, GOLD)
			_fill_circle(img, 64, 64, 12, PANEL)
		"skill":
			_star(img, 64, 64, 48, PURPLE)
		"prestige":
			_star(img, 64, 58, 42, GOLD)
			_fill_circle(img, 64, 58, 12, GOLD_L)
		"stats":
			_rect(img, 24, 80, 44, 108, BLUE)
			_rect(img, 52, 50, 72, 108, GREEN)
			_rect(img, 80, 28, 100, 108, GOLD)
		"floor":
			_round_rect(img, 16, 28, 112, 100, 8, PANEL)
			_rect(img, 28, 42, 56, 68, GREEN)
			_rect(img, 72, 42, 100, 68, RED)
			_rect(img, 28, 76, 100, 90, GOLD)
		"trophy":
			_poly(img, [Vector2(36, 28), Vector2(92, 28), Vector2(86, 70), Vector2(64, 82), Vector2(42, 70)], GOLD)
			_rect(img, 58, 82, 70, 100, GOLD_D)
			_rect(img, 44, 100, 84, 110, GOLD)
		"gift":
			_round_rect(img, 24, 48, 104, 108, 6, RED)
			_rect(img, 24, 48, 104, 64, GOLD)
			_rect(img, 58, 48, 70, 108, GOLD)
		"clock":
			_fill_circle(img, 64, 64, 50, WHITE)
			_ring(img, 64, 64, 50, 5, GOLD)
			_line(img, 64, 64, 64, 30, 4, INK)
			_line(img, 64, 64, 90, 64, 3, INK)
			_fill_circle(img, 64, 64, 5, RED)
		"lock":
			_round_rect(img, 34, 58, 94, 108, 8, GOLD_D)
			_ring(img, 64, 50, 22, 8, GOLD_L)
			_fill_circle(img, 64, 78, 8, INK)
		"check":
			_fill_circle(img, 64, 64, 50, GREEN)
			_line(img, 36, 66, 56, 86, 8, WHITE)
			_line(img, 56, 86, 96, 42, 8, WHITE)
		"bolt":
			_poly(img, [Vector2(72, 14), Vector2(44, 64), Vector2(64, 64), Vector2(48, 114), Vector2(92, 54), Vector2(70, 54)], ORANGE)
		"flame":
			_poly(img, [Vector2(64, 16), Vector2(88, 56), Vector2(76, 56), Vector2(96, 104), Vector2(64, 88), Vector2(32, 104), Vector2(52, 56), Vector2(40, 56)], ORANGE)
			_poly(img, [Vector2(64, 48), Vector2(74, 74), Vector2(64, 96), Vector2(54, 74)], GOLD_L)
		"moon":
			_fill_circle(img, 70, 64, 46, GOLD_L)
			_fill_circle(img, 88, 52, 40, Color("06060c"))
		"target":
			_fill_circle(img, 64, 64, 52, RED)
			_fill_circle(img, 64, 64, 36, WHITE)
			_fill_circle(img, 64, 64, 20, RED)
			_fill_circle(img, 64, 64, 8, GOLD)
		"exp":
			_star(img, 64, 64, 48, CYAN)
		"ball":
			_fill_circle(img, 64, 64, 46, WHITE)
			_fill_circle(img, 50, 50, 12, Color(0.85, 0.85, 0.95))
		"arrow_up":
			_poly(img, [Vector2(64, 20), Vector2(100, 70), Vector2(80, 70), Vector2(80, 108), Vector2(48, 108), Vector2(48, 70), Vector2(28, 70)], GREEN)
		"arrow_down":
			_poly(img, [Vector2(64, 108), Vector2(100, 58), Vector2(80, 58), Vector2(80, 20), Vector2(48, 20), Vector2(48, 58), Vector2(28, 58)], RED)
		"reel_seven":
			_round_rect(img, 16, 16, 112, 112, 12, PANEL)
			_rect(img, 48, 36, 80, 92, RED)
		"reel_bar":
			_round_rect(img, 16, 16, 112, 112, 12, PANEL)
			_rect(img, 32, 52, 96, 76, GOLD)
		"reel_bell":
			_round_rect(img, 16, 16, 112, 112, 12, PANEL)
			_fill_circle(img, 64, 56, 24, GOLD)
			_rect(img, 48, 72, 80, 88, GOLD_D)
		"reel_cherry":
			_round_rect(img, 16, 16, 112, 112, 12, PANEL)
			_fill_circle(img, 48, 72, 16, RED)
			_fill_circle(img, 78, 72, 16, RED)
			_line(img, 48, 72, 64, 36, 3, GREEN)
			_line(img, 78, 72, 64, 36, 3, GREEN)
		"reel_lemon":
			_round_rect(img, 16, 16, 112, 112, 12, PANEL)
			_fill_circle(img, 64, 64, 28, GOLD)
		"reel_diamond":
			_round_rect(img, 16, 16, 112, 112, 12, PANEL)
			_poly(img, [Vector2(64, 28), Vector2(96, 64), Vector2(64, 100), Vector2(32, 64)], CYAN)
		"reel_star":
			_round_rect(img, 16, 16, 112, 112, 12, PANEL)
			_star(img, 64, 64, 36, GOLD)
		"reel_clover":
			_round_rect(img, 16, 16, 112, 112, 12, PANEL)
			_fill_circle(img, 64, 44, 16, GREEN)
			_fill_circle(img, 48, 68, 16, GREEN)
			_fill_circle(img, 80, 68, 16, GREEN)
			_fill_circle(img, 64, 84, 16, GREEN)
		"sym_coin":
			_fill_circle(img, 64, 64, 50, GOLD)
			_fill_circle(img, 64, 64, 32, GOLD_L)
		"sym_gem":
			_poly(img, [Vector2(64, 20), Vector2(100, 52), Vector2(86, 100), Vector2(42, 100), Vector2(28, 52)], PURPLE)
		"sym_ring":
			_ring(img, 64, 72, 32, 10, GOLD)
			_fill_circle(img, 64, 36, 12, CYAN)
		"sym_crown":
			_poly(img, [Vector2(24, 80), Vector2(24, 44), Vector2(44, 68), Vector2(64, 32), Vector2(84, 68), Vector2(104, 44), Vector2(104, 80)], GOLD)
			_rect(img, 24, 80, 104, 96, GOLD_D)
		"sym_diamond":
			_poly(img, [Vector2(64, 20), Vector2(100, 64), Vector2(64, 108), Vector2(28, 64)], CYAN)
		"sym_skull":
			_fill_circle(img, 64, 52, 36, WHITE)
			_rect(img, 44, 72, 84, 100, WHITE)
			_fill_circle(img, 52, 50, 7, INK)
			_fill_circle(img, 76, 50, 7, INK)
		"fish_minnow", "fish_bass", "fish_salmon", "fish_tuna", "fish_shark", "fish_kraken", "fish_treasure", "fish_junk":
			_draw_fish(img, name)
		"prize_miss":
			_fill_circle(img, 64, 64, 46, PANEL)
			_line(img, 40, 40, 88, 88, 10, RED)
			_line(img, 88, 40, 40, 88, 10, RED)
		"prize_candy":
			_poly(img, [Vector2(28, 64), Vector2(48, 40), Vector2(80, 40), Vector2(100, 64), Vector2(80, 88), Vector2(48, 88)], PINK)
		"prize_plush":
			_fill_circle(img, 64, 72, 36, PINK)
			_fill_circle(img, 44, 44, 16, PINK)
			_fill_circle(img, 84, 44, 16, PINK)
			_fill_circle(img, 54, 68, 4, INK)
			_fill_circle(img, 74, 68, 4, INK)
		"prize_watch":
			_fill_circle(img, 64, 64, 36, GOLD)
			_rect(img, 58, 20, 70, 36, GOLD_D)
			_rect(img, 58, 92, 70, 108, GOLD_D)
			_fill_circle(img, 64, 64, 6, INK)
		"prize_phone":
			_round_rect(img, 40, 16, 88, 112, 10, PANEL)
			_rect(img, 48, 28, 80, 88, BLUE)
			_fill_circle(img, 64, 100, 5, WHITE)
		"prize_gold":
			_fill_circle(img, 64, 64, 46, GOLD)
			_fill_circle(img, 64, 64, 26, GOLD_L)
		"prize_diamond":
			_poly(img, [Vector2(64, 20), Vector2(100, 52), Vector2(86, 100), Vector2(42, 100), Vector2(28, 52)], CYAN)
		"prop_pennyslots", "prop_blackjack", "prop_roulette", "prop_poker", "prop_craps", \
		"prop_sportsbook", "prop_vip", "prop_highroller", "prop_resort", "prop_sky", \
		"prop_orbital", "prop_cruiser":
			_draw_prop(img, name)
		_:
			# Fallback unique hash-colored badge so missing names still look intentional.
			var h := float(name.hash() % 360)
			var col := Color.from_hsv(h / 360.0, 0.65, 0.9)
			_fill_circle(img, 64, 64, 48, col)
			_ring(img, 64, 64, 48, 4, GOLD)


static func _draw_die(img: Image, n: int) -> void:
	_round_rect(img, 18, 18, 110, 110, 14, WHITE)
	var dots := {
		1: [Vector2(64, 64)],
		2: [Vector2(40, 40), Vector2(88, 88)],
		3: [Vector2(40, 40), Vector2(64, 64), Vector2(88, 88)],
		4: [Vector2(40, 40), Vector2(88, 40), Vector2(40, 88), Vector2(88, 88)],
		5: [Vector2(40, 40), Vector2(88, 40), Vector2(64, 64), Vector2(40, 88), Vector2(88, 88)],
		6: [Vector2(40, 40), Vector2(88, 40), Vector2(40, 64), Vector2(88, 64), Vector2(40, 88), Vector2(88, 88)],
	}
	for p in dots.get(n, dots[1]):
		_fill_circle(img, p.x, p.y, 8, INK)


static func _draw_fish(img: Image, name: String) -> void:
	var body := Color("6ec8dc")
	var fin := Color("4a9bb0")
	match name:
		"fish_bass": body = Color("3c8c5a"); fin = Color("286440")
		"fish_salmon": body = Color("ff8c78"); fin = Color("dc5a50")
		"fish_tuna": body = Color("4670b4"); fin = Color("284682")
		"fish_shark": body = Color("788296"); fin = Color("505a6e")
		"fish_kraken": body = Color("5a2878"); fin = Color("3c145a")
		"fish_treasure": body = GOLD; fin = GOLD_D
		"fish_junk": body = Color("646464"); fin = Color("464646")
	_fill_circle(img, 56, 64, 28, body)
	_poly(img, [Vector2(80, 64), Vector2(112, 40), Vector2(112, 88)], fin)
	_fill_circle(img, 40, 56, 5, INK)


static func _draw_prop(img: Image, name: String) -> void:
	match name:
		"prop_pennyslots":
			_round_rect(img, 24, 24, 104, 104, 10, PANEL)
			_fill_circle(img, 64, 64, 24, GOLD)
		"prop_blackjack":
			_fill_circle(img, 64, 64, 48, Color("0e2e22"))
			_ring(img, 64, 64, 48, 4, GOLD)
		"prop_roulette":
			_fill_circle(img, 64, 64, 46, RED)
			_fill_circle(img, 64, 64, 24, INK)
			_fill_circle(img, 64, 64, 10, GOLD)
		"prop_poker":
			_round_rect(img, 28, 20, 68, 96, 6, WHITE)
			_round_rect(img, 56, 32, 96, 108, 6, WHITE)
		"prop_craps":
			_round_rect(img, 18, 44, 62, 88, 6, WHITE)
			_round_rect(img, 58, 28, 102, 72, 6, WHITE)
		"prop_sportsbook":
			_fill_circle(img, 64, 64, 48, GREEN)
			_fill_circle(img, 64, 64, 28, Color("0e2e22"))
		"prop_vip":
			_star(img, 64, 64, 46, GOLD)
		"prop_highroller":
			_fill_circle(img, 64, 64, 50, GOLD_D)
			_fill_circle(img, 64, 64, 34, GOLD)
			_fill_circle(img, 64, 64, 18, GOLD_L)
		"prop_resort":
			_poly(img, [Vector2(24, 72), Vector2(64, 24), Vector2(104, 72)], CYAN)
			_rect(img, 28, 72, 100, 108, PANEL)
		"prop_sky":
			_rect(img, 48, 44, 80, 108, PANEL)
			_rect(img, 36, 64, 92, 76, BLUE)
			_fill_circle(img, 64, 28, 12, GOLD)
		"prop_orbital":
			_fill_circle(img, 64, 64, 18, CYAN)
			_ring(img, 64, 64, 40, 5, PURPLE)
		"prop_cruiser":
			_poly(img, [Vector2(16, 72), Vector2(28, 48), Vector2(100, 48), Vector2(112, 72), Vector2(100, 96), Vector2(28, 96)], PANEL)
			_rect(img, 48, 32, 60, 48, GOLD)
