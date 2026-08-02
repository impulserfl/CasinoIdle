extends Minigame

## Casino fishing hole: cast a line, wait, reel in a weighted catch.
## Bigger fish pay more but are rarer. RTP ≈ 91%.

const CATCHES: Array[Dictionary] = [
	{"id": "boot",     "name": "Old Boot",     "icon": "👢", "mult": 0.0,  "weight": 22},
	{"id": "weed",     "name": "Seaweed",      "icon": "🌿", "mult": 0.3,  "weight": 18},
	{"id": "minnow",   "name": "Minnow",       "icon": "🐟", "mult": 1.0,  "weight": 20},
	{"id": "bass",     "name": "Bass",         "icon": "🐠", "mult": 2.0,  "weight": 14},
	{"id": "salmon",   "name": "Salmon",       "icon": "🍣", "mult": 4.0,  "weight": 10},
	{"id": "tuna",     "name": "Tuna",         "icon": "🐋", "mult": 8.0,  "weight": 7},
	{"id": "shark",    "name": "Shark",        "icon": "🦈", "mult": 15.0, "weight": 5},
	{"id": "treasure", "name": "Treasure",     "icon": "💎", "mult": 40.0, "weight": 3},
	{"id": "kraken",   "name": "KRAKEN",       "icon": "🦑", "mult": 100.0,"weight": 1},
]

var _water_label: Label
var _catch_label: Label
var _depth := 1  # 0 shallow, 1 mid, 2 deep — shifts weights
var _depth_buttons: Dictionary = {}


func _init() -> void:
	game_id = "fishing"
	game_name = "Fishing"
	game_icon = "🎣"
	base_rtp = 0.91


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)
	_water_label = UIKit.label("🌊🌊🌊", 36, UIKit.BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	_catch_label = UIKit.label("Cast your line", 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_water_label)
	col.add_child(_catch_label)
	panel.add_child(col)
	container.add_child(panel)

	var row := UIKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in [[0, "Shallow"], [1, "Mid"], [2, "Deep"]]:
		var b := UIKit.button(String(entry[1]), 15)
		b.custom_minimum_size = Vector2(100, 40)
		b.pressed.connect(_set_depth.bind(int(entry[0])))
		_depth_buttons[int(entry[0])] = b
		row.add_child(b)
	container.add_child(row)
	container.add_child(UIKit.wrapped(
		"Deeper water = rarer big catches, more boots. Kraken pays 100×.", 12, UIKit.DIM))
	_refresh_depth()


func _set_depth(d: int) -> void:
	_depth = d
	_refresh_depth()
	AudioManager.play_click()


func _refresh_depth() -> void:
	for d in _depth_buttons:
		var b: Button = _depth_buttons[d]
		b.add_theme_color_override("font_color", UIKit.GOLD if int(d) == _depth else UIKit.TEXT)


func _roll_catch() -> Dictionary:
	var entries: Array = []
	for c in CATCHES:
		var w: float = float(c["weight"])
		var mult: float = float(c["mult"])
		# Shallow: favor small fish. Deep: favor junk + jackpots.
		if _depth == 0:
			if mult <= 2.0:
				w *= 1.4
			elif mult >= 15.0:
				w *= 0.5
		elif _depth == 2:
			if mult <= 0.3:
				w *= 1.3
			elif mult >= 15.0:
				w *= 1.6
		entries.append([c, w])
	return weighted_pick(entries)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	set_result("Waiting...", UIKit.DIM)
	_catch_label.text = "..."
	for i in range(10):
		_water_label.text = "🌊".repeat((i % 3) + 1) + " 🎣"
		await wait(0.07)
		if not is_inside_tree():
			return

	var got: Dictionary = _roll_catch()
	_catch_label.text = "%s  %s" % [got["icon"], got["name"]]
	FX.pulse(_catch_label, 1.25, 0.25)

	var mult: float = float(got["mult"])
	var payout := staked * mult
	var loss_p := 0.40
	var credited := finish_round(payout, loss_p, mult >= 40.0)

	if mult >= 100.0:
		Achievements.notify("kraken")

	if mult > 0.0:
		set_result("Caught %s!  +%s" % [got["name"], Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, mult)
	elif credited <= 0.0:
		set_result("%s — nothing valuable." % got["name"], UIKit.DIM)
