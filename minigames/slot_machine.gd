extends Minigame

## Interactive three-reel slots — press STOP as each reel lands.
## Final symbols are still drawn from the verified weighted table (RTP 93.86%).

const SYMBOLS: Array[Dictionary] = [
	{"id": "cherry",  "icon": "reel_cherry",  "weight": 24, "triple": 8.0,    "pair": 0.40},
	{"id": "lemon",   "icon": "reel_lemon",   "weight": 20, "triple": 12.0,   "pair": 0.50},
	{"id": "bar",     "icon": "reel_bar",     "weight": 16, "triple": 19.0,   "pair": 0.65},
	{"id": "diamond", "icon": "reel_diamond", "weight": 12, "triple": 33.0,   "pair": 1.00},
	{"id": "bell",    "icon": "reel_bell",    "weight": 9,  "triple": 67.0,   "pair": 1.50},
	{"id": "star",    "icon": "reel_star",    "weight": 6,  "triple": 150.0,  "pair": 3.00},
	{"id": "clover",  "icon": "reel_clover",  "weight": 4,  "triple": 400.0,  "pair": 8.00},
	{"id": "seven",   "icon": "reel_seven",   "weight": 2,  "triple": 2000.0, "pair": 30.00},
]

const LOSS_RATE := 0.5465

var _reels: Array[TextureRect] = []
var _stop_buttons: Array[Button] = []
var _spinning := false
var _stop_request := -1
var _active_reel := 0


func _init() -> void:
	game_id = "slots"
	game_name = "Slot Machine"
	game_icon = "game_slots"
	base_rtp = 0.9386
	rules_text = "Spin, then STOP each reel. Three of a kind pays big."


func _build_board(container: VBoxContainer) -> void:
	var reel_panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(10)
	var reel_row := UIKit.hbox(20)
	reel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(3):
		var slot := UIKit.icon_tile(String(SYMBOLS[i]["icon"]), 104, 74, UIKit.PANEL_SUNK)
		_reels.append(slot.get_child(0) as TextureRect)
		reel_row.add_child(slot)
	col.add_child(reel_row)

	var stop_row := UIKit.hbox(20)
	stop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(3):
		var b := UIKit.button("STOP %d" % (i + 1), 14, UIKit.ORANGE)
		b.custom_minimum_size = Vector2(96, 36)
		b.disabled = true
		b.pressed.connect(_request_stop.bind(i))
		_stop_buttons.append(b)
		stop_row.add_child(b)
	col.add_child(stop_row)
	reel_panel.add_child(col)
	container.add_child(reel_panel)
	container.add_child(_build_paytable())
	if play_button != null:
		play_button.text = "SPIN"


func _build_paytable() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(4, 16, 4)
	for s in SYMBOLS:
		var entry := UIKit.hbox(6)
		for i in range(3):
			entry.add_child(UIKit.icon(String(s["icon"]), 16))
		entry.add_child(UIKit.label("x%s" % Fmt.chips(float(s["triple"])), 13, UIKit.GOLD))
		grid.add_child(entry)
	panel.add_child(grid)
	return panel


func _request_stop(index: int) -> void:
	if _spinning and index == _active_reel:
		_stop_request = index
		AudioManager.play_tick()


func _random_symbol() -> Dictionary:
	var entries: Array = []
	for s in SYMBOLS:
		entries.append([s, s["weight"]])
	return weighted_pick(entries)


func _set_reel(index: int, icon_name: String) -> void:
	if index < _reels.size() and _reels[index] != null:
		_reels[index].texture = Icons.tex(icon_name)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	var final_symbols: Array[Dictionary] = [_random_symbol(), _random_symbol(), _random_symbol()]
	set_result("Spinning — hit STOP on each reel", UIKit.DIM)
	_spinning = true
	AudioManager.play_spin()

	for r in range(3):
		_active_reel = r
		_stop_request = -1
		for i in range(3):
			_stop_buttons[i].disabled = (i != r) or auto

		var ticks := 0
		var min_ticks := 6 if not auto else 4
		var max_ticks := 40
		while ticks < max_ticks:
			_set_reel(r, String(SYMBOLS[randi() % SYMBOLS.size()]["icon"]))
			if ticks > 0 and ticks % 2 == 0 and (not auto or Settings.auto_spin_sfx):
				AudioManager.play_tick()
			await wait(0.04)
			if not is_inside_tree():
				return
			ticks += 1
			if auto and ticks >= min_ticks:
				break
			if not auto and _stop_request == r and ticks >= min_ticks:
				break
			# Auto-stop if player never presses
			if not auto and ticks >= 28:
				break

		_set_reel(r, String(final_symbols[r]["icon"]))
		FX.pulse(_reels[r], 1.18, 0.18)
		AudioManager.play_reel_stop()
		_stop_buttons[r].disabled = true

	_spinning = false
	for b in _stop_buttons:
		b.disabled = true

	var multiplier := _evaluate(final_symbols)
	var payout := staked * multiplier
	var is_jackpot := multiplier >= float(SYMBOLS[SYMBOLS.size() - 1]["triple"])

if is_jackpot:
		Achievements.notify("jackpot")
		if Settings.stop_auto_on_jackpot:
			stop_auto()

	var credited := finish_round(payout, LOSS_RATE, is_jackpot)
	if payout > 0.0:
		if is_jackpot:
			set_result("JACKPOT!  %s chips" % Fmt.chips(payout), UIKit.GOLD, "trophy")
			FX.flash(self, UIKit.GOLD)
		else:
			set_result("Win  +%s  (x%s)" % [Fmt.chips(payout), Fmt.chips(multiplier)], UIKit.GREEN, "check")
		celebrate(payout, multiplier)
	elif credited <= 0.0:
		set_result("No win.", UIKit.DIM)


func _evaluate(spin: Array[Dictionary]) -> float:
	var a := String(spin[0]["id"])
	var b := String(spin[1]["id"])
	var c := String(spin[2]["id"])
	if a == b and b == c:
		return float(spin[0]["triple"])
	var paired_index := -1
	if a == b:
		paired_index = 0
	elif b == c:
		paired_index = 1
	elif a == c:
		paired_index = 0
	if paired_index >= 0:
		return float(spin[paired_index]["pair"])
	return 0.0
