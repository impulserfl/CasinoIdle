extends Minigame

## Interactive crash — multiplier climbs until it busts. Cash out live or set a target.

const HOUSE := 0.94
const TARGETS: Array[float] = [1.2, 1.5, 2.0, 3.0, 5.0, 10.0, 25.0]

var _target := 2.0
var _mult_label: Label
var _bar: ProgressBar
var _target_buttons: Dictionary = {}
var _cashout_btn: Button
var _hint: Label

var _climbing := false
var _cashed := false
var _cash_at := 0.0
var _display := 1.0
var _crash_at := 1.0
var _staked := 0.0


func _init() -> void:
	game_id = "crash"
	game_name = "Crash"
	game_icon = "game_crash"
	base_rtp = HOUSE
	rules_text = "Ride the multiplier. Hit CASH OUT before it crashes."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(8)
	_mult_label = UIKit.numeral("x1.00", 54, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	_mult_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_mult_label)
	_bar = UIKit.progress_bar(UIKit.GREEN, 8)
	col.add_child(_bar)
	panel.add_child(col)
	container.add_child(panel)

	_cashout_btn = UIKit.primary_button("CASH OUT", 20, UIKit.GREEN)
	_cashout_btn.custom_minimum_size = Vector2(0, 52)
	_cashout_btn.disabled = true
	_cashout_btn.pressed.connect(_on_cashout)
	container.add_child(_cashout_btn)

	container.add_child(UIKit.label("Auto cash-out target (optional safety)", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var ids: Array = []
	var labels: Array = []
	for t in TARGETS:
		ids.append(t)
		labels.append("x%s" % Fmt.chips(t))
	var row := UIKit.segmented(ids, labels, _target_buttons, UIKit.GOLD, 62, 36)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in _target_buttons:
		_target_buttons[id].pressed.connect(_set_target.bind(float(id)))
	container.add_child(row)

	_hint = UIKit.label("Press PLAY — then CASH OUT before the crash.", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_hint)
	_refresh_targets()
	if play_button != null:
		play_button.text = "PLAY"


func _set_target(t: float) -> void:
	_target = t
	_refresh_targets()
	AudioManager.play_click()


func _refresh_targets() -> void:
	UIKit.segmented_select(_target_buttons, _target, UIKit.GOLD)


func _roll_crash_point() -> float:
	var r := randf()
	return maxf(1.0, snappedf(HOUSE / maxf(1.0 - r, 1e-9), 0.01))


func _on_cashout() -> void:
	if _climbing and not _cashed:
		_cashed = true
		_cash_at = snappedf(_display, 0.01)
		AudioManager.play_click()


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	_staked = bet
	_crash_at = _roll_crash_point()
	_display = 1.0
	_cashed = false
	_cash_at = 0.0
	_climbing = true
	_mult_label.add_theme_color_override("font_color", UIKit.GREEN)
	_mult_label.text = "x1.00"
	_bar.value = 0.0
	set_result("Climbing — cash out anytime!", UIKit.CYAN)
	_hint.text = "CASH OUT before it crashes!"
	if not auto:
		_cashout_btn.disabled = false
	if play_button != null:
		play_button.disabled = true

	while _climbing and is_inside_tree():
		if _cashed:
			break
		if auto and _display >= _target:
			_cashed = true
			_cash_at = _target
			break
		if _display >= _crash_at:
			break
		# Auto safety target also applies in manual if reached first
		if not auto and _display >= _target:
			_cashed = true
			_cash_at = _target
			break
		_display = minf(_display + 0.04 + _display * 0.025, _crash_at)
		_mult_label.text = "x%.2f" % _display
		_bar.value = clampf((_display - 1.0) / maxf(minf(_target, 10.0) - 1.0, 0.01), 0.0, 1.0)
		await wait(0.045)
		if not is_inside_tree():
			return

	_climbing = false
	_cashout_btn.disabled = true
	if play_button != null:
		play_button.disabled = false

	# Effective cash multiplier for RTP accounting uses the target the player
	# *intended*; live cash-out uses actual cash_at but still within the house curve.
	var used := _cash_at if _cashed else 0.0
	var loss_probability := clampf(1.0 - HOUSE / maxf(_target, 1.01), 0.0, 1.0)

	if _cashed and used > 1.0 and used <= _crash_at + 0.001:
		_mult_label.text = "x%.2f" % used
		_mult_label.add_theme_color_override("font_color", UIKit.GOLD)
		_bar.value = 1.0
		var payout := _staked * used
		# Use cash point for loss rate approximation
		loss_probability = clampf(1.0 - HOUSE / maxf(used, 1.01), 0.0, 1.0)
		finish_round(payout, loss_probability, used >= 10.0)
		set_result("Cashed out at x%.2f  +%s" % [used, Fmt.chips(payout)], UIKit.GREEN, "check")
		celebrate(payout, used)
		if used >= 10.0 and Settings.stop_auto_on_jackpot:
			stop_auto()
	else:
		_mult_label.text = "x%.2f" % _crash_at
		_mult_label.add_theme_color_override("font_color", UIKit.RED)
		_bar.value = 0.0
		if Settings.screen_shake:
			FX.shake(self, 8.0)
		var credited := finish_round(0.0, loss_probability, false)
		if credited <= 0.0:
			set_result("Crashed at x%.2f" % _crash_at, UIKit.DIM)
	_hint.text = "Press PLAY — then CASH OUT before the crash."


func stop_auto() -> void:
	super.stop_auto()
	_climbing = false
