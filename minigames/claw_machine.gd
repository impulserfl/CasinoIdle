extends Minigame

## Claw machine. Weighted prizes, arcade house edge.
##
## The prize ladder used to average 382% RTP — holding AUTO here multiplied a
## bankroll by nearly four every grab. The ladder is kept and the miss weight
## is solved to land the table on 88%:
##
##   sum(weight * mult) / sum(weight) = 3490 / 3966 = 0.8800
##
## No prize pays under 1.5x, so a successful grab always beats the token.

const PRIZES: Array[Dictionary] = [
	{"name": "Nothing", "icon": "prize_miss",    "mult": 0.0,   "weight": 3144},
	{"name": "Candy",   "icon": "prize_candy",   "mult": 1.5,   "weight": 500},
	{"name": "Plush",   "icon": "prize_plush",   "mult": 3.0,   "weight": 200},
	{"name": "Watch",   "icon": "prize_watch",   "mult": 8.0,   "weight": 80},
	{"name": "Phone",   "icon": "prize_phone",   "mult": 20.0,  "weight": 30},
	{"name": "Gold Bar", "icon": "prize_gold",   "mult": 60.0,  "weight": 10},
	{"name": "Diamond", "icon": "prize_diamond", "mult": 150.0, "weight": 2},
]

const LOSS_RATE := 0.792738

var _claw: TextureRect
var _prize_icon: TextureRect
var _prize_name: Label


func _init() -> void:
	game_id = "claw"
	game_name = "Claw Machine"
	game_icon = "game_claw"
	base_rtp = 0.88
	rules_text = "About one grab in five catches something. Arcade odds - the worst on the floor."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)
	_claw = UIKit.icon("game_claw", 62)
	_claw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_claw)

	var tile := UIKit.icon_tile("prize_miss", 96, 66, UIKit.PANEL_SUNK)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prize_icon = tile.get_child(0) as TextureRect
	col.add_child(tile)

	_prize_name = UIKit.label("Drop the claw", 17, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_prize_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_prize_name)
	panel.add_child(col)
	container.add_child(panel)
	container.add_child(_build_prize_table())


func _build_prize_table() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(3, 14, 4)
	for p in PRIZES:
		if float(p["mult"]) <= 0.0:
			continue
		var row := UIKit.hbox(6)
		row.add_child(UIKit.icon(String(p["icon"]), 20))
		var l := UIKit.label(String(p["name"]), 12, UIKit.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.label("%sx" % Fmt.chips(float(p["mult"])), 12,
			UIKit.tier_color(float(p["mult"]))))
		grid.add_child(row)
	panel.add_child(grid)
	return panel


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	set_result("Grabbing...", UIKit.DIM)
	_prize_name.text = "..."
	for i in range(10):
		_prize_icon.texture = Icons.tex(String(PRIZES[randi() % PRIZES.size()]["icon"]))
		await wait(0.05)
		if not is_inside_tree():
			return

	var entries: Array = []
	for p in PRIZES:
		entries.append([p, p["weight"]])
	var got: Dictionary = weighted_pick(entries)

	_prize_icon.texture = Icons.tex(String(got["icon"]))
	_prize_name.text = String(got["name"])
	FX.pulse(_prize_icon, 1.25, 0.25)

	var mult := float(got["mult"])
	var payout := staked * mult
	var is_jackpot := mult >= 60.0
	var credited := finish_round(payout, LOSS_RATE, is_jackpot)

	if mult > 0.0:
		set_result("Got the %s  +%s" % [String(got["name"]), Fmt.chips(payout)],
			UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if is_jackpot and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("The claw slips.", UIKit.DIM)
