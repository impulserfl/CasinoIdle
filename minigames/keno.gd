extends Minigame

## Keno: pick up to five numbers from twenty, the house draws five.
##
## Each pick count gets its own paytable, solved so all five return exactly
## 91%. The old table paid nothing at all for one or two matches regardless of
## how many numbers you picked, which made a single-number ticket a guaranteed
## 100% loss while the UI still invited you to buy one.
##
## Hit rates run from 44.7% on a two-spot down to 7.3% on a five-spot, so the
## spot count is a volatility dial, not a maths decision.

const POOL := 20
const DRAW := 5
const MAX_PICKS := 5

## picks -> { matches: multiplier }
const PAYTABLES: Dictionary = {
	1: {1: 3.640},
	2: {1: 1.239, 2: 8.0},
	3: {2: 4.916, 3: 30.0},
	4: {2: 1.913, 3: 12.0, 4: 120.0},
	5: {3: 8.199, 4: 60.0, 5: 1000.0},
}

var _picks: Array[int] = []
var _num_buttons: Dictionary = {}
var _drawn_label: Label
var _table_label: Label


func _init() -> void:
	game_id = "keno"
	game_name = "Keno"
	game_icon = "game_keno"
	base_rtp = 0.91
	rules_text = "Every spot count is priced to the same 91% return."


func _build_board(container: VBoxContainer) -> void:
	var grid := UIKit.grid(10, 4, 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for n in range(1, POOL + 1):
		var b := UIKit.button(str(n), 14)
		b.custom_minimum_size = Vector2(44, 36)
		b.pressed.connect(_toggle.bind(n))
		_num_buttons[n] = b
		grid.add_child(b)
	container.add_child(grid)

	var row := UIKit.hbox(8)
	var clear := UIKit.button("Clear", 13, UIKit.ORANGE)
	clear.custom_minimum_size = Vector2(80, 32)
	clear.pressed.connect(_clear_picks)
	row.add_child(clear)
	var quick := UIKit.button("Quick pick 5", 13, UIKit.BLUE)
	quick.custom_minimum_size = Vector2(120, 32)
	quick.pressed.connect(_quick_pick)
	row.add_child(quick)
	row.add_child(UIKit.spacer())
	_table_label = UIKit.label("", 12, UIKit.CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(_table_label)
	container.add_child(row)

	_drawn_label = UIKit.numeral("Draw: -", 17, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	container.add_child(_drawn_label)
	_refresh()


func _toggle(n: int) -> void:
	if n in _picks:
		_picks.erase(n)
	elif _picks.size() < MAX_PICKS:
		_picks.append(n)
	_refresh()
	AudioManager.play_click()


func _clear_picks() -> void:
	_picks.clear()
	_refresh()
	AudioManager.play_click()


func _quick_pick() -> void:
	_picks.clear()
	var pool: Array[int] = []
	for i in range(1, POOL + 1):
		pool.append(i)
	pool.shuffle()
	for i in range(MAX_PICKS):
		_picks.append(pool[i])
	_refresh()
	AudioManager.play_click()


func _refresh() -> void:
	for n in _num_buttons:
		var b: Button = _num_buttons[n]
		var picked: bool = int(n) in _picks
		b.add_theme_color_override("font_color", UIKit.GOLD if picked else UIKit.DIM)
		b.add_theme_stylebox_override("normal", UIKit.stylebox(
			UIKit.PANEL_HI.lerp(UIKit.GOLD, 0.30) if picked else UIKit.PANEL,
			8, 1, UIKit.GOLD if picked else UIKit.PANEL_EDGE))
	if _table_label != null:
		_table_label.text = _paytable_summary()


func _paytable_summary() -> String:
	var table: Dictionary = PAYTABLES.get(_picks.size(), {})
	if table.is_empty():
		return "Pick 1 to 5 numbers"
	var parts: Array[String] = []
	var keys := table.keys()
	keys.sort()
	for k in keys:
		parts.append("%d match %sx" % [int(k), Fmt.chips(float(table[k]))])
	return "  |  ".join(parts)


func play_once() -> void:
	if _picks.is_empty():
		set_result("Pick at least one number.", UIKit.ORANGE, "lock")
		AudioManager.play_error()
		stop_auto()
		return
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	var table: Dictionary = PAYTABLES.get(_picks.size(), {})
	var pool: Array[int] = []
	for i in range(1, POOL + 1):
		pool.append(i)
	pool.shuffle()
	var drawn: Array[int] = pool.slice(0, DRAW)
	drawn.sort()

	set_result("Drawing...", UIKit.DIM)
	_drawn_label.text = "Draw: ..."
	await wait(0.35)
	if not is_inside_tree():
		return
	var shown: Array[String] = []
	for n in drawn:
		shown.append(str(n))
	_drawn_label.text = "Draw: %s" % ", ".join(shown)
	FX.pulse(_drawn_label, 1.12, 0.2)

	var matches := 0
	for p in _picks:
		if p in drawn:
			matches += 1
	var mult := float(table.get(matches, 0.0))
	var payout := staked * mult
	var credited := finish_round(payout, _loss_rate(), matches >= 5)

	if payout > 0.0:
		set_result("%d match%s  +%s" % [matches, "" if matches == 1 else "es",
			Fmt.chips(payout)], UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if matches >= 5 and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("%d match%s - no win." % [matches, "" if matches == 1 else "es"], UIKit.DIM)


## Probability this ticket pays nothing, from the hypergeometric distribution
## for the current spot count.
func _loss_rate() -> float:
	var k := _picks.size()
	var table: Dictionary = PAYTABLES.get(k, {})
	if table.is_empty():
		return 1.0
	var paying := 0.0
	for m in table:
		paying += _match_probability(k, int(m))
	return clampf(1.0 - paying, 0.0, 1.0)


static func _combinations(n: int, r: int) -> float:
	if r < 0 or r > n:
		return 0.0
	var out := 1.0
	for i in range(r):
		out = out * float(n - i) / float(i + 1)
	return out


static func _match_probability(picks: int, matches: int) -> float:
	var total := _combinations(POOL, picks)
	if total <= 0.0:
		return 0.0
	return _combinations(DRAW, matches) * _combinations(POOL - DRAW, picks - matches) / total
