extends Control

## Idle floor UI — buy properties that earn chips/sec.

const REFRESH_INTERVAL := 0.1

var buy_amount := 1
var _rows: Dictionary = {}
var _list: VBoxContainer
var _summary: Label
var _hint: Label
var _amount_buttons: Dictionary = {}
var _visible_count := -1
var _refresh_accumulator := 0.0


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root := UIKit.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 14
	root.offset_right = -16
	root.offset_bottom = -14
	add_child(root)

	var header := UIKit.hbox(12)
	header.add_child(UIKit.title("🏛️  Casino Floor", 26))
	header.add_child(UIKit.spacer())
	header.add_child(UIKit.label("Buy", 14, UIKit.DIM))
	for amount in Casino.BUY_AMOUNTS:
		var text := "MAX" if amount == -1 else "x%d" % amount
		var b := UIKit.button(text, 14, UIKit.GOLD)
		b.custom_minimum_size = Vector2(60, 34)
		b.pressed.connect(_set_buy_amount.bind(amount))
		_amount_buttons[amount] = b
		header.add_child(b)
	root.add_child(header)

	var summary_panel := UIKit.panel(UIKit.PANEL_HI, 10, 1)
	var sum_col := UIKit.vbox(4)
	_summary = UIKit.label("", 16, UIKit.GREEN)
	_hint = UIKit.label("Passive income is your real bankroll — tables convert chips to EXP.", 12, UIKit.DIM)
	sum_col.add_child(_summary)
	sum_col.add_child(_hint)
	summary_panel.add_child(sum_col)
	root.add_child(summary_panel)

	var scroll := UIKit.scroll()
	_list = UIKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	root.add_child(scroll)

	Casino.changed.connect(_rebuild_if_needed)
	_rebuild()
	_refresh_amount_buttons()


func _set_buy_amount(amount: int) -> void:
	buy_amount = amount
	_refresh_amount_buttons()
	_refresh()
	AudioManager.play_click()


func _refresh_amount_buttons() -> void:
	for amount in _amount_buttons:
		var b: Button = _amount_buttons[amount]
		b.add_theme_color_override("font_color",
			UIKit.GOLD if int(amount) == buy_amount else UIKit.TEXT)


func _rebuild_if_needed() -> void:
	if Casino.unlocked_generators().size() != _visible_count:
		_rebuild()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	var unlocked := Casino.unlocked_generators()
	_visible_count = unlocked.size()
	for d in unlocked:
		_list.add_child(_make_row(d))
	_refresh()


func _make_row(d: Dictionary) -> Control:
	var id := String(d["id"])
	var panel := UIKit.panel(UIKit.PANEL, 12, 1)
	var row := UIKit.hbox(14)

	var icon_box := UIKit.panel(UIKit.PANEL_HI, 10, 0)
	icon_box.custom_minimum_size = Vector2(56, 56)
	var icon := UIKit.icon_label(String(d["icon"]), 30)
	icon_box.add_child(icon)
	row.add_child(icon_box)

	var info := UIKit.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UIKit.label(String(d["name"]), 18, UIKit.TEXT)
	var detail_label := UIKit.label("", 13, UIKit.DIM)
	var roi_label := UIKit.label("", 12, UIKit.CYAN)
	info.add_child(name_label)
	info.add_child(detail_label)
	info.add_child(roi_label)
	row.add_child(info)

	var owned_col := UIKit.vbox(0)
	owned_col.custom_minimum_size = Vector2(72, 0)
	var owned_label := UIKit.label("0", 28, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	var owned_sub := UIKit.label("owned", 11, UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	owned_col.add_child(owned_label)
	owned_col.add_child(owned_sub)
	row.add_child(owned_col)

	var buy := UIKit.primary_button("", 14, UIKit.GOLD)
	buy.custom_minimum_size = Vector2(170, 52)
	buy.pressed.connect(_buy.bind(id))
	row.add_child(buy)

	panel.add_child(row)
	_rows[id] = {
		"detail": detail_label, "roi": roi_label, "owned": owned_label, "buy": buy, "def": d, "panel": panel,
	}
	return panel


func _buy(id: String) -> void:
	if Casino.buy(id, buy_amount):
		var row: Dictionary = _rows.get(id, {})
		if row.has("owned"):
			FX.pulse(row["owned"], 1.3, 0.25)
		if row.has("panel"):
			FX.flash(row["panel"], Color(UIKit.GOLD, 0.35), 0.35)
		_refresh()


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < REFRESH_INTERVAL:
		return
	_refresh_accumulator = 0.0
	_rebuild_if_needed()
	_refresh()


func _refresh() -> void:
	_summary.text = "Earning %s   ·   %d properties   ·   x%.2f income mult" % [
		Fmt.rate(Casino.income_per_second()),
		Casino.total_properties(),
		GameManager.income_multiplier(),
	]

	for id in _rows:
		var row: Dictionary = _rows[id]
		var d: Dictionary = row["def"]
		var owned := Casino.count(String(id))
		var n := Casino.resolve_amount(String(id), buy_amount)
		var price := Casino.cost_for(String(id), n)
		var affordable := GameManager.chips >= price
		var rate_each := float(d["rate"]) * GameManager.income_multiplier()

		row["owned"].text = str(owned)
		row["detail"].text = "%s each   ·   producing %s" % [
			Fmt.rate(rate_each),
			Fmt.rate(Casino.income_from(String(id))),
		]
		var payback := 0.0
		if rate_each > 0.0 and n > 0:
			payback = price / (rate_each * float(n))
		row["roi"].text = "Payback ~%s" % Fmt.duration(payback) if payback > 0.0 else ""

		var buy: Button = row["buy"]
		buy.text = "Buy x%d  ·  %s" % [n, Fmt.chips(price)]
		buy.disabled = not affordable
