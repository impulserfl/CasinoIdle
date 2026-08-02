extends Minigame

## Simplified coin pusher: drop a coin, shelf may nudge prizes off.
## Outcome is a weighted table of coin returns. Feels like a pusher without physics.
## RTP ≈ 90% (skill-machine house edge).

const OUTCOMES: Array[Dictionary] = [
	{"label": "Nothing", "mult": 0.0, "weight": 38},
	{"label": "1 coin", "mult": 1.0, "weight": 28},
	{"label": "2 coins", "mult": 2.0, "weight": 16},
	{"label": "3 coins", "mult": 3.0, "weight": 9},
	{"label": "5 coins", "mult": 5.0, "weight": 5},
	{"label": "10 coins", "mult": 10.0, "weight": 3},
	{"label": "JACKPOT", "mult": 40.0, "weight": 1},
]

var _shelf: Label
var _result_line: Label


func _init() -> void:
	game_id = "coin_pusher"
	game_name = "Coin Pusher"
	game_icon = "🪙"
	base_rtp = 0.90


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 12, 2)
	var col := UIKit.vbox(6)
	_shelf = UIKit.label("▓▓  ▓  ▓▓  ▓   ▓▓", 22, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_result_line = UIKit.label("Drop a coin", 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(UIKit.label("SHELF", 12, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_shelf)
	col.add_child(_result_line)
	panel.add_child(col)
	container.add_child(panel)
	container.add_child(UIKit.wrapped("Drop coins onto the shelf. Sometimes a cascade pays out.", 12, UIKit.DIM))


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return
	var staked := bet
	set_result("Pushing...", UIKit.DIM)
	for i in range(8):
		_shelf.text = "▓ ".repeat(randi() % 6 + 3)
		await wait(0.06)
		if not is_inside_tree():
			return
	var entries: Array = []
	for o in OUTCOMES:
		entries.append([o, o["weight"]])
	var outcome: Dictionary = weighted_pick(entries)
	_result_line.text = String(outcome["label"])
	FX.pulse(_result_line, 1.2, 0.2)
	var mult: float = float(outcome["mult"])
	var payout := staked * mult
	var credited := finish_round(payout, 0.38, mult >= 40.0)
	if mult > 0.0:
		set_result("%s  +%s" % [outcome["label"], Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, mult)
	elif credited <= 0.0:
		set_result("Nothing fell.", UIKit.DIM)
