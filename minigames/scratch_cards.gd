extends Minigame

## Interactive scratch card — click each cell to reveal.

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

const PAYOUTS: Dictionary = {
	"coin":    {4: 1.0, 5: 3.0, 6: 14.0},
	"gem":     {4: 2.5, 5: 9.0, 6: 44.0},
	"ring":    {3: 1.5, 4: 7.0, 5: 31.0, 6: 177.0},
	"crown":   {3: 5.0, 4: 25.0, 5: 137.0, 6: 880.0},
	"diamond": {3: 20.0, 4: 108.0, 5: 687.0, 6: 4900.0},
}

var _cells: Array[TextureRect] = []
var _cell_buttons: Array[Button] = []
var _revealed: Array[bool] = []
var _drawn: Array[Dictionary] = []
var _scratching := false
var _staked := 0.0
var _hint: Label


func _init() -> void:
	game_id = "scratch"
	game_name = "Scratch Cards"
	game_icon = "game_scratch"
	base_rtp = 0.9174
	rules_text = "Buy a card, then scratch each cell. Best match pays."


func _build_board(container: VBoxContainer) -> void:
	var card := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var grid := UIKit.grid(3, 8, 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in range(CELLS):
		var b := UIKit.button("", 12)
		b.custom_minimum_size = Vector2(72, 72)
		var icon := UIKit.icon("", 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		# Center icon roughly
		icon.position = Vector2(16, 16)
		b.pressed.connect(_reveal.bind(i))
		_cell_buttons.append(b)
		_cells.append(icon)
		grid.add_child(b)
	card.add_child(grid)
	container.add_child(card)
	_hint = UIKit.label("Press BUY, then click cells to scratch.", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_hint)
	container.add_child(_build_prize_table())
	if play_button != null:
		play_button.text = "BUY"


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


func _reveal(i: int) -> void:
	if not _scratching or _revealed[i]:
		return
	_revealed[i] = true
	_cells[i].texture = Icons.tex(String(_drawn[i]["icon"]))
	_cell_buttons[i].disabled = true
	FX.pulse(_cells[i], 1.2, 0.12)
	AudioManager.play_tick()
	var all := true
	for r in _revealed:
		if not r:
			all = false
			break
	if all:
		_scratching = false


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	_staked = bet
	_drawn.clear()
	_revealed.clear()
	for i in range(CELLS):
		_drawn.append(_draw_symbol())
		_revealed.append(false)
		_cells[i].texture = null
		_cell_buttons[i].disabled = false

	set_result("Scratch the card!", UIKit.GOLD)
	_hint.text = "Click every cell to reveal."

	if auto:
		for i in range(CELLS):
			_reveal(i)
			await wait(0.08)
			if not is_inside_tree():
				return
	else:
		_scratching = true
		while _scratching and is_inside_tree():
			await get_tree().process_frame
		if not is_inside_tree():
			return

	var outcome := _evaluate(_drawn)
	var multiplier: float = outcome["multiplier"]
	var best_count: int = outcome["count"]
	var payout := _staked * multiplier
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
	_hint.text = "Press BUY for a new card."


func _evaluate(drawn: Array) -> Dictionary:
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
			best = {"multiplier": multiplier, "count": have, "icon": ""}
	return best


func stop_auto() -> void:
	super.stop_auto()
	_scratching = false
