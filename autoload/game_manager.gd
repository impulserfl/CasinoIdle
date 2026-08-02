extends Node

## Currency, EXP, prestige, stats and every derived multiplier.
##
## The one economic rule the whole game obeys: chips come from the casino
## floor, never from the tables. Anything that multiplies chip gains applies to
## passive income only. The single lever that touches table returns is
## rtp_bonus(), and Minigame hard-clamps the result to MAX_EFFECTIVE_RTP.

signal chips_changed(amount: float)
signal experience_changed(current: float, needed: float, level: int)
signal level_changed(level: int)
signal skill_points_changed(points: int)
signal gold_chips_changed(amount: float)
signal prestige_changed(count: int)
signal stats_changed()
signal toast(text: String, color: Color, icon: String)

const MAX_EFFECTIVE_RTP := 0.99
const BASE_START_CHIPS := 50.0

## Tuned against tools/verify_balance.py's pacing model: a first prestige lands
## near an hour of idling, and the simulator buys optimally every second, so
## real play runs slower than that rather than faster.
const BASE_PRESTIGE_REQUIREMENT := 50_000_000.0
const PRESTIGE_REQUIREMENT_GROWTH := 1.35

## Gold is priced off the ratio to the base requirement, not the raw chip
## count, so the payout stays sane no matter how far the numbers inflate.
const GOLD_SCALE := 4.0
const GOLD_POWER := 0.6

## EXP is a flat rate per round scaled by how much of your ceiling you wagered.
## It used to be 3*sqrt(wager), which meant a late-game bet was worth millions
## of EXP and levels became meaningless once the numbers grew.
const EXP_PER_ROUND := 10.0
const EXP_CURVE_BASE := 24.0
const EXP_CURVE_POWER := 1.30

var chips: float = BASE_START_CHIPS:
	set(value):
		if not is_finite(value):
			value = 0.0
		chips = maxf(value, 0.0)
		chips_changed.emit(chips)
var run_chips_earned: float = 0.0
var experience: float = 0.0
var level: int = 1
var skill_points: int = 0
var prestige_count: int = 0
var gold_chips: float = 0.0
var stats: Dictionary = {}
## Table ids played since the last prestige — feeds the Analyst skill.
var run_tables_played: Dictionary = {}
var pending_toasts: Array[Dictionary] = []


func _ready() -> void:
	stats = default_stats()


func notify_toast(text: String, color: Color, icon: String = "") -> void:
	if toast.get_connections().is_empty():
		pending_toasts.append({"text": text, "color": color, "icon": icon})
	else:
		toast.emit(text, color, icon)


func drain_pending_toasts() -> void:
	var queued := pending_toasts.duplicate()
	pending_toasts.clear()
	for entry in queued:
		toast.emit(String(entry["text"]), entry["color"], String(entry.get("icon", "")))


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
		"plays": {},
	}


func _process(delta: float) -> void:
	stats["play_time"] = float(stats.get("play_time", 0.0)) + delta


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
	if amount <= 0.0 or not is_finite(amount):
		return
	gold_chips += amount
	gold_chips_changed.emit(gold_chips)


func spend_gold_chips(amount: float) -> bool:
	if amount < 0.0 or not is_finite(amount) or gold_chips < amount:
		return false
	gold_chips -= amount
	gold_chips_changed.emit(gold_chips)
	return true


func exp_to_next() -> float:
	return EXP_CURVE_BASE * pow(float(level), EXP_CURVE_POWER)


func add_experience(raw: float) -> void:
	if raw <= 0.0 or not is_finite(raw):
		return
	experience += raw * exp_multiplier() * Events.exp_event_multiplier()
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
		if Settings.toast_level:
			notify_toast("Level %d reached, +1 skill point" % level, UIKit.BLUE, "skill")
		AudioManager.play_level_up()
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


# --- derived multipliers ---------------------------------------------------

func exp_multiplier() -> float:
	var m := 1.0 + 0.08 * float(Upgrades.skill_level("lucky_streak"))
	m += 0.05 * float(Upgrades.skill_level("comp_cards"))
	m += 0.02 * float(Upgrades.skill_level("analyst")) * float(run_tables_played.size())
	if int(stats.get("current_streak", 0)) > 0:
		m += 0.10 * float(Upgrades.skill_level("streak_hunter"))
	m *= 1.0 + 0.20 * float(Upgrades.prestige_rank("veteran"))
	m *= 1.0 + 0.15 * float(Upgrades.prestige_rank("librarian"))
	return m


func income_multiplier() -> float:
	var achievements := float(Achievements.unlocked_count())
	var m := 1.0 + 0.10 * float(Upgrades.skill_level("floor_manager"))
	m += 0.04 * float(Upgrades.skill_level("pit_boss"))
	m += 0.03 * float(Upgrades.skill_level("greeter"))
	m += 0.06 * float(Upgrades.skill_level("shift_lead"))
	m += 0.004 * float(Upgrades.skill_level("showman")) * achievements
	m *= 1.0 + 0.12 * float(Upgrades.prestige_rank("golden_touch"))
	m *= 1.0 + 0.006 * float(Upgrades.prestige_rank("curator")) * achievements
	m *= 1.0 + 0.02 * float(Upgrades.prestige_rank("syndicate")) * float(prestige_count)
	m *= 1.0 + 0.05 * float(prestige_count)
	m *= 1.0 + 0.01 * achievements
	return m


## The only path from an upgrade to a table's returns. Minigame clamps the sum
## to MAX_EFFECTIVE_RTP, so stacking every source here can never reach 100%.
func rtp_bonus() -> float:
	return 0.005 * float(Upgrades.skill_level("card_counter")) \
		+ 0.003 * float(Upgrades.skill_level("fortune_cookie")) \
		+ 0.004 * float(Upgrades.prestige_rank("loaded_dice")) \
		+ 0.0025 * float(Upgrades.prestige_rank("house_edge")) \
		+ Events.rtp_event_bonus()


