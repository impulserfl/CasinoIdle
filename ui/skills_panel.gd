extends Control

## Skill tree. Bought with skill points from levelling; wiped by prestige.

const REFRESH_INTERVAL := 0.2

var _cards: Dictionary = {}
var _header: Label
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

	var head := UIKit.hbox(12)
	head.add_child(UIKit.title("🎓  Skills", 24, UIKit.CYAN))
	head.add_child(UIKit.spacer())
	_header = UIKit.label("", 16, UIKit.CYAN)
	head.add_child(_header)
	root.add_child(head)
	root.add_child(UIKit.label("Reset on prestige. Earn one point per level.", 13, UIKit.DIM))
	root.add_child(UIKit.separator())

	var scroll := UIKit.scroll()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for d in Upgrades.SKILLS:
		grid.add_child(_make_card(d))
	scroll.add_child(grid)
	root.add_child(scroll)

	Upgrades.changed.connect(_refresh)
	GameManager.skill_points_changed.connect(_on_points_changed)
	_refresh()


func _make_card(d: Dictionary) -> Control:
	var id := String(d["id"])
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := UIKit.vbox(4)

	var head := UIKit.hbox(8)
	head.add_child(UIKit.label(String(d["icon"]), 24))
	var title_box := UIKit.vbox(0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(UIKit.label(String(d["name"]), 17))
	var rank_label := UIKit.label("", 13, UIKit.CYAN)
	title_box.add_child(rank_label)
	head.add_child(title_box)
	col.add_child(head)

	col.add_child(UIKit.wrapped(String(d["desc"]), 13, UIKit.DIM))
	col.add_child(UIKit.label(String(d["effect"]), 13, UIKit.GREEN))

	var bar := UIKit.progress_bar(UIKit.CYAN, 6)
	col.add_child(bar)

	var buy := UIKit.button("", 15, UIKit.CYAN)
	buy.custom_minimum_size = Vector2(0, 38)
	buy.pressed.connect(_buy.bind(id))
	col.add_child(buy)

	panel.add_child(col)
	_cards[id] = {"rank": rank_label, "buy": buy, "bar": bar, "def": d}
	return panel


func _buy(id: String) -> void:
	if Upgrades.buy_skill(id):
		var card: Dictionary = _cards.get(id, {})
		if card.has("rank"):
			FX.pulse(card["rank"], 1.3, 0.25)
		_refresh()


func _on_points_changed(_points: int) -> void:
	_refresh()


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator >= REFRESH_INTERVAL:
		_refresh_accumulator = 0.0
		_refresh()


func _refresh() -> void:
	_header.text = "%d skill points available" % GameManager.skill_points

	for id in _cards:
		var card: Dictionary = _cards[id]
		var d: Dictionary = card["def"]
		var rank := Upgrades.skill_level(String(id))
		var max_rank := int(d["max"])

		card["rank"].text = "Rank %d / %d" % [rank, max_rank]
		card["bar"].value = float(rank) / float(max_rank)

		var buy: Button = card["buy"]
		if Upgrades.skill_maxed(String(id)):
			buy.text = "MAXED"
			buy.disabled = true
		else:
			var cost := Upgrades.skill_cost(String(id))
			buy.text = "Upgrade  -  %d point%s" % [cost, "" if cost == 1 else "s"]
			buy.disabled = not Upgrades.can_buy_skill(String(id))
