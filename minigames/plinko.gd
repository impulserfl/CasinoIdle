extends Minigame

## Plinko: a ball drops into one of nine weighted slots.
##
## The centre slot pays nothing — it is the loss. Every other slot pays at
## least 1.2x, because a slot that returns a fraction of the stake reads as a
## win in the UI while actually being a loss. The centre weight is solved so
## the table lands on exactly 93%:
##
##   sum(weight * mult) / sum(weight) = 2740 / 2946 = 0.9301

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
var _ball_row: HBoxContainer


func _init() -> void:
	game_id = "plinko"
	game_name = "Plinko"
	game_icon = "game_plinko"
	base_rtp = 0.93
	rules_text = "The edges pay big and the middle pays nothing. Most balls land in the middle."


func _build_board(container: VBoxContainer) -> void:
	_ball_row = UIKit.hbox(0)
	_ball_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_ball = UIKit.icon("ball", 30)
	_ball_row.add_child(_ball)
	container.add_child(_ball_row)

	var pegs := UIKit.vbox(6)
	for row in range(3):
		var line := UIKit.hbox(18)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in range(3 + row):
			var dot := UIKit.icon("ball", 9, UIKit.FAINT)
			line.add_child(dot)
		pegs.add_child(line)
	container.add_child(pegs)

	var row2 := UIKit.hbox(5)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in SLOTS:
		var mult := float(s["mult"])
		var accent := _accent_of(String(s["accent"]))
		var p := UIKit.panel(UIKit.PANEL, 8, 1)
		p.custom_minimum_size = Vector2(58, 62)
		var l := UIKit.label("x%s" % Fmt.chips(mult) if mult > 0.0 else "-", 13, accent,
			HORIZONTAL_ALIGNMENT_CENTER)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		_slot_panels.append(p)
		row2.add_child(p)
	container.add_child(row2)


func _accent_of(name: String) -> Color:
	match name:
		"gold":
			return UIKit.GOLD
		"orange":
			return UIKit.ORANGE
		"purple":
			return UIKit.PURPLE
		"green":
			return UIKit.GREEN
	return UIKit.DIM


func _pick_slot() -> int:
	var entries: Array = []
	for i in range(SLOTS.size()):
		entries.append([i, SLOTS[i]["weight"]])
	return int(weighted_pick(entries))


## Nudge the ball horizontally by re-anchoring it over a slot column.
func _place_ball(index: int) -> void:
	if _ball == null:
		return
	var span := 63.0
	_ball.position.x = (float(index) - 4.0) * span


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	var target := _pick_slot()
	set_result("Dropping...", UIKit.DIM)

	for i in range(12):
		_place_ball(randi() % SLOTS.size())
		await wait(0.05 + i * 0.012)
		if not is_inside_tree():
			return

	_place_ball(target)
	FX.pulse(_slot_panels[target], 1.3, 0.25)

	var mult := float(SLOTS[target]["mult"])
	var payout := staked * mult
	var credited := finish_round(payout, LOSS_RATE, mult >= 25.0)

	if payout > 0.0:
		set_result("Landed x%s  +%s" % [Fmt.chips(mult), Fmt.chips(payout)],
			UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if mult >= 25.0 and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("Straight down the middle.", UIKit.DIM)
