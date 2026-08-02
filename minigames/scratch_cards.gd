extends Minigame

## Nine-cell scratch card. Only the single best matching symbol pays.
##
## Common symbols need 4+ matches, rare ones only 3, and the weights are set so
## no "win" is ever smaller than your stake -- a payout that returns 13% of the
## bet reads as a loss to the player, so the table has no tier below 1.0x.
##
## Exact figures, enumerated over all 2,002 ways 9 cells can fall across 6
## symbols: RTP 91.74% | hit rate 27.57% | top prize 4,900x
## Keep LOSS_RATE and base_rtp in step with this table -- Minigame sizes the
## Card Counter refund from them.

const CELLS := 9
const LOSS_RATE := 0.7243

const SYMBOLS: Array[Dictionary] = [
	{"id": "coin",    "icon": "🪙", "weight": 24},
	{"id": "gem",     "icon": "🔷", "weight": 17},
	{"id": "ring",    "icon": "💍", "weight": 11},
	{"id": "crown",   "icon": "👑", "weight": 6},
	{"id": "diamond", "icon": "💎", "weight": 3},
	{"id": "skull",   "icon": "💀", "weight": 39},
]

## symbol id -> { match count: bet multiplier }
const PAYOUTS: Dictionary = {
	"coin":    {4: 1.0, 5: 3.0, 6: 14.0},
	"gem":     {4: 2.5, 5: 9.0, 6: 44.0},
	"ring":    {3: 1.5, 4: 7.0, 5: 31.0, 6: 177.0},
	"crown":   {3: 5.0, 4: 25.0, 5: 137.0, 6: 880.0},
	"diamond": {3: 20.0, 4: 108.0, 5: 687.0, 6: 4900.0},
}

var _cells: Array[Label] = []


func _init() -> void:
	game_id = "scratch"
	game_name = "Scratch Cards"
	game_icon = "🎫"
	base_rtp = 0.9174


func _build_board(container: VBoxContainer) -> void:
	var card := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in range(CELLS):
		var cell := UIKit.panel(UIKit.PANEL, 8, 1)
		cell.custom_minimum_size = Vector2(72, 68)
		var l := UIKit.icon_label("?", 34)
		l.add_theme_color_override("font_color", UIKit.DIM)
		cell.add_child(l)
		_cells.append(l)
		grid.add_child(cell)
	card.add_child(grid)
	container.add_child(card)
	container.add_child(_build_prize_table())


func _build_prize_table() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	for s in SYMBOLS:
		var id := String(s["id"])
		if not PAYOUTS.has(id):
			continue
		var tiers: Dictionary = PAYOUTS[id]
		var counts := tiers.keys()
		counts.sort()
		var lowest := int(counts[0])
		var highest := int(counts[counts.size() - 1])
		var entry := UIKit.vbox(0)
		entry.add_child(UIKit.label("%s x%d+" % [s["icon"], lowest], 14))
		entry.add_child(UIKit.label(
			"%sx - %sx" % [Fmt.chips(float(tiers[lowest])), Fmt.chips(float(tiers[highest]))],
			12, UIKit.GOLD))
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
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	var drawn: Array[Dictionary] = []
	for i in range(CELLS):
		drawn.append(_draw_symbol())

	# Reset the card face.
	for l in _cells:
		l.text = "?"
		l.add_theme_color_override("font_color", UIKit.DIM)
	set_result("Scratching...", UIKit.DIM)

	for i in range(CELLS):
		_cells[i].text = String(drawn[i]["icon"])
		_cells[i].add_theme_color_override("font_color", UIKit.TEXT)
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

	var credited := finish_round(payout, LOSS_RATE, false)

	if payout > 0.0:
		set_result("%d matching %s!  +%s" % [
			best_count, outcome["icon"], Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, multiplier)
		if multiplier >= 100.0:
			FX.flash(self, UIKit.GOLD)
	elif credited <= 0.0:
		set_result("No match.", UIKit.DIM)


## Best single symbol match on the card. Matches the tuning simulation exactly:
## payouts do not stack across symbols.
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
	return "?"
