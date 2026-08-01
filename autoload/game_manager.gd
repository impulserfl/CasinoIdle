extends Node

# ======================
# CORE CURRENCY & STATS
# ======================
signal chips_changed(new_amount: float)
signal exp_changed(current_exp: float, exp_to_next: float)
signal level_changed(new_level: int)
signal skill_points_changed(new_amount: int)
signal prestige_changed(new_level: int)

var chips: float = 100.0:
	set(value):
		chips = value
		chips_changed.emit(chips)


var total_chips_earned: float = 0.0
var exp: float = 0.0
var level: int = 1
var skill_points: int = 0
var prestige_level: int = 0
var prestige_multiplier: float = 1.0

# How much exp is needed for next level
func get_exp_to_next_level() -> float:
	return 50.0 * level * (1.0 + prestige_level * 0.15)

# ======================
# GAINING RESOURCES
# ======================
func add_chips(amount: float) -> void:
	var final_amount = amount * prestige_multiplier
	chips += final_amount
	total_chips_earned += final_amount
	# Give a little exp for earning chips
	add_exp(final_amount * 0.05)

func add_exp(amount: float) -> void:
	exp += amount
	var needed = get_exp_to_next_level()
	while exp >= needed:
		exp -= needed
		level += 1
		skill_points += 1
		level_changed.emit(level)
		skill_points_changed.emit(skill_points)
		needed = get_exp_to_next_level()
	exp_changed.emit(exp, needed)

# ======================
# PRESTIGE
# ======================
func can_prestige() -> bool:
	return level >= 10 or total_chips_earned >= 5000.0

func do_prestige() -> void:
	if not can_prestige():
		return
	
	prestige_level += 1
	prestige_multiplier = 1.0 + (prestige_level * 0.25)
	
	# Reset run progress
	chips = 100.0
	exp = 0.0
	level = 1
	skill_points = 0
	total_chips_earned = 0.0
	
	prestige_changed.emit(prestige_level)
	level_changed.emit(level)
	skill_points_changed.emit(skill_points)
	chips_changed.emit(chips)
	exp_changed.emit(exp, get_exp_to_next_level())
	
	print("Prestiged! New multiplier: x", prestige_multiplier)

# ======================
# DEBUG / CHEATS (for testing)
# ======================
func debug_add_chips(amount: float = 1000.0) -> void:
	add_chips(amount)

func debug_add_exp(amount: float = 100.0) -> void:
	add_exp(amount)
