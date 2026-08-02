extends Control

## Midnight Gold title screen — play, settings, and multi-slot saves.

const SettingsPanel := preload("res://ui/settings_panel.gd")

var _overlay: Control = null
var _continue_btn: Button
var _menu_col: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()
	_refresh_continue()
	SaveManager.slots_changed.connect(_refresh_continue)


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UIKit.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_CENTER)
	glow.offset_left = -280
	glow.offset_top = -220
	glow.offset_right = 280
	glow.offset_bottom = 120
	glow.color = Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.06)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var glow2 := ColorRect.new()
	glow2.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	glow2.offset_top = -220
	glow2.color = Color(UIKit.PURPLE.r, UIKit.PURPLE.g, UIKit.PURPLE.b, 0.05)
	glow2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow2)


func _build_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := UIKit.glass_panel(22)
	card.custom_minimum_size = Vector2(440, 0)
	center.add_child(card)

	_menu_col = UIKit.vbox(16)
	card.add_child(_menu_col)

	var brand := UIKit.vbox(6)
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon_row := UIKit.hbox(12)
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_row.add_child(UIKit.icon("chip_gold", 48))
	icon_row.add_child(UIKit.icon("game_roulette", 40))
	icon_row.add_child(UIKit.icon("chip", 48))
	brand.add_child(icon_row)
	brand.add_child(UIKit.title("CASINO IDLE", 36, UIKit.GOLD))
	brand.add_child(UIKit.label("Midnight Gold Edition", 14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_menu_col.add_child(brand)

	_menu_col.add_child(UIKit.separator(Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.3)))

	_continue_btn = UIKit.primary_button("CONTINUE", 20, UIKit.GOLD)
	_continue_btn.custom_minimum_size = Vector2(0, 54)
	_continue_btn.pressed.connect(_on_continue)
	_menu_col.add_child(_continue_btn)

	var new_btn := UIKit.primary_button("NEW GAME", 18, UIKit.GREEN)
	new_btn.custom_minimum_size = Vector2(0, 50)
	new_btn.pressed.connect(_on_new_game)
	_menu_col.add_child(new_btn)

	var saves_btn := UIKit.icon_button("save", "  Saves", 16, UIKit.BLUE)
	saves_btn.custom_minimum_size = Vector2(0, 46)
	saves_btn.pressed.connect(_open_saves)
	_menu_col.add_child(saves_btn)

	var settings_btn := UIKit.icon_button("settings", "  Settings", 16, UIKit.PURPLE)
	settings_btn.custom_minimum_size = Vector2(0, 46)
	settings_btn.pressed.connect(_open_settings)
	_menu_col.add_child(settings_btn)

	if OS.get_name() != "Web":
		var quit_btn := UIKit.button("Quit", 15, UIKit.DIM)
		quit_btn.custom_minimum_size = Vector2(0, 42)
		quit_btn.pressed.connect(func(): get_tree().quit())
		_menu_col.add_child(quit_btn)

	_menu_col.add_child(UIKit.label("v%s" % ProjectSettings.get_setting("application/config/version", "0.9.0"),
		12, UIKit.FAINT, HORIZONTAL_ALIGNMENT_CENTER))


func _refresh_continue() -> void:
	if _continue_btn == null:
		return
	var info := SaveManager.slot_info(SaveManager.active_slot)
	if info.get("empty", true):
		_continue_btn.disabled = not SaveManager.any_slot_exists()
		if SaveManager.any_slot_exists():
			_continue_btn.text = "CONTINUE"
		else:
			_continue_btn.text = "CONTINUE"
			_continue_btn.disabled = true
	else:
		_continue_btn.disabled = false
		_continue_btn.text = "CONTINUE  ·  Slot %d" % (SaveManager.active_slot + 1)


func _on_continue() -> void:
	AudioManager.play_click()
	if SaveManager.slot_exists(SaveManager.active_slot):
		SaveManager.select_slot(SaveManager.active_slot, true)
	else:
		# Jump to first non-empty slot
		for i in range(SaveManager.SLOT_COUNT):
			if SaveManager.slot_exists(i):
				SaveManager.select_slot(i, true)
				break
	_go_main()


func _on_new_game() -> void:
	AudioManager.play_click()
	# Prefer an empty slot; otherwise overwrite active after confirm via saves menu.
	for i in range(SaveManager.SLOT_COUNT):
		if not SaveManager.slot_exists(i):
			SaveManager.start_new_in_slot(i)
			_go_main()
			return
	_open_saves()
	GameManager.notify_toast("All slots full — pick one to overwrite", UIKit.ORANGE, "save")


func _go_main() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _open_overlay(title_text: String, width: float = 560) -> VBoxContainer:
	_close_overlay()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.04, 0.82)
	add_child(dim)
	_overlay = dim

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := UIKit.glass_panel(18)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)

	var col := UIKit.vbox(12)
	panel.add_child(col)

	var head := UIKit.hbox(12)
	head.add_child(UIKit.title(title_text, 22))
	head.add_child(UIKit.spacer())
	var close := UIKit.button("Close", 14, UIKit.DIM)
	close.custom_minimum_size = Vector2(90, 34)
	close.pressed.connect(func():
		AudioManager.play_click()
		_close_overlay()
		_refresh_continue()
	)
	head.add_child(close)
	col.add_child(head)
	col.add_child(UIKit.separator(Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.25)))
	return col


