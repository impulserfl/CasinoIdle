extends Control

## In-depth settings: audio, gameplay preferences, and dangerous actions.

var _master_slider: HSlider
var _sfx_slider: HSlider
var _master_value: Label
var _sfx_value: Label
var _mute_button: Button
var _auto_spin_sfx_button: Button
var _confirm_prestige_button: Button
var _autosave_label: Label
var _reset_confirming := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root := UIKit.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 14
	root.offset_top = 12
	root.offset_right = -14
	root.offset_bottom = -12
	add_child(root)

	root.add_child(UIKit.title("⚙️  Settings", 24, UIKit.TEXT))
	root.add_child(UIKit.separator())

	var scroll := UIKit.scroll()
	var col := UIKit.vbox(16)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	col.add_child(_section_title("Audio"))
	col.add_child(_build_audio_block())

	col.add_child(_section_title("Gameplay"))
	col.add_child(_build_gameplay_block())

	col.add_child(_section_title("Danger Zone"))
	col.add_child(_build_danger_block())

	scroll.add_child(col)
	root.add_child(scroll)

	_sync_from_manager()


func _section_title(text: String) -> Label:
	return UIKit.label(text, 18, UIKit.GOLD)


func _build_audio_block() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var col := UIKit.vbox(10)

	# Master
	var master_row := UIKit.hbox(10)
	master_row.add_child(UIKit.label("Master Volume", 15))
	master_row.add_child(UIKit.spacer())
	_master_value = UIKit.label("85%", 14, UIKit.DIM)
	master_row.add_child(_master_value)
	col.add_child(master_row)
	_master_slider = _make_slider()
	_master_slider.value_changed.connect(_on_master_changed)
	col.add_child(_master_slider)

	# SFX
	var sfx_row := UIKit.hbox(10)
	sfx_row.add_child(UIKit.label("SFX Volume", 15))
	sfx_row.add_child(UIKit.spacer())
	_sfx_value = UIKit.label("100%", 14, UIKit.DIM)
	sfx_row.add_child(_sfx_value)
	col.add_child(sfx_row)
	_sfx_slider = _make_slider()
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	col.add_child(_sfx_slider)

	var btn_row := UIKit.hbox(10)
	_mute_button = UIKit.button("Mute: OFF", 15, UIKit.ORANGE)
	_mute_button.custom_minimum_size = Vector2(140, 36)
	_mute_button.pressed.connect(_on_mute_pressed)
	btn_row.add_child(_mute_button)

	var test_btn := UIKit.button("Test Sound", 15, UIKit.BLUE)
	test_btn.custom_minimum_size = Vector2(130, 36)
	test_btn.pressed.connect(func(): AudioManager.play_win(5.0))
	btn_row.add_child(test_btn)
	col.add_child(btn_row)

	col.add_child(UIKit.wrapped(
		"Sounds are generated tones (no external files). Real audio packs can be dropped in later.",
		12, UIKit.DIM))

	panel.add_child(col)
	return panel


func _build_gameplay_block() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var col := UIKit.vbox(10)

	_auto_spin_sfx_button = UIKit.button("Auto-spin SFX: ON", 15, UIKit.GREEN)
	_auto_spin_sfx_button.custom_minimum_size = Vector2(0, 38)
	_auto_spin_sfx_button.pressed.connect(_on_auto_sfx_pressed)
	col.add_child(_auto_spin_sfx_button)

	_confirm_prestige_button = UIKit.button("Prestige confirm: ON", 15, UIKit.GREEN)
	_confirm_prestige_button.custom_minimum_size = Vector2(0, 38)
	_confirm_prestige_button.pressed.connect(_on_confirm_prestige_pressed)
	col.add_child(_confirm_prestige_button)

	_autosave_label = UIKit.label("", 14, UIKit.DIM)
	col.add_child(_autosave_label)

	col.add_child(UIKit.wrapped(
		"Autosave runs in the background. Manual save is still available from the footer.",
		12, UIKit.DIM))

	panel.add_child(col)
	return panel


func _build_danger_block() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var col := UIKit.vbox(10)

	col.add_child(UIKit.wrapped(
		"These actions cannot be undone. Prestige is the safe way to reset a run.",
		13, UIKit.ORANGE))

	var reset_btn := UIKit.button("🗑  Reset Entire Save", 16, UIKit.RED)
	reset_btn.custom_minimum_size = Vector2(0, 44)
	reset_btn.pressed.connect(_on_reset_pressed)
	col.add_child(reset_btn)

	panel.add_child(col)
	return panel


func _make_slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 24)
	return s


func _sync_from_manager() -> void:
	_master_slider.value = AudioManager.master_volume
	_sfx_slider.value = AudioManager.sfx_volume
	_master_value.text = "%d%%" % int(AudioManager.master_volume * 100.0)
	_sfx_value.text = "%d%%" % int(AudioManager.sfx_volume * 100.0)
	_mute_button.text = "Mute: ON" if AudioManager.muted else "Mute: OFF"
	_auto_spin_sfx_button.text = "Auto-spin SFX: ON" if Settings.auto_spin_sfx else "Auto-spin SFX: OFF"
	_confirm_prestige_button.text = "Prestige confirm: ON" if Settings.confirm_prestige else "Prestige confirm: OFF"
	_autosave_label.text = "Autosave interval: every %d seconds" % int(SaveManager.AUTOSAVE_INTERVAL)


func _on_master_changed(v: float) -> void:
	AudioManager.master_volume = v
	_master_value.text = "%d%%" % int(v * 100.0)
	Settings.mark_dirty()


func _on_sfx_changed(v: float) -> void:
	AudioManager.sfx_volume = v
	_sfx_value.text = "%d%%" % int(v * 100.0)
	Settings.mark_dirty()


func _on_mute_pressed() -> void:
	AudioManager.muted = not AudioManager.muted
	_mute_button.text = "Mute: ON" if AudioManager.muted else "Mute: OFF"
	AudioManager.play_click()
	Settings.mark_dirty()


func _on_auto_sfx_pressed() -> void:
	Settings.auto_spin_sfx = not Settings.auto_spin_sfx
	_auto_spin_sfx_button.text = "Auto-spin SFX: ON" if Settings.auto_spin_sfx else "Auto-spin SFX: OFF"
	AudioManager.play_click()
	Settings.mark_dirty()


func _on_confirm_prestige_pressed() -> void:
	Settings.confirm_prestige = not Settings.confirm_prestige
	_confirm_prestige_button.text = "Prestige confirm: ON" if Settings.confirm_prestige else "Prestige confirm: OFF"
	AudioManager.play_click()
	Settings.mark_dirty()


func _on_reset_pressed() -> void:
	if not _reset_confirming:
		_reset_confirming = true
		GameManager.notify_toast("Click Reset again within 4s to wipe EVERYTHING", UIKit.ORANGE)
		AudioManager.play_error()
		await get_tree().create_timer(4.0).timeout
		_reset_confirming = false
		return
	_reset_confirming = false
	SaveManager.wipe_save()
	AudioManager.play_error()
	GameManager.notify_toast("Save wiped — starting fresh", UIKit.RED)
