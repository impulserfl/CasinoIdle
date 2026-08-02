extends Minigame

## Simplified baccarat: back Player, Banker or Tie.
##
## Two cards a side, totals mod 10, no third-card rules. That symmetry is worth
## being careful about — with Player paying a true 1:1 (a 2.0x total return)
## and ties returning the stake, this table is *exactly* fair, 100.00% RTP, and
## was an unlimited free EXP farm. Real baccarat's edge comes from the drawing
## rules this model does not have, so the edge is priced into the payouts:
##
##   P(tie) = 0.102552,  P(player) = P(banker) = 0.448724
##   player/banker pay 1.95x -> 0.448724 * 1.95 + 0.102552 = 97.7564%
##   tie pays 9.5323x       -> 0.102552 * 9.5323           = 97.7564%
##
## Every bet is priced to the same return, so the choice is volatility only.

const CARD_VALUES: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0]
const SIDE_PAYS := 1.95
const TIE_PAYS := 9.5323
const SIDE_LOSS_RATE := 0.448724
const TIE_LOSS_RATE := 0.897448

var _bet_on := "player"
var _player_row: HBoxContainer
var _banker_row: HBoxContainer
var _player_total: Label
var _banker_total: Label
var _buttons: Dictionary = {}


func _init() -> void:
	game_id = "baccarat"
	game_name = "Baccarat"
	game_icon = "game_baccarat"
	base_rtp = 0.977564
	rules_text = "Closest to nine wins. Lowest house edge in the game at 2.24%."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)

	var ph := UIKit.hbox(8)
	ph.add_child(UIKit.label("Player", 13, UIKit.DIM))
	ph.add_child(UIKit.spacer())
	_player_total = UIKit.label("", 15, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	ph.add_child(_player_total)
	col.add_child(ph)
	_player_row = UIKit.hbox(6)
	_player_row.custom_minimum_size = Vector2(0, 84)
	col.add_child(_player_row)

	col.add_child(UIKit.separator())

	var bh := UIKit.hbox(8)
	bh.add_child(UIKit.label("Banker", 13, UIKit.DIM))
	bh.add_child(UIKit.spacer())
	_banker_total = UIKit.label("", 15, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	bh.add_child(_banker_total)
	col.add_child(bh)
	_banker_row = UIKit.hbox(6)
	_banker_row.custom_minimum_size = Vector2(0, 84)
	col.add_child(_banker_row)

	panel.add_child(col)
	container.add_child(panel)

	var row := UIKit.segmented(
		["player", "banker", "tie"],
		["PLAYER\n1.95x", "BANKER\n1.95x", "TIE\n9.53x"],
		_buttons, UIKit.GOLD, 130, 52)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in _buttons:
		_buttons[id].pressed.connect(_select.bind(String(id)))
	container.add_child(row)
	_refresh()


func _select(s: String) -> void:
	_bet_on = s
	_refresh()
	AudioManager.play_click()


func _refresh() -> void:
	UIKit.segmented_select(_buttons, _bet_on, UIKit.GOLD)


func _deal_hand() -> Array:
	return [randi() % 13, randi() % 13]


func _hand_total(cards: Array) -> int:
	var t := 0
	for rank in cards:
		t += CARD_VALUES[int(rank)]
	return t % 10


func _render(row: HBoxContainer, cards: Array) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for rank in cards:
		var c := UIKit.card(56, 78)
		UIKit.set_card(c, int(rank), randi() % 4)
		row.add_child(c)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	set_result("Dealing...", UIKit.DIM)
	await wait(0.25)
	if not is_inside_tree():
		return

	var player := _deal_hand()
	var banker := _deal_hand()
	var p := _hand_total(player)
	var b := _hand_total(banker)
	_render(_player_row, player)
	_render(_banker_row, banker)
	_player_total.text = str(p)
	_banker_total.text = str(b)
	FX.pulse(_player_row, 1.06, 0.15)

	var loss_rate := TIE_LOSS_RATE if _bet_on == "tie" else SIDE_LOSS_RATE

	if p == b:
		if _bet_on == "tie":
			var tie_payout := staked * TIE_PAYS
			finish_round(tie_payout, loss_rate, true)
			set_result("Tie pays  +%s" % Fmt.chips(tie_payout), UIKit.GOLD, "trophy")
			celebrate(tie_payout, TIE_PAYS)
			if Settings.stop_auto_on_jackpot:
				stop_auto()
		else:
			# A tie is a push for Player and Banker, not a loss.
			settle_push("Tie - stake returned.")
		return

	var won := (p > b and _bet_on == "player") or (b > p and _bet_on == "banker")
	var payout := staked * SIDE_PAYS if won else 0.0
	var credited := finish_round(payout, loss_rate, false)

	if won:
		set_result("%s wins  +%s" % [_bet_on.capitalize(), Fmt.chips(payout)], UIKit.GREEN, "check")
		celebrate(payout, SIDE_PAYS)
	elif credited <= 0.0:
		set_result("%s wins - no bet." % ("Player" if p > b else "Banker"), UIKit.DIM)
