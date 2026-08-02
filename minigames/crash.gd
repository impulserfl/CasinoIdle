extends Minigame

## Crash-style rising multiplier. Cash out before it crashes.
## Auto-play uses a fixed cash-out target selected by the player.
## Instant crash chance + rising hazard keeps RTP ≈ 94%.

var _target := 2.0
var _mult_label: Label
var _target_buttons: Dictionary = {}

const TARGETS: Array[float] = [1.5, 2.0, 3.0, 5.0, 10.0]


func _init() -> void:
	game_id = "crash"
	game_name = "Crash"
	game_icon = "📈"
	base_rtp = 0.94


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	_mult_label = UIKit.label("x1.00", 56, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(_mult_label)
	container.add_child(panel)

	container.add_child(UIKit.label("Auto cash-out at", 14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for t in TARGETS:
		var b := UIKit.button("x%s" % str(t), 15)
		b.custom_minimum_size = Vector2(72, 36)
		b.pressed.connect(_set_target.bind(t))
		_target_buttons[t] = b
		row.add_child(b)
	container.add_child(row)
	container.add_child(UIKit.wrapped(
		"Multiplier climbs until it crashes. Auto cashes out at your target if it gets there.",
		12, UIKit.DIM))
	_refresh_targets()


func _set_target(t: float) -> void:
	_target = t
	_refresh_targets()
	AudioManager.play_click()


func _refresh_targets() -> void:
	for t in _target_buttons:
		var b: Button = _target_buttons[t]
		b.add_theme_color_override("font_color", UIKit.GOLD if is_equal_approx(float(t), _target) else UIKit.TEXT)


## Generate a crash point with heavy tail; house edge via e value.
func _roll_crash_point() -> float:
	# Classic crash formula variant: crash = max(1.0, floor(100 * e) / 100) with e edge
	var r := randf()
	if r < 0.03:
		return 1.0  # instant crash ~3%
	var e := 0.04  # house edge factor
	var point := (1.0 - e) / (1.0 - r)
	return maxf(1.0, snappedf(point, 0.01))


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return

	var staked := bet
	var crash_at := _roll_crash_point()
	var display := 1.0
	set_result("Rising...", UIKit.DIM)
	_mult_label.add_theme_color_override("font_color", UIKit.GREEN)

	while display < crash_at and display < _target:
		display = minf(display + 0.05 + display * 0.03, crash_at)
		_mult_label.text = "x%.2f" % display
		await wait(0.05)
		if not is_inside_tree():
			return

	if display >= _target and _target <= crash_at:
		# Cashed out successfully
		_mult_label.text = "x%.2f" % _target
		_mult_label.add_theme_color_override("font_color", UIKit.GOLD)
		var payout := staked * _target
		var loss_p := clampf(1.0 - (0.94 / _target), 0.2, 0.9)
		var credited := finish_round(payout, loss_p, _target >= 10.0)
		set_result("Cashed out x%.2f  +%s" % [_target, Fmt.chips(payout)], UIKit.GREEN)
		celebrate(payout, _target)
	else:
		# Crashed before target
		_mult_label.text = "x%.2f CRASH" % crash_at
		_mult_label.add_theme_color_override("font_color", UIKit.RED)
		FX.shake(self, 8.0)
		var loss_p := clampf(1.0 - (0.94 / _target), 0.2, 0.9)
		finish_round(0.0, loss_p, false)
		set_result("Crashed at x%.2f" % crash_at, UIKit.DIM)
