extends Minigame

## Three-reel weighted slot machine.
##
## Reels are weighted (cherries common, sevens rare) rather than uniform, which
## lets the jackpot sit at 1-in-100k while still paying on 45% of spins.
## Verified by full 512-outcome enumeration:
##   RTP 93.86%  |  hit rate 45.35%  |  three sevens 1 in 100,545

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

const LOSS_RATE := 0.5465  # P(no payout), from enumeration

var _reels: Array[TextureRect] = []


func _init() -> void:
	game_id = "slots"
	game_name = "Slot Machine"
	game_icon = "game_slots"
	base_rtp = 0.9386
	rules_text = "Three of a kind pays big. Two of a kind pays a little."


func _build_board(container: VBoxContainer) -> void:
	var reel_panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var reel_row := UIKit.hbox(20)
	reel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(3):
		var slot := UIKit.icon_tile(String(SYMBOLS[i]["icon"]), 104, 74, UIKit.PANEL_SUNK)
		_reels.append(slot.get_child(0) as TextureRect)
		reel_row.add_child(slot)
	reel_panel.add_child(reel_row)
	container.add_child(reel_panel)
	container.add_child(_build_paytable())


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
	set_result("Spinning...", UIKit.DIM)

	# Reels stop left to right so the last one carries the tension.
	for stopped in range(4):
		var ticks := 8 if stopped == 0 else 4
		for t in range(ticks):
			for r in range(stopped, 3):
				_set_reel(r, String(SYMBOLS[randi() % SYMBOLS.size()]["icon"]))
			await wait(0.045)
			if not is_inside_tree():
				return
		if stopped < 3:
			_set_reel(stopped, String(final_symbols[stopped]["icon"]))
			FX.pulse(_reels[stopped], 1.18, 0.18)
			if not auto or Settings.auto_spin_sfx:
				AudioManager.play_tick()

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
			set_result("Win  +%s  (x%s)" % [Fmt.chips(payout), Fmt.chips(multiplier)],
				UIKit.GREEN, "check")
		celebrate(payout, multiplier)
	elif credited <= 0.0:
		set_result("No win.", UIKit.DIM)


## Bet multiplier for a spin: three of a kind, else the best pair.
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
