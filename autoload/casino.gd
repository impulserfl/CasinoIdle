extends Node

## The idle layer: properties earn chips every second. This is the only source
## of chips in the game — the tables convert chips into EXP and jackpots at a
## known, verified loss.

signal changed()
signal purchased(id: String, count: int)

## Steeper than the classic 1.15. The floor used to compound so fast that a
## first prestige landed inside two minutes; the cost curve, not the prestige
## requirement, is what actually governs that.
const BASE_GROWTH := 1.22
const MIN_GROWTH := 1.10
const BUY_AMOUNTS: Array[int] = [1, 10, 25, -1]

const GENERATORS: Array[Dictionary] = [
	{"id": "penny_slots", "name": "Penny Slots",       "icon": "prop_pennyslots",  "cost": 20.0,    "rate": 1.0},
	{"id": "blackjack",   "name": "Blackjack Table",   "icon": "prop_blackjack",   "cost": 180.0,   "rate": 6.5},
	{"id": "roulette",    "name": "Roulette Wheel",    "icon": "prop_roulette",    "cost": 1600.0,  "rate": 42.0},
	{"id": "poker",       "name": "Poker Room",        "icon": "prop_poker",       "cost": 15000.0, "rate": 285.0},
	{"id": "craps",       "name": "Craps Pit",         "icon": "prop_craps",       "cost": 130000.0, "rate": 1750.0},
	{"id": "vip",         "name": "VIP Lounge",        "icon": "prop_vip",         "cost": 1.2e6,   "rate": 11500.0},
	{"id": "sportsbook",  "name": "Sports Book",       "icon": "prop_sportsbook",  "cost": 1.1e7,   "rate": 75000.0},
	{"id": "highroller",  "name": "High-Roller Suite", "icon": "prop_highroller",  "cost": 1.0e8,   "rate": 4.9e5},
	{"id": "sky",         "name": "Sky Casino",        "icon": "prop_sky",         "cost": 9.5e8,   "rate": 3.3e6},
	{"id": "cruiser",     "name": "Casino Cruiser",    "icon": "prop_cruiser",     "cost": 9.0e9,   "rate": 2.2e7},
	{"id": "resort",      "name": "Island Resort",     "icon": "prop_resort",      "cost": 8.5e10,  "rate": 1.5e8},
	{"id": "orbital",     "name": "Orbital Casino",    "icon": "prop_orbital",     "cost": 8.0e11,  "rate": 1.0e9},
]

var owned: Dictionary = {}
var _index: Dictionary = {}


func _ready() -> void:
	for d in GENERATORS:
		_index[String(d["id"])] = d
	call_deferred("_ensure_starter")


func _ensure_starter() -> void:
	if total_properties() == 0 and GameManager.prestige_count == 0:
		owned["penny_slots"] = 1
		changed.emit()


func generator_def(id: String) -> Dictionary:
	return _index.get(id, {})


func count(id: String) -> int:
	return int(owned.get(id, 0))


func total_properties() -> int:
	var n := 0
	for id in owned:
		n += int(owned[id])
	return n


## The Architect prestige rank flattens the cost curve slightly. It is the
## single most powerful upgrade in the game, which is why it is capped at 6 and
## priced accordingly.
func growth() -> float:
	return maxf(MIN_GROWTH, BASE_GROWTH - 0.002 * float(Upgrades.prestige_rank("architect")))


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
	return float(count(id)) * float(d["rate"]) * GameManager.income_multiplier() \
		* Events.income_event_multiplier()


func _process(delta: float) -> void:
	var income := income_per_second()
	if income > 0.0:
		GameManager.add_chips(income * delta)


func cost_for(id: String, amount: int) -> float:
	var d := generator_def(id)
	if d.is_empty() or amount <= 0:
		return INF
	var g := growth()
	var base := float(d["cost"]) * (1.0 - GameManager.cost_discount())
	var start := pow(g, float(count(id)))
	return base * start * (pow(g, float(amount)) - 1.0) / (g - 1.0)


func max_affordable(id: String) -> int:
	var d := generator_def(id)
	if d.is_empty():
		return 0
	var g := growth()
	var base := float(d["cost"]) * (1.0 - GameManager.cost_discount())
	var unit := base * pow(g, float(count(id)))
	if unit <= 0.0:
		return 0
	var ratio := GameManager.chips * (g - 1.0) / unit + 1.0
	if ratio <= 1.0:
		return 0
	return maxi(int(floorf(log(ratio) / log(g))), 0)


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


## Seconds for one more unit to pay for itself at the current multiplier.
func payback_seconds(id: String, amount: int) -> float:
	var d := generator_def(id)
	if d.is_empty() or amount <= 0:
		return 0.0
	var rate := float(d["rate"]) * float(amount) * GameManager.income_multiplier()
	if rate <= 0.0:
		return 0.0
	return cost_for(id, amount) / rate


func is_unlocked(id: String) -> bool:
	var d := generator_def(id)
	if d.is_empty():
		return false
	if id == String(GENERATORS[0]["id"]) or count(id) > 0:
		return true
	return float(GameManager.stats.get("lifetime_chips_earned", 0.0)) >= float(d["cost"]) * 0.15


func unlocked_generators() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in GENERATORS:
		if is_unlocked(String(d["id"])):
			out.append(d)
	return out


## The next locked tier and how close the player is to seeing it, so the floor
## panel can show something to aim at instead of just ending.
func next_locked() -> Dictionary:
	for d in GENERATORS:
		if not is_unlocked(String(d["id"])):
			var need := float(d["cost"]) * 0.15
			var have := float(GameManager.stats.get("lifetime_chips_earned", 0.0))
			return {"def": d, "need": need, "progress": clampf(have / maxf(need, 1.0), 0.0, 1.0)}
	return {}


func reset() -> void:
	owned.clear()
	owned["penny_slots"] = 1
	changed.emit()


func grant_free_start(ranks: int) -> void:
	if ranks <= 0:
		return
	for i in range(mini(3, GENERATORS.size())):
		var id := String(GENERATORS[i]["id"])
		owned[id] = count(id) + 3 * ranks
	changed.emit()
