extends Node

## Daily bonus, Lucky Hours and rare floor events.
##
## Events pay in chips and buffs. The only one that can touch table returns is
## the Slot Tournament RTP buff, and it feeds GameManager.rtp_bonus(), which
## Minigame clamps like every other source.

signal daily_changed()
signal lucky_hour_changed(active: bool, mult: float)
signal random_event_spawned(event: Dictionary)
signal random_event_resolved(event_id: String)
signal buff_changed()

const EVENT_COOLDOWN_SEC := 45.0 * 60.0
const SPAWN_CHECK_INTERVAL := 12.0
const SPAWN_CHANCE := 0.04
const LUCKY_HOUR_CHANCE := 0.0008
const LUCKY_HOUR_COOLDOWN := 300.0

var buff_income_mult: float = 1.0
var buff_exp_mult: float = 1.0
var buff_rtp_bonus: float = 0.0
var buff_remaining: float = 0.0
var buff_label: String = ""

var last_daily_day: int = -1
var daily_streak: int = 0
var lucky_hour_remaining: float = 0.0
var lucky_hour_mult: float = 1.0

var event_ready_at: float = 0.0
var pending_event: Dictionary = {}

var _lucky_cooldown: float = 0.0
var _spawn_check_timer: float = 0.0

const RANDOM_EVENTS: Array[Dictionary] = [
	{"id": "high_roller", "name": "High Roller Arrives", "icon": "prop_highroller",
		"desc": "A whale drops a tip at the cage.", "weight": 12},
	{"id": "slot_tournament", "name": "Slot Tournament", "icon": "game_slots",
		"desc": "The house runs a promo. Every table pays a little better for a while.", "weight": 10},
	{"id": "celebrity_guest", "name": "Celebrity Guest", "icon": "reel_star",
		"desc": "Cameras everywhere. You learn faster with an audience.", "weight": 10},
	{"id": "comp_package", "name": "Comp Package", "icon": "gift",
		"desc": "The loyalty desk slides you a free skill point.", "weight": 8},
	{"id": "jackpot_fever", "name": "Jackpot Fever", "icon": "flame",
		"desc": "The floor is packed and the tills are singing.", "weight": 10},
	{"id": "mystery_drop", "name": "Mystery Drop", "icon": "gift",
		"desc": "An unmarked envelope finds its way to you.", "weight": 11},
	{"id": "vip_invite", "name": "VIP Invitation", "icon": "chip_gold",
		"desc": "A gold token from the VIP desk.", "weight": 6},
	{"id": "floor_rush", "name": "Floor Rush", "icon": "bolt",
		"desc": "Every table is full and the queue is out the door.", "weight": 12},
	{"id": "security_sweep", "name": "Security Sweep", "icon": "lock",
		"desc": "You caught a skimmer. The house shares the recovery.", "weight": 9},
	{"id": "lucky_dice", "name": "Lucky Dice Drop", "icon": "game_dice",
		"desc": "The pit boss hands you a house chip stack.", "weight": 11},
	{"id": "rainy_night", "name": "Rainy Night Crowd", "icon": "moon",
		"desc": "Tourists flood in out of the storm.", "weight": 10},
	{"id": "dealer_tip_pool", "name": "Dealer Tip Pool", "icon": "chip",
		"desc": "The end of shift tip share lands in your pocket.", "weight": 12},
]


func _ready() -> void:
	if event_ready_at <= 0.0:
		event_ready_at = Time.get_unix_time_from_system() + 300.0


func _process(delta: float) -> void:
	_tick_lucky_hour(delta)
	_tick_buff(delta)
	_tick_random_event(delta)


func _notify(text: String, color: Color, icon: String) -> void:
	if Settings.toast_event:
		GameManager.notify_toast(text, color, icon)


# --- Lucky Hour ------------------------------------------------------------

func _tick_lucky_hour(delta: float) -> void:
	if lucky_hour_remaining > 0.0:
		lucky_hour_remaining = maxf(lucky_hour_remaining - delta, 0.0)
		if lucky_hour_remaining <= 0.0:
			lucky_hour_mult = 1.0
			lucky_hour_changed.emit(false, 1.0)
			_notify("Lucky Hour has ended", UIKit.DIM, "clock")
	else:
		_lucky_cooldown = maxf(_lucky_cooldown - delta, 0.0)
		if _lucky_cooldown <= 0.0 and randf() < LUCKY_HOUR_CHANCE:
			_start_lucky_hour()


func _start_lucky_hour() -> void:
	var ranks := float(Upgrades.prestige_rank("party_planner"))
	lucky_hour_mult = 1.5 + 0.1 * ranks
	lucky_hour_remaining = (90.0 + 30.0 * ranks) * GameManager.buff_duration_multiplier()
	_lucky_cooldown = LUCKY_HOUR_COOLDOWN
	lucky_hour_changed.emit(true, lucky_hour_mult)
	_notify("Lucky Hour!  x%.1f floor income" % lucky_hour_mult, UIKit.GREEN, "flame")
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
		_notify("Event buff has ended", UIKit.DIM, "clock")


func _set_buff(label: String, duration: float, income_m: float, exp_m: float, rtp: float) -> void:
	buff_label = label
	buff_remaining = duration * GameManager.buff_duration_multiplier()
	buff_income_mult = income_m
	buff_exp_mult = exp_m
	buff_rtp_bonus = rtp
	buff_changed.emit()


# --- rare floor events -----------------------------------------------------

func _tick_random_event(delta: float) -> void:
	if not pending_event.is_empty():
		return
	if Time.get_unix_time_from_system() < event_ready_at:
		return
	_spawn_check_timer += delta
	if _spawn_check_timer < SPAWN_CHECK_INTERVAL:
		return
	_spawn_check_timer = 0.0
	if randf() >= SPAWN_CHANCE:
		return
	_spawn_random_event()


