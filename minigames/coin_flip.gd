extends Minigame

## Simple coin flip — heads or tails at nearly even money.
## House edge keeps RTP at 95%.

var _side := "heads"
var _coin_label: Label
var _side_buttons: Dictionary = {}


func _init() -> void:
	game_id = "coin_flip"
	game_name = "Coin Flip"
	game_icon = "🪙"
	base_rtp = 0.95


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	_coin_label = UIKit.label("🪙", 72, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(_coin_label)
	container.add_child(panel)

	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in [["heads", "HEADS"], ["tails", "TAILS"]]:
		var b := UIKit.button(String(entry[1]), 20, UIKit.GOLD)
		b.custom_minimum_size = Vector2(130, 48)
		b.pressed.connect(_select.bind(String(entry[0])))
		_side_buttons[String(entry[0])] = b
		row.add_child(b)
	container.add_child(row)
	container.add_child(UIKit.wrapped("Call it in the air. Pays 1.9x on a correct call.", 12, UIKit.DIM))
	_refresh()


func _select(s: String) -> void:
	_side = s
	_refresh()
	AudioManager.play_click()


func _refresh() -> void:
	for k in _side_buttons:
		var b: Button = _side_buttons[k]
		b.add_theme_color_override("font_color", UIKit.GOLD if k == _side else UIKit.TEXT)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	set_result("Flipping...", UIKit.DIM)
	for i in range(10):
		if i % 2 == 0:
			_coin_label.text = "🪙"
		else:
			_coin_label.text = "⚪"
		await wait(0.04 + float(i) * 0.008)
		if not is_inside_tree():
			return

	var result := "heads"
	if randf() >= 0.5:
		result = "tails"
	if result == "heads":
		_coin_label.text = "🪙"
	else:
		_coin_label.text = "⚪"
	FX.pulse(_coin_label, 1.25, 0.2)

	var won := result == _side
	var payout := 0.0
	if won:
		payout = staked * 1.9
	var credited := finish_round(payout, 0.5, false)
	if won:
		set_result("%s!  +%s" % [result.capitalize(), Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, 1.9)
	elif credited <= 0.0:
		set_result("%s - wrong call." % result.capitalize(), UIKit.DIM)
