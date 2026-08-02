extends Minigame

## Interactive fishing.
##
## 1) Hold to charge cast power (sets depth).
## 2) Wait for the bite indicator — press when it flashes.
## 3) Fight the fish on a tension meter (keep the needle in the green).
## Catch is still drawn from the verified 91% depth tables; failed timing or a
## snapped line force the junk outcome so skill cannot push the table over 100%.

const CATCHES: Array[Dictionary] = [
	{"name": "Old boot", "icon": "fish_junk",     "mult": 0.0},
	{"name": "Minnow",   "icon": "fish_minnow",   "mult": 1.5},
	{"name": "Bass",     "icon": "fish_bass",     "mult": 3.0},
	{"name": "Salmon",   "icon": "fish_salmon",   "mult": 6.0},
	{"name": "Tuna",     "icon": "fish_tuna",     "mult": 12.0},
	{"name": "Shark",    "icon": "fish_shark",    "mult": 30.0},
	{"name": "Treasure", "icon": "fish_treasure", "mult": 100.0},
	{"name": "KRAKEN",   "icon": "fish_kraken",   "mult": 400.0},
]

const DEPTH_WEIGHTS: Dictionary = {
	0: [187259, 45000, 22500, 7000, 3000, 400, 100, 16],
	1: [206347, 30000, 15000, 7000, 3000, 1000, 250, 40],
	2: [299885, 18000, 9000, 7000, 3000, 2500, 625, 100],
}

const DEPTH_LOSS_RATE: Dictionary = {
	0: 0.705908,
	1: 0.785704,
	2: 0.881727,
}

const DEPTH_NAMES: Array[String] = ["Shallow", "Mid", "Deep"]

var _scene: Control
var _water: ColorRect
var _bobber: Control
var _fish_icon: TextureRect
var _status: Label
var _cast_bar: ProgressBar
var _tension_bar: ProgressBar
var _bite_flash: ColorRect

var _phase := "idle"  # idle, charging, waiting, bite, fighting, done
var _cast_power := 0.0
var _cast_dir := 1.0
var _depth := 1
var _staked := 0.0
var _bite_window := false
var _fight_time := 0.0
var _tension := 0.5
var _tension_vel := 0.0
var _fight_ok := 0.0
var _player_reel := false


func _init() -> void:
	game_id = "fishing"
	game_name = "Fishing"
	game_icon = "game_fishing"
	base_rtp = 0.91
	rules_text = "Cast, hook the bite, keep tension in the green."


func _build_board(container: VBoxContainer) -> void:
	var stage := UIKit.well(Color("0a2030"), 14)
	stage.custom_minimum_size = Vector2(0, 300)

	var root := Control.new()
	root.custom_minimum_size = Vector2(0, 280)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(root)
	_scene = root

	# Sky
	var sky := ColorRect.new()
	sky.color = Color("6eb6d9")
	sky.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sky.offset_bottom = 90
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky)

	# Water
	_water = ColorRect.new()
	_water.color = Color("1a6a8a")
	_water.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_water.offset_top = -190
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_water)

	var water2 := ColorRect.new()
	water2.color = Color("0f4a66")
	water2.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	water2.offset_top = -90
	water2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(water2)

	_bite_flash = ColorRect.new()
	_bite_flash.color = Color(1, 1, 0.4, 0.0)
	_bite_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bite_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bite_flash)

	_bobber = _Bobber.new()
	_bobber.position = Vector2(40, 70)
	_bobber.visible = false
	root.add_child(_bobber)

	_fish_icon = UIKit.icon("fish_junk", 48)
	_fish_icon.visible = false
	_fish_icon.position = Vector2(200, 160)
	root.add_child(_fish_icon)

	container.add_child(stage)

	_status = UIKit.label("Hold PLAY to charge your cast.", 15, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_status)

	var cast_row := UIKit.hbox(8)
	cast_row.add_child(UIKit.label("Cast", 13, UIKit.DIM))
	_cast_bar = UIKit.progress_bar(UIKit.BLUE, 12)
	_cast_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cast_row.add_child(_cast_bar)
	container.add_child(cast_row)

	var ten_row := UIKit.hbox(8)
	ten_row.add_child(UIKit.label("Line", 13, UIKit.DIM))
	_tension_bar = UIKit.progress_bar(UIKit.GREEN, 12)
	_tension_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ten_row.add_child(_tension_bar)
	container.add_child(ten_row)

	container.add_child(_build_catch_table())

	if play_button != null:
		play_button.text = "CAST"


