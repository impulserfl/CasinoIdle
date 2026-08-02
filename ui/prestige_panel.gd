extends Control

## Prestige: trade the current run for gold chips, then spend them on permanent
## upgrades. Everything here survives the reset.

const REFRESH_INTERVAL := 0.2

var _cards: Dictionary = {}
var _gold_label: Label
var _pending_label: Label
var _requirement_label: Label
var _prestige_button: Button
var _confirming := false
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
	head.add_child(UIKit.title("♻️  Prestige", 24, UIKit.PURPLE))
	head.add_child(UIKit.spacer())
	_gold_label = UIKit.label("", 18, UIKit.PURPLE)
	head.add_child(_gold_label)
	root.add_child(head)

	var box := UIKit.panel(UIKit.PANEL_HI, 10, 1)
	var box_col := UIKit.vbox(6)
	_pending_label = UIKit.label("", 20, UIKit.GOLD)
	box_col.add_child(_pending_label)
	_requirement_label = UIKit.wrapped("", 13, UIKit.DIM)
	box_col.add_child(_requirement_label)
	_prestige_button = UIKit.primary_button("PRESTIGE", 20, UIKit.PURPLE)
	_prestige_button.custom_minimum_size = Vector2(0, 50)
	_prestige_button.pressed.connect(_on_prestige_pressed)
	box_col.add_child(_prestige_button)
	box.add_child(box_col)
	root.add_child(box)
	root.add_child(UIKit.separator())

	var scroll := UIKit.scroll()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for d in Upgrades.PRESTIGE:
		grid.add_child(_make_card(d))
	scroll.add_child(grid)
	root.add_child(scroll)

	Upgrades.changed.connect(_refresh)
	GameManager.gold_chips_changed.connect(_on_gold_changed)
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
	var rank_label := UIKit.label("", 13, UIKit.PURPLE)
	title_box.add_child(rank_label)
	head.add_child(title_box)
	col.add_child(head)

	col.add_child(UIKit.wrapped(String(d["desc"]), 13, UIKit.DIM))
	col.add_child(UIKit.label(String(d["effect"]), 13, UIKit.GREEN))

	var bar := UIKit.progress_bar(UIKit.PURPLE, 6)
	col.add_child(bar)

	var buy := UIKit.button("", 15, UIKit.PURPLE)
	buy.custom_minimum_size = Vector2(0, 38)
	buy.pressed.connect(_buy.bind(id))
	col.add_child(buy)

	panel.add_child(col)
	_cards[id] = {"rank": rank_label, "buy": buy, "bar": bar, "def": d}
	return panel


func _buy(id: String) -> void:
	if Upgrades.buy_prestige(id):
		var card: Dictionary = _cards.get(id, {})
		if card.has("rank"):
			FX.pulse(card["rank"], 1.3, 0.25)
		_refresh()


func _on_prestige_pressed() -> void:
	if not GameManager.can_prestige():
		AudioManager.play_error()
		return
	# Respect Settings: skip two-step confirm when disabled.
	if Settings.confirm_prestige and not _confirming:
		_confirming = true
		_refresh()
		AudioManager.play_click()
		await get_tree().create_timer(4.0).timeout
		if _confirming:
			_confirming = false
			_refresh()
		return
	_confirming = false
	GameManager.do_prestige()
	SaveManager.save_game(true)
	_refresh()


func _on_gold_changed(_amount: float) -> void:
	_refresh()


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator >= REFRESH_INTERVAL:
		_refresh_accumulator = 0.0
		_refresh()


func _refresh() -> void:
	_gold_label.text = "💠 %s gold chips" % Fmt.chips(GameManager.gold_chips)

	var pending := GameManager.pending_gold_chips()
	_pending_label.text = "Prestige now for 💠 %s" % Fmt.chips(pending)

	var req := GameManager.prestige_requirement()
	if GameManager.can_prestige():
		_requirement_label.text = "Resets chips, level, skills and the casino floor. " \
			+ "Gold chips, prestige upgrades and achievements are kept."
		_prestige_button.disabled = false
		if Settings.confirm_prestige:
			_prestige_button.text = "TAP AGAIN TO CONFIRM" if _confirming else "PRESTIGE"
		else:
			_prestige_button.text = "PRESTIGE"
	else:
		var short := req - GameManager.run_chips_earned
		_requirement_label.text = "Earn %s more chips this run to unlock prestige (%s of %s)." % [
			Fmt.chips(short),
			Fmt.chips(GameManager.run_chips_earned),
			Fmt.chips(req),
		]
		_prestige_button.disabled = true
		_prestige_button.text = "PRESTIGE LOCKED"

	for id in _cards:
		var card: Dictionary = _cards[id]
		var d: Dictionary = card["def"]
		var rank := Upgrades.prestige_rank(String(id))
		var max_rank := int(d["max"])

		card["rank"].text = "Rank %d / %d" % [rank, max_rank]
		card["bar"].value = float(rank) / float(max_rank)

		var buy: Button = card["buy"]
		if Upgrades.prestige_maxed(String(id)):
			buy.text = "MAXED"
			buy.disabled = true
		else:
			buy.text = "Upgrade  ·  💠 %d" % Upgrades.prestige_cost(String(id))
			buy.disabled = not Upgrades.can_buy_prestige(String(id))
