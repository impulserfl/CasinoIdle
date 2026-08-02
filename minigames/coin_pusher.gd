extends Minigame

## Interactive coin pusher — time your drop as the shelf shifts.

const OUTCOMES: Array[Dictionary] = [
	{"label": "Nothing fell", "mult": 0.0,  "weight": 1060},
	{"label": "A trickle",    "mult": 1.5,  "weight": 260},
	{"label": "A small drop", "mult": 3.0,  "weight": 120},
	{"label": "A good push",  "mult": 6.0,  "weight": 45},
	{"label": "An avalanche", "mult": 15.0, "weight": 12},
	{"label": "JACKPOT SHELF", "mult": 50.0, "weight": 3},
]

const LOSS_RATE := 0.706667

var _shelf: HBoxContainer
var _outcome_label: Label
var _hint: Label
var _marker: ProgressBar
var _awaiting := false
var _drop_now := false
var _sweep := 0.0
var _sweep_dir := 1.0
var _staked := 0.0


func _init() -> void:
	game_id = "coin_pusher"
	game_name = "Coin Pusher"
	game_icon = "game_pusher"
	base_rtp = 0.90
	rules_text = "Time the DROP when the marker is near the centre for a better shelf."


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 2)
	var col := UIKit.vbox(10)
	col.add_child(UIKit.label("SHELF", 11, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_shelf = UIKit.hbox(4)
	_shelf.alignment = BoxContainer.ALIGNMENT_CENTER
	_shelf.custom_minimum_size = Vector2(0, 40)
	col.add_child(_shelf)
	_marker = UIKit.progress_bar(UIKit.GOLD, 12)
	col.add_child(_marker)
	_outcome_label = UIKit.label("Drop a coin", 17, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_outcome_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_outcome_label)
	panel.add_child(col)
	container.add_child(panel)
	_hint = UIKit.label("Press PLAY, then DROP near the centre.", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_hint)
	container.add_child(_build_prize_table())
	_render_shelf(5)
	if play_button != null:
		play_button.text = "DROP"


func _build_prize_table() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(3, 14, 4)
	for o in OUTCOMES:
		if float(o["mult"]) <= 0.0:
			continue
		var row := UIKit.hbox(6)
		var l := UIKit.label(String(o["label"]), 12, UIKit.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.label("%sx" % Fmt.chips(float(o["mult"])), 12, UIKit.tier_color(float(o["mult"]))))
		grid.add_child(row)
	panel.add_child(grid)
	return panel


func _render_shelf(coins: int) -> void:
	for child in _shelf.get_children():
		_shelf.remove_child(child)
		child.queue_free()
	for i in range(coins):
		_shelf.add_child(UIKit.icon("chip_gold", 26))


func _process(delta: float) -> void:
	super._process(delta)
	if not _awaiting:
		return
	_sweep += delta * 1.4 * _sweep_dir
	if _sweep >= 1.0:
		_sweep = 1.0
		_sweep_dir = -1.0
	elif _sweep <= 0.0:
		_sweep = 0.0
		_sweep_dir = 1.0
	_marker.value = _sweep


func _on_play_pressed() -> void:
	if _awaiting:
		_drop_now = true
		return
	super._on_play_pressed()


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED, "lock")
		stop_auto()
		return

	_staked = bet
	var timing := 0.5
	if auto:
		timing = randf_range(0.35, 0.65)
	else:
		_awaiting = true
		_drop_now = false
		_sweep = 0.0
		_sweep_dir = 1.0
		_hint.text = "Press DROP when the marker is near centre!"
		set_result("Watch the shelf...", UIKit.CYAN)
		while _awaiting and not _drop_now and is_inside_tree():
			await get_tree().process_frame
		if not is_inside_tree():
			return
		timing = _sweep
		_awaiting = false

	# Better centre timing slightly biases toward non-zero outcomes (still capped by weights).
	var centre := 1.0 - absf(timing - 0.5) * 2.0
	set_result("Pushing...", UIKit.DIM)
	AudioManager.play_chip_place()
	for i in range(8):
		_render_shelf(3 + randi() % 6)
		await wait(0.06)
		if not is_inside_tree():
			return

	var entries: Array = []
	for o in OUTCOMES:
		var w := float(o["weight"])
		if float(o["mult"]) > 0.0:
			w *= 1.0 + centre * 0.35
		else:
			w *= 1.0 - centre * 0.15
		entries.append([o, w])
	var outcome: Dictionary = weighted_pick(entries)
	var mult := float(outcome["mult"])
	_outcome_label.text = String(outcome["label"])
	_render_shelf(2 + int(mult))
	FX.pulse(_outcome_label, 1.2, 0.2)
	var payout := _staked * mult
	var is_jackpot := mult >= 50.0
	var credited := finish_round(payout, LOSS_RATE, is_jackpot)
	if mult > 0.0:
		set_result("%s  +%s" % [String(outcome["label"]), Fmt.chips(payout)], UIKit.tier_color(mult), "check")
		celebrate(payout, mult)
		if is_jackpot and Settings.stop_auto_on_jackpot:
			stop_auto()
	elif credited <= 0.0:
		set_result("Nothing fell.", UIKit.DIM)
	_hint.text = "Press PLAY, then DROP near the centre."


func stop_auto() -> void:
	super.stop_auto()
	_awaiting = false
