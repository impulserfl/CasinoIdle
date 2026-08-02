extends Minigame

## Interactive claw machine.
##
## Move the claw over the prize bay, then drop. Prize is still rolled from the
## verified 88% table — timing only shifts which bay you were over for flavour;
## a pure skill table would break the arcade edge.

const PRIZES: Array[Dictionary] = [
	{"name": "Nothing", "icon": "prize_miss",    "mult": 0.0,   "weight": 3144},
	{"name": "Candy",   "icon": "prize_candy",   "mult": 1.5,   "weight": 500},
	{"name": "Plush",   "icon": "prize_plush",   "mult": 3.0,   "weight": 200},
	{"name": "Watch",   "icon": "prize_watch",   "mult": 8.0,   "weight": 80},
	{"name": "Phone",   "icon": "prize_phone",   "mult": 20.0,  "weight": 30},
	{"name": "Gold Bar", "icon": "prize_gold",   "mult": 60.0,  "weight": 10},
	{"name": "Diamond", "icon": "prize_diamond", "mult": 150.0, "weight": 2},
]

const LOSS_RATE := 0.792738

var _stage: Control
var _claw: Control
var _prizes_row: HBoxContainer
var _status: Label
var _claw_x := 0.5
var _dropping := false
var _awaiting := false
var _staked := 0.0
var _move_left := false
var _move_right := false


func _init() -> void:
	game_id = "claw"
	game_name = "Claw Machine"
	game_icon = "game_claw"
	base_rtp = 0.88
	rules_text = "Move the claw, then drop. Arcade odds — about 1 in 5 catches."


func _build_board(container: VBoxContainer) -> void:
	var cabinet := UIKit.well(Color("141a28"), 12)
	cabinet.custom_minimum_size = Vector2(0, 280)

	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(0, 260)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cabinet.add_child(_stage)

	# Glass / bay background
	var glass := ColorRect.new()
	glass.color = Color("1c2740")
	glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(glass)

	# Prize shelf
	_prizes_row = UIKit.hbox(18)
	_prizes_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prizes_row.offset_top = -100
	_prizes_row.offset_bottom = -20
	_prizes_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for p in PRIZES:
		if float(p["mult"]) <= 0.0:
			continue
		_prizes_row.add_child(UIKit.icon(String(p["icon"]), 36))
	_stage.add_child(_prizes_row)

	_claw = _ClawArm.new()
	_claw.position = Vector2(120, 8)
	_stage.add_child(_claw)

	container.add_child(cabinet)

	var controls := UIKit.hbox(10)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	var left := UIKit.button("<<", 18, UIKit.BLUE)
	left.custom_minimum_size = Vector2(72, 40)
	left.button_down.connect(func(): _move_left = true)
	left.button_up.connect(func(): _move_left = false)
	controls.add_child(left)
	var drop := UIKit.primary_button("DROP", 18, UIKit.ORANGE)
	drop.custom_minimum_size = Vector2(120, 40)
	drop.pressed.connect(_on_drop_pressed)
	controls.add_child(drop)
	var right := UIKit.button(">>", 18, UIKit.BLUE)
	right.custom_minimum_size = Vector2(72, 40)
	right.button_down.connect(func(): _move_right = true)
	right.button_up.connect(func(): _move_right = false)
	controls.add_child(right)
	container.add_child(controls)

	_status = UIKit.label("Press PLAY, move the claw, then DROP.", 14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_status)
	container.add_child(_build_prize_table())

	if play_button != null:
		play_button.text = "PLAY"


func _build_prize_table() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(3, 14, 4)
	for p in PRIZES:
		if float(p["mult"]) <= 0.0:
			continue
		var row := UIKit.hbox(6)
		row.add_child(UIKit.icon(String(p["icon"]), 18))
		var l := UIKit.label(String(p["name"]), 12, UIKit.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.label("%sx" % Fmt.chips(float(p["mult"])), 12, UIKit.tier_color(float(p["mult"]))))
		grid.add_child(row)
	panel.add_child(grid)
	return panel


func _process(delta: float) -> void:
	super._process(delta)
	if not _awaiting or _dropping:
		return
	var speed := 0.55
	if _move_left:
		_claw_x = maxf(_claw_x - speed * delta, 0.08)
		AudioManager.play_claw_move()
	if _move_right:
		_claw_x = minf(_claw_x + speed * delta, 0.92)
		AudioManager.play_claw_move()
	_place_claw()


func _place_claw() -> void:
	if _stage == null or _claw == null:
		return
	var w := maxf(_stage.size.x, 200.0)
	_claw.position = Vector2(_claw_x * w - 20.0, 8.0)


func _on_drop_pressed() -> void:
	if _awaiting and not _dropping:
		_dropping = true


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	_staked = bet
	if auto:
		_claw_x = randf_range(0.2, 0.8)
		_place_claw()
		await _do_drop_and_resolve()
		return

	_awaiting = true
	_dropping = false
	_status.text = "Move << >> then press DROP"
	set_result("Position the claw...", UIKit.CYAN, "game_claw")
	if play_button != null:
		play_button.text = "DROP"

	while is_inside_tree() and _awaiting and not _dropping:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	await _do_drop_and_resolve()


func _on_play_pressed() -> void:
	if _awaiting and not _dropping:
		_dropping = true
		return
	super._on_play_pressed()


func _do_drop_and_resolve() -> void:
	_awaiting = false
	_dropping = true
	AudioManager.play_claw_drop()
	_status.text = "Dropping..."
	set_result("The claw descends...", UIKit.DIM)

	var start_y := _claw.position.y
	var tw := create_tween()
	tw.tween_property(_claw, "position:y", 150.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if not is_inside_tree():
		return
	await wait(0.2)
	tw = create_tween()
	tw.tween_property(_claw, "position:y", start_y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree():
		return

	var entries: Array = []
	for p in PRIZES:
		entries.append([p, p["weight"]])
	var got: Dictionary = weighted_pick(entries)
	var mult := float(got["mult"])
	var payout := _staked * mult
	var is_jackpot := mult >= 60.0
	var credited := finish_round(payout, LOSS_RATE, is_jackpot)

	_status.text = String(got["name"])
	if mult > 0.0:
		set_result("Got the %s  +%s" % [String(got["name"]), Fmt.chips(payout)],
			UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		AudioManager.play_win(mult)
		if is_jackpot and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("The claw slips.", UIKit.DIM)
		AudioManager.play_error()

	_dropping = false
	if play_button != null:
		play_button.text = "PLAY"


func stop_auto() -> void:
	super.stop_auto()
	_awaiting = false
	_dropping = false


class _ClawArm extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(40, 80)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(18, 0, 4, 36), Color("c0c6d0"))
		draw_rect(Rect2(8, 36, 24, 8), Color("8a93a6"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(8, 44), Vector2(4, 70), Vector2(12, 70)
		]), Color("d0d6e0"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(32, 44), Vector2(36, 70), Vector2(28, 70)
		]), Color("d0d6e0"))
