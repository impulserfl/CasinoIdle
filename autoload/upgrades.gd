extends Node

## The two persistent trees: skills (bought with level-up points, reset on
## prestige) and prestige ranks (bought with gold chips, permanent).
##
## Only `card_counter`, `fortune_cookie`, `loaded_dice` and `house_edge` touch
## minigame returns, and all four feed the capped RTP budget in Minigame. Every
## other entry here multiplies passive income, EXP, costs or convenience, which
## is what keeps "gambling is never a source of chips" true no matter how deep
## the trees go.

signal changed()

const SKILLS: Array[Dictionary] = [
	{"id": "card_counter", "name": "Card Counter", "icon": "suit_spade",
		"desc": "Shave the house edge on every table.", "effect": "+0.5% RTP per rank",
		"max": 10, "cost_base": 1, "cost_step": 1},
	{"id": "lucky_streak", "name": "Lucky Streak", "icon": "flame",
		"desc": "You learn faster at the tables.", "effect": "+8% EXP per rank",
		"max": 12, "cost_base": 1, "cost_step": 1},
	{"id": "floor_manager", "name": "Floor Manager", "icon": "floor",
		"desc": "More from every property.", "effect": "+10% casino income per rank",
		"max": 15, "cost_base": 1, "cost_step": 1},
	{"id": "haggler", "name": "Haggler", "icon": "chip",
		"desc": "Negotiate better property prices.", "effect": "-2% property cost per rank",
		"max": 10, "cost_base": 2, "cost_step": 2},
	{"id": "quick_hands", "name": "Quick Hands", "icon": "bolt",
		"desc": "Rounds resolve faster.", "effect": "-8% round time per rank",
		"max": 6, "cost_base": 2, "cost_step": 2},
	{"id": "high_roller", "name": "High Roller", "icon": "sym_diamond",
		"desc": "Raise the wager ceiling.", "effect": "+40% max bet per rank",
		"max": 10, "cost_base": 2, "cost_step": 1},
	{"id": "scout", "name": "Night Shift", "icon": "moon",
		"desc": "Better offline earnings.", "effect": "+4% offline rate, +20m cap per rank",
		"max": 10, "cost_base": 2, "cost_step": 2},
	{"id": "pit_boss", "name": "Pit Boss", "icon": "stats",
		"desc": "Tighter floor operations.", "effect": "+4% casino income per rank",
		"max": 12, "cost_base": 2, "cost_step": 1},
	{"id": "comp_cards", "name": "Comp Cards", "icon": "gift",
		"desc": "Loyalty desk perks.", "effect": "+5% EXP per rank",
		"max": 10, "cost_base": 1, "cost_step": 2},
	{"id": "chip_runner", "name": "Chip Runner", "icon": "clock",
		"desc": "Shorter gap between auto rounds.", "effect": "-6% auto delay per rank",
		"max": 5, "cost_base": 3, "cost_step": 2},
	{"id": "streak_hunter", "name": "Streak Hunter", "icon": "target",
		"desc": "Win streaks teach more.", "effect": "+10% EXP while on a streak per rank",
		"max": 8, "cost_base": 2, "cost_step": 2},
	{"id": "fortune_cookie", "name": "Fortune Cookie", "icon": "sym_gem",
		"desc": "A slightly kinder house.", "effect": "+0.3% RTP per rank",
		"max": 5, "cost_base": 3, "cost_step": 3},
	{"id": "greeter", "name": "Greeter", "icon": "check",
		"desc": "A warm welcome lifts the tips.", "effect": "+3% casino income per rank",
		"max": 10, "cost_base": 1, "cost_step": 1},
	{"id": "concierge", "name": "Concierge", "icon": "clock",
		"desc": "The floor keeps running longer without you.", "effect": "+15m offline cap per rank",
		"max": 10, "cost_base": 2, "cost_step": 2},
	{"id": "showman", "name": "Showman", "icon": "trophy",
		"desc": "Your reputation pulls a crowd.", "effect": "+0.4% income per achievement, per rank",
		"max": 8, "cost_base": 3, "cost_step": 2},
	{"id": "collector", "name": "Collector", "icon": "chip_gold",
		"desc": "You cash out on better terms.", "effect": "+3% gold chips on prestige per rank",
		"max": 10, "cost_base": 2, "cost_step": 2},
	{"id": "tipster", "name": "Tipster", "icon": "gift",
		"desc": "The daily desk likes you.", "effect": "+20% daily bonus per rank",
		"max": 8, "cost_base": 2, "cost_step": 1},
	{"id": "analyst", "name": "Analyst", "icon": "stats",
		"desc": "Variety sharpens you.", "effect": "+2% EXP per table played this run, per rank",
		"max": 6, "cost_base": 3, "cost_step": 2},
	{"id": "shift_lead", "name": "Shift Lead", "icon": "floor",
		"desc": "Nobody slacks on your watch.", "effect": "+6% casino income per rank",
		"max": 12, "cost_base": 2, "cost_step": 2},
	{"id": "promoter", "name": "Promoter", "icon": "bolt",
		"desc": "Something is always happening here.", "effect": "-7% event cooldown per rank",
		"max": 6, "cost_base": 3, "cost_step": 3},
]