func _open_settings() -> void:
	AudioManager.play_click()
	var col := _open_overlay("Settings", 620)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 480)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel := SettingsPanel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(panel)
	col.add_child(holder)


func _open_saves() -> void:
	AudioManager.play_click()
	var col := _open_overlay("Save Slots", 560)
	var list := UIKit.vbox(10)
	col.add_child(list)
	_rebuild_saves_list(list)


func _rebuild_saves_list(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

	for info in SaveManager.all_slot_info():
		var slot: int = int(info["slot"])
		var row_panel := UIKit.panel(UIKit.PANEL_HI, 12, 1)
		var row := UIKit.vbox(8)

		var head := UIKit.hbox(10)
		head.add_child(UIKit.icon("save", 28))
		var titles := UIKit.vbox(2)
		var title_l := UIKit.label("Slot %d%s" % [slot + 1, "  ·  ACTIVE" if info.get("active", false) else ""],
			16, UIKit.GOLD if info.get("active", false) else UIKit.TEXT)
		titles.add_child(title_l)
		if info.get("empty", true):
			titles.add_child(UIKit.label("Empty", 13, UIKit.DIM))
		else:
			titles.add_child(UIKit.label(String(info.get("label", "")), 13, UIKit.DIM))
			if not String(info.get("when", "")).is_empty():
				titles.add_child(UIKit.label(String(info["when"]), 11, UIKit.FAINT))
		head.add_child(titles)
		head.add_child(UIKit.spacer())
		row.add_child(head)

		var actions := UIKit.hbox(8)
		if info.get("empty", true):
			var create := UIKit.primary_button("New", 14, UIKit.GREEN)
			create.custom_minimum_size = Vector2(100, 36)
			create.pressed.connect(func():
				SaveManager.start_new_in_slot(slot)
				AudioManager.play_click()
				_go_main()
			)
			actions.add_child(create)
		else:
			var load_b := UIKit.primary_button("Load", 14, UIKit.GOLD)
			load_b.custom_minimum_size = Vector2(100, 36)
			load_b.pressed.connect(func():
				SaveManager.select_slot(slot, true)
				AudioManager.play_click()
				_go_main()
			)
			actions.add_child(load_b)

			var overwrite := UIKit.button("Overwrite", 13, UIKit.ORANGE)
			overwrite.custom_minimum_size = Vector2(110, 36)
			overwrite.pressed.connect(func():
				SaveManager.start_new_in_slot(slot)
				AudioManager.play_click()
				_go_main()
			)
			actions.add_child(overwrite)

			var delete_b := UIKit.button("Delete", 13, UIKit.RED)
			delete_b.custom_minimum_size = Vector2(90, 36)
			delete_b.pressed.connect(func():
				SaveManager.delete_slot(slot)
				AudioManager.play_error()
				_rebuild_saves_list(list)
				_refresh_continue()
			)
			actions.add_child(delete_b)

		row.add_child(actions)
		row_panel.add_child(row)
		list.add_child(row_panel)
