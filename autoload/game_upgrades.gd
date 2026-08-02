extends Node

## Per-table upgrades. Every table has six, bought with skill points.
## Wiped on prestige, exactly like the skill tree.
##
## Only the `rtp` archetype can move a table's returns, and it feeds the same
## capped budget as every other RTP source (see Minigame.rtp_budget). The old
## `fortune` archetype used to add refund chance *outside* that cap, which put
## every table over 100% RTP once it was maxed; it is now `solace`, which pays
## in EXP instead of chips and therefore cannot break the economy.

signal changed()

## Archetype -> tuning. Shared by all eighteen tables so a rank always means
## the same thing no matter which table bought it.
const EFFECTS: Dictionary = {
	"rtp":    {"max": 8,  "cost_base": 1, "cost_step": 1, "label": "+0.25% table RTP"},
	"exp":    {"max": 10, "cost_base": 1, "cost_step": 1, "label": "+8% EXP here"},
	"speed":  {"max": 6,  "cost_base": 1, "cost_step": 1, "label": "-6% round time"},
	"bet":    {"max": 8,  "cost_base": 1, "cost_step": 1, "label": "+12% max bet"},
	"solace": {"max": 6,  "cost_base": 2, "cost_step": 1, "label": "+18% EXP when you lose"},
	"auto":   {"max": 6,  "cost_base": 2, "cost_step": 1, "label": "-5% auto-play delay"},
}

const RTP_PER_RANK := 0.0025
const EXP_PER_RANK := 0.08
const SPEED_PER_RANK := 0.06
const BET_PER_RANK := 0.12
const SOLACE_PER_RANK := 0.18
const AUTO_PER_RANK := 0.05

