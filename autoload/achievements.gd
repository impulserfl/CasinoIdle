extends Node

## Achievements. Each unlocked achievement is worth +1% casino income, so the
## list length is a balance constant, not decoration — the pacing model in
## tools/verify_balance.py assumes it.

signal unlocked(def: Dictionary)

const INCOME_BONUS_EACH := 0.01
const CHECK_INTERVAL := 1.0

const LIST: Array[Dictionary] = [
	{"id": "first_spin",   "name": "First Pull",     "icon": "game_slots",     "desc": "Place your first wager."},
	{"id": "regular",      "name": "Regular",        "icon": "chip",           "desc": "Place 100 wagers."},
	{"id": "whale",        "name": "Whale",          "icon": "prop_highroller", "desc": "Place 10,000 wagers."},
	{"id": "jackpot",      "name": "Jackpot",        "icon": "reel_seven",     "desc": "Hit a jackpot."},
	{"id": "big_win",      "name": "Big Winner",     "icon": "sym_coin",       "desc": "Win 100x your bet."},
	{"id": "legend_win",   "name": "Legendary Haul", "icon": "sym_crown",      "desc": "Win 1,000x your bet."},
	{"id": "hot_streak",   "name": "Hot Streak",     "icon": "flame",          "desc": "Win 8 in a row."},
	{"id": "level_10",     "name": "Getting Good",   "icon": "exp",            "desc": "Reach level 10."},
	{"id": "level_25",     "name": "Seasoned",       "icon": "exp",            "desc": "Reach level 25."},
	{"id": "level_50",     "name": "Card Shark",     "icon": "skill",          "desc": "Reach level 50."},
	{"id": "level_100",    "name": "Living Legend",  "icon": "trophy",         "desc": "Reach level 100."},
	{"id": "landlord",     "name": "Landlord",       "icon": "prop_pennyslots", "desc": "Own 25 properties."},
	{"id": "tycoon",       "name": "Tycoon",         "icon": "prop_sky",       "desc": "Own 100 properties."},
	{"id": "mogul",        "name": "Mogul",          "icon": "floor",          "desc": "Own 250 properties."},
	{"id": "millionaire",  "name": "Millionaire",    "icon": "chip_gold",      "desc": "Earn 1M chips lifetime."},
	{"id": "billionaire",  "name": "Billionaire",    "icon": "sym_gem",        "desc": "Earn 1B chips lifetime."},
	{"id": "trillionaire", "name": "Trillionaire",   "icon": "sym_diamond",    "desc": "Earn 1T chips lifetime."},
	{"id": "reborn",       "name": "Reborn",         "icon": "prestige",       "desc": "Prestige once."},
	{"id": "ascended",     "name": "Ascended",       "icon": "prestige",       "desc": "Prestige 10 times."},
	{"id": "zero_hero",    "name": "Zero Hero",      "icon": "game_roulette",  "desc": "Win straight up on zero."},
	{"id": "snake_eyes",   "name": "Snake Eyes",     "icon": "die_1",          "desc": "Win on snake eyes."},
	{"id": "full_board",   "name": "Full Board",     "icon": "game_scratch",   "desc": "Six matches on a scratch card."},
	{"id": "specialist",   "name": "Specialist",     "icon": "skill",          "desc": "Max out any skill."},
	{"id": "dedicated",    "name": "Dedicated",      "icon": "clock",          "desc": "Play for two hours."},
	{"id": "daily_claim",  "name": "Regular Guest",  "icon": "gift",           "desc": "Claim a daily bonus."},
	{"id": "daily_week",   "name": "Weekly Regular", "icon": "gift",           "desc": "Reach a 7 day daily streak."},
	{"id": "table_hopper", "name": "Table Hopper",   "icon": "game_keno",      "desc": "Play 8 different tables."},
	{"id": "kraken",       "name": "Kraken Hunter",  "icon": "fish_kraken",    "desc": "Reel in the Kraken at 400x."},
	{"id": "bullseye",     "name": "Bullseye",       "icon": "target",         "desc": "Hit the dart bull for 25x."},
]

var unlocked_ids: Dictionary = {}
var _flags: Dictionary = {}
var _check_accumulator := 0.0


func _process(delta: float) -> void:
	_check_accumulator += delta
	if _check_accumulator >= CHECK_INTERVAL:
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
		if String(d["id"]) == id:
			return d
	return {}


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
	unlocked_ids[String(d["id"])] = true
	unlocked.emit(d)
	if Settings.toast_achievement:
		GameManager.notify_toast("%s unlocked" % String(d["name"]), UIKit.GOLD, String(d["icon"]))


func _test(id: String) -> bool:
	var s := GameManager.stats
	match id:
		"first_spin": return int(s.get("total_wagers", 0)) >= 1
		"regular": return int(s.get("total_wagers", 0)) >= 100
		"whale": return int(s.get("total_wagers", 0)) >= 10000
		"jackpot": return _flags.has("jackpot") or int(s.get("jackpots", 0)) >= 1
		"big_win": return float(s.get("best_multiplier", 0.0)) >= 100.0
		"legend_win": return float(s.get("best_multiplier", 0.0)) >= 1000.0
		"hot_streak": return int(s.get("best_streak", 0)) >= 8
		"level_10": return GameManager.level >= 10
		"level_25": return GameManager.level >= 25
		"level_50": return GameManager.level >= 50
		"level_100": return GameManager.level >= 100
		"landlord": return Casino.total_properties() >= 25
		"tycoon": return Casino.total_properties() >= 100
		"mogul": return Casino.total_properties() >= 250
		"millionaire": return float(s.get("lifetime_chips_earned", 0.0)) >= 1e6
		"billionaire": return float(s.get("lifetime_chips_earned", 0.0)) >= 1e9
		"trillionaire": return float(s.get("lifetime_chips_earned", 0.0)) >= 1e12
		"reborn": return GameManager.prestige_count >= 1
		"ascended": return GameManager.prestige_count >= 10
		"zero_hero": return _flags.has("zero_hero")
		"snake_eyes": return _flags.has("snake_eyes")
		"full_board": return _flags.has("full_board")
		"specialist": return Upgrades.any_skill_maxed()
		"dedicated": return float(s.get("play_time", 0.0)) >= 7200.0
		"daily_claim": return _flags.has("daily_claim") or Events.daily_streak >= 1
		"daily_week": return Events.daily_streak >= 7
		"kraken": return _flags.has("kraken")
		"bullseye": return _flags.has("bullseye")
		"table_hopper":
			var plays: Dictionary = s.get("plays", {})
			var kinds := 0
			for k in plays:
				if int(plays[k]) > 0:
					kinds += 1
			return kinds >= 8
	return false
