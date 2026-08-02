extends Control

## Prestige: trade the current run for gold chips, then spend those on
## permanent upgrades. Everything bought here survives the reset.

const REFRESH_INTERVAL := 0.2

var _cards: Dictionary = {}
var _gold_label: Label
var _pending_label: Label
var _requirement_label: Label
var _progress_bar: ProgressBar
var _prestige_button: Button
var _confirming := false
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
	head.add_child(UIKit.icon("prestige", 30))
	head.add_child(UIKit.title("Prestige", 24, UIKit.PURPLE))
	head.add_child(UIKit.spacer())
	var gold_row := UIKit.hbox(8)
	gold_row.add_child(UIKit.icon("chip_gold", 24))
	_gold_label = UIKit.numeral("", 18, UIKit.PURPLE)
	gold_row.add_child(_gold_label)
	head.add_child(gold_row)
	root.add_child(head)

	var box := UIKit.accent_panel(UIKit.PURPLE, UIKit.PANEL_HI, 10)
	var box_col := UIKit.vbox(6)
	_pending_label = UIKit.numeral("", 20, UIKit.GOLD)
	box_col.add_child(_pending_label)
	_progress_bar = UIKit.progress_bar(UIKit.PURPLE, 8)
	box_col.add_child(_progress_bar)
	_requirement_label = UIKit.wrapped("", 12, UIKit.DIM)
	box_col.add_child(_requirement_label)
	_prestige_button = UIKit.primary_button("PRESTIGE", 19, UIKit.PURPLE)
	_prestige_button.custom_minimum_size = Vector2(0, 48)
	_prestige_button.pressed.connect(_on_prestige_pressed)
	box_col.add_child(_prestige_button)
	box.add_child(box_col)
	root.add_child(box)
	root.add_child(UIKit.separator())

	var scroll := UIKit.scroll()
	var grid := UIKit.grid(2, 10, 10)
	for d in Upgrades.PRESTIGE:
		grid.add_child(_make_card(d))
	scroll.add_child(grid)
	root.add_child(scroll)

	Upgrades.changed.connect(_refresh)
	GameManager.gold_chips_changed.connect(func(_a): _refresh())
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
	var rank_label := UIKit.label("", 12, UIKit.PURPLE)
	title_box.add_child(rank_label)
	head.add_child(title_box)
	col.add_child(head)

	col.add_child(UIKit.wrapped(String(d["desc"]), 12, UIKit.DIM))
	col.add_child(UIKit.label(String(d["effect"]), 12, UIKit.GREEN))

	var bar := UIKit.progress_bar(UIKit.PURPLE, 6)
	col.add_child(bar)

	var buy := UIKit.button("", 14, UIKit.PURPLE)
	buy.custom_minimum_size = Vector2(0, 36)
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


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_refresh_accumulator += delta
	if _refresh_accumulator >= REFRESH_INTERVAL:
		_refresh_accumulator = 0.0
		_refresh()


func _refresh() -> void:
	_gold_label.text = Fmt.chips(GameManager.gold_chips)

	var req := GameManager.prestige_requirement()
	_progress_bar.value = GameManager.prestige_progress()

	if GameManager.can_prestige():
		_pending_label.text = "Prestige now for %s gold chips" % Fmt.chips(GameManager.pending_gold_chips())
		_requirement_label.text = "Resets chips, level, skills, table upgrades and the floor. " \
			+ "Gold chips, prestige ranks and achievements are kept."
		_prestige_button.disabled = false
		if Settings.confirm_prestige:
			_prestige_button.text = "PRESS AGAIN TO CONFIRM" if _confirming else "PRESTIGE"
		else:
			_prestige_button.text = "PRESTIGE"
	else:
		_pending_label.text = "Prestige locked"
		_requirement_label.text = "Earn %s more this run to unlock prestige. (%s of %s)" % [
			Fmt.chips(req - GameManager.run_chips_earned),
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

		card["rank"].text = "Rank %d of %d" % [rank, max_rank]
		card["bar"].value = float(rank) / float(max_rank)

		var buy: Button = card["buy"]
		if Upgrades.prestige_maxed(String(id)):
			buy.text = "MAXED"
			buy.disabled = true
		else:
			buy.text = "Upgrade for %d gold" % Upgrades.prestige_cost(String(id))
			buy.disabled = not Upgrades.can_buy_prestige(String(id))
