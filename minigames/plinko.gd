extends Minigame

## Interactive Plinko — pick a drop lane, ball bounces through pegs.
## Slot weights still enforce 93% RTP (centre is the loss pocket).

const SLOTS: Array[Dictionary] = [
	{"mult": 25.0, "weight": 10,   "accent": "gold"},
	{"mult": 6.0,  "weight": 60,   "accent": "orange"},
	{"mult": 2.5,  "weight": 160,  "accent": "purple"},
	{"mult": 1.2,  "weight": 300,  "accent": "green"},
	{"mult": 0.0,  "weight": 1886, "accent": "dim"},
	{"mult": 1.2,  "weight": 300,  "accent": "green"},
	{"mult": 2.5,  "weight": 160,  "accent": "purple"},
	{"mult": 6.0,  "weight": 60,   "accent": "orange"},
	{"mult": 25.0, "weight": 10,   "accent": "gold"},
]

const LOSS_RATE := 0.640190

var _slot_panels: Array[PanelContainer] = []
var _ball: TextureRect
var _lane := 4
var _lane_buttons: Dictionary = {}
var _hint: Label


func _init() -> void:
	game_id = "plinko"
	game_name = "Plinko"
	game_icon = "game_plinko"
	base_rtp = 0.93
	rules_text = "Pick a lane and drop. Edges pay big; the middle pays nothing."


func _build_board(container: VBoxContainer) -> void:
	var lane_row := UIKit.hbox(4)
	lane_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(9):
		var b := UIKit.button(str(i + 1), 12, UIKit.BLUE)
		b.custom_minimum_size = Vector2(36, 28)
		b.pressed.connect(_set_lane.bind(i))
		_lane_buttons[i] = b
		lane_row.add_child(b)
	container.add_child(lane_row)

	var ball_row := UIKit.hbox(0)
	ball_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_ball = UIKit.icon("ball", 30)
	ball_row.add_child(_ball)
	container.add_child(ball_row)

	var pegs := UIKit.vbox(6)
	for row in range(4):
		var line := UIKit.hbox(16)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in range(3 + row):
			line.add_child(UIKit.icon("ball", 8, UIKit.FAINT))
		pegs.add_child(line)
	container.add_child(pegs)

	var row2 := UIKit.hbox(5)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in SLOTS:
		var mult := float(s["mult"])
		var accent := _accent_of(String(s["accent"]))
		var p := UIKit.panel(UIKit.PANEL, 8, 1)
		p.custom_minimum_size = Vector2(58, 62)
		var l := UIKit.label("x%s" % Fmt.chips(mult) if mult > 0.0 else "-", 13, accent, HORIZONTAL_ALIGNMENT_CENTER)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		_slot_panels.append(p)
		row2.add_child(p)
	container.add_child(row2)

	_hint = UIKit.label("Choose a drop lane (1-9), then DROP.", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_hint)
	_refresh_lane()
	if play_button != null:
		play_button.text = "DROP"


func _accent_of(name: String) -> Color:
	match name:
		"gold": return UIKit.GOLD
		"orange": return UIKit.ORANGE
		"purple": return UIKit.PURPLE
		"green": return UIKit.GREEN
	return UIKit.DIM


func _set_lane(i: int) -> void:
	if busy:
		return
	_lane = i
	_refresh_lane()
	AudioManager.play_click()


func _refresh_lane() -> void:
	UIKit.segmented_select(_lane_buttons, _lane, UIKit.BLUE)
	_place_ball(_lane)


func _pick_slot() -> int:
	# Bias slightly toward chosen lane, then fall back to true weights.
	var entries: Array = []
	for i in range(SLOTS.size()):
		var w := float(SLOTS[i]["weight"])
		var dist := absf(float(i) - float(_lane))
		w *= 1.0 + maxf(0.0, 0.35 - dist * 0.08)
		entries.append([i, w])
	return int(weighted_pick(entries))


func _place_ball(index: int) -> void:
	if _ball == null:
		return
	_ball.position.x = (float(index) - 4.0) * 63.0


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	var target := _pick_slot()
	set_result("Dropping...", UIKit.DIM)
	AudioManager.play_tick()
	_place_ball(_lane)

	var pos := float(_lane)
	for step in range(14):
		# Random walk toward target
		var pull := signf(float(target) - pos)
		pos += pull * randf_range(0.15, 0.55) + randf_range(-0.4, 0.4)
		pos = clampf(pos, 0.0, 8.0)
		_place_ball(int(round(pos)))
		await wait(0.05 + step * 0.008)
		if not is_inside_tree():
			return

	_place_ball(target)
	FX.pulse(_slot_panels[target], 1.3, 0.25)
	AudioManager.play_tick()

	var mult := float(SLOTS[target]["mult"])
	var payout := staked * mult
	var credited := finish_round(payout, LOSS_RATE, mult >= 25.0)
	if payout > 0.0:
		set_result("Landed x%s  +%s" % [Fmt.chips(mult), Fmt.chips(payout)], UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if mult >= 25.0 and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("Straight down the middle.", UIKit.DIM)
