extends Control

## Builds the whole layout in code.

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
var _game_tabs: TabContainer
var _daily_button: Button
var _modal: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	var root := UIKit.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 14
	root.offset_right = -16
	root.offset_bottom = -14
	add_child(root)
	root.add_child(TopBar.new())
	root.add_child(_build_tabs())
	root.add_child(_build_footer())
	_build_toast_layer()

	GameManager.toast.connect(_show_toast)
	GameManager.drain_pending_toasts()
	Events.daily_changed.connect(_refresh_daily)
	Events.random_event_spawned.connect(_on_random_event)
	_show_offline_report()
	_refresh_daily()
	if Events.is_event_pending():
		_on_random_event(Events.pending_event)

	if OS.get_cmdline_args().has("--selftest"):
		_run_selftest.call_deferred()


func _run_selftest() -> void:
	AudioManager.enabled = false
	Settings.fast_animations = true
	Settings.show_float_text = false
	var audit := BalanceAudit.new()
	var balance_failures := audit.run()
	for line in audit.lines:
		print(line)
	var icon_failures := _audit_icons()
	for line in icon_failures:
		printerr("ICON ERROR: ", line)
	if not balance_failures.is_empty() or not icon_failures.is_empty():
		printerr("selftest: %d balance and %d icon failure(s)"
			% [balance_failures.size(), icon_failures.size()])
		get_tree().quit(1)
		return
	print("selftest: driving %d tables" % _minigames.size())
	for game in _minigames:
		if not is_instance_valid(game):
			continue
		GameManager.chips = 1.0e9
		if game.game_id == "keno":
			game._quick_pick()
		for round_index in range(6):
			game.bet = 100.0
			await game.play_once()
			if not is_instance_valid(game):
				break
		print("selftest: %s ok (%d rounds)" % [
			game.game_id, int(GameManager.stats.get("plays", {}).get(game.game_id, 0))])
	GameManager.chips = 1.0e12
	Casino.buy("penny_slots", 10)
	Upgrades.buy_skill("floor_manager")
	GameUpgrades.buy("slots", "reel_tension")
	Events.claim_daily()
	Achievements.check_all()
	SaveManager.save_game(true)
	print("selftest: complete, %d wagers recorded" % int(GameManager.stats.get("total_wagers", 0)))
	get_tree().quit()


func _audit_icons() -> Array[String]:
	var missing: Array[String] = []
	var wanted: Dictionary = {}
	for g in _minigames:
		wanted[g.game_icon] = "table %s" % g.game_id
		for d in GameUpgrades.defs_for(g.game_id):
			wanted[String(d["icon"])] = "upgrade %s" % String(d["id"])
	for d in Casino.GENERATORS:
		wanted[String(d["icon"])] = "property %s" % String(d["id"])
	for d in Upgrades.SKILLS:
		wanted[String(d["icon"])] = "skill %s" % String(d["id"])
	for d in Upgrades.PRESTIGE:
		wanted[String(d["icon"])] = "prestige %s" % String(d["id"])
	for d in Achievements.LIST:
		wanted[String(d["icon"])] = "achievement %s" % String(d["id"])
	for d in Events.RANDOM_EVENTS:
		wanted[String(d["icon"])] = "event %s" % String(d["id"])
	for name in ["chip", "chip_gold", "exp", "skill", "prestige", "trophy", "gift",
			"clock", "settings", "stats", "floor", "save", "lock", "check", "bolt",
			"ball", "flame", "moon", "target", "card_back", "arrow_up", "arrow_down",
			"suit_spade", "suit_heart", "suit_diamond", "suit_club"]:
		wanted[name] = "core UI"
	for i in range(1, 7):
		wanted["die_%d" % i] = "die face"
	for icon_name in wanted:
		if not Icons.has(String(icon_name)):
			missing.append("'%s' (used by %s)" % [icon_name, String(wanted[icon_name])])
	print("selftest: checked %d distinct icons" % wanted.size())
	return missing


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UIKit.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var glow_gold := ColorRect.new()
	glow_gold.set_anchors_preset(Control.PRESET_TOP_LEFT)
	glow_gold.offset_left = -120
	glow_gold.offset_top = -80
	glow_gold.offset_right = 420
	glow_gold.offset_bottom = 280
	glow_gold.color = Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.045)
	glow_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_gold)
	var glow_purple := ColorRect.new()
	glow_purple.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	glow_purple.offset_left = -380
	glow_purple.offset_top = -260
	glow_purple.offset_right = 80
	glow_purple.offset_bottom = 60
	glow_purple.color = Color(UIKit.PURPLE.r, UIKit.PURPLE.g, UIKit.PURPLE.b, 0.04)
	glow_purple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_purple)
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.02, 0.01, 0.04, 0.35)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)


