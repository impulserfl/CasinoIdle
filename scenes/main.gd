extends Control

const SlotMachine := preload("res://minigames/slot_machine.gd")
const Roulette := preload("res://minigames/roulette.gd")
const Dice := preload("res://minigames/dice.gd")
const ScratchCards := preload("res://minigames/scratch_cards.gd")
const HigherLower := preload("res://minigames/higher_lower.gd")
const Blackjack := preload("res://minigames/blackjack.gd")
const Plinko := preload("res://minigames/plinko.gd")
const CoinFlip := preload("res://minigames/coin_flip.gd")
const MoneyWheel := preload("res://minigames/money_wheel.gd")
const Crash := preload("res://minigames/crash.gd")
const Keno := preload("res://minigames/keno.gd")
const Baccarat := preload("res://minigames/baccarat.gd")
const VideoPoker := preload("res://minigames/video_poker.gd")
const War := preload("res://minigames/war.gd")
const CoinPusher := preload("res://minigames/coin_pusher.gd")
const ClawMachine := preload("res://minigames/claw_machine.gd")
const Darts := preload("res://minigames/darts.gd")
const Fishing := preload("res://minigames/fishing.gd")

const TopBar := preload("res://ui/top_bar.gd")
const CasinoPanel := preload("res://ui/casino_panel.gd")
const SkillsPanel := preload("res://ui/skills_panel.gd")
const PrestigePanel := preload("res://ui/prestige_panel.gd")
const StatsPanel := preload("res://ui/stats_panel.gd")
const SettingsPanel := preload("res://ui/settings_panel.gd")

const MAX_TOASTS := 5
const PLAY_TAB_INDEX := 1

var _toast_box: VBoxContainer
var _minigames: Array[Minigame] = []
var _main_tabs: TabContainer
var _daily_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	var root := UIKit.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 14
	root.offset_top = 12
	root.offset_right = -14
	root.offset_bottom = -12
	add_child(root)
	root.add_child(TopBar.new())
	root.add_child(_build_tabs())
	root.add_child(_build_footer())
	_build_toast_layer()
	GameManager.toast.connect(_show_toast)
	GameManager.drain_pending_toasts()
	Events.daily_changed.connect(_refresh_daily)
	_show_offline_report()
	_refresh_daily()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UIKit.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _tab_container(font_size: int) -> TabContainer:
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", font_size)
	tabs.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.PANEL, 10, 1))
	tabs.add_theme_stylebox_override("tab_selected", UIKit.stylebox(UIKit.PANEL, 8, 0))
	tabs.add_theme_stylebox_override("tab_unselected", UIKit.stylebox(UIKit.BG, 8, 0))
	tabs.add_theme_stylebox_override("tab_hovered", UIKit.stylebox(UIKit.PANEL_HI, 8, 0))
	tabs.add_theme_color_override("font_selected_color", UIKit.GOLD)
	tabs.add_theme_color_override("font_unselected_color", UIKit.DIM)
	tabs.add_theme_color_override("font_hovered_color", UIKit.TEXT)
	return tabs


func _build_tabs() -> Control:
	_main_tabs = _tab_container(16)
	_main_tabs.tab_changed.connect(_on_main_tab_changed)
	for entry in [
		[CasinoPanel, "🏛️ Casino"], [null, "🎲 Play"], [SkillsPanel, "🎓 Skills"],
		[PrestigePanel, "♻️ Prestige"], [StatsPanel, "📊 Records"], [SettingsPanel, "⚙️ Settings"],
	]:
		if entry[0] == null:
			var play := _build_play_tab()
			play.name = String(entry[1])
			_main_tabs.add_child(play)
		else:
			var panel = entry[0].new()
			panel.name = String(entry[1])
			_main_tabs.add_child(panel)
	return _main_tabs


