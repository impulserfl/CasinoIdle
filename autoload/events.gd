extends Node

## Daily bonus + Lucky Hour + rare Random Events.
##
## Random events:
##   - At least 12 unique event types
##   - Hard 45-minute cooldown between spawns (persists across sessions)
##   - Spawn is rare: only rolled while cooldown is clear, at a low rate

signal daily_changed()
signal lucky_hour_changed(active: bool, mult: float)
signal random_event_spawned(event: Dictionary)
signal random_event_resolved(event_id: String)
signal buff_changed()

const EVENT_COOLDOWN_SEC := 45.0 * 60.0  # 45 minutes
const SPAWN_CHECK_INTERVAL := 12.0       # seconds between rarity rolls
const SPAWN_CHANCE := 0.04              # 4% per check ≈ once ~5 min of active play after CD

## Timed buffs that stack from events (multipliers default 1.0).
var buff_income_mult: float = 1.0
var buff_exp_mult: float = 1.0
var buff_rtp_bonus: float = 0.0
var buff_remaining: float = 0.0
var buff_label: String = ""

var last_daily_day: int = -1
var daily_streak: int = 0
var lucky_hour_remaining: float = 0.0
var lucky_hour_mult: float = 1.0
var _lucky_cooldown: float = 0.0

## Unix time when the next random event is allowed to roll.
var event_ready_at: float = 0.0
var _spawn_check_timer: float = 0.0
## Pending unclaimed event (shown as a modal). Null/empty when none.
var pending_event: Dictionary = {}

## Catalog of rare floor events. Effects applied on claim.
const RANDOM_EVENTS: Array[Dictionary] = [
	{
		"id": "high_roller",
		"name": "High Roller Arrives",
		"icon": "🐋",
		"desc": "A whale drops a tip at the cage.",
		"weight": 12,
	},
	{
		"id": "slot_tournament",
		"name": "Slot Tournament",
		"icon": "🎰",
		"desc": "House runs a promo — temporary RTP bump.",
		"weight": 10,
	},
	{
		"id": "celebrity_guest",
		"name": "Celebrity Guest",
		"icon": "⭐",
		"desc": "Cameras everywhere. You learn faster for a while.",
		"weight": 10,
	},
	{
		"id": "comp_package",
		"name": "Comp Package",
		"icon": "🎫",
		"desc": "Loyalty desk slides you a free skill point.",
		"weight": 8,
	},
	{
		"id": "jackpot_fever",
		"name": "Jackpot Fever",
		"icon": "🔥",
		"desc": "Floor is packed. Passive income surges.",
		"weight": 10,
	},
	{
		"id": "mystery_drop",
		"name": "Mystery Drop",
		"icon": "🎁",
		"desc": "An unmarked envelope finds its way to you.",
		"weight": 11,
	},
	{
		"id": "vip_invite",
		"name": "VIP Invitation",
		"icon": "💠",
		"desc": "A soft gold-chip token from the VIP desk.",
		"weight": 6,
	},
	{
		"id": "floor_rush",
		"name": "Floor Rush",
		"icon": "🏃",
		"desc": "Every table is full. Short income burst.",
		"weight": 12,
	},
	{
		"id": "security_sweep",
		"name": "Security Sweep",
		"icon": "🛡️",
		"desc": "Caught a skimmer — house shares the recovery.",
		"weight": 9,
	},
	{
		"id": "lucky_dice",
		"name": "Lucky Dice Drop",
		"icon": "🎲",
		"desc": "Pit boss hands you a house chip stack.",
		"weight": 11,
	},
	{
		"id": "rainy_night",
		"name": "Rainy Night Crowd",
		"icon": "🌧️",
		"desc": "Tourists flood in from the storm.",
		"weight": 10,
	},
	{
		"id": "dealer_tip_pool",
		"name": "Dealer Tip Pool",
		"icon": "💵",
		"desc": "End-of-shift tip share hits your pocket.",
		"weight": 12,
	},
]


func _ready() -> void:
	# First session: allow an event after a short grace, not immediately.
	if event_ready_at <= 0.0:
		event_ready_at = Time.get_unix_time_from_system() + 300.0


func _process(delta: float) -> void:
	_tick_lucky_hour(delta)
	_tick_buff(delta)
	_tick_random_event(delta)


# ---------------------------------------------------------------------------
# Lucky Hour (kept, separate from rare events)
# ---------------------------------------------------------------------------

func _tick_lucky_hour(delta: float) -> void:
	if lucky_hour_remaining > 0.0:
		lucky_hour_remaining = maxf(lucky_hour_remaining - delta, 0.0)
		if lucky_hour_remaining <= 0.0:
			lucky_hour_mult = 1.0
			lucky_hour_changed.emit(false, 1.0)
			GameManager.notify_toast("Lucky Hour ended", UIKit.DIM)
	else:
		_lucky_cooldown = maxf(_lucky_cooldown - delta, 0.0)
		if _lucky_cooldown <= 0.0 and randf() < 0.0008:
			_start_lucky_hour()


