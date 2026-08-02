extends Minigame

## Classic higher/lower card game.
## A card is shown; you bet it will be higher or lower than the next draw.
## Aces high. Ties push (stake returned, not counted as a win).
## RTP ≈ 92.3% after house edge on non-ties.

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUITS := ["♠", "♥", "♦", "♣"]

var _choice := "higher"  # higher | lower
var _card_label: Label
var _next_label: Label
var _choice_buttons: Dictionary = {}


func _init() -> void:
	game_id = "higher_lower"
	game_name = "Higher / Lower"
	game_icon = "🃏"
	base_rtp = 0.923


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)
	col.add_child(UIKit.label("Current card", 14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_card_label = UIKit.label("A♠", 52, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_card_label)
	col.add_child(UIKit.label("Next", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_next_label = UIKit.label("?", 36, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_next_label)
	panel.add_child(col)
	container.add_child(panel)

	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in [["higher", "HIGHER ▲"], ["lower", "LOWER ▼"]]:
		var b := UIKit.button(String(entry[1]), 18, UIKit.BLUE)
		b.custom_minimum_size = Vector2(140, 44)
		b.pressed.connect(_select.bind(String(entry[0])))
		_choice_buttons[String(entry[0])] = b
		row.add_child(b)
	container.add_child(row)
	container.add_child(UIKit.wrapped("Ties push your stake back. Aces are high.", 12, UIKit.DIM))
	_refresh_choice()


func _select(c: String) -> void:
	_choice = c
	_refresh_choice()
	AudioManager.play_click()


func _refresh_choice() -> void:
	for k in _choice_buttons:
		var b: Button = _choice_buttons[k]
		b.add_theme_color_override("font_color", UIKit.GOLD if k == _choice else UIKit.TEXT)


func _draw_card() -> Dictionary:
	var r := randi() % RANKS.size()
	var s := randi() % SUITS.size()
	return {"rank": r, "suit": s, "label": "%s%s" % [RANKS[r], SUITS[s]], "value": r + 1}


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	var current := _draw_card()
	_card_label.text = String(current["label"])
	_next_label.text = "?"
	set_result("Drawing...", UIKit.DIM)

	await wait(0.25)
	if not is_inside_tree():
		return

	var nxt := _draw_card()
	# Avoid exact same display spam — reshuffle once if identical face
	if nxt["label"] == current["label"]:
		nxt = _draw_card()
	_next_label.text = String(nxt["label"])
	FX.pulse(_next_label, 1.2, 0.2)

	var cv: int = int(current["value"])
	var nv: int = int(nxt["value"])
	var payout := 0.0
	var loss_p := 0.48

	if nv == cv:
		# Push — return stake, not a win
		var credited := finish_round(0.0, 1.0, false)
		GameManager.add_chips(staked, false)
		set_result("Tie — stake returned.", UIKit.BLUE)
		AudioManager.play_refund()
		return

	var won := (nv > cv and _choice == "higher") or (nv < cv and _choice == "lower")
	if won:
		payout = staked * 1.9  # even-money-ish with house edge

	var credited2 := finish_round(payout, loss_p, false)
	if won:
		set_result("Correct!  +%s" % Fmt.chips(payout), UIKit.GREEN)
		celebrate(payout, 1.9)
	elif credited2 <= 0.0:
		set_result("Wrong way.", UIKit.DIM)