const PRESTIGE: Array[Dictionary] = [
	{"id": "golden_touch", "name": "Golden Touch", "icon": "sym_coin",
		"desc": "The floor earns more, forever.", "effect": "+12% casino income per rank",
		"max": 25, "cost_base": 1, "growth": 1.5},
	{"id": "veteran", "name": "Veteran", "icon": "trophy",
		"desc": "Experience carries between lives.", "effect": "+20% EXP per rank",
		"max": 15, "cost_base": 2, "growth": 1.55},
	{"id": "vault", "name": "The Vault", "icon": "lock",
		"desc": "A longer offline bank.", "effect": "+2h offline cap per rank",
		"max": 12, "cost_base": 3, "growth": 1.7},
	{"id": "head_start", "name": "Head Start", "icon": "arrow_up",
		"desc": "A fatter opening bankroll.", "effect": "x2 starting chips per rank",
		"max": 15, "cost_base": 2, "growth": 1.6},
	{"id": "apprentice", "name": "Apprentice", "icon": "skill",
		"desc": "Begin each run already trained.", "effect": "+1 starting skill point per rank",
		"max": 10, "cost_base": 8, "growth": 1.8},
	{"id": "loaded_dice", "name": "Loaded Dice", "icon": "game_dice",
		"desc": "A permanent nudge at every table.", "effect": "+0.4% RTP per rank",
		"max": 10, "cost_base": 4, "growth": 1.6},
	{"id": "magnate", "name": "Magnate", "icon": "floor",
		"desc": "You never pay list price.", "effect": "-3% property cost per rank",
		"max": 10, "cost_base": 6, "growth": 1.7},
	{"id": "compound_interest", "name": "Compound Interest", "icon": "game_crash",
		"desc": "Cash out on better terms.", "effect": "+5% gold chips on prestige per rank",
		"max": 20, "cost_base": 5, "growth": 1.45},
	{"id": "free_floor", "name": "Grandfathered", "icon": "prop_pennyslots",
		"desc": "Keep a few doors open.", "effect": "+3 of the first 3 properties per rank",
		"max": 5, "cost_base": 12, "growth": 2.0},
	{"id": "silver_spoon", "name": "Silver Spoon", "icon": "chip",
		"desc": "Extra chips in the opening pocket.", "effect": "+15% starting chips per rank",
		"max": 10, "cost_base": 3, "growth": 1.5},
	{"id": "time_lord", "name": "Time Lord", "icon": "clock",
		"desc": "The floor runs better while you sleep.", "effect": "+4% offline efficiency per rank",
		"max": 10, "cost_base": 4, "growth": 1.55},
	{"id": "house_edge", "name": "House Edge", "icon": "arrow_down",
		"desc": "A tiny permanent trim.", "effect": "+0.25% RTP per rank",
		"max": 8, "cost_base": 6, "growth": 1.65},
	{"id": "daily_whale", "name": "Daily Whale", "icon": "gift",
		"desc": "Fatter daily rewards.", "effect": "+15% daily bonus per rank",
		"max": 10, "cost_base": 4, "growth": 1.5},
	{"id": "party_planner", "name": "Party Planner", "icon": "flame",
		"desc": "Lucky Hours hit harder and last longer.", "effect": "+0.1x mult, +30s per rank",
		"max": 8, "cost_base": 5, "growth": 1.6},
	{"id": "high_limit", "name": "High Limit", "icon": "sym_diamond",
		"desc": "Raise the soft bet ceiling.", "effect": "+10% max bet fraction per rank",
		"max": 10, "cost_base": 7, "growth": 1.55},
	{"id": "architect", "name": "Architect", "icon": "prop_sky",
		"desc": "Each new property costs a little less to add than the last.",
		"effect": "-0.2% property cost growth per rank",
		"max": 6, "cost_base": 20, "growth": 2.1},
	{"id": "curator", "name": "Curator", "icon": "trophy",
		"desc": "Your trophy wall pulls in the crowds.",
		"effect": "+0.6% income per achievement, per rank",
		"max": 10, "cost_base": 6, "growth": 1.6},
	{"id": "kingmaker", "name": "Kingmaker", "icon": "sym_crown",
		"desc": "No prestige ever comes back empty-handed.",
		"effect": "+1 minimum gold chips per rank",
		"max": 10, "cost_base": 5, "growth": 1.55},
	{"id": "impresario", "name": "Impresario", "icon": "game_wheel",
		"desc": "The good times run long.", "effect": "+20% event buff duration per rank",
		"max": 8, "cost_base": 5, "growth": 1.6},
	{"id": "syndicate", "name": "Syndicate", "icon": "prop_highroller",
		"desc": "Every life you have lived pays a dividend.",
		"effect": "+2% income per prestige, per rank",
		"max": 10, "cost_base": 9, "growth": 1.7},
	{"id": "librarian", "name": "Librarian", "icon": "exp",
		"desc": "You keep better notes than the house does.",
		"effect": "+15% EXP per rank", "max": 12, "cost_base": 6, "growth": 1.5},
]

