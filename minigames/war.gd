extends Minigame

## Casino War: highest card wins.
##
## A tie goes to war, and the war is free — the old version charged a second
## stake for it, which meant a round could cost one unit or two and quietly
## broke the refund identity in Minigame (which assumes one stake per round).
## With a free war the maths is exact:
##
##   P(win) = P(higher) + P(tie) * P(war won) = 0.502959
##   RTP    = 0.502959 * 1.85 = 93.0473%

const PAYS := 1.85
const LOSS_RATE := 0.497041

var _you: PanelContainer
var _dealer: PanelContainer
var _banner: Label


func _init() -> void:
	game_id = "war"
	game_name = "Casino War"
	game_icon = "game_war"
	base_rtp = 0.930473
	rules_text = "Highest card wins. A tie goes to war at no extra cost."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)

	var row := UIKit.hbox(40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var left := UIKit.vbox(4)
	left.add_child(UIKit.label("You", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_you = UIKit.card(78, 108)
	UIKit.set_card_back(_you)
	left.add_child(_you)
	row.add_child(left)

	var right := UIKit.vbox(4)
	right.add_child(UIKit.label("Dealer", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_dealer = UIKit.card(78, 108)
	UIKit.set_card_back(_dealer)
	right.add_child(_dealer)
	row.add_child(right)

	col.add_child(row)
	_banner = UIKit.label("", 15, UIKit.ORANGE, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_banner)
	panel.add_child(col)
	container.add_child(panel)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	_banner.text = ""
	UIKit.set_card_back(_you)
	UIKit.set_card_back(_dealer)
	set_result("Dealing...", UIKit.DIM)
	await wait(0.22)
	if not is_inside_tree():
		return

	var a := randi() % 13
	var b := randi() % 13
	UIKit.set_card(_you, a, randi() % 4)
	UIKit.set_card(_dealer, b, randi() % 4)
	FX.pulse(_you, 1.12, 0.18)

	var won := false
	if a > b:
		won = true
	elif a == b:
		# War: one more card each, no extra stake. The dealer loses ties here,
		# which is what lifts P(win) above a plain coin flip.
		_banner.text = "Tie - going to war"
		await wait(0.3)
		if not is_inside_tree():
			return
		var a2 := randi() % 13
		var b2 := randi() % 13
		UIKit.set_card(_you, a2, randi() % 4)
		UIKit.set_card(_dealer, b2, randi() % 4)
		FX.pulse(_you, 1.15, 0.2)
		won = a2 >= b2
		_banner.text = "War won" if won else "War lost"
	await wait(0.12)

	var payout := staked * PAYS if won else 0.0
	var credited := finish_round(payout, LOSS_RATE, false)

	if won:
		set_result("You win  +%s" % Fmt.chips(payout), UIKit.GREEN, "check")
		celebrate(payout, PAYS)
	elif credited <= 0.0:
		set_result("Dealer takes it.", UIKit.DIM)
