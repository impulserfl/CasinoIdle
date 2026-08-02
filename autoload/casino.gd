extends Node

## The idle layer: properties on your casino floor that earn chips every second
## from NPC patrons. This -- not gambling -- is where your money comes from.

signal changed()
signal purchased(id: String, count: int)

const GROWTH := 1.15
const BUY_AMOUNTS: Array[int] = [1, 10, 25, -1]

const GENERATORS: Array[Dictionary] = [
	{"id": "penny_slots",  "name": "Penny Slots",       "icon": "🎰", "cost": 50.0,      "rate": 0.8},
	{"id": "blackjack",    "name": "Blackjack Table",   "icon": "🂡", "cost": 650.0,     "rate": 6.0},
	{"id": "roulette",     "name": "Roulette Wheel",    "icon": "🎡", "cost": 8500.0,    "rate": 42.0},
	{"id": "poker",        "name": "Poker Room",        "icon": "♠️", "cost": 110000.0,  "rate": 290.0},
	{"id": "craps",        "name": "Craps Pit",         "icon": "🎲", "cost": 1.4e6,     "rate": 2100.0},
	{"id": "vip",          "name": "VIP Lounge",        "icon": "🥂", "cost": 2.0e7,     "rate": 16000.0},
	{"id": "sportsbook",   "name": "Sports Book",       "icon": "🏇", "cost": 3.2e8,     "rate": 140000.0},
	{"id": "highroller",   "name": "High-Roller Suite", "icon": "💼", "cost": 5.4e9,     "rate": 1.25e6},
	{"id": "sky",          "name": "Sky Casino",        "icon": "🌆", "cost": 9.2e10,    "rate": 1.15e7},
	{"id": "cruiser",      "name": "Casino Cruiser",    "icon": "🛳️", "cost": 1.6e12,    "rate": 1.05e8},
	{"id": "resort",       "name": "Island Resort",     "icon": "🏝️", "cost": 3.0e13,    "rate": 1.2e9},
	{"id": "orbital",      "name": "Orbital Casino",    "icon": "🛰️", "cost": 6.0e14,    "rate": 1.5e10},
]

var owned: Dictionary = {}


func generator_def(id: String) -> Dictionary:
	for d in GENERATORS:
		if d["id"] == id:
			return d
	return {}


func count(id: String) -> int:
	return int(owned.get(id, 0))


func total_properties() -> int:
	var n := 0
	for id in owned:
		n += int(owned[id])
	return n


func base_income() -> float:
	var total := 0.0
	for d in GENERATORS:
		total += float(count(String(d["id"]))) * float(d["rate"])
	return total


func income_per_second() -> float:
	return base_income() * GameManager.income_multiplier() * Events.income_event_multiplier()


func income_from(id: String) -> float:
	var d := generator_def(id)
	if d.is_empty():
		return 0.0
	return float(count(id)) * float(d["rate"]) * GameManager.income_multiplier() * Events.income_event_multiplier()


func _process(delta: float) -> void:
	var income := income_per_second()
	if income > 0.0:
		GameManager.add_chips(income * delta)


func cost_for(id: String, amount: int) -> float:
	var d := generator_def(id)
	if d.is_empty() or amount <= 0:
		return INF
	var base := float(d["cost"]) * (1.0 - GameManager.cost_discount())
	var start := pow(GROWTH, float(count(id)))
	return base * start * (pow(GROWTH, float(amount)) - 1.0) / (GROWTH - 1.0)


func max_affordable(id: String) -> int:
	var d := generator_def(id)
	if d.is_empty():
		return 0
	var base := float(d["cost"]) * (1.0 - GameManager.cost_discount())
	var unit := base * pow(GROWTH, float(count(id)))
	if unit <= 0.0:
		return 0
	var ratio := GameManager.chips * (GROWTH - 1.0) / unit + 1.0
	if ratio <= 1.0:
		return 0
	var n := int(floorf(log(ratio) / log(GROWTH)))
	return maxi(n, 0)


func resolve_amount(id: String, requested: int) -> int:
	if requested == -1:
		return maxi(max_affordable(id), 1)
	return requested


func can_afford(id: String, amount: int) -> bool:
	return GameManager.chips >= cost_for(id, amount)


func buy(id: String, amount: int) -> bool:
	var n := resolve_amount(id, amount)
	if n <= 0:
		return false
	var price := cost_for(id, n)
	if not GameManager.spend_chips(price):
		AudioManager.play_error()
		return false
	owned[id] = count(id) + n
	GameManager.stats["properties_bought"] = int(GameManager.stats.get("properties_bought", 0)) + n
	purchased.emit(id, n)
	changed.emit()
	AudioManager.play_buy()
	Achievements.check_all()
	return true


func is_unlocked(id: String) -> bool:
	var d := generator_def(id)
	if d.is_empty():
		return false
	if String(d["id"]) == String(GENERATORS[0]["id"]):
		return true
	if count(id) > 0:
		return true
	var lifetime := float(GameManager.stats.get("lifetime_chips_earned", 0.0))
	return lifetime >= float(d["cost"]) * 0.3


func unlocked_generators() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in GENERATORS:
		if is_unlocked(String(d["id"])):
			out.append(d)
	return out


func reset() -> void:
	owned.clear()
	changed.emit()


func grant_free_start(ranks: int) -> void:
	if ranks <= 0:
		return
	for i in range(mini(3, GENERATORS.size())):
		var id := String(GENERATORS[i]["id"])
		owned[id] = count(id) + 3 * ranks
	changed.emit()
