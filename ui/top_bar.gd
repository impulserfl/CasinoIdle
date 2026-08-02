extends PanelContainer

## Persistent resource header. Chips and income tick continuously, so this polls
## in _process rather than leaning on signals for the fast-moving numbers.

var _chips_label: Label
var _income_label: Label
var _level_label: Label
var _exp_label: Label
var _exp_bar: ProgressBar
var _skill_label: Label
var _gold_label: Label
var _prestige_label: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.PANEL, 12, 1))

	var row := UIKit.hbox(22)
	add_child(row)

	# --- chips + income
	var chips_box := UIKit.vbox(0)
	_chips_label = UIKit.label("0", 28, UIKit.GOLD)
	_income_label = UIKit.label("+0/s", 14, UIKit.GREEN)
	chips_box.add_child(_chips_label)
	chips_box.add_child(_income_label)
	row.add_child(chips_box)

	row.add_child(_divider())

	# --- level + exp
	var exp_box := UIKit.vbox(2)
	exp_box.custom_minimum_size = Vector2(260, 0)
	exp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var exp_head := UIKit.hbox(8)
	_level_label = UIKit.label("Level 1", 18, UIKit.BLUE)
	_exp_label = UIKit.label("0 / 50", 13, UIKit.DIM)
	exp_head.add_child(_level_label)
	exp_head.add_child(UIKit.spacer())
	exp_head.add_child(_exp_label)
	exp_box.add_child(exp_head)
	_exp_bar = UIKit.progress_bar(UIKit.BLUE, 8)
	exp_box.add_child(_exp_bar)
	row.add_child(exp_box)

	row.add_child(_divider())

	_skill_label = _stat_label("🎓", UIKit.CYAN)
	row.add_child(_skill_label)
	_gold_label = _stat_label("💠", UIKit.PURPLE)
	row.add_child(_gold_label)
	_prestige_label = _stat_label("♻️", UIKit.ORANGE)
	row.add_child(_prestige_label)

	GameManager.experience_changed.connect(_on_experience_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.skill_points_changed.connect(_on_skill_points_changed)
	GameManager.gold_chips_changed.connect(_on_gold_changed)
	GameManager.prestige_changed.connect(_on_prestige_changed)

	_on_experience_changed(GameManager.experience, GameManager.exp_to_next(), GameManager.level)
	_on_skill_points_changed(GameManager.skill_points)
	_on_gold_changed(GameManager.gold_chips)
	_on_prestige_changed(GameManager.prestige_count)


func _divider() -> Control:
	var v := VSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.PANEL_EDGE
	sb.content_margin_left = 1
	sb.content_margin_right = 1
	v.add_theme_stylebox_override("separator", sb)
	return v


func _stat_label(icon: String, color: Color) -> Label:
	var l := UIKit.label("%s 0" % icon, 17, color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _process(_delta: float) -> void:
	_chips_label.text = Fmt.chips(GameManager.chips)
	_income_label.text = "+%s" % Fmt.rate(Casino.income_per_second())


func _on_experience_changed(current: float, needed: float, level: int) -> void:
	_level_label.text = "Level %d" % level
	_exp_label.text = "%s / %s" % [Fmt.chips(current), Fmt.chips(needed)]
	_exp_bar.value = clampf(current / maxf(needed, 1.0), 0.0, 1.0)


func _on_level_changed(level: int) -> void:
	_level_label.text = "Level %d" % level
	FX.pulse(_level_label, 1.25, 0.35)


func _on_skill_points_changed(points: int) -> void:
	_skill_label.text = "🎓 %d" % points


func _on_gold_changed(amount: float) -> void:
	_gold_label.text = "💠 %s" % Fmt.chips(amount)


func _on_prestige_changed(count: int) -> void:
	_prestige_label.text = "♻️ %d" % count
