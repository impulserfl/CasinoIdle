extends Minigame

## Simplified Jacks-or-Better style: dealt 5 cards, best hand pays.
## Auto-play keeps the dealt hand (no discard UI) for idle friendliness.
## RTP ≈ 92%.

const RANKS := ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
const SUITS := ["♠","♥","♦","♣"]

var _hand_label: Label
var _rank_label: Label


func _init() -> void:
	game_id = "video_poker"
	game_name = "Video Poker"
	game_icon = "♠️"
	base_rtp = 0.92


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 12, 2)
	var col := UIKit.vbox(8)
	_hand_label = UIKit.label("— — — — —", 28, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_rank_label = UIKit.label("", 18, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_hand_label)
	col.add_child(_rank_label)
	panel.add_child(col)
	container.add_child(panel)
	container.add_child(UIKit.wrapped(
		"Jacks or better to win. Auto keeps the dealt hand. Royal flush = 250×.", 12, UIKit.DIM))


func _draw_hand() -> Array:
	var deck: Array = []
	for r in range(13):
		for s in range(4):
			deck.append({"r": r, "s": s, "label": "%s%s" % [RANKS[r], SUITS[s]]})
	deck.shuffle()
	return deck.slice(0, 5)


func _evaluate(hand: Array) -> Dictionary:
	var ranks: Array[int] = []
	var suits: Array[int] = []
	for c in hand:
		ranks.append(int(c["r"]))
		suits.append(int(c["s"]))
	ranks.sort()
	var counts: Dictionary = {}
	for r in ranks:
		counts[r] = int(counts.get(r, 0)) + 1
	var freqs: Array = counts.values()
	freqs.sort()
	freqs.reverse()
	var flush := suits[0] == suits[1] and suits[1] == suits[2] and suits[2] == suits[3] and suits[3] == suits[4]
	var straight := true
	for i in range(4):
		if ranks[i + 1] != ranks[i] + 1:
			straight = false
			break
	# Wheel A-2-3-4-5
	if ranks == [0, 1, 2, 3, 12]:
		straight = true
	if flush and straight and ranks[0] == 8:
		return {"name": "Royal Flush", "mult": 250.0}
	if flush and straight:
		return {"name": "Straight Flush", "mult": 50.0}
	if freqs.size() > 0 and int(freqs[0]) == 4:
		return {"name": "Four of a Kind", "mult": 25.0}
	if freqs.size() >= 2 and int(freqs[0]) == 3 and int(freqs[1]) == 2:
		return {"name": "Full House", "mult": 9.0}
	if flush:
		return {"name": "Flush", "mult": 6.0}
	if straight:
		return {"name": "Straight", "mult": 4.0}
	if int(freqs[0]) == 3:
		return {"name": "Three of a Kind", "mult": 3.0}
	if freqs.size() >= 2 and int(freqs[0]) == 2 and int(freqs[1]) == 2:
		return {"name": "Two Pair", "mult": 2.0}
	# Jacks or better pair
	for r in counts:
		if int(counts[r]) == 2 and (int(r) >= 10 or int(r) == 0):
			return {"name": "Jacks or Better", "mult": 1.0}
	return {"name": "Nothing", "mult": 0.0}


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return
	var staked := bet
	set_result("Dealing...", UIKit.DIM)
	var hand := _draw_hand()
	_hand_label.text = "  ".join(hand.map(func(c): return String(c["label"])))
	await wait(0.3)
	if not is_inside_tree():
		return
	var result := _evaluate(hand)
	_rank_label.text = String(result["name"])
	var mult: float = float(result["mult"])
	var payout := staked * mult
	var credited := finish_round(payout, 0.55, mult >= 50.0)
	if mult > 0.0:
		set_result("%s!  +%s" % [result["name"], Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, mult)
	elif credited <= 0.0:
		set_result("No hand.", UIKit.DIM)
