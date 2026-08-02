extends Minigame

## Nine-cell scratch card. Only the single best matching symbol pays.
##
## Common symbols need 4+ matches, rare ones only 3, and the weights are set so
## no "win" is ever smaller than the stake — a payout returning 13% of the bet
## reads as a loss to the player, so the table has no tier below 1.0x.
##
## Exact figures, enumerated over all 2,002 ways 9 cells fall across 6 symbols:
##   RTP 91.74%  |  hit rate 27.57%  |  top prize 4,900x
## Keep LOSS_RATE and base_rtp in step with this table — Minigame sizes the
## loss refund from them.

const CELLS := 9
const LOSS_RATE := 0.7243

const SYMBOLS: Array[Dictionary] = [
	{"id": "coin",    "icon": "sym_coin",    "weight": 24},
	{"id": "gem",     "icon": "sym_gem",     "weight": 17},
	{"id": "ring",    "icon": "sym_ring",    "weight": 11},
	{"id": "crown",   "icon": "sym_crown",   "weight": 6},
	{"id": "diamond", "icon": "sym_diamond", "weight": 3},
	{"id": "skull",   "icon": "sym_skull",   "weight": 39},
]

## symbol id -> { match count: bet multiplier }
const PAYOUTS: Dictionary = {
	"coin":    {4: 1.0, 5: 3.0, 6: 14.0},
	"gem":     {4: 2.5, 5: 9.0, 6: 44.0},
	"ring":    {3: 1.5, 4: 7.0, 5: 31.0, 6: 177.0},
	"crown":   {3: 5.0, 4: 25.0, 5: 137.0, 6: 880.0},
	"diamond": {3: 20.0, 4: 108.0, 5: 687.0, 6: 4900.0},
}

var _cells: Array[TextureRect] = []


func _init() -> void:
	game_id = "scratch"
	game_name = "Scratch Cards"
	game_icon = "game_scratch"
	base_rtp = 0.9174
	rules_text = "Match symbols across nine cells. Only the best symbol pays."


func _build_board(container: VBoxContainer) -> void:
	var card := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var grid := UIKit.grid(3, 8, 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in range(CELLS):
		var tile := UIKit.icon_tile("", 70, 44, UIKit.PANEL_SUNK)
		_cells.append(tile.get_child(0) as TextureRect)
		grid.add_child(tile)
	card.add_child(grid)
	container.add_child(card)
	container.add_child(_build_prize_table())


func _build_prize_table() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(5, 12, 3)
	for s in SYMBOLS:
		var id := String(s["id"])
		if not PAYOUTS.has(id):
			continue
		var tiers: Dictionary = PAYOUTS[id]
		var counts := tiers.keys()
		counts.sort()
		var lowest := int(counts[0])
		var highest := int(counts[counts.size() - 1])
		var entry := UIKit.vbox(1)
		var head := UIKit.hbox(4)
		head.add_child(UIKit.icon(String(s["icon"]), 18))
		head.add_child(UIKit.label("x%d+" % lowest, 12, UIKit.DIM))
		entry.add_child(head)
		entry.add_child(UIKit.label("%sx - %sx" % [
			Fmt.chips(float(tiers[lowest])), Fmt.chips(float(tiers[highest]))], 12, UIKit.GOLD))
		grid.add_child(entry)
	panel.add_child(grid)
	return panel


func _draw_symbol() -> Dictionary:
	var entries: Array = []
	for s in SYMBOLS:
		entries.append([s, s["weight"]])
	return weighted_pick(entries)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	var drawn: Array[Dictionary] = []
	for i in range(CELLS):
		drawn.append(_draw_symbol())

	for c in _cells:
		c.texture = null
	set_result("Scratching...", UIKit.DIM)

	for i in range(CELLS):
		_cells[i].texture = Icons.tex(String(drawn[i]["icon"]))
		FX.pulse(_cells[i], 1.25, 0.16)
		await wait(0.09)
		if not is_inside_tree():
			return

	var outcome := _evaluate(drawn)
	var multiplier: float = outcome["multiplier"]
	var best_count: int = outcome["count"]
	var payout := staked * multiplier

	if best_count >= 6:
		Achievements.notify("full_board")

	var credited := finish_round(payout, LOSS_RATE, multiplier >= 100.0)

	if payout > 0.0:
		set_result("%d matching  +%s" % [best_count, Fmt.chips(payout)], UIKit.GREEN, "check")
		celebrate(payout, multiplier)
		if multiplier >= 100.0:
			FX.flash(self, UIKit.GOLD)
			if Settings.stop_auto_on_jackpot:
				stop_auto()
	elif credited <= 0.0:
		set_result("No match.", UIKit.DIM)


## Best single symbol on the card. Payouts never stack across symbols, which is
## exactly what the enumeration in verify_balance.py assumes.
func _evaluate(drawn: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for s in drawn:
		var id := String(s["id"])
		counts[id] = int(counts.get(id, 0)) + 1

	var best := {"multiplier": 0.0, "count": 0, "icon": ""}
	for id in counts:
		if not PAYOUTS.has(id):
			continue
		var have := int(counts[id])
		var tiers: Dictionary = PAYOUTS[id]
		var best_tier := 0
		for t in tiers:
			var tier := int(t)
			if have >= tier and tier > best_tier:
				best_tier = tier
		if best_tier == 0:
			continue
		var multiplier := float(tiers[best_tier])
		if multiplier > float(best["multiplier"]):
			best = {"multiplier": multiplier, "count": have, "icon": _icon_for(id)}
	return best


func _icon_for(id: String) -> String:
	for s in SYMBOLS:
		if String(s["id"]) == id:
			return String(s["icon"])
	return ""
