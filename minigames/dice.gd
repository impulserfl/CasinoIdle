extends Minigame

## Two-dice table.
##
## Every bet is priced to exactly 95% RTP, so the choice between them is a pure
## volatility trade -- grind 2.28x on Under 7 or chase 34.2x on snake eyes for
## the same expected return.

const FACES: Array[String] = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]

## wins = number of the 36 two-dice outcomes that win this bet.
const BETS: Array[Dictionary] = [
	{"type": "under",  "name": "Under 7",    "wins": 15, "pays": 2.28,  "accent": "blue"},
	{"type": "over",   "name": "Over 7",     "wins": 15, "pays": 2.28,  "accent": "blue"},
	{"type": "seven",  "name": "Exactly 7",  "wins": 6,  "pays": 5.70,  "accent": "green"},
	{"type": "double", "name": "Any Double", "wins": 6,  "pays": 5.70,  "accent": "green"},
	{"type": "snake",  "name": "Snake Eyes", "wins": 1,  "pays": 34.20, "accent": "gold"},
	{"type": "boxcars", "name": "Boxcars",   "wins": 1,  "pays": 34.20, "accent": "gold"},
]

var selected_type := "under"

var _die_labels: Array[Label] = []
var _total_label: Label
var _bet_buttons: Dictionary = {}


func _init() -> void:
	game_id = "dice"
	game_name = "Dice Table"
	game_icon = "🎲"
	base_rtp = 0.95


func _build_board(container: VBoxContainer) -> void:
	var dice_panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(4)

	var row := UIKit.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(2):
		var l := UIKit.icon_label(FACES[i], 76)
		l.custom_minimum_size = Vector2(96, 96)
		_die_labels.append(l)
		row.add_child(l)
	col.add_child(row)

	_total_label = UIKit.label("", 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_total_label)
	dice_panel.add_child(col)
	container.add_child(dice_panel)

	container.add_child(_build_bet_grid())
	_refresh_selection()


func _build_bet_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for d in BETS:
		var t := String(d["type"])
		var b := UIKit.button("%s\n%.2fx" % [d["name"], float(d["pays"])], 15, _accent_of(d))
		b.custom_minimum_size = Vector2(0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select.bind(t))
		_bet_buttons[t] = b
		grid.add_child(b)
	return grid


func _accent_of(d: Dictionary) -> Color:
	match String(d["accent"]):
		"gold":
			return UIKit.GOLD
		"green":
			return UIKit.GREEN
	return UIKit.BLUE


func _select(t: String) -> void:
	selected_type = t
	_refresh_selection()


func _bet_def() -> Dictionary:
	for d in BETS:
		if String(d["type"]) == selected_type:
			return d
	return BETS[0]


func _win_probability() -> float:
	return float(_bet_def()["wins"]) / 36.0


func _refresh_selection() -> void:
	for t in _bet_buttons:
		var b: Button = _bet_buttons[t]
		b.add_theme_color_override("font_color", UIKit.GOLD if t == selected_type else UIKit.TEXT)


func _wins(a: int, b: int) -> bool:
	var total := a + b
	match selected_type:
		"under":
			return total < 7
		"over":
			return total > 7
		"seven":
			return total == 7
		"double":
			return a == b
		"snake":
			return total == 2
		"boxcars":
			return total == 12
	return false


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	var a := randi() % 6 + 1
	var b := randi() % 6 + 1

	set_result("Rolling...", UIKit.DIM)
	_total_label.text = ""

	var delay := 0.04
	for i in range(14):
		_die_labels[0].text = FACES[randi() % 6]
		_die_labels[1].text = FACES[randi() % 6]
		await wait(delay)
		if not is_inside_tree():
			return
		delay *= 1.11

	_die_labels[0].text = FACES[a - 1]
	_die_labels[1].text = FACES[b - 1]
	_total_label.text = "Total: %d" % (a + b)
	FX.pulse(_die_labels[0], 1.2, 0.2)
	FX.pulse(_die_labels[1], 1.2, 0.2)

	var d := _bet_def()
	var won := _wins(a, b)
	var payout := staked * float(d["pays"]) if won else 0.0
	var loss_probability := 1.0 - _win_probability()

	if won and selected_type == "snake":
		Achievements.notify("snake_eyes")

	var credited := finish_round(payout, loss_probability, false)

	if won:
		set_result("%s hits!  +%s" % [d["name"], Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, float(d["pays"]))
	elif credited <= 0.0:
		set_result("Rolled %d -- no win." % (a + b), UIKit.DIM)
