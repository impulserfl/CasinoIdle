class_name Minigame
extends Control

## Shared shell for every gambling game: bet controls, play/auto buttons, result
## line, wager bookkeeping and the capped RTP bonus.

const AUTO_DELAY := 0.35
const HARD_BET_CAP := 1e15

var game_id := "game"
var game_name := "Game"
var game_icon := "🎲"
var base_rtp := 0.95

var bet: float = 10.0
var last_wager: float = 0.0
var busy := false
var auto := false

var board: VBoxContainer
var result_label: Label
var bet_label: Label
var play_button: Button
var auto_button: Button
var odds_label: Label

var _bet_initialised := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_shell()
	_build_board(board)
	_sync_bet()
	_refresh_controls()
	GameManager.chips_changed.connect(_on_chips_changed)


func _build_shell() -> void:
	var root := UIKit.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 14
	root.offset_top = 12
	root.offset_right = -14
	root.offset_bottom = -12
	add_child(root)

	var header := UIKit.hbox(10)
	header.add_child(UIKit.title("%s  %s" % [game_icon, game_name], 24))
	header.add_child(UIKit.spacer())
	odds_label = UIKit.label("", 13, UIKit.DIM)
	header.add_child(odds_label)
	root.add_child(header)
	root.add_child(UIKit.separator())

	board = UIKit.vbox(10)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board)

	result_label = UIKit.label("Place your bet.", 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(result_label)

	root.add_child(_build_bet_row())

	var actions := UIKit.hbox(12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	play_button = UIKit.primary_button("PLAY", 22, UIKit.GOLD)
	play_button.custom_minimum_size = Vector2(190, 52)
	play_button.pressed.connect(_on_play_pressed)
	actions.add_child(play_button)

	auto_button = UIKit.button("AUTO: OFF", 18, UIKit.GREEN)
	auto_button.custom_minimum_size = Vector2(150, 52)
	auto_button.pressed.connect(_on_auto_pressed)
	actions.add_child(auto_button)
	root.add_child(actions)


func _build_bet_row() -> Control:
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	bet_label = UIKit.label("Bet: 10", 18, UIKit.GOLD)
	bet_label.custom_minimum_size = Vector2(190, 0)
	bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(bet_label)

	for entry in [["/10", 0.1], ["/2", 0.5], ["x2", 2.0], ["x10", 10.0]]:
		var b := UIKit.button(String(entry[0]), 15)
		b.custom_minimum_size = Vector2(52, 34)
		b.pressed.connect(_scale_bet.bind(float(entry[1])))
		row.add_child(b)

	var max_button := UIKit.button("MAX", 15, UIKit.GOLD)
	max_button.custom_minimum_size = Vector2(58, 34)
	max_button.pressed.connect(_max_bet)
	row.add_child(max_button)
	return row


func max_bet() -> float:
	var soft := maxf(10.0, GameManager.chips * GameManager.max_bet_fraction())
	return minf(soft, HARD_BET_CAP)


func _scale_bet(factor: float) -> void:
	bet = clampf(bet * factor, 1.0, maxf(max_bet(), 1.0))
	_sync_bet()
	AudioManager.play_click()


func _max_bet() -> void:
	bet = maxf(floorf(max_bet()), 1.0)
	_sync_bet()
	AudioManager.play_click()


func _sync_bet() -> void:
	var ceiling := maxf(max_bet(), 1.0)
	if not _bet_initialised:
		bet = clampf(10.0, 1.0, ceiling)
		_bet_initialised = true
	bet = clampf(bet, 1.0, ceiling)
	if bet > 1000.0:
		bet = floorf(bet)
	if bet_label != null:
		bet_label.text = "Bet: %s" % Fmt.chips(bet)


func _on_chips_changed(_amount: float) -> void:
	_sync_bet()
	_refresh_controls()


func can_afford_bet() -> bool:
	return GameManager.chips >= bet and bet >= 1.0


func _refresh_controls() -> void:
	if play_button != null:
		play_button.disabled = busy or not can_afford_bet()
	if odds_label != null:
		odds_label.text = "RTP %s" % Fmt.percent(effective_rtp())


func effective_rtp() -> float:
	return minf(base_rtp + GameManager.rtp_bonus(), GameManager.MAX_EFFECTIVE_RTP)


func _on_play_pressed() -> void:
	if busy:
		return
	AudioManager.play_click()
	_start_round()


func _start_round() -> void:
	busy = true
	_refresh_controls()
	await play_once()
	busy = false
	_refresh_controls()


func _on_auto_pressed() -> void:
	auto = not auto
	_refresh_auto_button()
	AudioManager.play_click()
	if auto and not busy:
		_run_auto()


func _refresh_auto_button() -> void:
	if auto_button == null:
		return
	auto_button.text = "AUTO: ON" if auto else "AUTO: OFF"
	auto_button.add_theme_color_override("font_color", UIKit.GREEN if auto else UIKit.TEXT)


func _run_auto() -> void:
	busy = true
	_refresh_controls()
	while auto and is_inside_tree():
		if not can_afford_bet():
			set_result("Not enough chips for that bet.", UIKit.RED)
			AudioManager.play_error()
			auto = false
			_refresh_auto_button()
			break
		await play_once()
		if not auto or not is_inside_tree():
			break
		await wait(AUTO_DELAY * GameManager.auto_delay_multiplier())
	busy = false
	_refresh_controls()


func stop_auto() -> void:
	auto = false
	_refresh_auto_button()


func _exit_tree() -> void:
	auto = false


func wager(amount: float) -> bool:
	if not GameManager.spend_chips(amount):
		AudioManager.play_error()
		return false
	last_wager = amount
	GameManager.record_wager(game_id, amount)
	if not auto or Settings.auto_spin_sfx:
		AudioManager.play_spin()
	return true


func finish_round(payout: float, loss_probability: float, is_jackpot: bool = false) -> float:
	var credited := payout
	var refunded := false
	if payout <= 0.0 and _roll_fortune(loss_probability):
		credited = last_wager
		refunded = true

	if credited > 0.0:
		GameManager.add_chips(credited, not refunded)

	GameManager.record_result(payout, last_wager, is_jackpot)

	if refunded:
		set_result("Close one — stake refunded.", UIKit.BLUE)
		FX.float_text(self, "REFUND", UIKit.BLUE, size * 0.5, 24)
		if not auto or Settings.auto_spin_sfx:
			AudioManager.play_refund()
	elif payout > 0.0 and last_wager > 0.0:
		if not auto or Settings.auto_spin_sfx:
			AudioManager.play_win(payout / last_wager)
	return credited


func fortune_refund_chance(loss_probability: float) -> float:
	if loss_probability <= 0.0:
		return 0.0
	var deficit := maxf(effective_rtp() - base_rtp, 0.0)
	return clampf(deficit / loss_probability, 0.0, 1.0)


func _roll_fortune(loss_probability: float) -> bool:
	return randf() < fortune_refund_chance(loss_probability)


func wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	var scaled := maxf(seconds * GameManager.speed_multiplier(), 0.01)
	await get_tree().create_timer(scaled).timeout


func set_result(text: String, color: Color = UIKit.TEXT) -> void:
	if result_label == null:
		return
	result_label.text = text
	result_label.add_theme_color_override("font_color", color)


func celebrate(amount: float, multiplier: float) -> void:
	var color := UIKit.GREEN
	var prefix := "+"
	if multiplier >= 50.0:
		color = UIKit.GOLD
		prefix = "BIG WIN  +"
		FX.shake(self, 10.0)
	elif multiplier >= 10.0:
		color = UIKit.ORANGE
	FX.float_text(self, prefix + Fmt.chips(amount), color, size * Vector2(0.5, 0.42), 32)


static func weighted_pick(entries: Array, rng: RandomNumberGenerator = null) -> Variant:
	var total := 0.0
	for e in entries:
		total += float(e[1])
	var roll := (rng.randf() if rng != null else randf()) * total
	for e in entries:
		roll -= float(e[1])
		if roll <= 0.0:
			return e[0]
	return entries[entries.size() - 1][0]


func _build_board(_container: VBoxContainer) -> void:
	pass


func play_once() -> void:
	pass
