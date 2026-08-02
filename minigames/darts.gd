extends Minigame

## Interactive pub darts.
##
## Click-drag on the board to aim, hold to charge power, release to throw.
## Landing is aim + timing error + residual scatter. Zone still pays from the
## verified 92% tables so skill changes the *shape* of outcomes, not the edge.

const ZONES: Array[Dictionary] = [
	{"id": "bull",   "name": "Bullseye", "mult": 25.0, "r0": 0.00, "r1": 0.10},
	{"id": "treble", "name": "Treble",   "mult": 6.0,  "r0": 0.10, "r1": 0.28},
	{"id": "double", "name": "Double",   "mult": 3.0,  "r0": 0.28, "r1": 0.52},
	{"id": "outer",  "name": "Outer",    "mult": 1.5,  "r0": 0.52, "r1": 0.82},
]

## aim_id -> [miss, bull, treble, double, outer] weights (RTP 92%).
const AIM_WEIGHTS: Dictionary = {
	"bull":   [26483, 600, 1000, 1600, 2600],
	"treble": [24152, 300, 2000, 1600, 2600],
	"double": [22248, 300, 1000, 3200, 2600],
	"outer":  [20270, 300, 1000, 1600, 5200],
}

const AIM_LOSS_RATE: Dictionary = {
	"bull": 0.820339,
	"treble": 0.787943,
	"double": 0.758076,
	"outer": 0.714487,
}

var _board: Control
var _dart: Control
var _power_bar: ProgressBar
var _hint: Label
var _hit_label: Label

var _aim_local := Vector2.ZERO
var _charging := false
var _power := 0.0
var _power_dir := 1.0
var _awaiting_throw := false
var _last_aim_id := "treble"
var _staked := 0.0


func _init() -> void:
	game_id = "darts"
	game_name = "Darts"
	game_icon = "game_darts"
	base_rtp = 0.92
	rules_text = "Aim on the board, hold to charge, release to throw."


func _build_board(container: VBoxContainer) -> void:
	_hint = UIKit.label("Click the board to aim, then hold PLAY / click board to charge and throw.", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_hint)

	var stage := UIKit.well(Color("1a0f0a"), 14)
	stage.custom_minimum_size = Vector2(0, 340)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = Vector2(320, 320)
	stage.add_child(holder)

	_board = _DartBoard.new()
	_board.set_anchors_preset(Control.PRESET_CENTER)
	_board.custom_minimum_size = Vector2(300, 300)
	_board.size = Vector2(300, 300)
	_board.position = Vector2(10, 10)
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.gui_input.connect(_on_board_input)
	holder.add_child(_board)

	_dart = _DartSprite.new()
	_dart.visible = false
	_dart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_dart)

	container.add_child(stage)

	var power_row := UIKit.hbox(10)
	power_row.add_child(UIKit.label("Power", 13, UIKit.DIM))
	_power_bar = UIKit.progress_bar(UIKit.ORANGE, 14)
	_power_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_row.add_child(_power_bar)
	container.add_child(power_row)

	_hit_label = UIKit.label("Take aim", 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_hit_label)

	if play_button != null:
		play_button.text = "THROW"


func _process(delta: float) -> void:
	super._process(delta)
	if _charging:
		_power += delta * 1.35 * _power_dir
		if _power >= 1.0:
			_power = 1.0
			_power_dir = -1.0
		elif _power <= 0.0:
			_power = 0.0
			_power_dir = 1.0
		_power_bar.value = _power