func _build_catch_table() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(4, 12, 4)
	for c in CATCHES:
		if float(c["mult"]) <= 0.0:
			continue
		var row := UIKit.hbox(5)
		row.add_child(UIKit.icon(String(c["icon"]), 18))
		var l := UIKit.label(String(c["name"]), 12, UIKit.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.label("%sx" % Fmt.chips(float(c["mult"])), 12, UIKit.tier_color(float(c["mult"]))))
		grid.add_child(row)
	panel.add_child(grid)
	return panel


func _process(delta: float) -> void:
	super._process(delta)
	match _phase:
		"charging":
			_cast_power += delta * 1.1 * _cast_dir
			if _cast_power >= 1.0:
				_cast_power = 1.0
				_cast_dir = -1.0
			elif _cast_power <= 0.0:
				_cast_power = 0.0
				_cast_dir = 1.0
			_cast_bar.value = _cast_power
		"fighting":
			# Fish pulls randomly; player reels while holding.
			_tension_vel += randf_range(-1.2, 1.2) * delta
			if _player_reel:
				_tension_vel += 1.8 * delta
			else:
				_tension_vel -= 0.9 * delta
			_tension_vel = clampf(_tension_vel, -1.5, 1.5)
			_tension = clampf(_tension + _tension_vel * delta, 0.0, 1.0)
			_tension_bar.value = _tension
			# Green zone 0.28–0.72
			if _tension >= 0.28 and _tension <= 0.72:
				_fight_ok += delta
				_tension_bar.modulate = Color.WHITE
			else:
				_tension_bar.modulate = Color(1.0, 0.5, 0.5)
			_fight_time += delta
			if _tension <= 0.02 or _tension >= 0.98:
				_phase = "snapped"
			if _fight_time >= 2.4:
				_phase = "landed"


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _phase == "fighting":
			_player_reel = event.pressed
			if event.pressed:
				AudioManager.play_reel()
		elif _phase == "bite" and event.pressed:
			_hook_bite()
		elif _phase == "charging" and not event.pressed:
			_release_cast()


func _on_play_pressed() -> void:
	if _phase == "charging":
		_release_cast()
		return
	if _phase == "bite":
		_hook_bite()
		return
	if _phase == "fighting":
		_player_reel = true
		return
	super._on_play_pressed()


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	_staked = bet
	_fish_icon.visible = false
	_tension_bar.value = 0.5
	_cast_bar.value = 0.0

	if auto:
		_depth = randi() % 3
		_cast_power = [0.25, 0.55, 0.85][_depth]
		_cast_bar.value = _cast_power
		await _auto_finish(true, true)
		return

	_phase = "charging"
	_cast_power = 0.0
	_cast_dir = 1.0
	_status.text = "Hold to charge cast — release to cast. Shallow / Mid / Deep."
	set_result("Charging cast...", UIKit.BLUE)
	if play_button != null:
		play_button.text = "RELEASE"

	while _phase == "charging" and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return

	# After cast: waiting for bite
	while _phase == "waiting" and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return

	while _phase == "bite" and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return

	while _phase == "fighting" and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return

	var hooked := _phase != "missed" and _phase != "snapped"
	var fought := _phase == "landed" and _fight_ok >= 1.0
	await _finish_catch(hooked, fought)


