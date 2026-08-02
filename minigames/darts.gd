extends Minigame

## Pub-style darts: aim at a ring (Bull / Treble / Double / Outer / Miss).
## Weighted hits. RTP ≈ 92%.

const ZONES: Array[Dictionary] = [
	{"id": "bull",   "name": "BULL",   "mult": 10.0, "weight": 4,  "icon": "🔴"},
	{"id": "treble", "name": "TREBLE", "mult": 3.0,  "weight": 12, "icon": "🎯"},
	{"id": "double", "name": "DOUBLE", "mult": 2.0,  "weight": 18, "icon": "⭕"},
	{"id": "outer",  "name": "OUTER",  "mult": 1.0,  "weight": 28, "icon": "⚪"},
	{"id": "miss",   "name": "MISS",   "mult": 0.0,  "weight": 38, "icon": "💨"},
]

var _board_label: Label
var _aim := "treble"
var _aim_buttons: Dictionary = {}


func _init() -> void:
	game_id = "darts"
	game_name = "Darts"
	game_icon = "🎯"
	base_rtp = 0.92


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)
	_board_label = UIKit.label("🎯", 64, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_board_label)
	col.add_child(UIKit.label("Aim for a ring — higher pays less often.", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(col)
	container.add_child(panel)

	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for z in ZONES:
		if String(z["id"]) == "miss":
			continue
		var id := String(z["id"])
		var b := UIKit.button("%s  x%s" % [z["name"], Fmt.chips(float(z["mult"]))], 13)
		b.custom_minimum_size = Vector2(100, 40)
		b.pressed.connect(_select_aim.bind(id))
		_aim_buttons[id] = b
		row.add_child(b)
	container.add_child(row)
	container.add_child(UIKit.wrapped("You aim at a zone; the dart still drifts. Bull is 10×.", 12, UIKit.DIM))
	_refresh_aim()


func _select_aim(id: String) -> void:
	_aim = id
	_refresh_aim()
	AudioManager.play_click()


func _refresh_aim() -> void:
	for id in _aim_buttons:
		var b: Button = _aim_buttons[id]
		b.add_theme_color_override("font_color", UIKit.GOLD if id == _aim else UIKit.TEXT)


func _throw_result() -> Dictionary:
	var entries: Array = []
	for z in ZONES:
		var w: float = float(z["weight"])
		if String(z["id"]) == _aim:
			w *= 1.8
		entries.append([z, w])
	return weighted_pick(entries)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	set_result("Throwing...", UIKit.DIM)
	for i in range(8):
		_board_label.text = [".", "•", "●", "🎯"][i % 4]
		await wait(0.05)
		if not is_inside_tree():
			return

	var hit: Dictionary = _throw_result()
	_board_label.text = "%s  %s" % [hit["icon"], hit["name"]]
	FX.pulse(_board_label, 1.2, 0.25)

	var mult: float = float(hit["mult"])
	var payout := staked * mult
	var loss_p := 0.38
	var credited := finish_round(payout, loss_p, mult >= 10.0)

	if String(hit["id"]) == "bull":
		Achievements.notify("bullseye")

	if mult > 0.0:
		set_result("%s!  +%s" % [hit["name"], Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, mult)
	elif credited <= 0.0:
		set_result("Missed the board.", UIKit.DIM)