func cooldown_remaining() -> float:
	return maxf(event_ready_at - Time.get_unix_time_from_system(), 0.0)


func cooldown_length() -> float:
	return EVENT_COOLDOWN_SEC * GameManager.event_cooldown_multiplier()


func is_event_pending() -> bool:
	return not pending_event.is_empty()


func _spawn_random_event() -> void:
	var entries: Array = []
	for e in RANDOM_EVENTS:
		entries.append([e, float(e["weight"])])
	var picked: Dictionary = _weighted_pick(entries)
	pending_event = picked.duplicate(true)
	# The cooldown starts the moment it spawns; claiming does not refresh it.
	event_ready_at = Time.get_unix_time_from_system() + cooldown_length()
	random_event_spawned.emit(pending_event)
	_notify(String(picked["name"]), UIKit.ORANGE, String(picked["icon"]))
	AudioManager.play_level_up()


func claim_pending_event() -> void:
	if pending_event.is_empty():
		return
	var id := String(pending_event.get("id", ""))
	_apply_event(id)
	pending_event = {}
	random_event_resolved.emit(id)
	AudioManager.play_win(2.5)


func dismiss_pending_event() -> void:
	## Still consumes the event; the cooldown already started on spawn.
	if pending_event.is_empty():
		return
	var id := String(pending_event.get("id", ""))
	pending_event = {}
	random_event_resolved.emit(id)
	_notify("Event passed by", UIKit.DIM, "clock")


func _apply_event(id: String) -> void:
	var income := maxf(Casino.income_per_second(), 1.0)
	match id:
		"high_roller":
			var amt := floorf(income * 120.0 + 500.0)
			GameManager.add_chips(amt)
			_notify("High roller tipped +%s" % Fmt.chips(amt), UIKit.GOLD, "prop_highroller")
		"slot_tournament":
			_set_buff("Slot Tournament", 180.0, 1.0, 1.0, 0.02)
			_notify("+2% table RTP for three minutes", UIKit.GREEN, "game_slots")
		"celebrity_guest":
			_set_buff("Celebrity Guest", 240.0, 1.0, 1.5, 0.0)
			_notify("+50% EXP for four minutes", UIKit.BLUE, "reel_star")
		"comp_package":
			GameManager.grant_skill_points(1)
			_notify("Comp package: +1 skill point", UIKit.CYAN, "skill")
		"jackpot_fever":
			_set_buff("Jackpot Fever", 150.0, 2.0, 1.0, 0.0)
			_notify("x2 floor income for two and a half minutes", UIKit.ORANGE, "flame")
		"mystery_drop":
			var roll := randi() % 3
			if roll == 0:
				var mystery := floorf(income * 90.0 + 300.0)
				GameManager.add_chips(mystery)
				_notify("Mystery drop: +%s chips" % Fmt.chips(mystery), UIKit.GOLD, "gift")
			elif roll == 1:
				GameManager.grant_skill_points(1)
				_notify("Mystery drop: +1 skill point", UIKit.CYAN, "skill")
			else:
				_set_buff("Mystery Buzz", 120.0, 1.4, 1.2, 0.0)
				_notify("Mystery drop: a short income and EXP buff", UIKit.GREEN, "gift")
		"vip_invite":
			var gold := floorf(1.0 + float(GameManager.prestige_count) * 0.25)
			GameManager.add_gold_chips(maxf(gold, 1.0))
			_notify("VIP token: +%s gold chips" % Fmt.chips(maxf(gold, 1.0)),
				UIKit.PURPLE, "chip_gold")
		"floor_rush":
			var rush := floorf(income * 60.0 + 200.0)
			GameManager.add_chips(rush)
			_set_buff("Floor Rush", 90.0, 1.75, 1.0, 0.0)
			_notify("Rush payout +%s and x1.75 income" % Fmt.chips(rush), UIKit.GREEN, "bolt")
		"security_sweep":
			var recovered := floorf(income * 100.0 + 400.0)
			GameManager.add_chips(recovered)
			_notify("Recovery share +%s" % Fmt.chips(recovered), UIKit.GOLD, "lock")
		"lucky_dice":
			var amt := floorf(250.0 + GameManager.chips * 0.03)
			amt = minf(amt, income * 200.0 + 2000.0)
			GameManager.add_chips(floorf(amt))
			_notify("Lucky dice +%s" % Fmt.chips(amt), UIKit.GOLD, "game_dice")
		"rainy_night":
			_set_buff("Rainy Night", 200.0, 1.6, 1.15, 0.0)
			_notify("The storm crowd packs the floor", UIKit.BLUE, "moon")
		"dealer_tip_pool":
			var tips := floorf(income * 80.0 + 350.0)
			GameManager.add_chips(tips)
			_notify("Tip pool +%s" % Fmt.chips(tips), UIKit.GOLD, "chip")
		_:
			GameManager.add_chips(100.0)
			_notify("Event reward +100", UIKit.GOLD, "gift")


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


# --- daily -----------------------------------------------------------------

func _day_id() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func can_claim_daily() -> bool:
	return last_daily_day != _day_id()


func daily_reward_amount() -> float:
	var base := 2000.0 + 1500.0 * float(daily_streak)
	base *= GameManager.daily_bonus_multiplier()
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
	_notify("Daily bonus +%s chips (streak %d)" % [Fmt.chips(amount), daily_streak],
		UIKit.GOLD, "gift")
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
	var pe: Variant = data.get("pending_event", {})
	pending_event = pe if pe is Dictionary else {}
	if event_ready_at <= 0.0:
		event_ready_at = Time.get_unix_time_from_system() + 300.0
	daily_changed.emit()
