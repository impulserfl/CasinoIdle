extends Node

const SAVE_PATH := "user://casino_idle_save.cfg"

func _ready() -> void:
	load_game()

func save_game() -> void:
	var config = ConfigFile.new()
	
	config.set_value("player", "chips", GameManager.chips)
	config.set_value("player", "total_chips_earned", GameManager.total_chips_earned)
	config.set_value("player", "exp", GameManager.exp)
	config.set_value("player", "level", GameManager.level)
	config.set_value("player", "skill_points", GameManager.skill_points)
	config.set_value("player", "prestige_level", GameManager.prestige_level)
	config.set_value("player", "prestige_multiplier", GameManager.prestige_multiplier)
	
	var err = config.save(SAVE_PATH)
	if err == OK:
		print("Game saved.")
	else:
		print("Failed to save game: ", err)

func load_game() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	if err != OK:
		print("No save found or failed to load. Starting fresh.")
		return
	
	GameManager.chips = config.get_value("player", "chips", 100.0)
	GameManager.total_chips_earned = config.get_value("player", "total_chips_earned", 0.0)
	GameManager.exp = config.get_value("player", "exp", 0.0)
	GameManager.level = config.get_value("player", "level", 1)
	GameManager.skill_points = config.get_value("player", "skill_points", 0)
	GameManager.prestige_level = config.get_value("player", "prestige_level", 0)
	GameManager.prestige_multiplier = config.get_value("player", "prestige_multiplier", 1.0)
	
	# Emit signals so UI updates
	GameManager.chips_changed.emit(GameManager.chips)
	GameManager.level_changed.emit(GameManager.level)
	GameManager.skill_points_changed.emit(GameManager.skill_points)
	GameManager.prestige_changed.emit(GameManager.prestige_level)
	GameManager.exp_changed.emit(GameManager.exp, GameManager.get_exp_to_next_level())
	
	print("Game loaded.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
