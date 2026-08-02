extends Control

## The idle layer's UI: buy properties that earn chips per second.
##
## Rows are built once per unlock and then refreshed in place at 10Hz -- costs
## and affordability change every frame as passive income ticks in, and
## rebuilding ten rows every frame would be wasteful.

const REFRESH_INTERVAL := 0.1

var buy_amount := 1

var _rows: Dictionary = {}
var _list: VBoxContainer
var _summary: Label
var _amount_buttons: Dictionary = {}
var _visible_count := -1
var _refresh_accumulator := 0.0


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root := UIKit.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 14
	root.offset_top = 12
	root.offset_right = -14
	root.offset_bottom = -12
	add_child(root)

	var header := UIKit.hbox(12)
	header.add_child(UIKit.title("🏛️  Casino Floor", 24))
	header.add_child(UIKit.spacer())
	header.add_child(UIKit.label("Buy", 14, UIKit.DIM))
	for amount in Casino.BUY_AMOUNTS:
		var text := "MAX" if amount == -1 else "x%d" % amount
		var b := UIKit.button(text, 14, UIKit.GOLD)
		b.custom_minimum_size = Vector2(56, 32)
		b.pressed.connect(_set_buy_amount.bind(amount))
		_amount_buttons[amount] = b
		header.add_child(b)
	root.add_child(header)

	_summary = UIKit.label("", 15, UIKit.GREEN)
	root.add_child(_summary)
	root.add_child(UIKit.separator())

	var scroll := UIKit.scroll()
	_list = UIKit.vbox(8)
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
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var row := UIKit.hbox(14)

	row.add_child(UIKit.icon_label(String(d["icon"]), 34))

	var info := UIKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UIKit.label(String(d["name"]), 17)
	var detail_label := UIKit.label("", 13, UIKit.DIM)
	info.add_child(name_label)
	info.add_child(detail_label)
	row.add_child(info)

	var owned_label := UIKit.label("0", 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	owned_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(owned_label)

	var buy := UIKit.button("", 15, UIKit.GOLD)
	buy.custom_minimum_size = Vector2(180, 46)
	buy.pressed.connect(_buy.bind(id))
	row.add_child(buy)

	panel.add_child(row)
	_rows[id] = {
		"detail": detail_label, "owned": owned_label, "buy": buy, "def": d,
	}
	return panel


func _buy(id: String) -> void:
	if Casino.buy(id, buy_amount):
		var row: Dictionary = _rows.get(id, {})
		if row.has("owned"):
			FX.pulse(row["owned"], 1.3, 0.25)
		_refresh()


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < REFRESH_INTERVAL:
		return
	_refresh_accumulator = 0.0
	_rebuild_if_needed()
	_refresh()


func _refresh() -> void:
	_summary.text = "Earning %s from %d properties  (x%.2f multiplier)" % [
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

		row["owned"].text = str(owned)
		row["detail"].text = "%s each   |   producing %s" % [
			Fmt.rate(float(d["rate"]) * GameManager.income_multiplier()),
			Fmt.rate(Casino.income_from(String(id))),
		]
		var buy: Button = row["buy"]
		buy.text = "Buy x%d\n%s" % [n, Fmt.chips(price)]
		buy.disabled = not affordable
