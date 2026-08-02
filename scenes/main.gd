extends Control

## Assembles the whole UI: top bar, tabbed content, toast stack and the
## welcome-back popup. The layout is built in code so node paths cannot drift.

const SlotMachine := preload("res://minigames/slot_machine.gd")
const Roulette := preload("res://minigames/roulette.gd")
const Dice := preload("res://minigames/dice.gd")
const ScratchCards := preload("res://minigames/scratch_cards.gd")

const TopBar := preload("res://ui/top_bar.gd")
const CasinoPanel := preload("res://ui/casino_panel.gd")
const SkillsPanel := preload("res://ui/skills_panel.gd")
const PrestigePanel := preload("res://ui/prestige_panel.gd")
const StatsPanel := preload("res://ui/stats_panel.gd")

const MAX_TOASTS := 5
const PLAY_TAB_INDEX := 1

var _toast_box: VBoxContainer
var _minigames: Array[Minigame] = []
var _main_tabs: TabContainer
var _reset_confirming := false


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

	var top := TopBar.new()
	root.add_child(top)

	root.add_child(_build_tabs())
	root.add_child(_build_footer())

	_build_toast_layer()

	GameManager.toast.connect(_show_toast)
	GameManager.drain_pending_toasts()

	_show_offline_report()


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
	_main_tabs = _tab_container(17)
	# Leaving the Play tab entirely should kill any running auto-play.
	_main_tabs.tab_changed.connect(_on_main_tab_changed)

	var casino := CasinoPanel.new()
	casino.name = "🏛️ Casino"
	_main_tabs.add_child(casino)

	var play := _build_play_tab()
	play.name = "🎲 Play"
	_main_tabs.add_child(play)

	var skills := SkillsPanel.new()
	skills.name = "🎓 Skills"
	_main_tabs.add_child(skills)

	var prestige := PrestigePanel.new()
	prestige.name = "♻️ Prestige"
	_main_tabs.add_child(prestige)

	var stats := StatsPanel.new()
	stats.name = "📊 Records"
	_main_tabs.add_child(stats)

	return _main_tabs


func _build_play_tab() -> Control:
	var tabs := _tab_container(15)
	# Auto-play must not keep running on a table you have navigated away from.
	tabs.tab_changed.connect(_on_game_tab_changed)

	for entry in [[SlotMachine, "🎰 Slots"], [Roulette, "🎡 Roulette"],
			[Dice, "🎲 Dice"], [ScratchCards, "🎫 Scratch"]]:
		var game_script: GDScript = entry[0]
		var game: Minigame = game_script.new()
		game.name = String(entry[1])
		_minigames.append(game)
		tabs.add_child(game)
	return tabs


func _on_main_tab_changed(index: int) -> void:
	if index != PLAY_TAB_INDEX:
		_stop_all_auto()


func _on_game_tab_changed(_index: int) -> void:
	for game in _minigames:
		if is_instance_valid(game) and not game.is_visible_in_tree():
			game.stop_auto()


func _stop_all_auto() -> void:
	for game in _minigames:
		if is_instance_valid(game):
			game.stop_auto()


func _build_footer() -> Control:
	var row := UIKit.hbox(10)

	var save_button := UIKit.button("💾  Save", 15, UIKit.GREEN)
	save_button.custom_minimum_size = Vector2(120, 36)
	save_button.pressed.connect(_on_save_pressed)
	row.add_child(save_button)

	var reset_button := UIKit.button("🗑  Reset Save", 14, UIKit.RED)
	reset_button.custom_minimum_size = Vector2(130, 36)
	reset_button.pressed.connect(_on_reset_pressed)
	row.add_child(reset_button)

	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label(
		"Autosaves every %ds  ·  offline earnings while closed" % int(SaveManager.AUTOSAVE_INTERVAL),
		12, UIKit.DIM))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label("CasinoIdle v0.2.1", 12, UIKit.DIM))
	return row


func _on_save_pressed() -> void:
	SaveManager.save_game(false)


func _on_reset_pressed() -> void:
	if not _reset_confirming:
		_reset_confirming = true
		GameManager.notify_toast("Click Reset Save again within 4s to wipe everything", UIKit.ORANGE)
		await get_tree().create_timer(4.0).timeout
		_reset_confirming = false
		return

	_reset_confirming = false
	SaveManager.wipe_save()
	GameManager.notify_toast("Save wiped — starting fresh", UIKit.RED)


# ===========================================================================
# TOASTS
# ===========================================================================

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
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
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


# ===========================================================================
# WELCOME BACK
# ===========================================================================

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
	col.add_child(UIKit.label(
		"Your floor ran for %s." % Fmt.duration(float(report["seconds"])), 16, UIKit.TEXT))
	col.add_child(UIKit.label(
		"+%s chips" % Fmt.chips(float(report["amount"])), 30, UIKit.GOLD))
	col.add_child(UIKit.wrapped(
		"Collected at %s of the live rate." % Fmt.percent(GameManager.offline_efficiency(), 0),
		13, UIKit.DIM))

	if bool(report["capped"]):
		col.add_child(UIKit.wrapped(
			"Capped at %s offline. Upgrade The Vault to bank more."
			% Fmt.duration(float(report["cap"])), 13, UIKit.ORANGE))

	var ok := UIKit.primary_button("COLLECT", 18, UIKit.GOLD)
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(dim.queue_free)
	col.add_child(ok)

	panel.add_child(col)
