extends Minigame

## European single-zero roulette.
##
## The 37-pocket wheel with standard payouts gives a uniform 36/37 = 97.30% RTP
## on every bet type, so choosing a bet is purely a volatility decision rather
## than a maths decision. Lowest house edge in the game (2.70%).

const POCKETS := 37
const REDS: Array[int] = [
	1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36,
]

## type -> [display name, net odds, win probability]
const OUTSIDE_BETS: Array[Dictionary] = [
	{"type": "red",    "name": "RED",     "odds": 1, "wins": 18},
	{"type": "black",  "name": "BLACK",   "odds": 1, "wins": 18},
	{"type": "even",   "name": "EVEN",    "odds": 1, "wins": 18},
	{"type": "odd",    "name": "ODD",     "odds": 1, "wins": 18},
	{"type": "low",    "name": "1-18",    "odds": 1, "wins": 18},
	{"type": "high",   "name": "19-36",   "odds": 1, "wins": 18},
	{"type": "dozen1", "name": "1st 12",  "odds": 2, "wins": 12},
	{"type": "dozen2", "name": "2nd 12",  "odds": 2, "wins": 12},
	{"type": "dozen3", "name": "3rd 12",  "odds": 2, "wins": 12},
]

var selected_type := "red"
var selected_number := 0

var _wheel_label: Label
var _wheel_panel: PanelContainer
var _selection_label: Label
var _number_buttons: Dictionary = {}
var _outside_buttons: Dictionary = {}


func _init() -> void:
	game_id = "roulette"
	game_name = "Roulette"
	game_icon = "🎡"
	base_rtp = 36.0 / 37.0


static func is_red(n: int) -> bool:
	return REDS.has(n)


static func pocket_color(n: int) -> Color:
	if n == 0:
		return Color("1f7a4d")
	return Color("a33341") if is_red(n) else Color("22273a")


func _build_board(container: VBoxContainer) -> void:
	_wheel_panel = UIKit.panel(UIKit.PANEL_HI, 14, 2)
	_wheel_panel.custom_minimum_size = Vector2(0, 96)
	_wheel_label = UIKit.label("--", 56, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_wheel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wheel_panel.add_child(_wheel_label)
	container.add_child(_wheel_panel)

	_selection_label = UIKit.label("", 15, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	container.add_child(_selection_label)

	container.add_child(_build_number_grid())
	container.add_child(_build_outside_bets())
	_refresh_selection()


func _build_number_grid() -> Control:
	var row := UIKit.hbox(4)

	var zero := _make_number_button(0)
	zero.custom_minimum_size = Vector2(38, 100)
	row.add_child(zero)

	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	# Standard table layout: top row 3,6,9..., middle 2,5,8..., bottom 1,4,7...
	for offset in [3, 2, 1]:
		for col in range(12):
			grid.add_child(_make_number_button(col * 3 + offset))
	row.add_child(grid)
	return row


func _make_number_button(n: int) -> Button:
	var b := UIKit.button(str(n), 14)
	b.custom_minimum_size = Vector2(38, 32)
	var base := pocket_color(n)
	b.add_theme_stylebox_override("normal", UIKit.stylebox(base, 5, 1, base.lightened(0.15)))
	b.add_theme_stylebox_override("hover", UIKit.stylebox(base.lightened(0.25), 5, 1, UIKit.GOLD))
	b.add_theme_stylebox_override("pressed", UIKit.stylebox(base.lightened(0.4), 5, 1, UIKit.GOLD))
	b.pressed.connect(_select_number.bind(n))
	_number_buttons[n] = b
	return b


func _build_outside_bets() -> Control:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for d in OUTSIDE_BETS:
		var t := String(d["type"])
		var b := UIKit.button("%s  (%d:1)" % [d["name"], int(d["odds"])], 14)
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_outside.bind(t))
		_outside_buttons[t] = b
		grid.add_child(b)
	return grid


func _select_number(n: int) -> void:
	selected_type = "straight"
	selected_number = n
	_refresh_selection()


func _select_outside(t: String) -> void:
	selected_type = t
	_refresh_selection()


func _refresh_selection() -> void:
	for t in _outside_buttons:
		var b: Button = _outside_buttons[t]
		b.add_theme_color_override("font_color", UIKit.GOLD if t == selected_type else UIKit.TEXT)
	for n in _number_buttons:
		var nb: Button = _number_buttons[n]
		var picked := selected_type == "straight" and int(n) == selected_number
		nb.add_theme_color_override("font_color", UIKit.GOLD if picked else UIKit.TEXT)

	if _selection_label != null:
		_selection_label.text = "Betting: %s   -   pays %d:1   -   %s" % [
			_bet_display_name(), _bet_odds(), Fmt.percent(_bet_win_probability(), 1),
		]


func _bet_display_name() -> String:
	if selected_type == "straight":
		return "Straight up on %d" % selected_number
	for d in OUTSIDE_BETS:
		if String(d["type"]) == selected_type:
			return String(d["name"])
	return selected_type


func _bet_odds() -> int:
	if selected_type == "straight":
		return 35
	for d in OUTSIDE_BETS:
		if String(d["type"]) == selected_type:
			return int(d["odds"])
	return 1


func _bet_win_probability() -> float:
	if selected_type == "straight":
		return 1.0 / float(POCKETS)
	for d in OUTSIDE_BETS:
		if String(d["type"]) == selected_type:
			return float(d["wins"]) / float(POCKETS)
	return 0.0


func _bet_wins(n: int) -> bool:
	match selected_type:
		"straight":
			return n == selected_number
		"red":
			return is_red(n)
		"black":
			return n != 0 and not is_red(n)
		"even":
			return n != 0 and n % 2 == 0
		"odd":
			return n % 2 == 1
		"low":
			return n >= 1 and n <= 18
		"high":
			return n >= 19 and n <= 36
		"dozen1":
			return n >= 1 and n <= 12
		"dozen2":
			return n >= 13 and n <= 24
		"dozen3":
			return n >= 25 and n <= 36
	return false


func _show_pocket(n: int) -> void:
	_wheel_label.text = str(n)
	if _wheel_panel != null:
		_wheel_panel.add_theme_stylebox_override(
			"panel", UIKit.stylebox(pocket_color(n), 14, 2, pocket_color(n).lightened(0.3))
		)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	var result := randi() % POCKETS
	set_result("No more bets...", UIKit.DIM)

	# Decelerating ball: ticks get progressively slower.
	var delay := 0.03
	for i in range(22):
		_show_pocket(randi() % POCKETS)
		await wait(delay)
		if not is_inside_tree():
			return
		delay *= 1.12

	_show_pocket(result)
	FX.pulse(_wheel_panel, 1.06, 0.25)

	var won := _bet_wins(result)
	var payout := staked * float(_bet_odds() + 1) if won else 0.0
	var loss_probability := 1.0 - _bet_win_probability()

	if won and selected_type == "straight" and result == 0:
		Achievements.notify("zero_hero")

	var credited := finish_round(payout, loss_probability, false)

	if won:
		var multiplier := payout / staked
		set_result("%d wins!  +%s" % [result, Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, multiplier)
	elif credited <= 0.0:
		set_result("%d -- no win." % result, UIKit.DIM)
