extends Control

## The idle floor: buy properties that earn chips every second.

const REFRESH_INTERVAL := 0.1

var buy_amount := 1
var _rows: Dictionary = {}
var _list: VBoxContainer
var _summary: Label
var _detail: Label
var _next_panel: PanelContainer
var _next_label: Label
var _next_bar: ProgressBar
var _amount_buttons: Dictionary = {}
var _visible_count := -1
var _refresh_accumulator := 0.0


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root := UIKit.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_top = 16
	root.offset_right = -18
	root.offset_bottom = -16
	add_child(root)

	var header := UIKit.hbox(12)
	header.add_child(UIKit.icon("floor", 34))
	header.add_child(UIKit.title("Casino Floor", 26))
	header.add_child(UIKit.spacer())
	header.add_child(UIKit.label("Buy", 13, UIKit.DIM))
	var ids: Array = []
	var labels: Array = []
	for amount in Casino.BUY_AMOUNTS:
		ids.append(amount)
		labels.append("MAX" if amount == -1 else "x%d" % amount)
	header.add_child(UIKit.segmented(ids, labels, _amount_buttons, UIKit.GOLD, 58, 34))
	for id in _amount_buttons:
		_amount_buttons[id].pressed.connect(_set_buy_amount.bind(int(id)))
	root.add_child(header)

	var summary_panel := UIKit.accent_panel(UIKit.GREEN, UIKit.PANEL_HI, 12)
	var sum_col := UIKit.vbox(4)
	_summary = UIKit.numeral("", 22, UIKit.GREEN)
	_detail = UIKit.label("", 12, UIKit.DIM)
	sum_col.add_child(_summary)
	sum_col.add_child(_detail)
	summary_panel.add_child(sum_col)
	root.add_child(summary_panel)

	var scroll := UIKit.scroll()
	_list = UIKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	root.add_child(scroll)

	_next_panel = UIKit.glass_panel(12)
	var next_col := UIKit.vbox(5)
	_next_label = UIKit.label("", 13, UIKit.CYAN)
	_next_bar = UIKit.progress_bar(UIKit.CYAN, 7)
	next_col.add_child(_next_label)
	next_col.add_child(_next_bar)
	_next_panel.add_child(next_col)
	root.add_child(_next_panel)

	Casino.changed.connect(_rebuild_if_needed)
	Settings.changed.connect(_rebuild)
	_rebuild()
	_refresh_amount_buttons()


func _set_buy_amount(amount: int) -> void:
	buy_amount = amount
	_refresh_amount_buttons()
	_refresh()
	AudioManager.play_click()


func _refresh_amount_buttons() -> void:
	UIKit.segmented_select(_amount_buttons, buy_amount, UIKit.GOLD)


func _rebuild_if_needed() -> void:
	if Casino.unlocked_generators().size() != _visible_count:
		_rebuild()


func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	var unlocked := Casino.unlocked_generators()
	_visible_count = unlocked.size()
	for d in unlocked:
		_list.add_child(_make_row(d))
	_refresh()


func _make_row(d: Dictionary) -> Control:
	var id := String(d["id"])
	var compact: bool = Settings.compact_rows
	var panel := UIKit.panel(UIKit.PANEL_HI, 14, 1)
	var row := UIKit.hbox(14)

	row.add_child(UIKit.icon_tile(String(d["icon"]), 56 if compact else 66, 34 if compact else 42))

	var info := UIKit.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(String(d["name"]), 17 if compact else 19, UIKit.TEXT))
	var detail_label := UIKit.label("", 12, UIKit.DIM)
	info.add_child(detail_label)
	var roi_label := UIKit.label("", 11, UIKit.CYAN)
	if not compact:
		info.add_child(roi_label)
	row.add_child(info)

	var owned_col := UIKit.vbox(0)
	owned_col.custom_minimum_size = Vector2(78, 0)
	var owned_label := UIKit.numeral("0", 28, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	owned_col.add_child(owned_label)
	owned_col.add_child(UIKit.label("owned", 10, UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(owned_col)

	var buy := UIKit.primary_button("", 14, UIKit.GOLD)
	buy.custom_minimum_size = Vector2(188, 52 if compact else 56)
	buy.pressed.connect(_buy.bind(id))
	row.add_child(buy)

	panel.add_child(row)
	_rows[id] = {"detail": detail_label, "roi": roi_label, "owned": owned_label,
		"buy": buy, "def": d, "panel": panel}
	return panel


func _buy(id: String) -> void:
	if Casino.buy(id, buy_amount):
		var row: Dictionary = _rows.get(id, {})
		if row.has("owned"):
			FX.pulse(row["owned"], 1.3, 0.25)
		if row.has("panel"):
			FX.flash(row["panel"], Color(UIKit.GOLD, 0.4), 0.35)
		_refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_refresh_accumulator += delta
	if _refresh_accumulator < REFRESH_INTERVAL:
		return
	_refresh_accumulator = 0.0
	_rebuild_if_needed()
	_refresh()


func _refresh() -> void:
	_summary.text = "Earning %s" % Fmt.rate(Casino.income_per_second())
	_detail.text = "%d properties  |  x%.2f income  |  %d achievements" % [
		Casino.total_properties(),
		GameManager.income_multiplier(),
		Achievements.unlocked_count(),
	]

	for id in _rows:
		var row: Dictionary = _rows[id]
		var d: Dictionary = row["def"]
		var owned := Casino.count(String(id))
		var n := Casino.resolve_amount(String(id), buy_amount)
		var price := Casino.cost_for(String(id), n)
		var rate_each := float(d["rate"]) * GameManager.income_multiplier()

		row["owned"].text = str(owned)
		row["detail"].text = "%s each  |  producing %s" % [
			Fmt.rate(rate_each), Fmt.rate(Casino.income_from(String(id)))]

		var roi: Label = row["roi"]
		if Settings.show_payback:
			var payback := Casino.payback_seconds(String(id), n)
			roi.text = "Pays for itself in %s" % Fmt.duration(payback) if payback > 0.0 else ""
		else:
			roi.text = ""

		var buy: Button = row["buy"]
		buy.text = "Buy x%d\n%s" % [n, Fmt.chips(price)]
		buy.disabled = GameManager.chips < price

	var next := Casino.next_locked()
	if next.is_empty():
		_next_panel.visible = false
	else:
		_next_panel.visible = true
		var d: Dictionary = next["def"]
		_next_label.text = "Next: %s unlocks at %s lifetime chips" % [
			String(d["name"]), Fmt.chips(float(next["need"]))]
		_next_bar.value = float(next["progress"])
