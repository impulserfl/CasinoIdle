extends Control

@onready var chips_label: Label = $TopBar/ChipsLabel
@onready var level_label: Label = $TopBar/LevelLabel
@onready var exp_label: Label = $TopBar/ExpLabel
@onready var skill_label: Label = $TopBar/SkillLabel
@onready var prestige_label: Label = $TopBar/PrestigeLabel
@onready var prestige_button: Button = $TopBar/PrestigeButton
@onready var slot_machine = $SlotMachine

func _ready() -> void:
	# Connect signals
	GameManager.chips_changed.connect(_on_chips_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.exp_changed.connect(_on_exp_changed)
	GameManager.skill_points_changed.connect(_on_skill_points_changed)
	GameManager.prestige_changed.connect(_on_prestige_changed)
	
	# Initial UI update
	_on_chips_changed(GameManager.chips)
	_on_level_changed(GameManager.level)
	_on_exp_changed(GameManager.exp, GameManager.get_exp_to_next_level())
	_on_skill_points_changed(GameManager.skill_points)
	_on_prestige_changed(GameManager.prestige_level)
	
	_update_prestige_button()

func _on_chips_changed(amount: float) -> void:
	chips_label.text = "Chips: %.0f" % amount

func _on_level_changed(lvl: int) -> void:
	level_label.text = "Level: %d" % lvl
	_update_prestige_button()

func _on_exp_changed(current: float, needed: float) -> void:
	exp_label.text = "EXP: %.0f / %.0f" % [current, needed]

func _on_skill_points_changed(points: int) -> void:
	skill_label.text = "Skill Points: %d" % points

func _on_prestige_changed(p_level: int) -> void:
	prestige_label.text = "Prestige: %d (x%.2f)" % [p_level, GameManager.prestige_multiplier]
	_update_prestige_button()

func _update_prestige_button() -> void:
	prestige_button.disabled = not GameManager.can_prestige()
	if GameManager.can_prestige():
		prestige_button.text = "PRESTIGE READY"
	else:
		prestige_button.text = "Prestige (Need Lv 10 or 5k earned)"

func _on_prestige_button_pressed() -> void:
	GameManager.do_prestige()
	SaveManager.save_game()

func _on_save_button_pressed() -> void:
	SaveManager.save_game()

func _on_debug_chips_pressed() -> void:
	GameManager.debug_add_chips(1000)

func _on_debug_exp_pressed() -> void:
	GameManager.debug_add_exp(200)
