extends Minigame

## Simplified single-deck blackjack vs dealer.
## Player auto-strategy for auto-play: hit below 17, stand on 17+.
## Blackjack pays 2.5x stake. Win 2x, push returns stake.
## Approximate RTP ~94%.

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const VALUES := [11, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]

var _player_label: Label
var _dealer_label: Label
var _total_p: Label
var _total_d: Label


func _init() -> void:
	game_id = "blackjack"
	game_name = "Blackjack"
	game_icon = "🂡"
	base_rtp = 0.94


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(10)

	col.add_child(UIKit.label("Dealer", 14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_dealer_label = UIKit.label("—", 28, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_dealer_label)
	_total_d = UIKit.label("", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_total_d)

	col.add_child(UIKit.separator())

	col.add_child(UIKit.label("You", 14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_player_label = UIKit.label("—", 28, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_player_label)
	_total_p = UIKit.label("", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_total_p)

	panel.add_child(col)
	container.add_child(panel)
	container.add_child(UIKit.wrapped(
		"Auto strategy: hit below 17. Blackjack pays 3:2. Dealer stands on 17.",
		12, UIKit.DIM))


func _draw_card() -> Dictionary:
	var i := randi() % RANKS.size()
	return {"name": RANKS[i], "value": VALUES[i]}


func _hand_value(cards: Array) -> int:
	var total := 0
	var aces := 0
	for c in cards:
		total += int(c["value"])
		if int(c["value"]) == 11:
			aces += 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


func _fmt(cards: Array) -> String:
	var parts: Array[String] = []
	for c in cards:
		parts.append(String(c["name"]))
	return "  ".join(parts)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	var player: Array = [_draw_card(), _draw_card()]
	var dealer: Array = [_draw_card(), _draw_card()]

	_player_label.text = _fmt(player)
	_dealer_label.text = "%s  ?" % dealer[0]["name"]
	_total_p.text = str(_hand_value(player))
	_total_d.text = "?"
	set_result("Playing...", UIKit.DIM)
	await wait(0.2)
	if not is_inside_tree():
		return

	var pval := _hand_value(player)
	var dval := _hand_value(dealer)

	# Natural blackjack
	if pval == 21 or dval == 21:
		_dealer_label.text = _fmt(dealer)
		_total_d.text = str(dval)
		var payout := 0.0
		if pval == 21 and dval == 21:
			GameManager.add_chips(staked, false)
			finish_round(0.0, 1.0, false)
			set_result("Double blackjack — push.", UIKit.BLUE)
			return
		elif pval == 21:
			payout = staked * 2.5
			finish_round(payout, 0.52, true)
			set_result("BLACKJACK!  +%s" % Fmt.chips(payout), UIKit.GOLD)
			celebrate(payout, 2.5)
			return
		else:
			finish_round(0.0, 0.52, false)
			set_result("Dealer blackjack.", UIKit.DIM)
			return

	# Player hits to 17
	while pval < 17 and player.size() < 6:
		player.append(_draw_card())
		pval = _hand_value(player)
		_player_label.text = _fmt(player)
		_total_p.text = str(pval)
		await wait(0.18)
		if not is_inside_tree():
			return

	if pval > 21:
		_dealer_label.text = _fmt(dealer)
		_total_d.text = str(dval)
		finish_round(0.0, 0.52, false)
		set_result("Bust (%d)." % pval, UIKit.DIM)
		return

	# Dealer plays
	_dealer_label.text = _fmt(dealer)
	_total_d.text = str(dval)
	await wait(0.2)
	while dval < 17 and dealer.size() < 6:
		dealer.append(_draw_card())
		dval = _hand_value(dealer)
		_dealer_label.text = _fmt(dealer)
		_total_d.text = str(dval)
		await wait(0.18)
		if not is_inside_tree():
			return

	var payout2 := 0.0
	if dval > 21 or pval > dval:
		payout2 = staked * 2.0
		finish_round(payout2, 0.52, false)
		set_result("You win!  +%s" % Fmt.chips(payout2), UIKit.GREEN)
		celebrate(payout2, 2.0)
	elif pval == dval:
		GameManager.add_chips(staked, false)
		finish_round(0.0, 1.0, false)
		set_result("Push.", UIKit.BLUE)
		AudioManager.play_refund()
	else:
		finish_round(0.0, 0.52, false)
		set_result("Dealer wins.", UIKit.DIM)