func cost_discount() -> float:
	var d := 0.02 * float(Upgrades.skill_level("haggler")) \
		+ 0.03 * float(Upgrades.prestige_rank("magnate"))
	return clampf(d, 0.0, 0.75)


func speed_multiplier() -> float:
	return maxf(0.15, 1.0 - 0.08 * float(Upgrades.skill_level("quick_hands")))


func auto_delay_multiplier() -> float:
	return maxf(0.35, 1.0 - 0.06 * float(Upgrades.skill_level("chip_runner")))


func max_bet_fraction() -> float:
	var f := 0.08 * (1.0 + 0.4 * float(Upgrades.skill_level("high_roller")))
	f *= 1.0 + 0.10 * float(Upgrades.prestige_rank("high_limit"))
	return clampf(f, 0.08, 1.0)


func offline_cap_seconds() -> float:
	return 7200.0 \
		+ 7200.0 * float(Upgrades.prestige_rank("vault")) \
		+ 1200.0 * float(Upgrades.skill_level("scout")) \
		+ 900.0 * float(Upgrades.skill_level("concierge"))


func offline_efficiency() -> float:
	var e := 0.50 + 0.04 * float(Upgrades.skill_level("scout")) \
		+ 0.04 * float(Upgrades.prestige_rank("time_lord"))
	return clampf(e, 0.0, 1.0)


func event_cooldown_multiplier() -> float:
	return maxf(0.40, 1.0 - 0.07 * float(Upgrades.skill_level("promoter")))


func buff_duration_multiplier() -> float:
	return 1.0 + 0.20 * float(Upgrades.prestige_rank("impresario"))


func daily_bonus_multiplier() -> float:
	return (1.0 + 0.15 * float(Upgrades.prestige_rank("daily_whale"))) \
		* (1.0 + 0.20 * float(Upgrades.skill_level("tipster")))


# --- wagering --------------------------------------------------------------

## `fraction` is the share of the table's maximum bet that was staked. EXP is
## priced off that rather than the raw chip amount so a level means the same
## amount of play whether you are betting 40 chips or 40 quadrillion.
func record_wager(game_id: String, amount: float, fraction: float) -> void:
	stats["total_wagered"] = float(stats.get("total_wagered", 0.0)) + amount
	stats["total_wagers"] = int(stats.get("total_wagers", 0)) + 1
	var plays: Dictionary = stats.get("plays", {})
	plays[game_id] = int(plays.get(game_id, 0)) + 1
	stats["plays"] = plays
	run_tables_played[game_id] = true

	var table_exp := EXP_PER_ROUND * sqrt(clampf(fraction, 0.0, 1.0)) \
		* GameUpgrades.exp_multiplier(game_id)
	add_experience(table_exp)
	stats_changed.emit()


## EXP consolation for a losing round. Pays in EXP only — never chips — so the
## per-table `solace` upgrade cannot lift a table above its declared RTP.
func record_loss_solace(game_id: String, fraction: float) -> void:
	var bonus := GameUpgrades.solace_bonus(game_id)
	if bonus <= 0.0:
		return
	add_experience(EXP_PER_ROUND * sqrt(clampf(fraction, 0.0, 1.0)) * bonus)


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


# --- prestige --------------------------------------------------------------

func prestige_requirement() -> float:
	return BASE_PRESTIGE_REQUIREMENT * pow(PRESTIGE_REQUIREMENT_GROWTH, float(prestige_count))


func can_prestige() -> bool:
	return run_chips_earned >= prestige_requirement()


func prestige_progress() -> float:
	return clampf(run_chips_earned / maxf(prestige_requirement(), 1.0), 0.0, 1.0)


func pending_gold_chips() -> float:
	if not can_prestige():
		return 0.0
	var ratio := run_chips_earned / BASE_PRESTIGE_REQUIREMENT
	var base := GOLD_SCALE * pow(maxf(ratio, 0.0), GOLD_POWER)
	base *= 1.0 + 0.05 * float(Upgrades.prestige_rank("compound_interest"))
	base *= 1.0 + 0.03 * float(Upgrades.skill_level("collector"))
	var floor_gold := 1.0 + float(Upgrades.prestige_rank("kingmaker"))
	return floorf(maxf(base, floor_gold))


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
	notify_toast("Prestige %d complete, +%s gold chips" % [prestige_count, Fmt.chips(gained)],
		UIKit.PURPLE, "prestige")
	AudioManager.play_prestige()
	Achievements.check_all()
	return true


func reset_run() -> void:
	Upgrades.reset_skills()
	GameUpgrades.reset()
	Casino.reset()
	var start_mult := pow(2.0, float(Upgrades.prestige_rank("head_start")))
	start_mult *= 1.0 + 0.15 * float(Upgrades.prestige_rank("silver_spoon"))
	chips = BASE_START_CHIPS * start_mult
	run_chips_earned = 0.0
	experience = 0.0
	level = 1
	skill_points = Upgrades.prestige_rank("apprentice")
	run_tables_played.clear()
	Casino.grant_free_start(Upgrades.prestige_rank("free_floor"))
	level_changed.emit(level)
	skill_points_changed.emit(skill_points)
	experience_changed.emit(experience, exp_to_next(), level)


func broadcast() -> void:
	chips_changed.emit(chips)
	level_changed.emit(level)
	skill_points_changed.emit(skill_points)
	gold_chips_changed.emit(gold_chips)
	prestige_changed.emit(prestige_count)
	experience_changed.emit(experience, exp_to_next(), level)
	stats_changed.emit()
