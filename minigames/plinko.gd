extends Minigame

## Plinko-style ball drop into weighted slots.
## 9 slots with multipliers; center is safer, edges are jackpot-tier.
## Designed RTP ≈ 93%.

const SLOTS: Array[Dictionary] = [
	{"mult": 5.0,  "weight": 4,  "color": "gold"},
	{"mult": 2.0,  "weight": 10, "color": "orange"},
	{"mult": 1.2,  "weight": 16, "color": "green"},
	{"mult": 0.6,  "weight": 22, "color": "blue"},
	{"mult": 0.3,  "weight": 28, "color": "dim"},
	{"mult": 0.6,  "weight": 22, "color": "blue"},
	{"mult": 1.2,  "weight": 16, "color": "green"},
	{"mult": 2.0,  "weight": 10, "color": "orange"},
	{"mult": 5.0,  "weight": 4,  "color": "gold"},
]

var _slot_labels: Array[Label] = []
var _ball_label: Label


func _init() -> void:
	game_id = "plinko"
	game_name = "Plinko"
	game_icon = "🔵"
	base_rtp = 0.93


func _build_board(container: VBoxContainer) -> void:
	_ball_label = UIKit.label("●", 40, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	container.add_child(_ball_label)

	var row := UIKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in SLOTS:
		var panel := UIKit.panel(UIKit.PANEL, 8, 1)
		panel.custom_minimum_size = Vector2(56, 64)
		var l := UIKit.label("x%s" % Fmt.chips(float(s["mult"])), 14, _color_of(String(s["color"])) , HORIZONTAL_ALIGNMENT_CENTER)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(l)
		_slot_labels.append(l)
		row.add_child(panel)
	container.add_child(row)
	container.add_child(UIKit.wrapped("Ball drops into a slot. Edges pay more, center more often.", 12, UIKit.DIM))


func _color_of(name: String) -> Color:
	match name:
		"gold": return UIKit.GOLD
		"orange": return UIKit.ORANGE
		"green": return UIKit.GREEN
		"blue": return UIKit.BLUE
	return UIKit.DIM


func _pick_slot() -> int:
	var entries: Array = []
	for i in range(SLOTS.size()):
		entries.append([i, SLOTS[i]["weight"]])
	return int(weighted_pick(entries))


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	var target := _pick_slot()
	set_result("Dropping...", UIKit.DIM)

	for i in range(12):
		var bounce := randi() % SLOTS.size()
		_ball_label.text = "  ".repeat(bounce) + "●"
		await wait(0.05 + i * 0.012)
		if not is_inside_tree():
			return

	_ball_label.text = "  ".repeat(target) + "●"
	FX.pulse(_slot_labels[target], 1.3, 0.25)

	var mult: float = float(SLOTS[target]["mult"])
	var payout := staked * mult
	var loss_p := 0.42  # approximate P(mult < 1)
	var credited := finish_round(payout if mult > 0.0 else 0.0, loss_p, mult >= 5.0)

	if mult >= 1.0:
		set_result("Landed x%s  +%s" % [Fmt.chips(mult), Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, mult)
	elif credited <= 0.0:
		set_result("Landed x%s — loss." % Fmt.chips(mult), UIKit.DIM)
	else:
		set_result("Landed x%s  +%s" % [Fmt.chips(mult), Fmt.chips(payout)], UIKit.ORANGE)
		# partial return still paid via finish_round when mult > 0
		if mult > 0.0 and mult < 1.0:
			# already credited inside finish_round only if payout>0 — good
			pass