## game_id -> [[id, display name, icon, archetype], ...]
## The ids are load-bearing: they are what lives in save files, so they keep
## their original spelling even where the display name has moved on.
const TABLE_UPGRADES: Dictionary = {
	"slots": [
		["reel_tension", "Reel Tension", "reel_bar", "rtp"],
		["symbol_study", "Symbol Study", "exp", "exp"],
		["fast_reels", "Fast Reels", "bolt", "speed"],
		["high_limit_slots", "High Limit Slots", "chip_gold", "bet"],
		["near_miss", "Near-Miss Sympathy", "moon", "solace"],
		["reel_rhythm", "Reel Rhythm", "clock", "auto"],
	],
	"roulette": [
		["wheel_bias", "Wheel Bias", "game_roulette", "rtp"],
		["croupier_notes", "Croupier Notes", "exp", "exp"],
		["quick_spin", "Quick Spin", "bolt", "speed"],
		["vip_chip", "VIP Chip Stack", "chip_gold", "bet"],
		["zero_cushion", "Zero Cushion", "moon", "solace"],
		["rapid_croupier", "Rapid Croupier", "clock", "auto"],
	],
	"dice": [
		["loaded_feel", "Loaded Feel", "game_dice", "rtp"],
		["odds_tutor", "Odds Tutor", "exp", "exp"],
		["snap_roll", "Snap Roll", "bolt", "speed"],
		["high_stakes_dice", "High Stakes Dice", "chip_gold", "bet"],
		["snake_shield", "Snake Shield", "moon", "solace"],
		["dice_drill", "Dice Drill", "clock", "auto"],
	],
	"scratch": [
		["lucky_ink", "Lucky Ink", "game_scratch", "rtp"],
		["ticket_reader", "Ticket Reader", "exp", "exp"],
		["quick_scratch", "Quick Scratch", "bolt", "speed"],
		["bulk_buy", "Bulk Buy", "chip_gold", "bet"],
		["consolation", "Consolation Prize", "moon", "solace"],
		["book_of_tickets", "Book of Tickets", "clock", "auto"],
	],
	"higher_lower": [
		["card_sense", "Card Sense", "suit_spade", "rtp"],
		["memory_drill", "Memory Drill", "exp", "exp"],
		["fast_deal_hl", "Fast Deal", "bolt", "speed"],
		["raise_ladder", "Raise the Ladder", "chip_gold", "bet"],
		["soft_land", "Soft Landing", "moon", "solace"],
		["quick_cut", "Quick Cut", "clock", "auto"],
	],
	"blackjack": [
		["basic_strategy", "Basic Strategy", "suit_spade", "rtp"],
		["count_practice", "Count Practice", "exp", "exp"],
		["fast_shoe", "Fast Shoe", "bolt", "speed"],
		["table_min", "Table Minimum Up", "chip_gold", "bet"],
		["insurance_pro", "Insurance Pro", "moon", "solace"],
		["auto_shuffler", "Auto Shuffler", "clock", "auto"],
	],
	"plinko": [
		["peg_polish", "Peg Polish", "ball", "rtp"],
		["drop_study", "Drop Study", "exp", "exp"],
		["gravity_boost", "Gravity Boost", "bolt", "speed"],
		["multi_ball", "Multi-Ball Budget", "chip_gold", "bet"],
		["side_pocket", "Side Pocket", "moon", "solace"],
		["ball_feeder", "Ball Feeder", "clock", "auto"],
	],
	"coin_flip": [
		["weighted_feel", "Weighted Feel", "chip_gold", "rtp"],
		["call_practice", "Call Practice", "exp", "exp"],
		["flick_wrist", "Flick of the Wrist", "bolt", "speed"],
		["double_or", "Double-or Budget", "chip", "bet"],
		["lucky_call", "Lucky Call", "moon", "solace"],
		["fast_hands", "Fast Hands", "clock", "auto"],
	],
	"money_wheel": [
		["spoke_tune", "Spoke Tune", "game_wheel", "rtp"],
		["pointer_study", "Pointer Study", "exp", "exp"],
		["spin_up", "Spin Up", "bolt", "speed"],
		["grand_wheel", "Grand Wheel", "chip_gold", "bet"],
		["banker_pity", "Banker's Pity", "moon", "solace"],
		["wheel_servo", "Wheel Servo", "clock", "auto"],
	],
	"crash": [
		["graph_edge", "Graph Edge", "game_crash", "rtp"],
		["chart_reader", "Chart Reader", "exp", "exp"],
		["fast_tick", "Fast Tick", "bolt", "speed"],
		["moon_bag", "Moon Bag", "chip_gold", "bet"],
		["soft_crash", "Soft Crash", "moon", "solace"],
		["auto_cashout", "Auto Cash-Out", "clock", "auto"],
	],
	"keno": [
		["ball_bias", "Ball Bias", "game_keno", "rtp"],
		["number_nerd", "Number Nerd", "exp", "exp"],
		["rapid_draw", "Rapid Draw", "bolt", "speed"],
		["multi_spot", "Multi-Spot Budget", "chip_gold", "bet"],
		["one_away", "One Away", "moon", "solace"],
		["draw_machine", "Draw Machine", "clock", "auto"],
	],
	"baccarat": [
		["shoe_edge", "Shoe Edge", "suit_diamond", "rtp"],
		["pattern_watch", "Pattern Watch", "exp", "exp"],
		["fast_deal_bacc", "Fast Deal", "bolt", "speed"],
		["salon_prive", "Salon Prive", "chip_gold", "bet"],
		["tie_cushion", "Tie Cushion", "moon", "solace"],
		["shoe_loader", "Shoe Loader", "clock", "auto"],
	],
	"video_poker": [
		["hold_guide", "Hold Guide", "suit_club", "rtp"],
		["hand_coach", "Hand Coach", "exp", "exp"],
		["fast_deal_vp", "Fast Deal", "bolt", "speed"],
		["max_credits", "Max Credits", "chip_gold", "bet"],
		["deuces_pity", "Deuces Pity", "moon", "solace"],
		["quick_hold", "Quick Hold", "clock", "auto"],
	],
	"war": [
		["rank_edge", "Rank Edge", "game_war", "rtp"],
		["war_drills", "War Drills", "exp", "exp"],
		["fast_war", "Fast War", "bolt", "speed"],
		["ante_up", "Ante Up", "chip_gold", "bet"],
		["surrender", "Soft Surrender", "moon", "solace"],
		["field_promo", "Field Promotion", "clock", "auto"],
	],
	"coin_pusher": [
		["shelf_angle", "Shelf Angle", "game_pusher", "rtp"],
		["pusher_study", "Pusher Study", "exp", "exp"],
		["fast_drop", "Fast Drop", "bolt", "speed"],
		["coin_stack", "Coin Stack", "chip_gold", "bet"],
		["ledge_save", "Ledge Save", "moon", "solace"],
		["hopper_feed", "Hopper Feed", "clock", "auto"],
	],
	"claw": [
		["grip_strength", "Grip Strength", "game_claw", "rtp"],
		["prize_guide", "Prize Guide", "exp", "exp"],
		["fast_arm", "Fast Arm", "bolt", "speed"],
		["token_pile", "Token Pile", "chip_gold", "bet"],
		["almost_had", "Almost Had It", "moon", "solace"],
		["arm_servo", "Arm Servo", "clock", "auto"],
	],
	"darts": [
		["steady_hand", "Steady Hand", "target", "rtp"],
		["pub_lessons", "Pub Lessons", "exp", "exp"],
		["quick_throw", "Quick Throw", "bolt", "speed"],
		["match_stakes", "Match Stakes", "chip_gold", "bet"],
		["wire_save", "Wire Save", "moon", "solace"],
		["oche_rhythm", "Oche Rhythm", "clock", "auto"],
	],
	"fishing": [
		["bait_quality", "Bait Quality", "game_fishing", "rtp"],
		["angler_log", "Angler's Log", "exp", "exp"],
		["fast_reel", "Fast Reel", "bolt", "speed"],
		["charter_boat", "Charter Boat", "chip_gold", "bet"],
		["catch_release", "Catch & Release", "moon", "solace"],
		["second_rod", "Second Rod", "clock", "auto"],
	],
}