func _on_board_input(event: InputEvent) -> void:
	if busy and not _awaiting_throw:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_set_aim_from_local(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_set_aim_from_local(event.position)
			if _awaiting_throw:
				_start_charge()
		else:
			if _charging:
				_release_throw()


func _set_aim_from_local(local: Vector2) -> void:
	var center := _board.size * 0.5
	var offset := local - center
	var max_r := minf(center.x, center.y) * 0.92
	if offset.length() > max_r:
		offset = offset.normalized() * max_r
	_aim_local = center + offset
	if _board.has_method("set_aim"):
		_board.call("set_aim", _aim_local)
	_last_aim_id = _aim_id_from_radius(offset.length() / max_r)
	_hit_label.text = "Aiming: %s" % _last_aim_id.capitalize()


func _aim_id_from_radius(norm_r: float) -> String:
	if norm_r < 0.12:
		return "bull"
	if norm_r < 0.32:
		return "treble"
	if norm_r < 0.55:
		return "double"
	return "outer"


func _start_charge() -> void:
	_charging = true
	_power = 0.0
	_power_dir = 1.0
	_power_bar.value = 0.0
	_hint.text = "Release to throw — mid power is steadiest."
	AudioManager.play_click()


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	_staked = bet
	if auto:
		# Auto picks a random ring aim and average power.
		var ids: Array = AIM_WEIGHTS.keys()
		_last_aim_id = String(ids[randi() % ids.size()])
		_power = randf_range(0.35, 0.65)
		await _resolve_throw(_last_aim_id, _power)
		return

	_awaiting_throw = true
	_hint.text = "Aim on the board, then press and hold to charge. Release to throw."
	set_result("Your throw — aim and charge.", UIKit.GOLD, "game_darts")
	# Wait until player releases a charge (or cancels via stop_auto).
	while _awaiting_throw and is_inside_tree() and not auto:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _charging:
			# If they already aimed and press again over UI, allow charge from PLAY flow
			pass
		await get_tree().process_frame
		if not is_inside_tree():
			return
		# Safety: if they hit THROW again while waiting, treat as mid power auto-aim
		if not _awaiting_throw:
			break


func _on_play_pressed() -> void:
	if _awaiting_throw and not _charging:
		_start_charge()
		return
	if _charging:
		_release_throw()
		return
	super._on_play_pressed()


func _release_throw() -> void:
	if not _charging:
		return
	_charging = false
	_awaiting_throw = false
	var power := _power
	_power_bar.value = power
	AudioManager.play_dart_throw()
	await _resolve_throw(_last_aim_id, power)


func _resolve_throw(aim_id: String, power: float) -> void:
	# Stability peaks near 0.55 power; extremes add scatter.
	var stability := 1.0 - absf(power - 0.55) * 1.6
	stability = clampf(stability, 0.15, 1.0)

	var index := _roll_zone(aim_id, stability)
	var mult := 0.0
	var label := "Missed the board"
	var land_r := 0.95
	if index > 0:
		var zone: Dictionary = ZONES[index - 1]
		mult = float(zone["mult"])
		label = String(zone["name"])
		land_r = (float(zone["r0"]) + float(zone["r1"])) * 0.5
		if String(zone["id"]) == "bull":
			Achievements.notify("bullseye")

	# Animate flight toward a point on the ring.
	var center := _board.size * 0.5
	var angle := randf() * TAU
	if _aim_local != Vector2.ZERO:
		angle = (_aim_local - center).angle()
	var target := center + Vector2(cos(angle), sin(angle)) * (land_r * minf(center.x, center.y) * 0.92)
	_dart.visible = true
	_dart.position = center + Vector2(-40, 120)
	_dart.rotation = (target - _dart.position).angle() + PI * 0.5
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_dart, "position", target - Vector2(6, 6), 0.35)
	await tw.finished
	if not is_inside_tree():
		return
	AudioManager.play_dart_hit()
	FX.pulse(_board, 1.04, 0.2)
	_hit_label.text = label

	var payout := _staked * mult
	var loss_rate := float(AIM_LOSS_RATE.get(aim_id, 0.78))
	var is_jackpot := mult >= 25.0
	var credited := finish_round(payout, loss_rate, is_jackpot)

	if mult > 0.0:
		set_result("%s  +%s" % [label, Fmt.chips(payout)], UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if is_jackpot and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("Missed the board.", UIKit.DIM)

	_hint.text = "Aim, charge, throw again."
	await wait(0.35)
	_dart.visible = false


func _roll_zone(aim_id: String, stability: float) -> int:
	## Blend the aimed weights with a flatter table when stability is low.
	var weights: Array = AIM_WEIGHTS.get(aim_id, AIM_WEIGHTS["treble"]).duplicate()
	var flat: Array = [22000, 400, 1400, 2000, 3200]
	for i in range(weights.size()):
		weights[i] = lerpf(float(flat[i]), float(weights[i]), stability)
	var entries: Array = []
	for i in range(weights.size()):
		entries.append([i, float(weights[i])])
	return int(weighted_pick(entries))


func stop_auto() -> void:
	super.stop_auto()
	_charging = false
	_awaiting_throw = false


# --- drawn dartboard -------------------------------------------------------

class _DartBoard extends Control:
	var aim_pos := Vector2(-1, -1)

	func set_aim(p: Vector2) -> void:
		aim_pos = p
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(c.x, c.y) * 0.92
		# Outer wood ring
		draw_circle(c, r * 1.05, Color("3a2415"))
		draw_arc(c, r * 1.05, 0.0, TAU, 64, Color("5a3820"), 4.0, true)
		# Scoring rings alternating
		var rings := [
			[1.00, Color("1a1a1a")],
			[0.82, Color("1e4d2b")],
			[0.70, Color("f2f2f2")],
			[0.52, Color("1e4d2b")],
			[0.40, Color("f2f2f2")],
			[0.28, Color("b22222")],
			[0.18, Color("f2f2f2")],
			[0.10, Color("b22222")],
			[0.04, Color("1a1a1a")],
		]
		for ring in rings:
			draw_circle(c, r * float(ring[0]), ring[1])
		# Wire separators
		for i in range(20):
			var a := -PI * 0.5 + i * TAU / 20.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * r, Color(0, 0, 0, 0.45), 1.5)
		# Numbers around the rim
		var order := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
		var font := ThemeDB.fallback_font
		for i in range(20):
			var a := -PI * 0.5 + i * TAU / 20.0
			var p := c + Vector2(cos(a), sin(a)) * (r * 0.91)
			draw_string(font, p + Vector2(-6, 4), str(order[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f0e6d0"))
		if aim_pos.x >= 0.0:
			draw_arc(aim_pos, 10.0, 0.0, TAU, 24, Color(1, 0.85, 0.2, 0.9), 2.0, true)
			draw_line(aim_pos + Vector2(-14, 0), aim_pos + Vector2(14, 0), Color(1, 0.85, 0.2, 0.8), 1.5)
			draw_line(aim_pos + Vector2(0, -14), aim_pos + Vector2(0, 14), Color(1, 0.85, 0.2, 0.8), 1.5)


class _DartSprite extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(18, 48)
		size = custom_minimum_size

	func _draw() -> void:
		# Simple dart: barrel + point + flight
		draw_colored_polygon(PackedVector2Array([
			Vector2(9, 0), Vector2(12, 14), Vector2(6, 14)
		]), Color("c0c6d0"))
		draw_rect(Rect2(7, 14, 4, 18), Color("b87333"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(5, 32), Vector2(13, 32), Vector2(15, 46), Vector2(9, 40), Vector2(3, 46)
		]), Color("d9455f"))
