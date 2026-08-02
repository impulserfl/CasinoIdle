extends Minigame

## Crash: a multiplier climbs until it busts. You cash out at a chosen target.
##
## The crash point is drawn as
##
##     crash = HOUSE / (1 - r),  r uniform on [0, 1),  floored at 1.0
##
## so P(crash >= T) = HOUSE / T for any target T >= HOUSE, and the return is
## (HOUSE / T) * T = HOUSE exactly — the same 94% whichever target you pick.
##
## The old version used 0.96 while declaring 0.94, and carried an "instant
## crash" branch that could never fire: any target of 1.5x or more already
## loses on every roll that branch would have caught.

const HOUSE := 0.94
const TARGETS: Array[float] = [1.2, 1.5, 2.0, 3.0, 5.0, 10.0, 25.0]

var _target := 2.0
var _mult_label: Label
var _bar: ProgressBar
var _target_buttons: Dictionary = {}


func _init() -> void:
	game_id = "crash"
	game_name = "Crash"
	game_icon = "game_crash"
	base_rtp = HOUSE
	rules_text = "Every cash-out target returns the same 94%. Higher targets just hit less often."


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

	container.add_child(UIKit.label("Cash out at", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
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

	container.add_child(UIKit.wrapped(
		"A target of x%s hits about %s of the time." % [
			Fmt.chips(_target), Fmt.percent(HOUSE / _target, 1)], 12, UIKit.DIM))
	_refresh_targets()


func _set_target(t: float) -> void:
	_target = t
	_refresh_targets()
	AudioManager.play_click()


func _refresh_targets() -> void:
	UIKit.segmented_select(_target_buttons, _target, UIKit.GOLD)


## Crash point with the house edge folded into the numerator.
func _roll_crash_point() -> float:
	var r := randf()
	return maxf(1.0, snappedf(HOUSE / maxf(1.0 - r, 1e-9), 0.01))


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	var staked := bet
	var crash_at := _roll_crash_point()
	var display := 1.0
	set_result("Climbing...", UIKit.DIM)
	_mult_label.add_theme_color_override("font_color", UIKit.GREEN)

	while display < crash_at and display < _target:
		display = minf(display + 0.05 + display * 0.03, minf(crash_at, _target))
		_mult_label.text = "x%.2f" % display
		_bar.value = clampf((display - 1.0) / maxf(_target - 1.0, 0.01), 0.0, 1.0)
		await wait(0.05)
		if not is_inside_tree():
			return

	# P(this round pays nothing) for the chosen target.
	var loss_probability := clampf(1.0 - HOUSE / _target, 0.0, 1.0)

	if crash_at >= _target:
		_mult_label.text = "x%.2f" % _target
		_mult_label.add_theme_color_override("font_color", UIKit.GOLD)
		_bar.value = 1.0
		var payout := staked * _target
		finish_round(payout, loss_probability, _target >= 10.0)
		set_result("Cashed out at x%s  +%s" % [Fmt.chips(_target), Fmt.chips(payout)],
			UIKit.GREEN, "check")
		celebrate(payout, _target)
		if _target >= 10.0 and Settings.stop_auto_on_jackpot:
			stop_auto()
	else:
		_mult_label.text = "x%.2f" % crash_at
		_mult_label.add_theme_color_override("font_color", UIKit.RED)
		_bar.value = 0.0
		if Settings.screen_shake:
			FX.shake(self, 8.0)
		var credited := finish_round(0.0, loss_probability, false)
		if credited <= 0.0:
			set_result("Crashed at x%.2f" % crash_at, UIKit.DIM)