var levels: Dictionary = {}
var _defs_cache: Dictionary = {}


func defs_for(game_id: String) -> Array:
	if _defs_cache.has(game_id):
		return _defs_cache[game_id]
	var rows: Array = TABLE_UPGRADES.get(game_id, [])
	var out: Array = []
	for row in rows:
		var archetype := String(row[3])
		var eff: Dictionary = EFFECTS[archetype]
		out.append({
			"id": String(row[0]),
			"name": String(row[1]),
			"icon": String(row[2]),
			"effect": archetype,
			"effect_label": String(eff["label"]),
			"max": int(eff["max"]),
			"cost_base": int(eff["cost_base"]),
			"cost_step": int(eff["cost_step"]),
		})
	_defs_cache[game_id] = out
	return out


func def_for(game_id: String, upgrade_id: String) -> Dictionary:
	for d in defs_for(game_id):
		if String(d["id"]) == upgrade_id:
			return d
	return {}


func level(game_id: String, upgrade_id: String) -> int:
	var g: Dictionary = levels.get(game_id, {})
	return int(g.get(upgrade_id, 0))


func cost(game_id: String, upgrade_id: String) -> int:
	var d := def_for(game_id, upgrade_id)
	if d.is_empty():
		return 0
	return int(d["cost_base"]) + int(d["cost_step"]) * level(game_id, upgrade_id)


func maxed(game_id: String, upgrade_id: String) -> bool:
	var d := def_for(game_id, upgrade_id)
	return not d.is_empty() and level(game_id, upgrade_id) >= int(d["max"])


func can_buy(game_id: String, upgrade_id: String) -> bool:
	return not maxed(game_id, upgrade_id) and GameManager.skill_points >= cost(game_id, upgrade_id)


func buy(game_id: String, upgrade_id: String) -> bool:
	if not can_buy(game_id, upgrade_id):
		return false
	if not GameManager.spend_skill_points(cost(game_id, upgrade_id)):
		return false
	var g: Dictionary = levels.get(game_id, {})
	g[upgrade_id] = level(game_id, upgrade_id) + 1
	levels[game_id] = g
	changed.emit()
	AudioManager.play_buy()
	return true


func _sum(game_id: String, archetype: String) -> float:
	var total := 0.0
	for d in defs_for(game_id):
		if String(d["effect"]) == archetype:
			total += float(level(game_id, String(d["id"])))
	return total


func rtp_bonus(game_id: String) -> float:
	return RTP_PER_RANK * _sum(game_id, "rtp")


func exp_multiplier(game_id: String) -> float:
	return 1.0 + EXP_PER_RANK * _sum(game_id, "exp")


func speed_multiplier(game_id: String) -> float:
	return maxf(0.20, 1.0 - SPEED_PER_RANK * _sum(game_id, "speed"))


func bet_multiplier(game_id: String) -> float:
	return 1.0 + BET_PER_RANK * _sum(game_id, "bet")


## Share of a round's EXP handed back when the round loses. Pays in EXP, never
## chips, so it can never lift a table's RTP.
func solace_bonus(game_id: String) -> float:
	return SOLACE_PER_RANK * _sum(game_id, "solace")


func auto_multiplier(game_id: String) -> float:
	return maxf(0.35, 1.0 - AUTO_PER_RANK * _sum(game_id, "auto"))


func ranks_in(game_id: String) -> int:
	var n := 0
	var g: Dictionary = levels.get(game_id, {})
	for id in g:
		n += int(g[id])
	return n


func total_ranks() -> int:
	var n := 0
	for g in levels:
		var d: Dictionary = levels[g]
		for id in d:
			n += int(d[id])
	return n


func reset() -> void:
	levels.clear()
	changed.emit()
