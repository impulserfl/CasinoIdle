extends Minigame

## Claw machine: attempt to grab a prize. Success chance scales slightly with bet tier display only.
## Weighted prizes. RTP ≈ 88% (arcade tax).

const PRIZES: Array[Dictionary] = [
	{"name": "Miss", "mult": 0.0, "weight": 45},
	{"name": "Candy", "mult": 0.5, "weight": 20},
	{"name": "Plush", "mult": 2.0, "weight": 15},
	{"name": "Watch", "mult": 5.0, "weight": 10},
	{"name": "Phone", "mult": 12.0, "weight": 6},
	{"name": "Gold Bar", "mult": 40.0, "weight": 3},
	{"name": "DIAMOND", "mult": 100.0, "weight": 1},
]

var _claw: Label
var _prize: Label


func _init() -> void:
	game_id = "claw"
	game_name = "Claw Machine"
	game_icon = "🦾"
	base_rtp = 0.88


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 12, 2)
	var col := UIKit.vbox(8)
	_claw = UIKit.label("🦾", 48, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_prize = UIKit.label("?", 28, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_claw)
	col.add_child(_prize)
	panel.add_child(col)
	container.add_child(panel)
	container.add_child(UIKit.wrapped("Drop the claw. Prizes range from candy to diamonds.", 12, UIKit.DIM))


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return
	var staked := bet
	set_result("Grabbing...", UIKit.DIM)
	for i in range(10):
		_claw.text = "  ".repeat(i % 5) + "🦾"
		await wait(0.05)
		if not is_inside_tree():
			return
	var entries: Array = []
	for p in PRIZES:
		entries.append([p, p["weight"]])
	var got: Dictionary = weighted_pick(entries)
	_prize.text = String(got["name"])
	FX.pulse(_prize, 1.25, 0.25)
	var mult: float = float(got["mult"])
	var payout := staked * mult
	var credited := finish_round(payout, 0.45, mult >= 40.0)
	if mult > 0.0:
		set_result("Got %s!  +%s" % [got["name"], Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, mult)
	elif credited <= 0.0:
		set_result("Missed.", UIKit.DIM)