func _tab_container(font_size: int) -> TabContainer:
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", font_size)
	tabs.add_theme_constant_override("icon_max_width", font_size + 8)
	tabs.add_theme_constant_override("side_margin", 6)
	var panel_sb := UIKit.glass_stylebox(14)
	panel_sb.content_margin_top = 10
	tabs.add_theme_stylebox_override("panel", panel_sb)
	var sel := UIKit.stylebox(UIKit.PANEL_HI, 10, 1, Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.55))
	sel.shadow_color = Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.2)
	sel.shadow_size = 8
	sel.content_margin_left = 12
	sel.content_margin_right = 12
	sel.content_margin_top = 8
	sel.content_margin_bottom = 8
	tabs.add_theme_stylebox_override("tab_selected", sel)
	var unsel := UIKit.stylebox(UIKit.BG_DEEP, 10, 0)
	unsel.content_margin_left = 12
	unsel.content_margin_right = 12
	unsel.content_margin_top = 8
	unsel.content_margin_bottom = 8
	tabs.add_theme_stylebox_override("tab_unselected", unsel)
	var hover := UIKit.stylebox(UIKit.PANEL_HI, 10, 1, UIKit.PANEL_EDGE)
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8
	tabs.add_theme_stylebox_override("tab_hovered", hover)
	tabs.add_theme_color_override("font_selected_color", UIKit.GOLD)
	tabs.add_theme_color_override("font_unselected_color", UIKit.DIM)
	tabs.add_theme_color_override("font_hovered_color", UIKit.TEXT)
	return tabs


func _build_tabs() -> Control:
	_main_tabs = _tab_container(15)
	_main_tabs.tab_changed.connect(_on_main_tab_changed)
	var entries: Array = [
		[CasinoPanel, "Casino", "floor"],
		[null, "Play", "game_dice"],
		[SkillsPanel, "Skills", "skill"],
		[PrestigePanel, "Prestige", "prestige"],
		[StatsPanel, "Records", "stats"],
		[SettingsPanel, "Settings", "settings"],
	]
	for i in range(entries.size()):
		var entry: Array = entries[i]
		var child: Control
		if entry[0] == null:
			child = _build_play_tab()
		else:
			child = entry[0].new()
		child.name = String(entry[1])
		_main_tabs.add_child(child)
		_main_tabs.set_tab_icon(i, Icons.tex(String(entry[2])))
	return _main_tabs


