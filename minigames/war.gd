extends Minigame

## Casino War: one card each. Higher wins 1:1. Tie → optional war (auto: go to war).
## Go to war costs another 1× stake; win pays 2× original on the war card.
## RTP ≈ 93%.

const RANKS := ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
const SUITS := ["♠","♥","♦","♣"]

var _you: Label
var _dealer: Label


func _init() -> void:
	game_id = "war"
	game_name = "Casino War"
	game_icon = "⚔️"
	base_rtp = 0.93


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 12, 2)
	var row := UIKit.hbox(40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var left := UIKit.vbox(4)
	left.add_child(UIKit.label("You", 14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_you = UIKit.label("—", 40, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	left.add_child(_you)
	var right := UIKit.vbox(4)
	right.add_child(UIKit.label("Dealer", 14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_dealer = UIKit.label("—", 40, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	right.add_child(_dealer)
	row.add_child(left)
	row.add_child(right)
	panel.add_child(row)
	container.add_child(panel)
	container.add_child(UIKit.wrapped("Highest card wins. On a tie, auto-war for another stake.", 12, UIKit.DIM))


func _card() -> Dictionary:
	var r := randi() % 13
	var s := randi() % 4
	return {"v": r + 1, "label": "%s%s" % [RANKS[r], SUITS[s]]}


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return
	var staked := bet
	var a := _card()
	var b := _card()
	_you.text = String(a["label"])
	_dealer.text = String(b["label"])
	set_result("War!", UIKit.DIM)
	await wait(0.3)
	if not is_inside_tree():
		return

	if int(a["v"]) > int(b["v"]):
		var payout := staked * 2.0
		finish_round(payout, 0.48, false)
		set_result("You win!  +%s" % Fmt.chips(payout), UIKit.GREEN)
		celebrate(payout, 2.0)
	elif int(a["v"]) < int(b["v"]):
		finish_round(0.0, 0.48, false)
		set_result("Dealer wins.", UIKit.DIM)
	else:
		# Auto war — needs another stake
		set_result("Tie — going to war...", UIKit.ORANGE)
		await wait(0.25)
		if not GameManager.spend_chips(staked):
			finish_round(0.0, 0.48, false)
			set_result("Tie — couldn't afford war.", UIKit.DIM)
			return
		GameManager.record_wager(game_id, staked)
		var a2 := _card()
		var b2 := _card()
		_you.text = String(a2["label"])
		_dealer.text = String(b2["label"])
		await wait(0.25)
		if not is_inside_tree():
			return
		if int(a2["v"]) >= int(b2["v"]):
			var payout2 := staked * 2.0  # win pays original bet back as 1:1 on war ante net ~2x one stake
			finish_round(payout2, 0.48, false)
			set_result("War won!  +%s" % Fmt.chips(payout2), UIKit.GREEN)
			celebrate(payout2, 2.0)
		else:
			finish_round(0.0, 0.48, false)
			set_result("Lost the war.", UIKit.DIM)