func _start_lucky_hour() -> void:
	lucky_hour_mult = 1.5 + 0.1 * float(Upgrades.prestige_rank("party_planner"))
	lucky_hour_remaining = 90.0 + 30.0 * float(Upgrades.prestige_rank("party_planner"))
	_lucky_cooldown = 300.0
	lucky_hour_changed.emit(true, lucky_hour_mult)
	GameManager.notify_toast("🍀 LUCKY HOUR!  x%.1f income" % lucky_hour_mult, UIKit.GREEN)
	AudioManager.play_level_up()


func income_event_multiplier() -> float:
	var m := lucky_hour_mult if lucky_hour_remaining > 0.0 else 1.0
	m *= buff_income_mult if buff_remaining > 0.0 else 1.0
	return m


func exp_event_multiplier() -> float:
	return buff_exp_mult if buff_remaining > 0.0 else 1.0


func rtp_event_bonus() -> float:
	return buff_rtp_bonus if buff_remaining > 0.0 else 0.0


func _tick_buff(delta: float) -> void:
	if buff_remaining <= 0.0:
		return
	buff_remaining = maxf(buff_remaining - delta, 0.0)
	if buff_remaining <= 0.0:
		buff_income_mult = 1.0
		buff_exp_mult = 1.0
		buff_rtp_bonus = 0.0
		buff_label = ""
		buff_changed.emit()
		GameManager.notify_toast("Event buff ended", UIKit.DIM)


# ---------------------------------------------------------------------------
# Random events — rare + 45 min cooldown
# ---------------------------------------------------------------------------

func _tick_random_event(delta: float) -> void:
	# Never roll while an event is waiting to be claimed.
	if not pending_event.is_empty():
		return
	var now := Time.get_unix_time_from_system()
	if now < event_ready_at:
		return
	_spawn_check_timer += delta
	if _spawn_check_timer < SPAWN_CHECK_INTERVAL:
		return
	_spawn_check_timer = 0.0
	# Rare roll
	if randf() >= SPAWN_CHANCE:
		return
	_spawn_random_event()


func cooldown_remaining() -> float:
	return maxf(event_ready_at - Time.get_unix_time_from_system(), 0.0)


func is_event_pending() -> bool:
	return not pending_event.is_empty()


func _spawn_random_event() -> void:
	var entries: Array = []
	for e in RANDOM_EVENTS:
		entries.append([e, float(e["weight"])])
	var picked: Dictionary = _weighted_pick(entries)
	pending_event = picked.duplicate(true)
	# Start the hard cooldown the moment it spawns (claiming does not refresh it).
	event_ready_at = Time.get_unix_time_from_system() + EVENT_COOLDOWN_SEC
	random_event_spawned.emit(pending_event)
	GameManager.notify_toast("%s  %s!" % [picked["icon"], picked["name"]], UIKit.ORANGE)
	AudioManager.play_level_up()


func claim_pending_event() -> void:
	if pending_event.is_empty():
		return
	var id := String(pending_event.get("id", ""))
	_apply_event(id)
	var claimed := pending_event.duplicate(true)
	pending_event = {}
	random_event_resolved.emit(id)
	AudioManager.play_win(2.5)


func dismiss_pending_event() -> void:
	## Still consumes the event; cooldown already started on spawn.
	if pending_event.is_empty():
		return
	var id := String(pending_event.get("id", ""))
	pending_event = {}
	random_event_resolved.emit(id)
	GameManager.notify_toast("Event passed by", UIKit.DIM)


