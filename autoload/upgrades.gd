extends Node

## Two upgrade trees:
##   SKILLS   - bought with skill points, wiped on prestige.
##   PRESTIGE - bought with gold chips, permanent.
##
## Note that no upgrade multiplies minigame winnings directly. Payout boosts
## would raise RTP without bound and turn auto-play into free money, so the only
## gambling lever is `card_counter` / `loaded_dice`, which feed
## GameManager.rtp_bonus() and are clamped by MAX_EFFECTIVE_RTP.

signal changed()

const SKILLS: Array[Dictionary] = [
	{
		"id": "card_counter", "name": "Card Counter", "icon": "🃏",
		"desc": "Shave the house edge on every game you play.",
		"effect": "+0.5% RTP per rank", "max": 10, "cost_base": 1, "cost_step": 1,
	},
	{
		"id": "lucky_streak", "name": "Lucky Streak", "icon": "🔥",
		"desc": "You learn faster at the tables.",
		"effect": "+8% EXP per rank", "max": 12, "cost_base": 1, "cost_step": 1,
	},
	{
		"id": "floor_manager", "name": "Floor Manager", "icon": "🎩",
		"desc": "Squeeze more out of every property on your casino floor.",
		"effect": "+10% casino income per rank", "max": 15, "cost_base": 1, "cost_step": 1,
	},
	{
		"id": "haggler", "name": "Haggler", "icon": "🤝",
		"desc": "Negotiate better prices on new property.",
		"effect": "-2% property cost per rank", "max": 10, "cost_base": 2, "cost_step": 2,
	},
	{
		"id": "quick_hands", "name": "Quick Hands", "icon": "⚡",
		"desc": "Deal, spin and scratch faster.",
		"effect": "-8% animation time per rank", "max": 6, "cost_base": 2, "cost_step": 2,
	},
	{
		"id": "high_roller", "name": "High Roller", "icon": "💎",
		"desc": "Raise the ceiling on a single wager, converting chips to EXP faster.",
		"effect": "+50% max bet per rank", "max": 10, "cost_base": 2, "cost_step": 1,
	},
	{
		"id": "scout", "name": "Night Shift", "icon": "🌙",
		"desc": "Keep the floor running properly while you are away.",
		"effect": "+5% offline rate, +30m offline cap per rank",
		"max": 10, "cost_base": 2, "cost_step": 2,
	},
	# --- new skills ---
	{
		"id": "pit_boss", "name": "Pit Boss", "icon": "📋",
		"desc": "Tighter floor operations. Small but permanent income edge.",
		"effect": "+4% casino income per rank", "max": 12, "cost_base": 2, "cost_step": 1,
	},
	{
		"id": "comp_cards", "name": "Comp Cards", "icon": "🎫",
		"desc": "Loyalty perks that make every spin teach you a little more.",
		"effect": "+5% EXP per rank", "max": 10, "cost_base": 1, "cost_step": 2,
	},
	{
		"id": "chip_runner", "name": "Chip Runner", "icon": "🏃",
		"desc": "Faster table turnover between auto spins.",
		"effect": "-6% auto-spin delay per rank", "max": 5, "cost_base": 3, "cost_step": 2,
	},
]

const PRESTIGE: Array[Dictionary] = [
	{
		"id": "golden_touch", "name": "Golden Touch", "icon": "✨",
		"desc": "Every property on the floor earns more, forever.",
		"effect": "+12% casino income per rank", "max": 25, "cost_base": 1, "growth": 1.5,
	},
	{
		"id": "veteran", "name": "Veteran", "icon": "🏅",
		"desc": "Experience carries over between lives.",
		"effect": "+20% EXP per rank", "max": 15, "cost_base": 2, "growth": 1.55,
	},
	{
		"id": "vault", "name": "The Vault", "icon": "🏦",
		"desc": "Bank more of what the floor earns while you are logged out.",
		"effect": "+2h offline cap per rank", "max": 12, "cost_base": 3, "growth": 1.7,
	},
	{
		"id": "head_start", "name": "Head Start", "icon": "🚀",
		"desc": "Begin each new run with a fatter bankroll.",
		"effect": "x2 starting chips per rank", "max": 15, "cost_base": 2, "growth": 1.6,
	},
	{
		"id": "apprentice", "name": "Apprentice", "icon": "📘",
		"desc": "Start each run with skill points already banked.",
		"effect": "+1 starting skill point per rank", "max": 10, "cost_base": 8, "growth": 1.8,
	},
	{
		"id": "loaded_dice", "name": "Loaded Dice", "icon": "🎲",
		"desc": "Permanently tilt the odds in your favour.",
		"effect": "+0.4% RTP per rank", "max": 10, "cost_base": 4, "growth": 1.6,
	},
	{
		"id": "magnate", "name": "Magnate", "icon": "🏛️",
		"desc": "Buy property at scale.",
		"effect": "-3% property cost per rank", "max": 10, "cost_base": 6, "growth": 1.7,
	},
	{
		"id": "compound_interest", "name": "Compound Interest", "icon": "📈",
		"desc": "Walk away from each run with more gold chips.",
		"effect": "+5% gold chips on prestige per rank", "max": 20, "cost_base": 5, "growth": 1.45,
	},
	{
		"id": "free_floor", "name": "Grandfathered", "icon": "🗝️",
		"desc": "Keep a slice of your empire through the reset.",
		"effect": "+3 of each of the first 3 properties per rank",
		"max": 5, "cost_base": 12, "growth": 2.0,
	},
	# --- new prestige upgrades ---
	{
		"id": "silver_spoon", "name": "Silver Spoon", "icon": "🥄",
		"desc": "Born into a slightly better table.",
		"effect": "+15% starting chips per rank (stacks with Head Start)",
		"max": 10, "cost_base": 3, "growth": 1.5,
	},
	{
		"id": "time_lord", "name": "Time Lord", "icon": "⏳",
		"desc": "Offline earnings feel closer to being there.",
		"effect": "+4% offline efficiency per rank", "max": 10, "cost_base": 4, "growth": 1.55,
	},
	{
		"id": "house_edge", "name": "House Edge", "icon": "📉",
		"desc": "A permanent, tiny nudge on every table.",
		"effect": "+0.25% RTP per rank", "max": 8, "cost_base": 6, "growth": 1.65,
	},
]

var skill_levels: Dictionary = {}
var prestige_levels: Dictionary = {}


func skill_def(id: String) -> Dictionary:
	for d in SKILLS:
		if d["id"] == id:
			return d
	return {}


func prestige_def(id: String) -> Dictionary:
	for d in PRESTIGE:
		if d["id"] == id:
			return d
	return {}


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
