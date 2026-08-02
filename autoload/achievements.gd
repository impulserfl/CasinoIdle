extends Node

## Achievements are permanent and survive prestige. Each one grants +1% casino
## income, so collecting them is a real (if gentle) progression axis.

signal unlocked(def: Dictionary)

const INCOME_BONUS_EACH := 0.01

const LIST: Array[Dictionary] = [
	{"id": "first_spin",   "name": "First Pull",      "icon": "🎰", "desc": "Place your first wager."},
	{"id": "regular",      "name": "Regular",         "icon": "🪑", "desc": "Place 100 wagers."},
	{"id": "whale",        "name": "Whale",           "icon": "🐋", "desc": "Place 10,000 wagers."},
	{"id": "jackpot",      "name": "Jackpot!",        "icon": "7️⃣", "desc": "Line up three sevens."},
	{"id": "big_win",      "name": "Big Winner",      "icon": "💰", "desc": "Win 100x your bet in one go."},
	{"id": "legend_win",   "name": "Legendary Haul",  "icon": "👑", "desc": "Win 1,000x your bet in one go."},
	{"id": "hot_streak",   "name": "Hot Streak",      "icon": "🔥", "desc": "Win 8 wagers in a row."},
	{"id": "level_10",     "name": "Getting Good",    "icon": "⭐", "desc": "Reach level 10."},
	{"id": "level_25",     "name": "Seasoned",        "icon": "🌟", "desc": "Reach level 25."},
	{"id": "level_50",     "name": "Card Shark",      "icon": "🦈", "desc": "Reach level 50."},
	{"id": "level_100",    "name": "Living Legend",   "icon": "🏆", "desc": "Reach level 100."},
	{"id": "landlord",     "name": "Landlord",        "icon": "🏠", "desc": "Own 25 properties."},
	{"id": "tycoon",       "name": "Tycoon",          "icon": "🏢", "desc": "Own 100 properties."},
	{"id": "mogul",        "name": "Mogul",           "icon": "🏙️", "desc": "Own 250 properties."},
	{"id": "millionaire",  "name": "Millionaire",     "icon": "💵", "desc": "Earn 1M chips lifetime."},
	{"id": "billionaire",  "name": "Billionaire",     "icon": "💸", "desc": "Earn 1B chips lifetime."},
	{"id": "trillionaire", "name": "Trillionaire",    "icon": "🤑", "desc": "Earn 1T chips lifetime."},
	{"id": "reborn",       "name": "Reborn",          "icon": "♻️", "desc": "Prestige for the first time."},
	{"id": "ascended",     "name": "Ascended",        "icon": "🔮", "desc": "Prestige 10 times."},
	{"id": "zero_hero",    "name": "Zero Hero",       "icon": "🟢", "desc": "Win a straight-up bet on zero."},
	{"id": "snake_eyes",   "name": "Snake Eyes",      "icon": "🐍", "desc": "Win a snake eyes bet."},
	{"id": "full_board",   "name": "Full Board",      "icon": "🎯", "desc": "Match 6 symbols on one scratch card."},
	{"id": "specialist",   "name": "Specialist",      "icon": "📗", "desc": "Max out any skill."},
	{"id": "dedicated",    "name": "Dedicated",       "icon": "⏳", "desc": "Play for 2 hours."},
]

var unlocked_ids: Dictionary = {}

## Events fired by minigames that no stat can reconstruct after the fact.
var _flags: Dictionary = {}

var _check_accumulator := 0.0


func _process(delta: float) -> void:
	_check_accumulator += delta
	if _check_accumulator >= 1.0:
		_check_accumulator = 0.0
		check_all()


func is_unlocked(id: String) -> bool:
	return unlocked_ids.has(id)


func unlocked_count() -> int:
	return unlocked_ids.size()


func income_bonus() -> float:
	return INCOME_BONUS_EACH * float(unlocked_count())


func definition(id: String) -> Dictionary:
	for d in LIST:
		if d["id"] == id:
			return d
	return {}


## Called by minigames for one-shot events, e.g. notify("jackpot").
func notify(flag: String) -> void:
	_flags[flag] = true
	check_all()


func check_all() -> void:
	for d in LIST:
		var id := String(d["id"])
		if unlocked_ids.has(id):
			continue
		if _test(id):
			_unlock(d)


func _unlock(d: Dictionary) -> void:
	var id := String(d["id"])
	unlocked_ids[id] = true
	unlocked.emit(d)
	GameManager.notify_toast("%s  %s unlocked!" % [d["icon"], d["name"]], UIKit.GOLD)


func _test(id: String) -> bool:
	var s := GameManager.stats
	match id:
		"first_spin":
			return int(s.get("total_wagers", 0)) >= 1
		"regular":
			return int(s.get("total_wagers", 0)) >= 100
		"whale":
			return int(s.get("total_wagers", 0)) >= 10000
		"jackpot":
			return _flags.has("jackpot") or int(s.get("jackpots", 0)) >= 1
		"big_win":
			return float(s.get("best_multiplier", 0.0)) >= 100.0
		"legend_win":
			return float(s.get("best_multiplier", 0.0)) >= 1000.0
		"hot_streak":
			return int(s.get("best_streak", 0)) >= 8
		"level_10":
			return GameManager.level >= 10
		"level_25":
			return GameManager.level >= 25
		"level_50":
			return GameManager.level >= 50
		"level_100":
			return GameManager.level >= 100
		"landlord":
			return Casino.total_properties() >= 25
		"tycoon":
			return Casino.total_properties() >= 100
		"mogul":
			return Casino.total_properties() >= 250
		"millionaire":
			return float(s.get("lifetime_chips_earned", 0.0)) >= 1e6
		"billionaire":
			return float(s.get("lifetime_chips_earned", 0.0)) >= 1e9
		"trillionaire":
			return float(s.get("lifetime_chips_earned", 0.0)) >= 1e12
		"reborn":
			return GameManager.prestige_count >= 1
		"ascended":
			return GameManager.prestige_count >= 10
		"zero_hero":
			return _flags.has("zero_hero")
		"snake_eyes":
			return _flags.has("snake_eyes")
		"full_board":
			return _flags.has("full_board")
		"specialist":
			return Upgrades.any_skill_maxed()
		"dedicated":
			return float(s.get("play_time", 0.0)) >= 7200.0
	return false
