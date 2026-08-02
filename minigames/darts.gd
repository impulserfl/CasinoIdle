extends Minigame

## Pub darts. Aim at a ring; the dart drifts.
##
## You are paid for whatever ring you actually hit, not for matching your aim —
## aiming only bends the weights toward that ring. That means aim changes the
## shape of the distribution, so each aim needs its own miss weight to keep the
## table at 92%. The old version boosted the aimed ring and paid on every hit
## with a single shared table, which is why aiming at the bull returned 167%.

const ZONES: Array[Dictionary] = [
	{"id": "bull",   "name": "Bull",   "mult": 25.0, "icon": "target"},
	{"id": "treble", "name": "Treble", "mult": 6.0,  "icon": "game_darts"},
	{"id": "double", "name": "Double", "mult": 3.0,  "icon": "game_darts"},
	{"id": "outer",  "name": "Outer",  "mult": 1.5,  "icon": "game_darts"},
]

## aim -> [miss, bull, treble, double, outer], each solved so RTP is 92%.
const AIM_WEIGHTS: Dictionary = {
	"bull":   [26483, 600, 1000, 1600, 2600],
	"treble": [24152, 300, 2000, 1600, 2600],
	"double": [22248, 300, 1000, 3200, 2600],
	"outer":  [20270, 300, 1000, 1600, 5200],
}

const AIM_LOSS_RATE: Dictionary = {
	"bull": 0.820339,
	"treble": 0.787943,
	"double": 0.758076,
	"outer": 0.714487,
}

var _aim := "treble"
var _board_icon: TextureRect
var _hit_label: Label
var _aim_buttons: Dictionary = {}


func _init() -> void:
	game_id = "darts"
	game_name = "Darts"
	game_icon = "game_darts"
	base_rtp = 0.92
	rules_text = "Aiming bends the odds toward a ring. Every aim returns the same 92%."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)
	_board_icon = UIKit.icon("game_darts", 84)
	_board_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_board_icon)
	_hit_label = UIKit.label("Take aim", 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_hit_label)
	panel.add_child(col)
	container.add_child(panel)

	var ids: Array = []
	var labels: Array = []
	for z in ZONES:
		ids.append(String(z["id"]))
		labels.append("%s\n%sx" % [String(z["name"]), Fmt.chips(float(z["mult"]))])
	var row := UIKit.segmented(ids, labels, _aim_buttons, UIKit.GOLD, 96, 50)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in _aim_buttons:
		_aim_buttons[id].pressed.connect(_select_aim.bind(String(id)))
	container.add_child(row)
	container.add_child(UIKit.wrapped(
		"A miss pays nothing. Aiming at the bull hits it more often but misses more too.",
		12, UIKit.DIM))
	_refresh_aim()


func _select_aim(id: String) -> void:
	_aim = id
	_refresh_aim()
	AudioManager.play_click()


func _refresh_aim() -> void:
	UIKit.segmented_select(_aim_buttons, _aim, UIKit.GOLD)


## Index 0 is a miss; 1..4 map onto ZONES.
func _throw() -> int:
	var weights: Array = AIM_WEIGHTS[_aim]
	var entries: Array = []
	for i in range(weights.size()):
		entries.append([i, float(weights[i])])
	return int(weighted_pick(entries))


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	set_result("Throwing...", UIKit.DIM)
	for i in range(8):
		_board_icon.modulate = Color(1, 1, 1, 0.5 if i % 2 == 0 else 1.0)
		await wait(0.05)
		if not is_inside_tree():
			return
	_board_icon.modulate = Color.WHITE

	var index := _throw()
	var mult := 0.0
	var label := "Missed the board"
	if index > 0:
		var zone: Dictionary = ZONES[index - 1]
		mult = float(zone["mult"])
		label = String(zone["name"])
		if String(zone["id"]) == "bull":
			Achievements.notify("bullseye")
	_hit_label.text = label
	FX.pulse(_board_icon, 1.2, 0.25)

	var payout := staked * mult
	var loss_rate := float(AIM_LOSS_RATE[_aim])
	var is_jackpot := mult >= 25.0
	var credited := finish_round(payout, loss_rate, is_jackpot)

	if mult > 0.0:
		set_result("%s  +%s" % [label, Fmt.chips(payout)], UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if is_jackpot and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("Missed the board.", UIKit.DIM)
