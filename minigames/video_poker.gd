extends Minigame

## Five-card poker, one deal, no draw.
##
## The evaluator here is a rewrite. The old one had three bugs that all
## survived because nothing enumerated the deck:
##   - a real royal (A-10-J-Q-K) sorts to [0,9,10,11,12] and failed the
##     "consecutive ranks" test, so it paid as a plain flush;
##   - "ranks[0] == 8" meant 9-10-J-Q-K suited was the hand being paid 250x;
##   - the wheel special case tested for [0,1,2,3,12] — A-2-3-4-K, not a
##     straight at all — so that suited hand paid as a straight flush.
## Actual return was 33.6% against a declared 92%.
##
## Because there is no draw, a natural deal cannot reach 92% on a standard
## jacks-or-better ladder, so the table pays any pair. The paytable is exact
## over all 2,598,960 deals; verify_balance.py re-derives it.
##   RTP 92.00%  |  hit rate 49.88%

const HANDS: Array[Dictionary] = [
	{"id": "royal",     "name": "Royal Flush",     "pays": 800.0},
	{"id": "str_flush", "name": "Straight Flush",  "pays": 100.0},
	{"id": "quads",     "name": "Four of a Kind",  "pays": 50.0},
	{"id": "boat",      "name": "Full House",      "pays": 12.0},
	{"id": "flush",     "name": "Flush",           "pays": 9.0},
	{"id": "straight",  "name": "Straight",        "pays": 7.0},
	{"id": "trips",     "name": "Three of a Kind", "pays": 4.0},
	{"id": "two_pair",  "name": "Two Pair",        "pays": 2.5},
	{"id": "jacks",     "name": "Jacks or Better", "pays": 2.0},
	{"id": "pair",      "name": "Pair",            "pays": 1.2972},
]

const LOSS_RATE := 0.501177

## Sorted rank indices of an ace-high straight (10-J-Q-K-A). Aces are index 0,
## so this run is not consecutive and needs naming explicitly.
const ACE_HIGH_RUN: Array[int] = [0, 9, 10, 11, 12]

var _cards: Array[PanelContainer] = []
var _hand_label: Label


func _init() -> void:
	game_id = "video_poker"
	game_name = "Video Poker"
	game_icon = "game_videopoker"
	base_rtp = 0.92
	rules_text = "One deal, no draw. Any pair pays, and the ladder is priced for it."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(5):
		var c := UIKit.card(66, 92)
		UIKit.set_card_back(c)
		_cards.append(c)
		row.add_child(c)
	col.add_child(row)
	_hand_label = UIKit.label("", 18, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_hand_label)
	panel.add_child(col)
	container.add_child(panel)
	container.add_child(_build_paytable())


func _build_paytable() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(2, 24, 2)
	for h in HANDS:
		var row := UIKit.hbox(6)
		var name_label := UIKit.label(String(h["name"]), 12, UIKit.DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UIKit.label("%sx" % Fmt.chips(float(h["pays"])), 12, UIKit.GOLD))
		grid.add_child(row)
	panel.add_child(grid)
	return panel


func _deal() -> Array:
	## Deal five distinct cards. A card is suit * 13 + rank.
	var deck: Array[int] = []
	for i in range(52):
		deck.append(i)
	deck.shuffle()
	return deck.slice(0, 5)


## Rank index 0..12 where 0 is an Ace.
static func rank_of(card: int) -> int:
	return card % 13


static func suit_of(card: int) -> int:
	return int(card / 13)


## Returns the winning HANDS entry, or an empty dictionary for no pay.
static func evaluate(hand: Array) -> Dictionary:
	var ranks: Array[int] = []
	var suits: Array[int] = []
	for c in hand:
		ranks.append(rank_of(int(c)))
		suits.append(suit_of(int(c)))
	ranks.sort()

	var counts: Dictionary = {}
	for r in ranks:
		counts[r] = int(counts.get(r, 0)) + 1
	var freqs: Array[int] = []
	for r in counts:
		freqs.append(int(counts[r]))
	freqs.sort()
	freqs.reverse()

	var flush := true
	for s in suits:
		if s != suits[0]:
			flush = false
			break

	# Aces are index 0, so a straight is either five consecutive indices
	# (A-2-3-4-5 included) or the ace-high run [0, 9, 10, 11, 12].
	var run := true
	for i in range(4):
		if ranks[i + 1] != ranks[i] + 1:
			run = false
			break
	var ace_high := ranks == ACE_HIGH_RUN
	var straight := run or ace_high

	if flush and ace_high:
		return _hand("royal")
	if flush and straight:
		return _hand("str_flush")
	if freqs[0] == 4:
		return _hand("quads")
	if freqs.size() >= 2 and freqs[0] == 3 and freqs[1] == 2:
		return _hand("boat")
	if flush:
		return _hand("flush")
	if straight:
		return _hand("straight")
	if freqs[0] == 3:
		return _hand("trips")
	if freqs.size() >= 2 and freqs[0] == 2 and freqs[1] == 2:
		return _hand("two_pair")
	for r in counts:
		if int(counts[r]) == 2:
			# Jacks, queens, kings and aces qualify for the better tier.
			return _hand("jacks") if int(r) >= 10 or int(r) == 0 else _hand("pair")
	return {}


static func _hand(id: String) -> Dictionary:
	for h in HANDS:
		if String(h["id"]) == id:
			return h
	return {}


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	set_result("Dealing...", UIKit.DIM)
	_hand_label.text = ""
	for c in _cards:
		UIKit.set_card_back(c)
	await wait(0.16)
	if not is_inside_tree():
		return

	var hand := _deal()
	for i in range(hand.size()):
		UIKit.set_card(_cards[i], rank_of(int(hand[i])), suit_of(int(hand[i])))
		FX.pulse(_cards[i], 1.1, 0.14)
		await wait(0.06)
		if not is_inside_tree():
			return

	var result := evaluate(hand)
	var mult := float(result.get("pays", 0.0))
	var payout := staked * mult
	_hand_label.text = String(result.get("name", "No pair"))
	var is_jackpot := mult >= 100.0
	var credited := finish_round(payout, LOSS_RATE, is_jackpot)

	if payout > 0.0:
		set_result("%s  +%s" % [String(result["name"]), Fmt.chips(payout)],
			UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if is_jackpot and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("No pair.", UIKit.DIM)
