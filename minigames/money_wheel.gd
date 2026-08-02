extends Minigame

## Carnival-style money wheel. Pick a segment color/value and spin.
## Weighted segments; rarer numbers pay more. RTP ≈ 92%.

const SEGMENTS: Array[Dictionary] = [
	{"label": "1",  "mult": 1.0,  "weight": 24, "id": "1"},
	{"label": "2",  "mult": 2.0,  "weight": 16, "id": "2"},
	{"label": "5",  "mult": 5.0,  "weight": 10, "id": "5"},
	{"label": "10", "mult": 10.0, "weight": 6,  "id": "10"},
	{"label": "20", "mult": 20.0, "weight": 3,  "id": "20"},
	{"label": "40", "mult": 40.0, "weight": 1,  "id": "40"},
]

var _pick := "1"
var _wheel_label: Label
var _buttons: Dictionary = {}


func _init() -> void:
	game_id = "money_wheel"
	game_name = "Money Wheel"
	game_icon = "🎡"
	base_rtp = 0.92


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	_wheel_label = UIKit.label("—", 56, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(_wheel_label)
	container.add_child(panel)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for s in SEGMENTS:
		var id := String(s["id"])
		var b := UIKit.button("%s  (x%s)" % [s["label"], Fmt.chips(float(s["mult"]))], 15)
		b.custom_minimum_size = Vector2(120, 42)
		b.pressed.connect(_select.bind(id))
		_buttons[id] = b
		grid.add_child(b)
	container.add_child(grid)
	container.add_child(UIKit.wrapped("Bet on a number. The wheel decides.", 12, UIKit.DIM))
	_refresh()


func _select(id: String) -> void:
	_pick = id
	_refresh()
	AudioManager.play_click()


func _refresh() -> void:
	for id in _buttons:
		var b: Button = _buttons[id]
		b.add_theme_color_override("font_color", UIKit.GOLD if id == _pick else UIKit.TEXT)


func _spin_result() -> Dictionary:
	var entries: Array = []
	for s in SEGMENTS:
		entries.append([s, s["weight"]])
	return weighted_pick(entries)


func _segment(id: String) -> Dictionary:
	for s in SEGMENTS:
		if String(s["id"]) == id:
			return s
	return SEGMENTS[0]


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	var chosen := _segment(_pick)
	set_result("Spinning...", UIKit.DIM)

	var delay := 0.04
	for i in range(18):
		var temp: Dictionary = _spin_result()
		_wheel_label.text = String(temp["label"])
		await wait(delay)
		if not is_inside_tree():
			return
		delay *= 1.1

	var result: Dictionary = _spin_result()
	_wheel_label.text = String(result["label"])
	FX.pulse(_wheel_label, 1.2, 0.25)

	var won := String(result["id"]) == _pick
	var mult: float = float(chosen["mult"])
	var payout := staked * mult if won else 0.0
	# rough P(win) from weights
	var total_w := 0.0
	var pick_w := 0.0
	for s in SEGMENTS:
		total_w += float(s["weight"])
		if String(s["id"]) == _pick:
			pick_w = float(s["weight"])
	var loss_p := 1.0 - (pick_w / total_w)

	var credited := finish_round(payout, loss_p, mult >= 20.0)
	if won:
		set_result("Hit %s!  +%s" % [result["label"], Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, mult)
	elif credited <= 0.0:
		set_result("Landed on %s." % result["label"], UIKit.DIM)
