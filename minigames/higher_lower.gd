extends Minigame

## Higher or lower against a card you can actually see.
##
## The old version drew the current card *after* the bet was placed, so the
## call was a blind coin flip dressed up as a decision, and it paid a flat 1.9x
## regardless. Here the card is on the table before you choose, and the payout
## is priced from that card:
##
##     payout = (base_rtp - P(tie)) / P(win)
##
## which holds RTP at exactly 92% for every card and either call. Skill is in
## reading the board; the house edge never moves.
##
## The shown card is restricted to ranks 4..J so the priced payout can never
## fall below 1.0x — a "win" that returns less than the stake reads as a loss.

const LOW_RANK := 3    # index of "4"
const HIGH_RANK := 10  # index of "J"
const P_TIE := 1.0 / 13.0

var _choice := "higher"
var _current_rank := 6
var _current_suit := 0
var _card_current: PanelContainer
var _card_next: PanelContainer
var _choice_buttons: Dictionary = {}


func _init() -> void:
	game_id = "higher_lower"
	game_name = "Higher / Lower"
	game_icon = "game_hilo"
	base_rtp = 0.92
	rules_text = "The payout is priced from the card on the table. Ties return your stake."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var row := UIKit.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var left := UIKit.vbox(4)
	left.add_child(UIKit.label("On the table", 12, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_card_current = UIKit.card(78, 108)
	left.add_child(_card_current)
	row.add_child(left)

	var right := UIKit.vbox(4)
	right.add_child(UIKit.label("Next", 12, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_card_next = UIKit.card(78, 108)
	right.add_child(_card_next)
	row.add_child(right)

	panel.add_child(row)
	container.add_child(panel)

	var buttons := UIKit.segmented(["higher", "lower"], ["HIGHER", "LOWER"], _choice_buttons,
		UIKit.BLUE, 150, 46)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in _choice_buttons:
		_choice_buttons[id].pressed.connect(_select.bind(String(id)))
	container.add_child(buttons)

	_deal_current()


func _select(c: String) -> void:
	_choice = c
	_refresh_choice()
	AudioManager.play_click()


## P(the next card beats the shown one) for a given call.
func _win_probability(choice: String) -> float:
	var value := _current_rank + 1
	if choice == "higher":
		return float(13 - value) / 13.0
	return float(value - 1) / 13.0


func _payout_for(choice: String) -> float:
	var p := _win_probability(choice)
	if p <= 0.0:
		return 0.0
	return (base_rtp - P_TIE) / p


func _refresh_choice() -> void:
	UIKit.segmented_select(_choice_buttons, _choice, UIKit.BLUE)
	for id in _choice_buttons:
		var b: Button = _choice_buttons[id]
		b.text = "%s\n%.2fx" % [String(id).to_upper(), _payout_for(String(id))]


func _deal_current() -> void:
	_current_rank = LOW_RANK + randi() % (HIGH_RANK - LOW_RANK + 1)
	_current_suit = randi() % 4
	UIKit.set_card(_card_current, _current_rank, _current_suit)
	UIKit.set_card_back(_card_next)
	_refresh_choice()


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	var pays := _payout_for(_choice)
	var p_win := _win_probability(_choice)
	set_result("Turning...", UIKit.DIM)

	await wait(0.28)
	if not is_inside_tree():
		return

	var next_rank := randi() % 13
	var next_suit := randi() % 4
	UIKit.set_card(_card_next, next_rank, next_suit)
	FX.pulse(_card_next, 1.15, 0.2)

	var current_value := _current_rank + 1
	var next_value := next_rank + 1

	if next_value == current_value:
		settle_push("Tie - stake returned.")
		await wait(0.35)
		_deal_current()
		return

	var won := (next_value > current_value and _choice == "higher") \
		or (next_value < current_value and _choice == "lower")
	var payout := staked * pays if won else 0.0
	# The true chance of a losing round: not a win and not a tie.
	var loss_probability := 1.0 - p_win - P_TIE
	var credited := finish_round(payout, loss_probability, false)

	if won:
		set_result("Correct  +%s  (%.2fx)" % [Fmt.chips(payout), pays], UIKit.GREEN, "check")
		celebrate(payout, pays)
	elif credited <= 0.0:
		set_result("Wrong way.", UIKit.DIM)

	await wait(0.35)
	if is_inside_tree():
		_deal_current()