func _release_cast() -> void:
	if _phase != "charging":
		return
	_phase = "waiting"
	_depth = 0 if _cast_power < 0.33 else (1 if _cast_power < 0.66 else 2)
	_status.text = "Cast to %s water... wait for the bite!" % DEPTH_NAMES[_depth]
	set_result("Line is out — %s" % DEPTH_NAMES[_depth], UIKit.CYAN)
	AudioManager.play_cast()
	_bobber.visible = true
	_bobber.position = Vector2(80 + _depth * 90, 100 + _depth * 20)
	FX.pulse(_bobber, 1.2, 0.3)
	AudioManager.play_splash()
	if play_button != null:
		play_button.text = "HOOK"

	# Bobber idle then bite window
	var wait_t := randf_range(0.7, 1.8)
	var t0 := Time.get_ticks_msec()
	while _phase == "waiting" and is_inside_tree():
		var bob := sin(Time.get_ticks_msec() * 0.008) * 4.0
		_bobber.position.y = 100 + _depth * 20 + bob
		if Time.get_ticks_msec() - t0 > int(wait_t * 1000.0):
			break
		await get_tree().process_frame
	if not is_inside_tree() or _phase != "waiting":
		return

	_phase = "bite"
	_bite_window = true
	_status.text = "BITE! Press HOOK / click NOW!"
	AudioManager.play_bite()
	_bite_flash.color = Color(1, 1, 0.5, 0.35)
	var window := 0.55 + 0.1 * float(2 - _depth)
	var t1 := Time.get_ticks_msec()
	while _phase == "bite" and is_inside_tree():
		var pulse := 0.25 + 0.2 * absf(sin(Time.get_ticks_msec() * 0.02))
		_bite_flash.color = Color(1, 1, 0.4, pulse)
		if Time.get_ticks_msec() - t1 > int(window * 1000.0):
			_phase = "missed"
			break
		await get_tree().process_frame
	_bite_flash.color = Color(1, 1, 0.4, 0.0)
	_bite_window = false


func _hook_bite() -> void:
	if _phase != "bite":
		return
	_phase = "fighting"
	_tension = 0.5
	_tension_vel = randf_range(-0.3, 0.3)
	_fight_time = 0.0
	_fight_ok = 0.0
	_player_reel = false
	_status.text = "Hold left mouse / CAST to reel — keep the line in the green!"
	set_result("Fish on! Fight it!", UIKit.ORANGE, "game_fishing")
	AudioManager.play_reel()
	if play_button != null:
		play_button.text = "REEL"


func _auto_finish(hooked: bool, fought: bool) -> void:
	await wait(0.2)
	await _finish_catch(hooked, fought)


func _finish_catch(hooked: bool, fought: bool) -> void:
	_phase = "done"
	_bobber.visible = false
	_player_reel = false
	if play_button != null:
		play_button.text = "CAST"

	var got: Dictionary
	if not hooked or not fought:
		got = CATCHES[0]
		_status.text = "Got away..." if hooked else "Missed the bite."
	else:
		got = _roll_catch()
		_status.text = "Landed a %s!" % String(got["name"])

	_fish_icon.texture = Icons.tex(String(got["icon"]))
	_fish_icon.visible = true
	FX.pulse(_fish_icon, 1.3, 0.3)

	var mult := float(got["mult"])
	var payout := _staked * mult
	var is_jackpot := mult >= 100.0
	var credited := finish_round(payout, float(DEPTH_LOSS_RATE[_depth]), is_jackpot)

	if mult >= 400.0:
		Achievements.notify("kraken")

	if mult > 0.0:
		set_result("Landed a %s  +%s" % [String(got["name"]), Fmt.chips(payout)],
			UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if is_jackpot and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result(_status.text, UIKit.DIM)

	_phase = "idle"


func _roll_catch() -> Dictionary:
	var weights: Array = DEPTH_WEIGHTS[_depth]
	var entries: Array = []
	for i in range(CATCHES.size()):
		entries.append([CATCHES[i], float(weights[i])])
	return weighted_pick(entries)


func stop_auto() -> void:
	super.stop_auto()
	_phase = "idle"
	_player_reel = false


class _Bobber extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(14, 22)
		size = custom_minimum_size

	func _draw() -> void:
		draw_circle(Vector2(7, 8), 7, Color("d9455f"))
		draw_circle(Vector2(7, 8), 7, Color("f2f2f2"))
		draw_rect(Rect2(6, 0, 2, 8), Color("f2f2f2"))
		draw_circle(Vector2(7, 5), 5, Color("d9455f"))
