extends Minigame

## Coin pusher. A weighted table of coin returns, no physics.
##
## Solved to 90%: sum(weight * mult) / sum(weight) = 1350 / 1500.
## The previous table averaged 182%, and its lowest "win" returned exactly the
## stake — a push dressed up as a payout. Nothing here pays under 1.5x.

const OUTCOMES: Array[Dictionary] = [
	{"label": "Nothing fell", "mult": 0.0,  "weight": 1060},
	{"label": "A trickle",    "mult": 1.5,  "weight": 260},
	{"label": "A small drop", "mult": 3.0,  "weight": 120},
	{"label": "A good push",  "mult": 6.0,  "weight": 45},
	{"label": "An avalanche", "mult": 15.0, "weight": 12},
	{"label": "JACKPOT SHELF", "mult": 50.0, "weight": 3},
]

const LOSS_RATE := 0.706667

var _shelf: HBoxContainer
var _outcome_label: Label


func _init() -> void:
	game_id = "coin_pusher"
	game_name = "Coin Pusher"
	game_icon = "game_pusher"
	base_rtp = 0.90
	rules_text = "Drop a coin and hope the shelf gives. Pays about three times in ten."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(10)
	col.add_child(UIKit.label("SHELF", 11, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_shelf = UIKit.hbox(4)
	_shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	_shelf.custom_minimum_size = Vector2(0, 40)
	col.add_child(_shelf)
	_outcome_label = UIKit.label("Drop a coin", 17, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_outcome_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_outcome_label)
	panel.add_child(col)
	container.add_child(panel)
	container.add_child(_build_prize_table())
	_render_shelf(5)


func _build_prize_table() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(3, 14, 4)
	for o in OUTCOMES:
		if float(o["mult"]) <= 0.0:
			continue
		var row := UIKit.hbox(6)
		var l := UIKit.label(String(o["label"]), 12, UIKit.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.label("%sx" % Fmt.chips(float(o["mult"])), 12,
			UIKit.tier_color(float(o["mult"]))))
		grid.add_child(row)
	panel.add_child(grid)
	return panel


func _render_shelf(coins: int) -> void:
	for child in _shelf.get_children():
		_shelf.remove_child(child)
		child.queue_free()
	for i in range(coins):
		_shelf.add_child(UIKit.icon("chip_gold", 26))


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	set_result("Pushing...", UIKit.DIM)
	for i in range(8):
		_render_shelf(3 + randi() % 6)
		await wait(0.06)
		if not is_inside_tree():
			return

	var entries: Array = []
	for o in OUTCOMES:
		entries.append([o, o["weight"]])
	var outcome: Dictionary = weighted_pick(entries)

	var mult := float(outcome["mult"])
	_outcome_label.text = String(outcome["label"])
	_render_shelf(2 + int(mult))
	FX.pulse(_outcome_label, 1.2, 0.2)

	var payout := staked * mult
	var is_jackpot := mult >= 50.0
	var credited := finish_round(payout, LOSS_RATE, is_jackpot)

	if mult > 0.0:
		set_result("%s  +%s" % [String(outcome["label"]), Fmt.chips(payout)],
			UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if is_jackpot and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("Nothing fell.", UIKit.DIM)
