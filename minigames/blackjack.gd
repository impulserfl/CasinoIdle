extends Minigame

## Interactive blackjack — you decide hit or stand. Dealer stands on 17.
## Base RTP assumes solid basic-ish play; bad play can underperform it.

const VALUES: Array[int] = [11, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]
const MAX_CARDS := 6
const NATURAL_PAYS := 2.5
const WIN_PAYS := 2.0
const LOSS_RATE := 0.490432

var _player_row: HBoxContainer
var _dealer_row: HBoxContainer
var _player_total: Label
var _dealer_total: Label
var _hit_btn: Button
var _stand_btn: Button
var _hint: Label

var _player: Array = []
var _dealer: Array = []
var _awaiting := false
var _stood := false
var _staked := 0.0


func _init() -> void:
	game_id = "blackjack"
	game_name = "Blackjack"
	game_icon = "game_blackjack"
	base_rtp = 0.943366
	rules_text = "Hit or stand. Dealer stands on 17. Natural pays 2.5x."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.FELT, 14, 2)
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

	var actions := UIKit.hbox(12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_hit_btn = UIKit.primary_button("HIT", 18, UIKit.BLUE)
	_hit_btn.custom_minimum_size = Vector2(140, 48)
	_hit_btn.disabled = true
	_hit_btn.pressed.connect(_on_hit)
	actions.add_child(_hit_btn)
	_stand_btn = UIKit.primary_button("STAND", 18, UIKit.ORANGE)
	_stand_btn.custom_minimum_size = Vector2(140, 48)
	_stand_btn.disabled = true
	_stand_btn.pressed.connect(_on_stand)
	actions.add_child(_stand_btn)
	container.add_child(actions)

	_hint = UIKit.label("Press DEAL to start a hand.", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_hint)
	if play_button != null:
		play_button.text = "DEAL"


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


func _render(row: HBoxContainer, cards: Array, hide_hole: bool = false) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for i in range(cards.size()):
		var c := UIKit.card(58, 82)
		if hide_hole and i == 1:
			UIKit.set_card_back(c)
		else:
			UIKit.set_card(c, int(cards[i]), randi() % 4)
		row.add_child(c)


func _set_actions(enabled: bool) -> void:
	_hit_btn.disabled = not enabled
	_stand_btn.disabled = not enabled


func _on_hit() -> void:
	if not _awaiting:
		return
	_player.append(_deal_card())
	var pval := _hand_value(_player)
	_render(_player_row, _player)
	_player_total.text = str(pval)
	AudioManager.play_tick()
	if pval > 21 or _player.size() >= MAX_CARDS:
		_stood = true
		_awaiting = false
		_set_actions(false)


func _on_stand() -> void:
	if not _awaiting:
		return
	_stood = true
	_awaiting = false
	_set_actions(false)
	AudioManager.play_click()


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	_staked = bet
	_player = [_deal_card(), _deal_card()]
	_dealer = [_deal_card(), _deal_card()]
	_stood = false

	_render(_player_row, _player)
	_render(_dealer_row, _dealer, true)
	_player_total.text = str(_hand_value(_player))
	_dealer_total.text = "?"
	set_result("Your move...", UIKit.CYAN)
	_hint.text = "HIT or STAND"
	AudioManager.play_chip_place()
	await wait(0.2)
	if not is_inside_tree():
		return

	var pval := _hand_value(_player)
	var dval := _hand_value(_dealer)

	if pval == 21 or dval == 21:
		_render(_dealer_row, _dealer)
		_dealer_total.text = str(dval)
		if pval == 21 and dval == 21:
			settle_push("Both blackjack - push.")
			return
		if pval == 21:
			var natural := _staked * NATURAL_PAYS
			finish_round(natural, LOSS_RATE, true)
			set_result("BLACKJACK  +%s" % Fmt.chips(natural), UIKit.GOLD, "trophy")
			celebrate(natural, NATURAL_PAYS)
			if Settings.stop_auto_on_jackpot:
				stop_auto()
			return
		finish_round(0.0, LOSS_RATE, false)
		set_result("Dealer blackjack.", UIKit.DIM)
		return

	if auto:
		while pval < 17 and _player.size() < MAX_CARDS:
			_player.append(_deal_card())
			pval = _hand_value(_player)
			_render(_player_row, _player)
			_player_total.text = str(pval)
			await wait(0.15)
			if not is_inside_tree():
				return
	else:
		_awaiting = true
		_set_actions(true)
		while _awaiting and is_inside_tree():
			await get_tree().process_frame
		if not is_inside_tree():
			return
		pval = _hand_value(_player)

	if pval > 21:
		_render(_dealer_row, _dealer)
		_dealer_total.text = str(dval)
		finish_round(0.0, LOSS_RATE, false)
		set_result("Bust at %d." % pval, UIKit.DIM)
		_hint.text = "Press DEAL for another hand."
		return

	_render(_dealer_row, _dealer)
	_dealer_total.text = str(dval)
	await wait(0.18)
	while dval < 17 and _dealer.size() < MAX_CARDS:
		_dealer.append(_deal_card())
		dval = _hand_value(_dealer)
		_render(_dealer_row, _dealer)
		_dealer_total.text = str(dval)
		AudioManager.play_tick()
		await wait(0.18)
		if not is_inside_tree():
			return

	if dval > 21 or pval > dval:
		var payout := _staked * WIN_PAYS
		finish_round(payout, LOSS_RATE, false)
		set_result("You win  +%s" % Fmt.chips(payout), UIKit.GREEN, "check")
		celebrate(payout, WIN_PAYS)
	elif pval == dval:
		settle_push("Push - stake returned.")
	else:
		finish_round(0.0, LOSS_RATE, false)
		set_result("Dealer wins with %d." % dval, UIKit.DIM)
	_hint.text = "Press DEAL for another hand."


func stop_auto() -> void:
	super.stop_auto()
	_awaiting = false
	_set_actions(false)
