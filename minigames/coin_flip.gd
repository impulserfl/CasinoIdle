extends Minigame

## Call heads or tails, then flip. 1.9x on a fair coin = 95% RTP.

const PAYS := 1.9
const LOSS_RATE := 0.5

var _side := "heads"
var _coin: TextureRect
var _coin_panel: PanelContainer
var _side_buttons: Dictionary = {}
var _hint: Label


func _init() -> void:
	game_id = "coin_flip"
	game_name = "Coin Flip"
	game_icon = "game_coinflip"
	base_rtp = 0.95
	rules_text = "Call it, then flip. Correct call pays 1.9x."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var tile := UIKit.icon_tile("chip_gold", 140, 110, UIKit.PANEL_SUNK)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_coin_panel = tile
	_coin = tile.get_child(0) as TextureRect
	panel.add_child(tile)
	container.add_child(panel)

	var row := UIKit.segmented(["heads", "tails"], ["HEADS", "TAILS"], _side_buttons, UIKit.GOLD, 140, 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in _side_buttons:
		_side_buttons[id].pressed.connect(_select.bind(String(id)))
	container.add_child(row)
	_hint = UIKit.label("Pick a side, then press FLIP.", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_hint)
	_refresh()
	if play_button != null:
		play_button.text = "FLIP"


func _select(s: String) -> void:
	if busy:
		return
	_side = s
	_refresh()
	AudioManager.play_chip_place()


func _refresh() -> void:
	UIKit.segmented_select(_side_buttons, _side, UIKit.GOLD)


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	set_result("Flipping...", UIKit.DIM)
	_hint.text = "In the air..."
	AudioManager.play_spin()

	# Spin with scale squash to fake 3D flip
	var delay := 0.03
	for i in range(16):
		var heads := i % 2 == 0
		_coin.texture = Icons.tex("chip_gold" if heads else "chip")
		if _coin_panel != null:
			_coin_panel.scale = Vector2(1.0, 0.35 + 0.65 * absf(sin(float(i) * 0.4)))
			_coin_panel.pivot_offset = _coin_panel.size * 0.5
		await wait(delay)
		if not is_inside_tree():
			return
		delay *= 1.08

	if _coin_panel != null:
		_coin_panel.scale = Vector2.ONE
	var result := "heads" if randf() < 0.5 else "tails"
	_coin.texture = Icons.tex("chip_gold" if result == "heads" else "chip")
	FX.pulse(_coin, 1.25, 0.2)
	AudioManager.play_tick()

	var won := result == _side
	var payout := staked * PAYS if won else 0.0
	var credited := finish_round(payout, LOSS_RATE, false)
	if won:
		set_result("%s  +%s" % [result.capitalize(), Fmt.chips(payout)], UIKit.GREEN, "check")
		celebrate(payout, PAYS)
		_hint.text = "Nice call."
	elif credited <= 0.0:
		set_result("%s - wrong call." % result.capitalize(), UIKit.DIM)
		_hint.text = "Pick a side, then press FLIP."
