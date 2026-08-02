extends Minigame

## Cast a line and reel in a weighted catch.
##
## Depth shifts the weights, so each depth carries its own junk weight, solved
## so all three return exactly 91%. Shallow hits often for small fish; deep
## hits rarely but holds most of the Kraken odds. Same expected return either
## way — the old table ran between 254% and 531% depending on where you cast.

const CATCHES: Array[Dictionary] = [
	{"name": "Old boot", "icon": "fish_junk",     "mult": 0.0},
	{"name": "Minnow",   "icon": "fish_minnow",   "mult": 1.5},
	{"name": "Bass",     "icon": "fish_bass",     "mult": 3.0},
	{"name": "Salmon",   "icon": "fish_salmon",   "mult": 6.0},
	{"name": "Tuna",     "icon": "fish_tuna",     "mult": 12.0},
	{"name": "Shark",    "icon": "fish_shark",    "mult": 30.0},
	{"name": "Treasure", "icon": "fish_treasure", "mult": 100.0},
	{"name": "KRAKEN",   "icon": "fish_kraken",   "mult": 400.0},
]

## depth -> weights aligned with CATCHES, junk first.
const DEPTH_WEIGHTS: Dictionary = {
	0: [187259, 45000, 22500, 7000, 3000, 400, 100, 16],
	1: [206347, 30000, 15000, 7000, 3000, 1000, 250, 40],
	2: [299885, 18000, 9000, 7000, 3000, 2500, 625, 100],
}

const DEPTH_LOSS_RATE: Dictionary = {
	0: 0.705908,
	1: 0.785704,
	2: 0.881727,
}

const DEPTH_NAMES: Array[String] = ["Shallow", "Mid", "Deep"]

var _depth := 1
var _catch_icon: TextureRect
var _catch_label: Label
var _depth_buttons: Dictionary = {}


func _init() -> void:
	game_id = "fishing"
	game_name = "Fishing"
	game_icon = "game_fishing"
	base_rtp = 0.91
	rules_text = "Depth trades hit rate for size. All three return the same 91%."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)
	var tile := UIKit.icon_tile("fish_junk", 108, 78, UIKit.PANEL_SUNK)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_catch_icon = tile.get_child(0) as TextureRect
	col.add_child(tile)
	_catch_label = UIKit.label("Cast your line", 17, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_catch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_catch_label)
	panel.add_child(col)
	container.add_child(panel)

	var row := UIKit.segmented([0, 1, 2], DEPTH_NAMES, _depth_buttons, UIKit.BLUE, 104, 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in _depth_buttons:
		_depth_buttons[id].pressed.connect(_set_depth.bind(int(id)))
	container.add_child(row)
	container.add_child(_build_catch_table())
	_refresh_depth()


func _build_catch_table() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(4, 12, 4)
	for c in CATCHES:
		if float(c["mult"]) <= 0.0:
			continue
		var row := UIKit.hbox(5)
		row.add_child(UIKit.icon(String(c["icon"]), 20))
		var l := UIKit.label(String(c["name"]), 12, UIKit.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.label("%sx" % Fmt.chips(float(c["mult"])), 12,
			UIKit.tier_color(float(c["mult"]))))
		grid.add_child(row)
	panel.add_child(grid)
	return panel


func _set_depth(d: int) -> void:
	_depth = d
	_refresh_depth()
	AudioManager.play_click()


func _refresh_depth() -> void:
	UIKit.segmented_select(_depth_buttons, _depth, UIKit.BLUE)


func _roll_catch() -> Dictionary:
	var weights: Array = DEPTH_WEIGHTS[_depth]
	var entries: Array = []
	for i in range(CATCHES.size()):
		entries.append([CATCHES[i], float(weights[i])])
	return weighted_pick(entries)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	set_result("Waiting for a bite...", UIKit.DIM)
	_catch_label.text = "..."
	for i in range(10):
		_catch_icon.texture = Icons.tex("ball" if i % 2 == 0 else "game_fishing")
		await wait(0.07)
		if not is_inside_tree():
			return

	var got := _roll_catch()
	_catch_icon.texture = Icons.tex(String(got["icon"]))
	_catch_label.text = String(got["name"])
	FX.pulse(_catch_icon, 1.25, 0.25)

	var mult := float(got["mult"])
	var payout := staked * mult
	var is_jackpot := mult >= 100.0
	var credited := finish_round(payout, float(DEPTH_LOSS_RATE[_depth]), is_jackpot)

	if mult >= 400.0:
		Achievements.notify("kraken")

	if mult > 0.0:
		set_result("Landed a %s  +%s" % [String(got["name"]), Fmt.chips(payout)],
			UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if is_jackpot and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("Just an old boot.", UIKit.DIM)
