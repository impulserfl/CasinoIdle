extends Minigame

## Carnival money wheel. Pick a segment; the wheel decides.
##
## Each segment's payout is derived from its own probability rather than picked
## by eye: pays = base_rtp / P(segment). That makes every segment worth exactly
## 92%, so the choice is variance only. The old table used the segment's face
## value as the multiplier, which meant the common "1" segment returned the
## stake and nothing more (40% RTP) while "10" and "20" were exactly break-even.

const SEGMENTS: Array[Dictionary] = [
	{"id": "a", "weight": 24, "accent": "green"},
	{"id": "b", "weight": 16, "accent": "blue"},
	{"id": "c", "weight": 10, "accent": "cyan"},
	{"id": "d", "weight": 6,  "accent": "purple"},
	{"id": "e", "weight": 3,  "accent": "orange"},
	{"id": "f", "weight": 1,  "accent": "gold"},
]

var _pick := "a"
var _wheel_label: Label
var _buttons: Dictionary = {}


func _init() -> void:
	game_id = "money_wheel"
	game_name = "Money Wheel"
	game_icon = "game_wheel"
	base_rtp = 0.92
	rules_text = "Every segment is priced to the same 92% return."


func _total_weight() -> float:
	var t := 0.0
	for s in SEGMENTS:
		t += float(s["weight"])
	return t


func _probability(id: String) -> float:
	for s in SEGMENTS:
		if String(s["id"]) == id:
			return float(s["weight"]) / _total_weight()
	return 0.0


func pays_for(id: String) -> float:
	var p := _probability(id)
	if p <= 0.0:
		return 0.0
	return base_rtp / p


func _accent_of(name: String) -> Color:
	match name:
		"gold":
			return UIKit.GOLD
		"orange":
			return UIKit.ORANGE
		"purple":
			return UIKit.PURPLE
		"cyan":
			return UIKit.CYAN
		"blue":
			return UIKit.BLUE
	return UIKit.GREEN


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(6)
	col.add_child(UIKit.icon("game_wheel", 56))
	_wheel_label = UIKit.numeral("-", 44, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_wheel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_wheel_label)
	panel.add_child(col)
	container.add_child(panel)

	var grid := UIKit.grid(3, 8, 8)
	for s in SEGMENTS:
		var id := String(s["id"])
		var pays := pays_for(id)
		var b := UIKit.button("%sx\n1 in %.1f" % [Fmt.chips(pays), 1.0 / _probability(id)],
			15, _accent_of(String(s["accent"])))
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select.bind(id))
		_buttons[id] = b
		grid.add_child(b)
	container.add_child(grid)
	_refresh()


func _select(id: String) -> void:
	_pick = id
	_refresh()
	AudioManager.play_click()


func _refresh() -> void:
	UIKit.segmented_select(_buttons, _pick, UIKit.GOLD)


func _spin() -> String:
	var entries: Array = []
	for s in SEGMENTS:
		entries.append([String(s["id"]), s["weight"]])
	return String(weighted_pick(entries))


func _label_for(id: String) -> String:
	return "%sx" % Fmt.chips(pays_for(id))


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	var pays := pays_for(_pick)
	set_result("Spinning...", UIKit.DIM)

	var delay := 0.04
	for i in range(18):
		_wheel_label.text = _label_for(_spin())
		await wait(delay)
		if not is_inside_tree():
			return
		delay *= 1.1

	var landed := _spin()
	_wheel_label.text = _label_for(landed)
	FX.pulse(_wheel_label, 1.2, 0.25)

	var won := landed == _pick
	var payout := staked * pays if won else 0.0
	var loss_probability := 1.0 - _probability(_pick)
	var credited := finish_round(payout, loss_probability, pays >= 18.0 and won)

	if won:
		set_result("Hit  +%s" % Fmt.chips(payout), UIKit.tier_color(pays), "check")
		celebrate(payout, pays)
		if pays >= 18.0 and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("Landed on %s." % _label_for(landed), UIKit.DIM)