var skill_levels: Dictionary = {}
var prestige_levels: Dictionary = {}

var _skill_index: Dictionary = {}
var _prestige_index: Dictionary = {}


func _ready() -> void:
	for d in SKILLS:
		_skill_index[String(d["id"])] = d
	for d in PRESTIGE:
		_prestige_index[String(d["id"])] = d


func skill_def(id: String) -> Dictionary:
	return _skill_index.get(id, {})


func prestige_def(id: String) -> Dictionary:
	return _prestige_index.get(id, {})


func skill_level(id: String) -> int:
	return int(skill_levels.get(id, 0))


func prestige_rank(id: String) -> int:
	return int(prestige_levels.get(id, 0))


func skill_cost(id: String) -> int:
	var d := skill_def(id)
	if d.is_empty():
		return 0
	return int(d["cost_base"]) + int(d["cost_step"]) * skill_level(id)


func prestige_cost(id: String) -> int:
	var d := prestige_def(id)
	if d.is_empty():
		return 0
	return int(ceilf(float(d["cost_base"]) * pow(float(d["growth"]), float(prestige_rank(id)))))


func skill_maxed(id: String) -> bool:
	var d := skill_def(id)
	return not d.is_empty() and skill_level(id) >= int(d["max"])


func prestige_maxed(id: String) -> bool:
	var d := prestige_def(id)
	return not d.is_empty() and prestige_rank(id) >= int(d["max"])


func can_buy_skill(id: String) -> bool:
	return not skill_maxed(id) and GameManager.skill_points >= skill_cost(id)


func can_buy_prestige(id: String) -> bool:
	return not prestige_maxed(id) and GameManager.gold_chips >= float(prestige_cost(id))


func buy_skill(id: String) -> bool:
	if not can_buy_skill(id):
		return false
	if not GameManager.spend_skill_points(skill_cost(id)):
		return false
	skill_levels[id] = skill_level(id) + 1
	changed.emit()
	AudioManager.play_buy()
	Achievements.check_all()
	return true


func buy_prestige(id: String) -> bool:
	if not can_buy_prestige(id):
		return false
	if not GameManager.spend_gold_chips(float(prestige_cost(id))):
		return false
	prestige_levels[id] = prestige_rank(id) + 1
	changed.emit()
	AudioManager.play_buy()
	Achievements.check_all()
	return true


func reset_skills() -> void:
	skill_levels.clear()
	changed.emit()


func any_skill_maxed() -> bool:
	for d in SKILLS:
		if skill_maxed(String(d["id"])):
			return true
	return false


func total_skill_ranks() -> int:
	var n := 0
	for id in skill_levels:
		n += int(skill_levels[id])
	return n


func total_prestige_ranks() -> int:
	var n := 0
	for id in prestige_levels:
		n += int(prestige_levels[id])
	return n
