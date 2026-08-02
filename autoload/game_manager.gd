extends Node

## Central game state: currency, progression, prestige and lifetime stats.
##
## ECONOMY DESIGN NOTE
## -------------------
## Chips are produced by the casino floor (passive income) and consumed by
## property purchases and wagers. Every minigame is deliberately below 100% RTP,
## so gambling is *not* an income source -- it is how you convert chips into EXP
## and chase jackpots. That keeps auto-play from being an infinite money loop no
## matter how many upgrades are stacked. Anything that multiplies chip gains
## therefore applies to passive income only; the single lever that touches
## minigame returns is `rtp_bonus()`, and it is hard-clamped by MAX_EFFECTIVE_RTP.

signal chips_changed(amount: float)
signal experience_changed(current: float, needed: float, level: int)
signal level_changed(level: int)
signal skill_points_changed(points: int)
signal gold_chips_changed(amount: float)
signal prestige_changed(count: int)
signal stats_changed()
signal toast(text: String, color: Color)

## No stack of upgrades may push a minigame to or past break-even.
const MAX_EFFECTIVE_RTP := 0.99
const BASE_START_CHIPS := 250.0
const PRESTIGE_REQUIREMENT := 10000.0
const EXP_CURVE_BASE := 50.0
const EXP_CURVE_POWER := 1.55

# --- run state (wiped by prestige) -----------------------------------------
var chips: float = BASE_START_CHIPS:
	set(value):
		chips = maxf(value, 0.0)
		chips_changed.emit(chips)

var run_chips_earned: float = 0.0
var experience: float = 0.0
var level: int = 1
var skill_points: int = 0

# --- meta state (survives prestige) ----------------------------------------
var prestige_count: int = 0
var gold_chips: float = 0.0

# --- lifetime stats --------------------------------------------------------
var stats: Dictionary = {}

## Toasts raised by autoloads during their own _ready() (save migration, offline
## earnings, early achievements) happen before the main scene can connect, so
## they are buffered here and drained once a listener exists.
var pending_toasts: Array[Dictionary] = []

var _session_start_msec: int = 0


func _ready() -> void:
	stats = default_stats()
	_session_start_msec = Time.get_ticks_msec()


## Always raise player-facing messages through this, never `toast.emit` directly.
func notify_toast(text: String, color: Color) -> void:
	if toast.get_connections().is_empty():
		pending_toasts.append({"text": text, "color": color})
	else:
		toast.emit(text, color)


## Called by the main scene once it has connected to `toast`.
func drain_pending_toasts() -> void:
	var queued := pending_toasts.duplicate()
	pending_toasts.clear()
	for entry in queued:
		toast.emit(String(entry["text"]), entry["color"])


func default_stats() -> Dictionary:
	return {
		"lifetime_chips_earned": 0.0,
		"total_wagered": 0.0,
		"total_wagers": 0,
		"total_wins": 0,
		"biggest_win": 0.0,
		"best_multiplier": 0.0,
		"current_streak": 0,
		"best_streak": 0,
		"jackpots": 0,
		"properties_bought": 0,
		"prestiges": 0,
		"play_time": 0.0,
		"plays": {"slots": 0, "roulette": 0, "dice": 0, "scratch": 0},
	}


func _process(delta: float) -> void:
	stats["play_time"] = float(stats.get("play_time", 0.0)) + delta


# ===========================================================================
# CURRENCY
# ===========================================================================

## `count_as_earned` is false for refunds/rebates so they do not inflate the
## prestige payout or the lifetime-earned stat.
func add_chips(amount: float, count_as_earned: bool = true) -> void:
	if amount <= 0.0 or not is_finite(amount):
		return
	chips += amount
	if count_as_earned:
		run_chips_earned += amount
		stats["lifetime_chips_earned"] = float(stats.get("lifetime_chips_earned", 0.0)) + amount


func spend_chips(amount: float) -> bool:
	if amount < 0.0 or not is_finite(amount) or chips < amount:
		return false
	chips -= amount
	return true


func add_gold_chips(amount: float) -> void:
	if amount <= 0.0:
		return
	gold_chips += amount
	gold_chips_changed.emit(gold_chips)


func spend_gold_chips(amount: float) -> bool:
	if amount < 0.0 or gold_chips < amount:
		return false
	gold_chips -= amount
	gold_chips_changed.emit(gold_chips)
	return true


# ===========================================================================
# EXPERIENCE / LEVELS
# ===========================================================================

func exp_to_next() -> float:
	return EXP_CURVE_BASE * pow(float(level), EXP_CURVE_POWER)


## `raw` is pre-multiplier; the EXP multiplier is applied here so callers never
## have to remember to do it.
func add_experience(raw: float) -> void:
	if raw <= 0.0 or not is_finite(raw):
		return
	experience += raw * exp_multiplier()
	var levelled := false
	var guard := 0
	while experience >= exp_to_next() and guard < 100000:
		experience -= exp_to_next()
		level += 1
		skill_points += 1
		levelled = true
		guard += 1
	if levelled:
		level_changed.emit(level)
		skill_points_changed.emit(skill_points)
		notify_toast("LEVEL %d!  +1 skill point" % level, UIKit.BLUE)
	experience_changed.emit(experience, exp_to_next(), level)


func spend_skill_points(amount: int) -> bool:
	if amount < 0 or skill_points < amount:
		return false
	skill_points -= amount
	skill_points_changed.emit(skill_points)
	return true


func grant_skill_points(amount: int) -> void:
	if amount <= 0:
		return
	skill_points += amount
	skill_points_changed.emit(skill_points)


