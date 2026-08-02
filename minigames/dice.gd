extends Minigame

## Interactive two-dice table. Hold to shake, release to roll.
## Every bet priced to 95% RTP.

const BETS: Array[Dictionary] = [
	{"type": "under",   "name": "Under 7",    "wins": 15, "pays": 2.28,  "accent": "blue"},
	{"type": "over",    "name": "Over 7",     "wins": 15, "pays": 2.28,  "accent": "blue"},
	{"type": "seven",   "name": "Exactly 7",  "wins": 6,  "pays": 5.70,  "accent": "green"},
	{"type": "double",  "name": "Any Double", "wins": 6,  "pays": 5.70,  "accent": "green"},
	{"type": "snake",   "name": "Snake Eyes", "wins": 1,  "pays": 34.20, "accent": "gold"},
	{"type": "boxcars", "name": "Boxcars",    "wins": 1,  "pays": 34.20, "accent": "gold"},
]

var selected_type := "under"
var _dice: Array[TextureRect] = []
var _total_label: Label
var _bet_buttons: Dictionary = {}
var _hint: Label
var _shaking := false
var _awaiting := false
var _shake_t := 0.0
var _staked := 0.0


func _init() -> void:
	game_id = "dice"
	game_name = "Dice Table"
	game_icon = "game_dice"
	base_rtp = 0.95
	rules_text = "Pick a bet, hold ROLL to shake, release to throw."


func _build_board(container: VBoxContainer) -> void:
	var dice_panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(6)
	var row := UIKit.hbox(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(2):
		var tile := UIKit.icon_tile("die_%d" % (i + 1), 96, 74, UIKit.PANEL_SUNK)
		_dice.append(tile.get_child(0) as TextureRect)
		row.add_child(tile)
	col.add_child(row)
	_total_label = UIKit.label("", 19, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_total_label)
	dice_panel.add_child(col)
	container.add_child(dice_panel)
	container.add_child(_build_bet_grid())
	_hint = UIKit.label("Select a bet, then hold ROLL to shake.", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_hint)
	_refresh_selection()
	if play_button != null:
		play_button.text = "ROLL"


func _build_bet_grid() -> Control:
	var grid := UIKit.grid(3, 8, 8)
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
		"gold": return UIKit.GOLD
		"green": return UIKit.GREEN
	return UIKit.BLUE


func _select(t: String) -> void:
	if _awaiting or _shaking:
		return
	selected_type = t
	_refresh_selection()
	AudioManager.play_click()


func _bet_def() -> Dictionary:
	for d in BETS:
		if String(d["type"]) == selected_type:
			return d
	return BETS[0]


func _win_probability() -> float:
	return float(_bet_def()["wins"]) / 36.0


func _refresh_selection() -> void:
	UIKit.segmented_select(_bet_buttons, selected_type, UIKit.GOLD)


func _set_die(index: int, face: int) -> void:
	if index < _dice.size() and _dice[index] != null:
		_dice[index].texture = Icons.tex("die_%d" % clampi(face, 1, 6))


func _wins(a: int, b: int) -> bool:
	var total := a + b
	match selected_type:
		"under": return total < 7
		"over": return total > 7
		"seven": return total == 7
		"double": return a == b
		"snake": return total == 2
		"boxcars": return total == 12
	return false


func _process(delta: float) -> void:
	super._process(delta)
	if not _shaking:
		return
	_shake_t += delta
	if int(_shake_t * 20.0) % 2 == 0:
		_set_die(0, randi() % 6 + 1)
		_set_die(1, randi() % 6 + 1)


func _on_play_pressed() -> void:
	if _awaiting and not _shaking:
		_shaking = true
		_shake_t = 0.0
		_hint.text = "Release to throw!"
		AudioManager.play_dice_shake()
		return
	if _shaking:
		_shaking = false
		_awaiting = false
		return
	super._on_play_pressed()


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	_staked = bet
	_total_label.text = ""
	if auto:
		await _do_roll(true)
		return

	_awaiting = true
	_shaking = false
	_hint.text = "Hold ROLL to shake, release (press again) to throw."
	set_result("Shake the dice...", UIKit.GOLD, "game_dice")
	while _awaiting and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	await _do_roll(false)


func _do_roll(was_auto: bool) -> void:
	var a := randi() % 6 + 1
	var b := randi() % 6 + 1
	if was_auto:
		set_result("Rolling...", UIKit.DIM)
		AudioManager.play_dice_shake()
		var delay := 0.04
		for i in range(12):
			_set_die(0, randi() % 6 + 1)
			_set_die(1, randi() % 6 + 1)
			await wait(delay)
			if not is_inside_tree():
				return
			delay *= 1.1
	else:
		# Brief settle after shake
		for i in range(4):
			_set_die(0, randi() % 6 + 1)
			_set_die(1, randi() % 6 + 1)
			await wait(0.05)
			if not is_inside_tree():
				return

	_set_die(0, a)
	_set_die(1, b)
	_total_label.text = "Total %d" % (a + b)
	FX.pulse(_dice[0], 1.2, 0.2)
	FX.pulse(_dice[1], 1.2, 0.2)
	AudioManager.play_tick()

	var d := _bet_def()
	var won := _wins(a, b)
	var payout := _staked * float(d["pays"]) if won else 0.0
	var loss_probability := 1.0 - _win_probability()
	if won and selected_type == "snake":
		Achievements.notify("snake_eyes")
	var credited := finish_round(payout, loss_probability, false)
	if won:
		set_result("%s hits  +%s" % [d["name"], Fmt.chips(payout)], UIKit.GREEN, "check")
		celebrate(payout, float(d["pays"]))
	elif credited <= 0.0:
		set_result("Rolled %d - no win." % (a + b), UIKit.DIM)
	_hint.text = "Select a bet, then hold ROLL to shake."
	_awaiting = false
	_shaking = false


func stop_auto() -> void:
	super.stop_auto()
	_awaiting = false
	_shaking = false
