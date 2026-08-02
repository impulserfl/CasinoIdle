extends Control

## Lifetime records, per-table play counts, and the achievement wall.

const REFRESH_INTERVAL := 0.5

var _stat_labels: Dictionary = {}
var _achievement_cards: Dictionary = {}
var _achievement_header: Label
var _refresh_accumulator := 0.0

const STAT_ROWS: Array[Dictionary] = [
	{"key": "lifetime_chips_earned", "label": "Chips earned (lifetime)", "kind": "chips"},
	{"key": "total_wagered",         "label": "Total wagered",           "kind": "chips"},
	{"key": "total_wagers",          "label": "Wagers placed",           "kind": "count"},
	{"key": "total_wins",            "label": "Winning wagers",          "kind": "count"},
	{"key": "biggest_win",           "label": "Biggest single win",      "kind": "chips"},
	{"key": "best_multiplier",       "label": "Best multiplier",         "kind": "mult"},
	{"key": "best_streak",           "label": "Longest win streak",      "kind": "count"},
	{"key": "jackpots",              "label": "Jackpots hit",            "kind": "count"},
	{"key": "properties_bought",     "label": "Properties bought",       "kind": "count"},
	{"key": "prestiges",             "label": "Times prestiged",         "kind": "count"},
	{"key": "play_time",             "label": "Time played",             "kind": "time"},
]

const GAME_ROWS: Array[Dictionary] = [
	{"id": "slots", "label": "Slots", "icon": "game_slots"},
	{"id": "roulette", "label": "Roulette", "icon": "game_roulette"},
	{"id": "dice", "label": "Dice", "icon": "game_dice"},
	{"id": "scratch", "label": "Scratch", "icon": "game_scratch"},
	{"id": "higher_lower", "label": "Hi-Lo", "icon": "game_hilo"},
	{"id": "blackjack", "label": "Blackjack", "icon": "game_blackjack"},
	{"id": "plinko", "label": "Plinko", "icon": "game_plinko"},
	{"id": "coin_flip", "label": "Coin Flip", "icon": "game_coinflip"},
	{"id": "money_wheel", "label": "Wheel", "icon": "game_wheel"},
	{"id": "crash", "label": "Crash", "icon": "game_crash"},
	{"id": "keno", "label": "Keno", "icon": "game_keno"},
	{"id": "baccarat", "label": "Baccarat", "icon": "game_baccarat"},
	{"id": "video_poker", "label": "Video Poker", "icon": "game_videopoker"},
	{"id": "war", "label": "War", "icon": "game_war"},
	{"id": "coin_pusher", "label": "Coin Pusher", "icon": "game_pusher"},
	{"id": "claw", "label": "Claw", "icon": "game_claw"},
	{"id": "darts", "label": "Darts", "icon": "game_darts"},
	{"id": "fishing", "label": "Fishing", "icon": "game_fishing"},
]


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
	head.add_child(UIKit.icon("stats", 30))
	head.add_child(UIKit.title("Records", 24, UIKit.BLUE))
	root.add_child(head)
	root.add_child(UIKit.separator())

	var scroll := UIKit.scroll()
	var col := UIKit.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_build_stats_block())
	col.add_child(UIKit.icon_row("game_dice", "Rounds played", 17, UIKit.GOLD, 22))
	col.add_child(_build_play_block())
	var ach_head := UIKit.hbox(10)
	ach_head.add_child(UIKit.icon("trophy", 22))
	ach_head.add_child(UIKit.label("Achievements", 17, UIKit.GOLD))
	ach_head.add_child(UIKit.spacer())
	_achievement_header = UIKit.label("", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	ach_head.add_child(_achievement_header)
	col.add_child(ach_head)
	col.add_child(_build_achievements_block())
	scroll.add_child(col)
	root.add_child(scroll)

	Achievements.unlocked.connect(_on_achievement_unlocked)
	_refresh()


func _build_stats_block() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(2, 30, 6)
	for row in STAT_ROWS:
		grid.add_child(UIKit.label(String(row["label"]), 13, UIKit.DIM))
		var value := UIKit.label("-", 14, UIKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stat_labels[String(row["key"])] = value
		grid.add_child(value)
	panel.add_child(grid)
	return panel


func _build_play_block() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var grid := UIKit.grid(3, 18, 6)
	for row in GAME_ROWS:
		var line := UIKit.hbox(6)
		line.add_child(UIKit.icon(String(row["icon"]), 18))
		var name_label := UIKit.label(String(row["label"]), 12, UIKit.DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var value := UIKit.label("0", 13, UIKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		_stat_labels["play_" + String(row["id"])] = value
		line.add_child(value)
		grid.add_child(line)
	panel.add_child(grid)
	return panel


func _build_achievements_block() -> Control:
	var grid := UIKit.grid(3, 8, 8)
	for d in Achievements.LIST:
		var id := String(d["id"])
		var panel := UIKit.panel(UIKit.PANEL, 8, 1)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := UIKit.hbox(8)
		var icon := UIKit.icon(String(d["icon"]), 28)
		row.add_child(icon)
		var box := UIKit.vbox(1)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := UIKit.label(String(d["name"]), 13)
		box.add_child(name_label)
		box.add_child(UIKit.wrapped(String(d["desc"]), 11, UIKit.DIM))
		row.add_child(box)
		panel.add_child(row)
		_achievement_cards[id] = {"panel": panel, "icon": icon, "name": name_label}
		grid.add_child(panel)
	return grid


func _on_achievement_unlocked(d: Dictionary) -> void:
	var card: Dictionary = _achievement_cards.get(String(d["id"]), {})
	if card.has("icon"):
		FX.pulse(card["icon"], 1.6, 0.5)
	_refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_refresh_accumulator += delta
	if _refresh_accumulator >= REFRESH_INTERVAL:
		_refresh_accumulator = 0.0
		_refresh()


func _refresh() -> void:
	var s := GameManager.stats
	for row in STAT_ROWS:
		var key := String(row["key"])
		if not _stat_labels.has(key):
			continue
		var raw := float(s.get(key, 0.0))
		var target: Label = _stat_labels[key]
		match String(row["kind"]):
			"chips": target.text = Fmt.chips(raw)
			"count": target.text = Fmt.commas(raw)
			"mult": target.text = Fmt.mult(raw) if raw > 0.0 else "-"
			"time": target.text = Fmt.duration(raw)

	var plays: Dictionary = s.get("plays", {})
	for row in GAME_ROWS:
		var key := "play_" + String(row["id"])
		if _stat_labels.has(key):
			_stat_labels[key].text = Fmt.commas(float(plays.get(String(row["id"]), 0)))

	_achievement_header.text = "%d of %d unlocked, worth +%s casino income" % [
		Achievements.unlocked_count(), Achievements.LIST.size(),
		Fmt.percent(Achievements.income_bonus(), 0)]

	for id in _achievement_cards:
		var card: Dictionary = _achievement_cards[id]
		var got := Achievements.is_unlocked(String(id))
		var panel: PanelContainer = card["panel"]
		panel.add_theme_stylebox_override("panel", UIKit.stylebox(
			UIKit.PANEL_HI if got else UIKit.PANEL, 8, 1,
			UIKit.GOLD if got else UIKit.PANEL_EDGE))
		card["icon"].modulate = Color.WHITE if got else Color(1, 1, 1, 0.22)
		card["name"].add_theme_color_override("font_color", UIKit.GOLD if got else UIKit.DIM)