func _build_play_tab() -> Control:
	_game_tabs = _tab_container(12)
	_game_tabs.tab_changed.connect(_on_game_tab_changed)
	var games: Array = [
		[SlotMachine, "Slots", "game_slots"],
		[Roulette, "Roulette", "game_roulette"],
		[Dice, "Dice", "game_dice"],
		[ScratchCards, "Scratch", "game_scratch"],
		[HigherLower, "Hi-Lo", "game_hilo"],
		[Blackjack, "Blackjack", "game_blackjack"],
		[Plinko, "Plinko", "game_plinko"],
		[CoinFlip, "Flip", "game_coinflip"],
		[MoneyWheel, "Wheel", "game_wheel"],
		[Crash, "Crash", "game_crash"],
		[Keno, "Keno", "game_keno"],
		[Baccarat, "Baccarat", "game_baccarat"],
		[VideoPoker, "Poker", "game_videopoker"],
		[War, "War", "game_war"],
		[CoinPusher, "Pusher", "game_pusher"],
		[ClawMachine, "Claw", "game_claw"],
		[Darts, "Darts", "game_darts"],
		[Fishing, "Fishing", "game_fishing"],
	]
	for i in range(games.size()):
		var entry: Array = games[i]
		var g: Minigame = entry[0].new()
		g.name = String(entry[1])
		_minigames.append(g)
		_game_tabs.add_child(g)
		_game_tabs.set_tab_icon(i, Icons.tex(String(entry[2])))
	return _game_tabs


func _on_main_tab_changed(index: int) -> void:
	if index != PLAY_TAB_INDEX and Settings.stop_auto_on_tab:
		_stop_all_auto()
	AudioManager.play_click()


func _on_game_tab_changed(_index: int) -> void:
	if Settings.stop_auto_on_tab:
		for game in _minigames:
			if is_instance_valid(game) and not game.is_visible_in_tree():
				game.stop_auto()
	if Settings.keep_bet_on_switch:
		_carry_bet()
	AudioManager.play_click()


func _carry_bet() -> void:
	for game in _minigames:
		if is_instance_valid(game) and game.is_visible_in_tree():
			if Settings.carried_bet > 0.0:
				game.bet = Settings.carried_bet
				game._sync_bet()
		elif is_instance_valid(game) and game.bet > 0.0:
			Settings.carried_bet = game.bet


func _stop_all_auto() -> void:
	for game in _minigames:
		if is_instance_valid(game):
			game.stop_auto()


func _build_footer() -> Control:
	var bar := UIKit.glass_panel(12)
	var row := UIKit.hbox(12)
	var title_btn := UIKit.button("Title", 14, UIKit.PURPLE)
	title_btn.custom_minimum_size = Vector2(90, 38)
	title_btn.pressed.connect(func():
		SaveManager.save_game(true)
		AudioManager.play_click()
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	)
	row.add_child(title_btn)

	var save_button := UIKit.icon_button("save", "Save", 14, UIKit.GREEN)
	save_button.custom_minimum_size = Vector2(110, 38)
	save_button.pressed.connect(func(): SaveManager.save_game(false))
	row.add_child(save_button)

	_daily_button = UIKit.icon_button("gift", "Daily", 14, UIKit.GOLD)
	_daily_button.custom_minimum_size = Vector2(160, 38)
	_daily_button.pressed.connect(_on_daily)
	row.add_child(_daily_button)

	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label("CasinoIdle  ·  Slot %d" % (SaveManager.active_slot + 1), 12, UIKit.DIM))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label("v%s" % ProjectSettings.get_setting("application/config/version", "1.0.0"),
		12, UIKit.FAINT))
	bar.add_child(row)
	return bar


func _on_daily() -> void:
	if Events.claim_daily() > 0.0:
		_refresh_daily()
	else:
		GameManager.notify_toast("Already claimed today (streak %d)" % Events.daily_streak,
			UIKit.DIM, "clock")
		AudioManager.play_error()


func _refresh_daily() -> void:
	if _daily_button == null:
		return
	if Events.can_claim_daily():
		_daily_button.text = "Daily +%s" % Fmt.chips(Events.daily_reward_amount())
		_daily_button.disabled = false
	else:
		_daily_button.text = "Streak %d" % Events.daily_streak
		_daily_button.disabled = true


