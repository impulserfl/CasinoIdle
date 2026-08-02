extends Node

## Per-table upgrades. Each minigame has ≥5 dedicated ranks bought with skill points.
## Wiped on prestige (same as Skills). Effects are intentionally soft so stacking
## every table cannot break the economy — RTP is still hard-capped globally.

signal changed()

## effect keys:
##   rtp     +0.25% effective RTP per rank (this table only)
##   exp     +8% EXP from this table per rank
##   speed   -6% animation time per rank
##   bet     +12% max-bet fraction per rank
##   fortune +1.5% loss-refund chance per rank
##   auto    -5% auto-spin delay per rank

const DEFS: Dictionary = {
	"slots": [
		_u("reel_tension", "Reel Tension", "🎰", "Smoother stops, slightly kinder odds.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("symbol_study", "Symbol Study", "📗", "You learn more from every spin.", "exp", "+8% EXP", 10, 1, 1),
		_u("fast_reels", "Fast Reels", "⚡", "Spins finish quicker.", "speed", "-6% spin time", 6, 1, 1),
		_u("high_limit_slots", "High Limit Slots", "💎", "Bigger allowed wagers.", "bet", "+12% max bet", 8, 1, 1),
		_u("near_miss", "Near-Miss Sympathy", "🍀", "More stake refunds on close losses.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"roulette": [
		_u("wheel_bias", "Wheel Bias", "🎡", "Tiny house-edge trim.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("croupier_notes", "Croupier Notes", "📝", "More EXP per spin.", "exp", "+8% EXP", 10, 1, 1),
		_u("quick_spin", "Quick Spin", "⏱️", "Faster wheel animations.", "speed", "-6% spin time", 6, 1, 1),
		_u("vip_chip", "VIP Chip Stack", "🪙", "Higher max bets.", "bet", "+12% max bet", 8, 1, 1),
		_u("zero_cushion", "Zero Cushion", "🟢", "Better refunds on bad spins.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"dice": [
		_u("loaded_feel", "Loaded Feel", "🎲", "Slightly friendlier dice.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("odds_tutor", "Odds Tutor", "📐", "More EXP from rolls.", "exp", "+8% EXP", 10, 1, 1),
		_u("snap_roll", "Snap Roll", "⚡", "Faster rolls.", "speed", "-6% anim", 6, 1, 1),
		_u("high_stakes_dice", "High Stakes Dice", "💰", "Raise the ceiling.", "bet", "+12% max bet", 8, 1, 1),
		_u("snake_shield", "Snake Shield", "🛡️", "Refund buffer on losses.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"scratch": [
		_u("lucky_ink", "Lucky Ink", "🎫", "Cards pay a bit more often.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("ticket_reader", "Ticket Reader", "🔍", "More EXP per card.", "exp", "+8% EXP", 10, 1, 1),
		_u("quick_scratch", "Quick Scratch", "✋", "Faster reveals.", "speed", "-6% anim", 6, 1, 1),
		_u("bulk_buy", "Bulk Buy", "📦", "Bigger card stakes.", "bet", "+12% max bet", 8, 1, 1),
		_u("consolation", "Consolation Prize", "🎁", "More near-miss refunds.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"higher_lower": [
		_u("card_sense", "Card Sense", "🃏", "Slight edge on the streak.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("memory_drill", "Memory Drill", "🧠", "More EXP per guess.", "exp", "+8% EXP", 10, 1, 1),
		_u("fast_deal_hl", "Fast Deal", "⚡", "Quicker flips.", "speed", "-6% anim", 6, 1, 1),
		_u("raise_ladder", "Raise the Ladder", "📈", "Higher max stake.", "bet", "+12% max bet", 8, 1, 1),
		_u("soft_land", "Soft Landing", "🪂", "Refund cushion.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"blackjack": [
		_u("basic_strategy", "Basic Strategy", "🂡", "Play closer to optimal.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("count_practice", "Count Practice", "🧮", "More EXP per hand.", "exp", "+8% EXP", 10, 1, 1),
		_u("fast_shoe", "Fast Shoe", "⏩", "Faster deals.", "speed", "-6% anim", 6, 1, 1),
		_u("table_min", "Table Minimum Up", "💵", "Higher max bet.", "bet", "+12% max bet", 8, 1, 1),
		_u("insurance_pro", "Insurance Pro", "🛡️", "Better loss refunds.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"plinko": [
		_u("peg_polish", "Peg Polish", "🔵", "Balls bounce your way a bit more.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("drop_study", "Drop Study", "📊", "More EXP per drop.", "exp", "+8% EXP", 10, 1, 1),
		_u("gravity_boost", "Gravity Boost", "⬇️", "Faster drops.", "speed", "-6% anim", 6, 1, 1),
		_u("multi_ball", "Multi-Ball Budget", "🟡", "Higher stakes.", "bet", "+12% max bet", 8, 1, 1),
		_u("side_pocket", "Side Pocket", "🧲", "Refund near-misses.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"coin_flip": [
		_u("weighted_feel", "Weighted Feel", "🪙", "Coin is a touch friendlier.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("call_practice", "Call Practice", "📣", "More EXP per flip.", "exp", "+8% EXP", 10, 1, 1),
		_u("flick_wrist", "Flick Wrist", "🖐️", "Faster flips.", "speed", "-6% anim", 6, 1, 1),
		_u("double_or", "Double-or Budget", "💰", "Higher max bet.", "bet", "+12% max bet", 8, 1, 1),
		_u("lucky_call", "Lucky Call", "✨", "Refund cushion.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"money_wheel": [
		_u("spoke_tune", "Spoke Tune", "🎯", "Wheel leans your way slightly.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("pointer_study", "Pointer Study", "📍", "More EXP per spin.", "exp", "+8% EXP", 10, 1, 1),
		_u("spin_up", "Spin Up", "🌪️", "Faster spins.", "speed", "-6% anim", 6, 1, 1),
		_u("grand_wheel", "Grand Wheel", "💎", "Higher stakes.", "bet", "+12% max bet", 8, 1, 1),
		_u("banker_pity", "Banker Pity", "🤝", "Refund buffer.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"crash": [
		_u("graph_edge", "Graph Edge", "📈", "Slightly better crash curve feel.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("chart_reader", "Chart Reader", "📉", "More EXP per round.", "exp", "+8% EXP", 10, 1, 1),
		_u("fast_tick", "Fast Tick", "⏱️", "Rounds resolve quicker.", "speed", "-6% anim", 6, 1, 1),
		_u("moon_bag", "Moon Bag", "🚀", "Higher max bet.", "bet", "+12% max bet", 8, 1, 1),
		_u("soft_crash", "Soft Crash", "🛟", "Refund cushion.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"keno": [
		_u("ball_bias", "Ball Bias", "🎱", "Draws a shade kinder.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("number_nerd", "Number Nerd", "🔢", "More EXP per draw.", "exp", "+8% EXP", 10, 1, 1),
		_u("rapid_draw", "Rapid Draw", "⚡", "Faster draws.", "speed", "-6% anim", 6, 1, 1),
		_u("multi_spot", "Multi-Spot Budget", "🎟️", "Higher stakes.", "bet", "+12% max bet", 8, 1, 1),
		_u("one_away", "One Away", "🤞", "Refund near-misses.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"baccarat": [
		_u("shoe_edge", "Shoe Edge", "🎴", "Tiny edge trim.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("pattern_watch", "Pattern Watch", "👁️", "More EXP per hand.", "exp", "+8% EXP", 10, 1, 1),
		_u("fast_deal_bacc", "Fast Deal", "⏩", "Quicker hands.", "speed", "-6% anim", 6, 1, 1),
		_u("salon_privé", "Salon Privé", "🥂", "Higher max bet.", "bet", "+12% max bet", 8, 1, 1),
		_u("tie_cushion", "Tie Cushion", "🪢", "Refund buffer.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"video_poker": [
		_u("hold_guide", "Hold Guide", "♠️", "Slightly better deals.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("hand_coach", "Hand Coach", "📚", "More EXP per hand.", "exp", "+8% EXP", 10, 1, 1),
		_u("fast_deal_vp", "Fast Deal", "⚡", "Quicker deals.", "speed", "-6% anim", 6, 1, 1),
		_u("max_credits", "Max Credits", "💳", "Higher stakes.", "bet", "+12% max bet", 8, 1, 1),
		_u("deuces_pity", "Deuces Pity", "🃏", "Refund cushion.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"war": [
		_u("rank_edge", "Rank Edge", "⚔️", "Slight card lean.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("war_drills", "War Drills", "🪖", "More EXP per bout.", "exp", "+8% EXP", 10, 1, 1),
		_u("fast_war", "Fast War", "⚡", "Quicker flips.", "speed", "-6% anim", 6, 1, 1),
		_u("ante_up", "Ante Up", "💰", "Higher max bet.", "bet", "+12% max bet", 8, 1, 1),
		_u("surrender", "Soft Surrender", "🏳️", "Refund buffer.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"coin_pusher": [
		_u("shelf_angle", "Shelf Angle", "🪙", "Coins fall your way more often.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("pusher_study", "Pusher Study", "📖", "More EXP per drop.", "exp", "+8% EXP", 10, 1, 1),
		_u("fast_drop", "Fast Drop", "⬇️", "Quicker cycles.", "speed", "-6% anim", 6, 1, 1),
		_u("coin_stack", "Coin Stack", "🏦", "Higher stakes.", "bet", "+12% max bet", 8, 1, 1),
		_u("ledge_save", "Ledge Save", "🧱", "Refund cushion.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"claw": [
		_u("grip_strength", "Grip Strength", "🦾", "Slightly better grabs.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("prize_guide", "Prize Guide", "🎁", "More EXP per try.", "exp", "+8% EXP", 10, 1, 1),
		_u("fast_arm", "Fast Arm", "⚡", "Quicker grabs.", "speed", "-6% anim", 6, 1, 1),
		_u("token_pile", "Token Pile", "🪙", "Higher stakes.", "bet", "+12% max bet", 8, 1, 1),
		_u("almost_had", "Almost Had It", "😅", "Refund near-misses.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"darts": [
		_u("steady_hand", "Steady Hand", "🎯", "Aim sticks a little better.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("pub_lessons", "Pub Lessons", "🍺", "More EXP per throw.", "exp", "+8% EXP", 10, 1, 1),
		_u("quick_throw", "Quick Throw", "💨", "Faster throws.", "speed", "-6% anim", 6, 1, 1),
		_u("match_stakes", "Match Stakes", "💷", "Higher max bet.", "bet", "+12% max bet", 8, 1, 1),
		_u("wire_save", "Wire Save", "🧵", "Refund cushion.", "fortune", "+1.5% refund", 6, 2, 1),
	],
	"fishing": [
		_u("bait_quality", "Bait Quality", "🪱", "Better bites.", "rtp", "+0.25% RTP", 8, 1, 1),
		_u("angler_log", "Angler Log", "📓", "More EXP per cast.", "exp", "+8% EXP", 10, 1, 1),
		_u("fast_reel", "Fast Reel", "🎣", "Quicker casts.", "speed", "-6% anim", 6, 1, 1),
		_u("charter_boat", "Charter Boat", "🚤", "Higher stakes.", "bet", "+12% max bet", 8, 1, 1),
		_u("catch_release", "Catch & Release", "🌊", "Refund cushion.", "fortune", "+1.5% refund", 6, 2, 1),
	],
}

## levels[game_id][upgrade_id] = rank
var levels: Dictionary = {}


static func _u(id: String, name: String, icon: String, desc: String, effect: String, effect_label: String, max_rank: int, cost_base: int, cost_step: int) -> Dictionary:
	return {
		"id": id, "name": name, "icon": icon, "desc": desc,
		"effect": effect, "effect_label": effect_label,
		"max": max_rank, "cost_base": cost_base, "cost_step": cost_step,
	}


func defs_for(game_id: String) -> Array:
	return DEFS.get(game_id, [])


func level(game_id: String, upgrade_id: String) -> int:
	var g: Dictionary = levels.get(game_id, {})
	return int(g.get(upgrade_id, 0))


func def_for(game_id: String, upgrade_id: String) -> Dictionary:
	for d in defs_for(game_id):
		if String(d["id"]) == upgrade_id:
			return d
	return {}


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
	if not levels.has(game_id):
		levels[game_id] = {}
	var g: Dictionary = levels[game_id]
	g[upgrade_id] = level(game_id, upgrade_id) + 1
	levels[game_id] = g
	changed.emit()
	AudioManager.play_buy()
	return true


func _sum_effect(game_id: String, effect: String) -> float:
	var total := 0.0
	for d in defs_for(game_id):
		if String(d["effect"]) != effect:
			continue
		total += float(level(game_id, String(d["id"])))
	return total


func rtp_bonus(game_id: String) -> float:
	return 0.0025 * _sum_effect(game_id, "rtp")


func exp_multiplier(game_id: String) -> float:
	return 1.0 + 0.08 * _sum_effect(game_id, "exp")


func speed_multiplier(game_id: String) -> float:
	return maxf(0.20, 1.0 - 0.06 * _sum_effect(game_id, "speed"))


func bet_multiplier(game_id: String) -> float:
	return 1.0 + 0.12 * _sum_effect(game_id, "bet")


func fortune_bonus(game_id: String) -> float:
	return 0.015 * _sum_effect(game_id, "fortune")


func auto_multiplier(game_id: String) -> float:
	return maxf(0.35, 1.0 - 0.05 * _sum_effect(game_id, "auto"))


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