func _apply_event(id: String) -> void:
	var income := maxf(Casino.income_per_second(), 1.0)
	match id:
		"high_roller":
			var amt := floorf(income * 120.0 + 500.0)
			GameManager.add_chips(amt)
			GameManager.notify_toast("🐋 High roller tipped +%s" % Fmt.chips(amt), UIKit.GOLD)
		"slot_tournament":
			_set_buff("Slot Tournament", 180.0, 1.0, 1.0, 0.02)
			GameManager.notify_toast("🎰 +2% RTP for 3 minutes", UIKit.GREEN)
		"celebrity_guest":
			_set_buff("Celebrity Guest", 240.0, 1.0, 1.5, 0.0)
			GameManager.notify_toast("⭐ +50% EXP for 4 minutes", UIKit.BLUE)
		"comp_package":
			GameManager.grant_skill_points(1)
			GameManager.notify_toast("🎫 Comp package: +1 skill point", UIKit.CYAN)
		"jackpot_fever":
			_set_buff("Jackpot Fever", 150.0, 2.0, 1.0, 0.0)
			GameManager.notify_toast("🔥 x2 floor income for 2.5 minutes", UIKit.ORANGE)
		"mystery_drop":
			var roll := randi() % 3
			if roll == 0:
				var amt := floorf(income * 90.0 + 300.0)
				GameManager.add_chips(amt)
				GameManager.notify_toast("🎁 Mystery: +%s chips" % Fmt.chips(amt), UIKit.GOLD)
			elif roll == 1:
				GameManager.grant_skill_points(1)
				GameManager.notify_toast("🎁 Mystery: +1 skill point", UIKit.CYAN)
			else:
				_set_buff("Mystery Buzz", 120.0, 1.4, 1.2, 0.0)
				GameManager.notify_toast("🎁 Mystery: short income + EXP buff", UIKit.GREEN)
		"vip_invite":
			var gold := 1.0 + float(GameManager.prestige_count) * 0.25
			gold = floorf(gold)
			GameManager.add_gold_chips(maxf(gold, 1.0))
			GameManager.notify_toast("💠 VIP token: +%s gold chips" % Fmt.chips(gold), UIKit.PURPLE)
		"floor_rush":
			var amt := floorf(income * 60.0 + 200.0)
			GameManager.add_chips(amt)
			_set_buff("Floor Rush", 90.0, 1.75, 1.0, 0.0)
			GameManager.notify_toast("🏃 Rush payout +%s and x1.75 income" % Fmt.chips(amt), UIKit.GREEN)
		"security_sweep":
			var amt := floorf(income * 100.0 + 400.0)
			GameManager.add_chips(amt)
			GameManager.notify_toast("🛡️ Recovery share +%s" % Fmt.chips(amt), UIKit.GOLD)
		"lucky_dice":
			var amt := floorf(250.0 + GameManager.chips * 0.03)
			amt = minf(amt, income * 200.0 + 2000.0)
			GameManager.add_chips(floorf(amt))
			GameManager.notify_toast("🎲 Lucky dice +%s" % Fmt.chips(amt), UIKit.GOLD)
		"rainy_night":
			_set_buff("Rainy Night", 200.0, 1.6, 1.15, 0.0)
			GameManager.notify_toast("🌧️ Crowded floor buff for ~3 minutes", UIKit.BLUE)
		"dealer_tip_pool":
			var amt := floorf(income * 80.0 + 350.0)
			GameManager.add_chips(amt)
			GameManager.notify_toast("💵 Tip pool +%s" % Fmt.chips(amt), UIKit.GOLD)
		_:
			GameManager.add_chips(100.0)
			GameManager.notify_toast("Event reward +100", UIKit.GOLD)


func _set_buff(label: String, duration: float, income_m: float, exp_m: float, rtp: float) -> void:
	buff_label = label
	buff_remaining = duration
	buff_income_mult = income_m
	buff_exp_mult = exp_m
	buff_rtp_bonus = rtp
	buff_changed.emit()


func _weighted_pick(entries: Array) -> Dictionary:
	var total := 0.0
	for e in entries:
		total += float(e[1])
	var roll := randf() * total
	for e in entries:
		roll -= float(e[1])
		if roll <= 0.0:
			return e[0]
	return entries[entries.size() - 1][0]


# ---------------------------------------------------------------------------
# Daily
# ---------------------------------------------------------------------------

func _day_id() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func can_claim_daily() -> bool:
	return last_daily_day != _day_id()


func daily_reward_amount() -> float:
	var base := 200.0 + 150.0 * float(daily_streak)
	base *= 1.0 + 0.15 * float(Upgrades.prestige_rank("daily_whale"))
	base *= 1.0 + 0.05 * float(GameManager.prestige_count)
	return floorf(base)


func claim_daily() -> float:
	if not can_claim_daily():
		return 0.0
	var today := _day_id()
	if last_daily_day == today - 1:
		daily_streak += 1
	else:
		daily_streak = 1
	last_daily_day = today
	var amount := daily_reward_amount()
	GameManager.add_chips(amount)
	daily_changed.emit()
	GameManager.notify_toast("Daily bonus!  +%s chips  (streak %d)" % [Fmt.chips(amount), daily_streak], UIKit.GOLD)
	AudioManager.play_win(3.0)
	Achievements.notify("daily_claim")
	return amount


func to_dict() -> Dictionary:
	return {
		"last_daily_day": last_daily_day,
		"daily_streak": daily_streak,
		"event_ready_at": event_ready_at,
		"pending_event": pending_event,
	}


func from_dict(data: Dictionary) -> void:
	last_daily_day = int(data.get("last_daily_day", -1))
	daily_streak = int(data.get("daily_streak", 0))
	event_ready_at = float(data.get("event_ready_at", 0.0))
	var pe = data.get("pending_event", {})
	pending_event = pe if pe is Dictionary else {}
	if event_ready_at <= 0.0:
		event_ready_at = Time.get_unix_time_from_system() + 300.0
	daily_changed.emit()