# ===========================================================================
# DERIVED MULTIPLIERS
# ===========================================================================

func exp_multiplier() -> float:
	var m := 1.0 + 0.08 * float(Upgrades.skill_level("lucky_streak"))
	m *= 1.0 + 0.20 * float(Upgrades.prestige_rank("veteran"))
	return m


## Applies to passive casino income only -- never to minigame payouts.
func income_multiplier() -> float:
	var m := 1.0 + 0.10 * float(Upgrades.skill_level("floor_manager"))
	m *= 1.0 + 0.12 * float(Upgrades.prestige_rank("golden_touch"))
	m *= 1.0 + 0.05 * float(prestige_count)
	m *= 1.0 + 0.01 * float(Achievements.unlocked_count())
	return m


## Additive RTP bonus, before the MAX_EFFECTIVE_RTP clamp applied per-game.
func rtp_bonus() -> float:
	return 0.005 * float(Upgrades.skill_level("card_counter")) \
		+ 0.004 * float(Upgrades.prestige_rank("loaded_dice"))


func cost_discount() -> float:
	var d := 0.02 * float(Upgrades.skill_level("haggler")) \
		+ 0.03 * float(Upgrades.prestige_rank("magnate"))
	return clampf(d, 0.0, 0.75)


## Multiplies minigame animation durations (lower is faster).
func speed_multiplier() -> float:
	return maxf(0.15, 1.0 - 0.08 * float(Upgrades.skill_level("quick_hands")))


## Fraction of your bank you may put on a single wager.
func max_bet_fraction() -> float:
	return clampf(0.05 * (1.0 + 0.5 * float(Upgrades.skill_level("high_roller"))), 0.05, 1.0)


func offline_cap_seconds() -> float:
	return 7200.0 \
		+ 7200.0 * float(Upgrades.prestige_rank("vault")) \
		+ 1800.0 * float(Upgrades.skill_level("scout"))


func offline_efficiency() -> float:
	return clampf(0.50 + 0.05 * float(Upgrades.skill_level("scout")), 0.0, 1.0)


# ===========================================================================
# WAGER BOOKKEEPING
# ===========================================================================

## EXP from a wager scales with sqrt(bet) so that exponential chip growth does
## not translate into exponential level growth.
func record_wager(game_id: String, amount: float) -> void:
	stats["total_wagered"] = float(stats.get("total_wagered", 0.0)) + amount
	stats["total_wagers"] = int(stats.get("total_wagers", 0)) + 1
	var plays: Dictionary = stats.get("plays", {})
	plays[game_id] = int(plays.get(game_id, 0)) + 1
	stats["plays"] = plays
	add_experience(2.0 * sqrt(maxf(amount, 0.0)))
	stats_changed.emit()


func record_result(payout: float, wager: float, is_jackpot: bool) -> void:
	if payout > 0.0:
		stats["total_wins"] = int(stats.get("total_wins", 0)) + 1
		stats["current_streak"] = int(stats.get("current_streak", 0)) + 1
		stats["best_streak"] = maxi(int(stats.get("best_streak", 0)), int(stats["current_streak"]))
		stats["biggest_win"] = maxf(float(stats.get("biggest_win", 0.0)), payout)
		if wager > 0.0:
			stats["best_multiplier"] = maxf(float(stats.get("best_multiplier", 0.0)), payout / wager)
	else:
		stats["current_streak"] = 0
	if is_jackpot:
		stats["jackpots"] = int(stats.get("jackpots", 0)) + 1
	stats_changed.emit()


# ===========================================================================
# PRESTIGE
# ===========================================================================

func can_prestige() -> bool:
	return run_chips_earned >= PRESTIGE_REQUIREMENT


func pending_gold_chips() -> float:
	if not can_prestige():
		return 0.0
	var base := floorf(sqrt(run_chips_earned / 10000.0))
	var bonus := 1.0 + 0.05 * float(Upgrades.prestige_rank("compound_interest"))
	return floorf(base * bonus)


func do_prestige() -> bool:
	if not can_prestige():
		return false
	var gained := pending_gold_chips()
	add_gold_chips(gained)
	prestige_count += 1
	stats["prestiges"] = prestige_count

	reset_run()

	prestige_changed.emit(prestige_count)
	stats_changed.emit()
	notify_toast("PRESTIGE %d  ->  +%s gold chips" % [prestige_count, Fmt.chips(gained)], UIKit.PURPLE)
	Achievements.check_all()
	return true


## Resets everything a prestige wipes, then re-applies the permanent head starts.
func reset_run() -> void:
	Upgrades.reset_skills()
	Casino.reset()

	var start_mult := pow(2.0, float(Upgrades.prestige_rank("head_start")))
	chips = BASE_START_CHIPS * start_mult
	run_chips_earned = 0.0
	experience = 0.0
	level = 1
	skill_points = Upgrades.prestige_rank("apprentice")

	Casino.grant_free_start(Upgrades.prestige_rank("free_floor"))

	level_changed.emit(level)
	skill_points_changed.emit(skill_points)
	experience_changed.emit(experience, exp_to_next(), level)


## Pushes every signal so freshly-built UI can sync without special-casing.
func broadcast() -> void:
	chips_changed.emit(chips)
	level_changed.emit(level)
	skill_points_changed.emit(skill_points)
	gold_chips_changed.emit(gold_chips)
	prestige_changed.emit(prestige_count)
	experience_changed.emit(experience, exp_to_next(), level)
	stats_changed.emit()
