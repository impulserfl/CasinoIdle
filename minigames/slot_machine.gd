extends Minigame

## Three-reel weighted slot machine.
##
## Reels are weighted (cherries common, sevens rare) rather than uniform, which
## lets the jackpot sit at 1-in-100k while still paying something on 45% of
## spins. Table verified by full 512-outcome enumeration:
##   RTP 93.86%  |  hit rate 45.35%  |  three sevens 1 in 100,545

const SYMBOLS: Array[Dictionary] = [
	{"id": "cherry", "icon": "🍒", "weight": 24, "triple": 8.0,    "pair": 0.40},
	{"id": "lemon",  "icon": "🍋", "weight": 20, "triple": 12.0,   "pair": 0.50},
	{"id": "orange", "icon": "🍊", "weight": 16, "triple": 19.0,   "pair": 0.65},
	{"id": "grape",  "icon": "🍇", "weight": 12, "triple": 33.0,   "pair": 1.00},
	{"id": "bell",   "icon": "🔔", "weight": 9,  "triple": 67.0,   "pair": 1.50},
	{"id": "star",   "icon": "⭐", "weight": 6,  "triple": 150.0,  "pair": 3.00},
	{"id": "clover", "icon": "🍀", "weight": 4,  "triple": 400.0,  "pair": 8.00},
	{"id": "seven",  "icon": "7️⃣", "weight": 2,  "triple": 2000.0, "pair": 30.00},
]

const LOSS_RATE := 0.5465  # P(no payout), from enumeration

var _reels: Array[Label] = []


func _init() -> void:
	game_id = "slots"
	game_name = "Slot Machine"
	game_icon = "🎰"
	base_rtp = 0.9386


func _build_board(container: VBoxContainer) -> void:
	var reel_panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var reel_row := UIKit.hbox(24)
	reel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(3):
		var l := UIKit.icon_label(String(SYMBOLS[i]["icon"]), 68)
		l.custom_minimum_size = Vector2(96, 104)
		_reels.append(l)
		reel_row.add_child(l)
	reel_panel.add_child(reel_row)
	container.add_child(reel_panel)
	container.add_child(_build_paytable())


func _build_paytable() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	for s in SYMBOLS:
		var entry := UIKit.hbox(6)
		entry.add_child(UIKit.label("%s%s%s" % [s["icon"], s["icon"], s["icon"]], 15))
		entry.add_child(UIKit.label("x%s" % Fmt.chips(float(s["triple"])), 14, UIKit.GOLD))
		grid.add_child(entry)
	panel.add_child(grid)
	return panel


func _random_symbol() -> Dictionary:
	var entries: Array = []
	for s in SYMBOLS:
		entries.append([s, s["weight"]])
	return weighted_pick(entries)


func _random_icon() -> String:
	return String(SYMBOLS[randi() % SYMBOLS.size()]["icon"])


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	var final_symbols: Array[Dictionary] = [_random_symbol(), _random_symbol(), _random_symbol()]

	set_result("Spinning...", UIKit.DIM)

	# Reels stop left-to-right so the last one carries the tension.
	for stopped in range(4):
		var ticks := 8 if stopped == 0 else 4
		for t in range(ticks):
			for r in range(stopped, 3):
				if r < _reels.size():
					_reels[r].text = _random_icon()
			await wait(0.045)
			if not is_inside_tree():
				return
		if stopped < 3:
			_reels[stopped].text = String(final_symbols[stopped]["icon"])
			FX.pulse(_reels[stopped], 1.18, 0.18)

	var multiplier := _evaluate(final_symbols)
	var payout := staked * multiplier
	var is_jackpot := multiplier >= float(SYMBOLS[SYMBOLS.size() - 1]["triple"])

	if is_jackpot:
		Achievements.notify("jackpot")

	var credited := finish_round(payout, LOSS_RATE, is_jackpot)

	if payout > 0.0:
		if is_jackpot:
			set_result("★ JACKPOT ★  %s chips!" % Fmt.chips(payout), UIKit.GOLD)
			FX.flash(self, UIKit.GOLD)
		else:
			set_result("Win!  +%s  (x%s)" % [Fmt.chips(payout), Fmt.chips(multiplier)], UIKit.GREEN)
		celebrate(payout, multiplier)
	elif credited <= 0.0:
		set_result("No win.", UIKit.DIM)


## Returns the bet multiplier for a spin: three of a kind, else best pair.
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
