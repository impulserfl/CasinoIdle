extends Minigame

## Heads or tails at 1.9x on a fair coin: 0.5 * 1.9 = exactly 95% RTP.

const PAYS := 1.9
const LOSS_RATE := 0.5

var _side := "heads"
var _coin: TextureRect
var _side_buttons: Dictionary = {}


func _init() -> void:
	game_id = "coin_flip"
	game_name = "Coin Flip"
	game_icon = "game_coinflip"
	base_rtp = 0.95
	rules_text = "Call it in the air. A correct call pays 1.9x."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var tile := UIKit.icon_tile("chip_gold", 132, 104, UIKit.PANEL_SUNK)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_coin = tile.get_child(0) as TextureRect
	panel.add_child(tile)
	container.add_child(panel)

	var row := UIKit.segmented(["heads", "tails"], ["HEADS", "TAILS"], _side_buttons,
		UIKit.GOLD, 140, 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in _side_buttons:
		_side_buttons[id].pressed.connect(_select.bind(String(id)))
	container.add_child(row)
	_refresh()


func _select(s: String) -> void:
	_side = s
	_refresh()
	AudioManager.play_click()


func _refresh() -> void:
	UIKit.segmented_select(_side_buttons, _side, UIKit.GOLD)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	set_result("Flipping...", UIKit.DIM)
	for i in range(10):
		_coin.texture = Icons.tex("chip_gold" if i % 2 == 0 else "chip")
		await wait(0.04 + float(i) * 0.008)
		if not is_inside_tree():
			return

	var result := "heads" if randf() < 0.5 else "tails"
	_coin.texture = Icons.tex("chip_gold" if result == "heads" else "chip")
	FX.pulse(_coin, 1.25, 0.2)

	var won := result == _side
	var payout := staked * PAYS if won else 0.0
	var credited := finish_round(payout, LOSS_RATE, false)

	if won:
		set_result("%s  +%s" % [result.capitalize(), Fmt.chips(payout)], UIKit.GREEN, "check")
		celebrate(payout, PAYS)
	elif credited <= 0.0:
		set_result("%s - wrong call." % result.capitalize(), UIKit.DIM)
