extends Minigame

## Pick up to 5 numbers from 1–20. House draws 5. Matches pay a table.
## RTP ≈ 91%.

const POOL := 20
const DRAW := 5
const MAX_PICKS := 5

## matches -> multiplier
const PAY: Dictionary = {0: 0.0, 1: 0.0, 2: 1.5, 3: 5.0, 4: 20.0, 5: 100.0}

var _picks: Array[int] = []
var _num_buttons: Dictionary = {}
var _drawn_label: Label


func _init() -> void:
	game_id = "keno"
	game_name = "Keno"
	game_icon = "🎱"
	base_rtp = 0.91


func _build_board(container: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for n in range(1, POOL + 1):
		var b := UIKit.button(str(n), 14)
		b.custom_minimum_size = Vector2(42, 36)
		b.pressed.connect(_toggle.bind(n))
		_num_buttons[n] = b
		grid.add_child(b)
	container.add_child(grid)

	var clear := UIKit.button("Clear picks", 13, UIKit.ORANGE)
	clear.pressed.connect(func():
		_picks.clear()
		_refresh()
		AudioManager.play_click()
	)
	container.add_child(clear)

	_drawn_label = UIKit.label("Draw: —", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	container.add_child(_drawn_label)
	container.add_child(UIKit.wrapped("Pick 1–5 numbers. House draws 5. 5 matches = 100×.", 12, UIKit.DIM))
	_refresh()


func _toggle(n: int) -> void:
	if n in _picks:
		_picks.erase(n)
	elif _picks.size() < MAX_PICKS:
		_picks.append(n)
	_refresh()
	AudioManager.play_click()


func _refresh() -> void:
	for n in _num_buttons:
		var b: Button = _num_buttons[n]
		b.add_theme_color_override("font_color", UIKit.GOLD if int(n) in _picks else UIKit.TEXT)


func play_once() -> void:
	if _picks.is_empty():
		set_result("Pick at least one number.", UIKit.ORANGE)
		AudioManager.play_error()
		return
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
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
	_drawn_label.text = "Draw: %s" % ", ".join(drawn.map(func(x): return str(x)))

	var matches := 0
	for p in _picks:
		if p in drawn:
			matches += 1
	var mult: float = float(PAY.get(matches, 0.0))
	var payout := staked * mult
	var loss_p := 0.72
	var credited := finish_round(payout, loss_p, matches >= 5)
	if matches >= 2:
		set_result("%d match%s!  +%s" % [matches, "es" if matches != 1 else "", Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, mult)
	elif credited <= 0.0:
		set_result("%d matches." % matches, UIKit.DIM)