func _open_modal(width: int, height: int) -> VBoxContainer:
	_close_modal()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.04, 0.78)
	add_child(dim)
	_modal = dim
	var panel := UIKit.glass_panel(18)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(width, 0)
	panel.offset_left = -width / 2.0
	panel.offset_top = -height / 2.0
	panel.offset_right = width / 2.0
	panel.offset_bottom = height / 2.0
	dim.add_child(panel)
	var col := UIKit.vbox(14)
	panel.add_child(col)
	return col


func _close_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null


func _on_random_event(event: Dictionary) -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	var col := _open_modal(520, 320)
	var head := UIKit.hbox(14)
	head.add_child(UIKit.icon(String(event.get("icon", "gift")), 44))
	var titles := UIKit.vbox(2)
	titles.add_child(UIKit.label("FLOOR EVENT", 12, UIKit.ORANGE))
	titles.add_child(UIKit.title(String(event.get("name", "Event")), 24))
	head.add_child(titles)
	col.add_child(head)
	col.add_child(UIKit.separator(Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.25)))
	col.add_child(UIKit.wrapped(String(event.get("desc", "")), 15, UIKit.TEXT))
	col.add_child(UIKit.label("Next event in about %s."
		% Fmt.duration(Events.cooldown_length()), 12, UIKit.DIM))
	col.add_child(UIKit.spacer(false))
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var claim := UIKit.primary_button("CLAIM", 18, UIKit.GOLD)
	claim.custom_minimum_size = Vector2(180, 50)
	claim.pressed.connect(func():
		Events.claim_pending_event()
		AudioManager.play_click()
		_close_modal()
	)
	row.add_child(claim)
	var skip := UIKit.button("Skip", 15, UIKit.DIM)
	skip.custom_minimum_size = Vector2(100, 50)
	skip.pressed.connect(func():
		Events.dismiss_pending_event()
		AudioManager.play_click()
		_close_modal()
	)
	row.add_child(skip)
	col.add_child(row)


func _show_offline_report() -> void:
	var report := SaveManager.claim_offline_report()
	if report.is_empty():
		return
	var col := _open_modal(500, 320)
	var head := UIKit.hbox(14)
	head.add_child(UIKit.icon("moon", 42))
	head.add_child(UIKit.title("Welcome back", 26))
	col.add_child(head)
	col.add_child(UIKit.separator(Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.25)))
	col.add_child(UIKit.label("Your floor ran for %s."
		% Fmt.duration(float(report["seconds"])), 15))
	col.add_child(UIKit.numeral("+%s chips" % Fmt.chips(float(report["amount"])), 32, UIKit.GOLD))
	if bool(report.get("capped", false)):
		col.add_child(UIKit.wrapped(
			"That is the %s cap. Vault and Night Shift upgrades raise it."
			% Fmt.duration(float(report.get("cap", 0.0))), 12, UIKit.ORANGE))
	col.add_child(UIKit.spacer(false))
	var ok := UIKit.primary_button("COLLECT", 18, UIKit.GOLD)
	ok.custom_minimum_size = Vector2(0, 48)
	ok.pressed.connect(func():
		AudioManager.play_click()
		_close_modal()
	)
	col.add_child(ok)


func _build_toast_layer() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_toast_box = UIKit.vbox(8)
	_toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_box.offset_left = -440
	_toast_box.offset_top = 100
	_toast_box.offset_right = -20
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_toast_box)


func _show_toast(text: String, color: Color, icon: String) -> void:
	if _toast_box == null:
		return
	while _toast_box.get_child_count() >= MAX_TOASTS:
		var oldest := _toast_box.get_child(0)
		_toast_box.remove_child(oldest)
		oldest.queue_free()
	var panel := UIKit.accent_panel(color, UIKit.PANEL_HI, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UIKit.hbox(10)
	if not icon.is_empty():
		row.add_child(UIKit.icon(icon, 24))
	var l := UIKit.label(text, 14, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	panel.add_child(row)
	_toast_box.add_child(panel)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.55)
	tw.tween_callback(panel.queue_free)
