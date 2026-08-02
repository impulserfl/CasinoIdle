extends PanelContainer

## Persistent status strip with glass chrome and gold edge.

const REFRESH_INTERVAL := 0.1

var _chips_label: Label
var _income_label: Label
var _level_label: Label
var _exp_label: Label
var _exp_bar: ProgressBar
var _skill_label: Label
var _gold_label: Label
var _prestige_label: Label
var _buff_row: HBoxContainer
var _buff_icon: TextureRect
var _buff_label: Label
var _refresh_accumulator := 0.0


func _ready() -> void:
	var sb := UIKit.glass_stylebox(18)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.border_color = Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.35)
	sb.set_border_width_all(1)
	add_theme_stylebox_override("panel", sb)

	var row := UIKit.hbox(20)
	add_child(row)

	var chips_box := UIKit.hbox(12)
	chips_box.add_child(UIKit.icon("chip", 36))
	var chips_col := UIKit.vbox(2)
	_chips_label = UIKit.numeral("0", 30, UIKit.GOLD)
	_income_label = UIKit.label("+0/s", 13, UIKit.GREEN)
	chips_col.add_child(_chips_label)
	chips_col.add_child(_income_label)
	chips_box.add_child(chips_col)
	row.add_child(chips_box)

	row.add_child(_divider())

	var exp_box := UIKit.vbox(5)
	exp_box.custom_minimum_size = Vector2(240, 0)
	exp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var exp_head := UIKit.hbox(8)
	_level_label = UIKit.label("Level 1", 18, UIKit.BLUE)
	_exp_label = UIKit.label("0 / 24", 12, UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_exp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_head.add_child(_level_label)
	exp_head.add_child(_exp_label)
	exp_box.add_child(exp_head)
	_exp_bar = UIKit.progress_bar(UIKit.BLUE, 11)
	exp_box.add_child(_exp_bar)
	row.add_child(exp_box)

	row.add_child(_divider())

	_skill_label = _stat("skill", UIKit.CYAN)
	row.add_child(_skill_label.get_parent())
	_gold_label = _stat("chip_gold", UIKit.PURPLE)
	row.add_child(_gold_label.get_parent())
	_prestige_label = _stat("prestige", UIKit.ORANGE)
	row.add_child(_prestige_label.get_parent())

	_buff_row = UIKit.hbox(6)
	_buff_icon = UIKit.icon("flame", 20)
	_buff_label = UIKit.label("", 12, UIKit.GREEN)
	_buff_row.add_child(_buff_icon)
	_buff_row.add_child(_buff_label)
	_buff_row.visible = false
	row.add_child(_buff_row)

	GameManager.experience_changed.connect(_on_experience_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.skill_points_changed.connect(func(p): _skill_label.text = str(p))
	GameManager.gold_chips_changed.connect(func(a): _gold_label.text = Fmt.chips(a))
	GameManager.prestige_changed.connect(func(c): _prestige_label.text = str(c))

	_on_experience_changed(GameManager.experience, GameManager.exp_to_next(), GameManager.level)
	_skill_label.text = str(GameManager.skill_points)
	_gold_label.text = Fmt.chips(GameManager.gold_chips)
	_prestige_label.text = str(GameManager.prestige_count)


func _divider() -> Control:
	var v := VSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.2)
	sb.content_margin_left = 1
	sb.content_margin_right = 1
	v.add_theme_stylebox_override("separator", sb)
	return v


func _stat(icon_name: String, color: Color) -> Label:
	var box := UIKit.hbox(6)
	box.add_child(UIKit.icon(icon_name, 24))
	var l := UIKit.numeral("0", 18, color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	return l


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < REFRESH_INTERVAL:
		return
	_refresh_accumulator = 0.0

	_chips_label.text = Fmt.chips(GameManager.chips)
	_income_label.text = "+%s" % Fmt.rate(Casino.income_per_second())

	if Events.lucky_hour_remaining > 0.0:
		_show_buff("flame", "Lucky Hour x%.1f  %ds"
			% [Events.lucky_hour_mult, int(Events.lucky_hour_remaining)], UIKit.GREEN)
	elif Events.buff_remaining > 0.0:
		_show_buff("bolt", "%s  %ds" % [Events.buff_label, int(Events.buff_remaining)], UIKit.ORANGE)
	elif Events.is_event_pending():
		_show_buff("gift", "Event waiting", UIKit.GOLD)
	else:
		var cd := Events.cooldown_remaining()
		if cd > 0.0:
			_show_buff("clock", "Next event %d:%02d" % [int(cd) / 60, int(cd) % 60], UIKit.DIM)
		else:
			_buff_row.visible = false


func _show_buff(icon_name: String, text: String, color: Color) -> void:
	_buff_row.visible = true
	_buff_icon.texture = Icons.tex(icon_name)
	_buff_label.text = text
	_buff_label.add_theme_color_override("font_color", color)


func _on_experience_changed(current: float, needed: float, level: int) -> void:
	_level_label.text = "Level %d" % level
	_exp_label.text = "%s / %s" % [Fmt.chips(current), Fmt.chips(needed)]
	_exp_bar.value = clampf(current / maxf(needed, 1.0), 0.0, 1.0)


func _on_level_changed(level: int) -> void:
	_level_label.text = "Level %d" % level
	FX.pulse(_level_label, 1.25, 0.35)
