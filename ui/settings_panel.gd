extends Control

## Settings, built entirely from Settings.SPEC.
##
## Nothing here hardcodes the option list — adding a preference to SPEC makes
## it appear in the right group with a working control and correct persistence,
## so the panel and the save format cannot drift apart.

const GROUP_ICONS: Dictionary = {
	"Audio": "bolt",
	"Presentation": "stats",
	"Tables": "game_dice",
	"Notifications": "gift",
}

var _controls: Dictionary = {}
var _value_labels: Dictionary = {}
var _reset_confirming := false
var _wipe_confirming := false
var _reset_button: Button
var _wipe_button: Button
var _save_info: Label


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
	head.add_child(UIKit.icon("settings", 30))
	head.add_child(UIKit.title("Settings", 24, UIKit.TEXT))
	head.add_child(UIKit.spacer())
	_reset_button = UIKit.button("Restore defaults", 13, UIKit.ORANGE)
	_reset_button.custom_minimum_size = Vector2(160, 34)
	_reset_button.pressed.connect(_on_restore_defaults)
	head.add_child(_reset_button)
	root.add_child(head)
	root.add_child(UIKit.separator())

	var scroll := UIKit.scroll()
	var col := UIKit.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for group in Settings.groups():
		col.add_child(UIKit.icon_row(String(GROUP_ICONS.get(group, "settings")),
			String(group), 17, UIKit.GOLD, 22))
		col.add_child(_build_group(String(group)))

	col.add_child(UIKit.icon_row("save", "Save data", 17, UIKit.GOLD, 22))
	col.add_child(_build_save_block())

	col.add_child(UIKit.icon_row("lock", "Danger zone", 17, UIKit.RED, 22))
	col.add_child(_build_danger_block())

	scroll.add_child(col)
	root.add_child(scroll)

	Settings.changed.connect(_sync_all)
	_sync_all()


func _build_group(group: String) -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var col := UIKit.vbox(10)
	var specs := Settings.specs_in(group)
	for i in range(specs.size()):
		var spec: Dictionary = specs[i]
		if i > 0:
			col.add_child(UIKit.separator(UIKit.PANEL_SUNK))
		col.add_child(_build_row(spec))
	panel.add_child(col)
	return panel


func _build_row(spec: Dictionary) -> Control:
	var key := String(spec["key"])
	var row := UIKit.hbox(12)

	var text_col := UIKit.vbox(1)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_child(UIKit.label(String(spec["name"]), 14, UIKit.TEXT))
	text_col.add_child(UIKit.wrapped(String(spec["desc"]), 11, UIKit.DIM))
	row.add_child(text_col)

	match String(spec["kind"]):
		"slider":
			var box := UIKit.vbox(2)
			box.custom_minimum_size = Vector2(200, 0)
			var value_label := UIKit.label("", 12, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
			box.add_child(value_label)
			var s := UIKit.slider(0.0, 1.0, 0.01)
			s.value_changed.connect(func(v): Settings.set_value(key, v))
			box.add_child(s)
			row.add_child(box)
			_controls[key] = s
			_value_labels[key] = value_label
		"toggle":
			var b := UIKit.button("", 13, UIKit.GREEN)
			b.custom_minimum_size = Vector2(94, 34)
			b.pressed.connect(func():
				Settings.toggle(key)
				AudioManager.play_click()
			)
			row.add_child(b)
			_controls[key] = b
	return row


func _build_save_block() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var col := UIKit.vbox(8)
	_save_info = UIKit.label("", 12, UIKit.DIM)
	col.add_child(_save_info)
	var row := UIKit.hbox(10)
	var save_now := UIKit.icon_button("save", "Save now", 13, UIKit.GREEN)
	save_now.custom_minimum_size = Vector2(140, 36)
	save_now.pressed.connect(func(): SaveManager.save_game(false))
	row.add_child(save_now)
	row.add_child(UIKit.spacer())
	col.add_child(row)
	panel.add_child(col)
	return panel


func _build_danger_block() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var col := UIKit.vbox(10)
	col.add_child(UIKit.wrapped(
		"Wiping the save cannot be undone. Prestige is the safe way to reset a run.",
		12, UIKit.ORANGE))
	_wipe_button = UIKit.button("Erase all progress", 15, UIKit.RED)
	_wipe_button.custom_minimum_size = Vector2(0, 44)
	_wipe_button.pressed.connect(_on_wipe_pressed)
	col.add_child(_wipe_button)
	panel.add_child(col)
	return panel


func _on_restore_defaults() -> void:
	if not _reset_confirming:
		_reset_confirming = true
		_reset_button.text = "Press again to confirm"
		AudioManager.play_error()
		await get_tree().create_timer(4.0).timeout
		_reset_confirming = false
		if is_instance_valid(_reset_button):
			_reset_button.text = "Restore defaults"
		return
	_reset_confirming = false
	_reset_button.text = "Restore defaults"
	Settings.reset_to_defaults()
	AudioManager.play_click()
	GameManager.notify_toast("Settings restored to defaults", UIKit.BLUE, "settings")


func _on_wipe_pressed() -> void:
	if not _wipe_confirming:
		_wipe_confirming = true
		_wipe_button.text = "PRESS AGAIN TO ERASE EVERYTHING"
		AudioManager.play_error()
		await get_tree().create_timer(4.0).timeout
		_wipe_confirming = false
		if is_instance_valid(_wipe_button):
			_wipe_button.text = "Erase all progress"
		return
	_wipe_confirming = false
	_wipe_button.text = "Erase all progress"
	SaveManager.wipe_save()
	AudioManager.play_error()
	GameManager.notify_toast("Save erased - starting fresh", UIKit.RED, "prestige")


func _sync_all() -> void:
	for key in _controls:
		var spec := Settings.spec_for(String(key))
		if spec.is_empty():
			continue
		var control: Control = _controls[key]
		match String(spec["kind"]):
			"slider":
				var s := control as HSlider
				var v := float(Settings.value(String(key)))
				if not is_equal_approx(s.value, v):
					s.set_value_no_signal(v)
				if _value_labels.has(key):
					_value_labels[key].text = "%d%%" % int(v * 100.0)
			"toggle":
				var b := control as Button
				var on := bool(Settings.value(String(key)))
				b.text = "ON" if on else "OFF"
				b.add_theme_color_override("font_color", UIKit.GREEN if on else UIKit.DIM)
				b.add_theme_stylebox_override("normal", UIKit.stylebox(
					UIKit.PANEL_HI.lerp(UIKit.GREEN, 0.28) if on else UIKit.PANEL,
					10, 1, UIKit.GREEN if on else UIKit.PANEL_EDGE))

	if _save_info != null:
		_save_info.text = "Autosaves every %d seconds, plus on exit and when the window loses focus." \
			% int(SaveManager.AUTOSAVE_INTERVAL)
