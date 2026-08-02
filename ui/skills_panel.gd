extends Control

## Skill tree. Bought with level-up points, wiped by prestige.

const REFRESH_INTERVAL := 0.2

var _cards: Dictionary = {}
var _header: Label
var _refresh_accumulator := 0.0


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root := UIKit.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 14
	root.offset_right = -16
	root.offset_bottom = -14
	add_child(root)

	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon("skill", 30))
	head.add_child(UIKit.title("Skills", 24, UIKit.CYAN))
	head.add_child(UIKit.spacer())
	_header = UIKit.numeral("", 18, UIKit.CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	head.add_child(_header)
	root.add_child(head)
	root.add_child(UIKit.label(
		"One point per level. Everything here resets when you prestige.", 12, UIKit.DIM))
	root.add_child(UIKit.separator())

	var scroll := UIKit.scroll()
	var grid := UIKit.grid(2, 10, 10)
	for d in Upgrades.SKILLS:
		grid.add_child(_make_card(d))
	scroll.add_child(grid)
	root.add_child(scroll)

	Upgrades.changed.connect(_refresh)
	GameManager.skill_points_changed.connect(func(_p): _refresh())
	_refresh()


func _make_card(d: Dictionary) -> Control:
	var id := String(d["id"])
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := UIKit.vbox(5)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.icon_tile(String(d["icon"]), 44, 26))
	var title_box := UIKit.vbox(1)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(UIKit.label(String(d["name"]), 16))
	var rank_label := UIKit.label("", 12, UIKit.CYAN)
	title_box.add_child(rank_label)
	head.add_child(title_box)
	col.add_child(head)

	col.add_child(UIKit.wrapped(String(d["desc"]), 12, UIKit.DIM))
	col.add_child(UIKit.label(String(d["effect"]), 12, UIKit.GREEN))

	var bar := UIKit.progress_bar(UIKit.CYAN, 6)
	col.add_child(bar)

	var buy := UIKit.button("", 14, UIKit.CYAN)
	buy.custom_minimum_size = Vector2(0, 36)
	buy.pressed.connect(_buy.bind(id))
	col.add_child(buy)

	panel.add_child(col)
	_cards[id] = {"rank": rank_label, "buy": buy, "bar": bar, "def": d, "panel": panel}
	return panel


func _buy(id: String) -> void:
	if Upgrades.buy_skill(id):
		var card: Dictionary = _cards.get(id, {})
		if card.has("rank"):
			FX.pulse(card["rank"], 1.3, 0.25)
		_refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_refresh_accumulator += delta
	if _refresh_accumulator >= REFRESH_INTERVAL:
		_refresh_accumulator = 0.0
		_refresh()


func _refresh() -> void:
	var points := GameManager.skill_points
	_header.text = "%d point%s to spend" % [points, "" if points == 1 else "s"]

	for id in _cards:
		var card: Dictionary = _cards[id]
		var d: Dictionary = card["def"]
		var rank := Upgrades.skill_level(String(id))
		var max_rank := int(d["max"])

		card["rank"].text = "Rank %d of %d" % [rank, max_rank]
		card["bar"].value = float(rank) / float(max_rank)

		var buy: Button = card["buy"]
		if Upgrades.skill_maxed(String(id)):
			buy.text = "MAXED"
			buy.disabled = true
		else:
			var cost := Upgrades.skill_cost(String(id))
			buy.text = "Upgrade for %d point%s" % [cost, "" if cost == 1 else "s"]
			buy.disabled = not Upgrades.can_buy_skill(String(id))
