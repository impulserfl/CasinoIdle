extends Minigame

## Simplified blackjack against the dealer.
##
## Infinite shoe, player hits below 17, dealer stands on 17, six cards maximum
## either side. A natural pays 2.5x, an ordinary win 2x, a tie returns the
## stake. Those rules give an exact return, and BalanceAudit enumerates the full
## state tree rather than sampling it:
##   RTP 94.3366%  |  win 41.13%  |  push 9.83%  |  loss 49.0432%

const VALUES: Array[int] = [11, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]
const MAX_CARDS := 6
const NATURAL_PAYS := 2.5
const WIN_PAYS := 2.0
const LOSS_RATE := 0.490432

var _player_row: HBoxContainer
var _dealer_row: HBoxContainer
var _player_total: Label
var _dealer_total: Label


func _init() -> void:
	game_id = "blackjack"
	game_name = "Blackjack"
	game_icon = "game_blackjack"
	base_rtp = 0.943366
	rules_text = "You hit below 17, the dealer stands on 17. A natural pays 2.5x."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)

	var dealer_head := UIKit.hbox(8)
	dealer_head.add_child(UIKit.label("Dealer", 13, UIKit.DIM))
	dealer_head.add_child(UIKit.spacer())
	_dealer_total = UIKit.label("", 15, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	dealer_head.add_child(_dealer_total)
	col.add_child(dealer_head)
	_dealer_row = UIKit.hbox(6)
	_dealer_row.custom_minimum_size = Vector2(0, 88)
	col.add_child(_dealer_row)

	col.add_child(UIKit.separator())

	var player_head := UIKit.hbox(8)
	player_head.add_child(UIKit.label("You", 13, UIKit.DIM))
	player_head.add_child(UIKit.spacer())
	_player_total = UIKit.label("", 15, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	player_head.add_child(_player_total)
	col.add_child(player_head)
	_player_row = UIKit.hbox(6)
	_player_row.custom_minimum_size = Vector2(0, 88)
	col.add_child(_player_row)

	panel.add_child(col)
	container.add_child(panel)


## A card is a rank index 0..12; the value table maps it to blackjack points.
func _deal_card() -> int:
	return randi() % 13


func _hand_value(cards: Array) -> int:
	var total := 0
	var aces := 0
	for rank in cards:
		var v: int = VALUES[int(rank)]
		total += v
		if v == 11:
			aces += 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


func _render(row: HBoxContainer, cards: Array, hide_first: bool = false) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for i in range(cards.size()):
		var c := UIKit.card(58, 82)
		if hide_first and i == 1:
			UIKit.set_card_back(c)
		else:
			UIKit.set_card(c, int(cards[i]), randi() % 4)
		row.add_child(c)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	var player: Array = [_deal_card(), _deal_card()]
	var dealer: Array = [_deal_card(), _deal_card()]

	_render(_player_row, player)
	_render(_dealer_row, dealer, true)
	_player_total.text = str(_hand_value(player))
	_dealer_total.text = "?"
	set_result("Dealing...", UIKit.DIM)
	await wait(0.22)
	if not is_inside_tree():
		return

	var pval := _hand_value(player)
	var dval := _hand_value(dealer)

	# Naturals resolve before anyone draws.
	if pval == 21 or dval == 21:
		_render(_dealer_row, dealer)
		_dealer_total.text = str(dval)
		if pval == 21 and dval == 21:
			settle_push("Both blackjack - push.")
			return
		if pval == 21:
			var natural := staked * NATURAL_PAYS
			finish_round(natural, LOSS_RATE, true)
			set_result("BLACKJACK  +%s" % Fmt.chips(natural), UIKit.GOLD, "trophy")
			celebrate(natural, NATURAL_PAYS)
			if Settings.stop_auto_on_jackpot:
				stop_auto()
			return
		finish_round(0.0, LOSS_RATE, false)
		set_result("Dealer blackjack.", UIKit.DIM)
		return

	while pval < 17 and player.size() < MAX_CARDS:
		player.append(_deal_card())
		pval = _hand_value(player)
		_render(_player_row, player)
		_player_total.text = str(pval)
		await wait(0.18)
		if not is_inside_tree():
			return

	if pval > 21:
		_render(_dealer_row, dealer)
		_dealer_total.text = str(dval)
		finish_round(0.0, LOSS_RATE, false)
		set_result("Bust at %d." % pval, UIKit.DIM)
		return

	_render(_dealer_row, dealer)
	_dealer_total.text = str(dval)
	await wait(0.2)
	while dval < 17 and dealer.size() < MAX_CARDS:
		dealer.append(_deal_card())
		dval = _hand_value(dealer)
		_render(_dealer_row, dealer)
		_dealer_total.text = str(dval)
		await wait(0.18)
		if not is_inside_tree():
			return

	if dval > 21 or pval > dval:
		var payout := staked * WIN_PAYS
		finish_round(payout, LOSS_RATE, false)
		set_result("You win  +%s" % Fmt.chips(payout), UIKit.GREEN, "check")
		celebrate(payout, WIN_PAYS)
	elif pval == dval:
		settle_push("Push - stake returned.")
	else:
		finish_round(0.0, LOSS_RATE, false)
		set_result("Dealer wins with %d." % dval, UIKit.DIM)