func _build_play_tab() -> Control:
	var tabs := _tab_container(12)
	tabs.tab_changed.connect(_on_game_tab_changed)
	var games: Array = [
		[SlotMachine, "🎰 Slots"], [Roulette, "🎡 Roulette"], [Dice, "🎲 Dice"],
		[ScratchCards, "🎫 Scratch"], [HigherLower, "🃏 Hi-Lo"], [Blackjack, "🂡 BJ"],
		[Plinko, "🔵 Plinko"], [CoinFlip, "🪙 Flip"], [MoneyWheel, "🎯 Wheel"],
		[Crash, "📈 Crash"], [Keno, "🎱 Keno"], [Baccarat, "🎴 Bacc"],
		[VideoPoker, "♠️ Poker"], [War, "⚔️ War"], [CoinPusher, "🪙 Push"],
		[ClawMachine, "🦾 Claw"], [Darts, "🎯 Darts"], [Fishing, "🎣 Fish"],
	]
	for entry in games:
		var g: Minigame = entry[0].new()
		g.name = String(entry[1])
		_minigames.append(g)
		tabs.add_child(g)
	return tabs


func _on_main_tab_changed(index: int) -> void:
	if index != PLAY_TAB_INDEX:
		_stop_all_auto()
	AudioManager.play_click()


func _on_game_tab_changed(_index: int) -> void:
	for game in _minigames:
		if is_instance_valid(game) and not game.is_visible_in_tree():
			game.stop_auto()
	AudioManager.play_click()


func _stop_all_auto() -> void:
	for game in _minigames:
		if is_instance_valid(game):
			game.stop_auto()


func _build_footer() -> Control:
	var row := UIKit.hbox(10)
	var save_button := UIKit.button("💾 Save", 15, UIKit.GREEN)
	save_button.custom_minimum_size = Vector2(100, 36)
	save_button.pressed.connect(func(): SaveManager.save_game(false))
	row.add_child(save_button)

	_daily_button = UIKit.button("🎁 Daily", 15, UIKit.GOLD)
	_daily_button.custom_minimum_size = Vector2(110, 36)
	_daily_button.pressed.connect(_on_daily)
	row.add_child(_daily_button)

	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label("18 tables · Lucky Hour · Daily streak", 12, UIKit.DIM))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label("v0.4.1", 12, UIKit.DIM))
	return row


func _on_daily() -> void:
	if Events.claim_daily() > 0.0:
		_refresh_daily()
	else:
		GameManager.notify_toast("Already claimed today (streak %d)" % Events.daily_streak, UIKit.DIM)
		AudioManager.play_error()


func _refresh_daily() -> void:
	if _daily_button == null:
		return
	if Events.can_claim_daily():
		_daily_button.text = "🎁 Daily +%s" % Fmt.chips(Events.daily_reward_amount())
		_daily_button.disabled = false
	else:
		_daily_button.text = "🎁 Streak %d" % Events.daily_streak
		_daily_button.disabled = true


func _build_toast_layer() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_toast_box = UIKit.vbox(6)
	_toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_box.offset_left = -420
	_toast_box.offset_top = 96
	_toast_box.offset_right = -24
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_toast_box)


func _show_toast(text: String, color: Color) -> void:
	if _toast_box == null:
		return
	while _toast_box.get_child_count() >= MAX_TOASTS:
		var oldest := _toast_box.get_child(0)
		_toast_box.remove_child(oldest)
		oldest.queue_free()
	var panel := UIKit.panel(UIKit.PANEL_HI, 8, 1)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(UIKit.label(text, 15, color, HORIZONTAL_ALIGNMENT_RIGHT))
	_toast_box.add_child(panel)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


func _show_offline_report() -> void:
	var report := SaveManager.claim_offline_report()
	if report.is_empty():
		return
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)
	var panel := UIKit.panel(UIKit.PANEL, 14, 2)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	panel.offset_left = -230
	panel.offset_top = -120
	panel.offset_right = 230
	panel.offset_bottom = 120
	dim.add_child(panel)
	var col := UIKit.vbox(10)
	col.add_child(UIKit.title("🌙  Welcome back", 26))
	col.add_child(UIKit.separator())
	col.add_child(UIKit.label("Your floor ran for %s." % Fmt.duration(float(report["seconds"])), 16))
	col.add_child(UIKit.label("+%s chips" % Fmt.chips(float(report["amount"])), 30, UIKit.GOLD))
	var ok := UIKit.primary_button("COLLECT", 18, UIKit.GOLD)
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(func():
		AudioManager.play_click()
		dim.queue_free()
	)
	col.add_child(ok)
	panel.add_child(col)
