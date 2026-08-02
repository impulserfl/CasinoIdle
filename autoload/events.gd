extends Node

## Unique meta content: daily login bonus + random Lucky Hour income spikes.

signal daily_changed()
signal lucky_hour_changed(active: bool, mult: float)

var last_daily_day: int = -1
var daily_streak: int = 0
var lucky_hour_remaining: float = 0.0
var lucky_hour_mult: float = 1.0
var _lucky_cooldown: float = 0.0


func _process(delta: float) -> void:
	if lucky_hour_remaining > 0.0:
		lucky_hour_remaining = maxf(lucky_hour_remaining - delta, 0.0)
		if lucky_hour_remaining <= 0.0:
			lucky_hour_mult = 1.0
			lucky_hour_changed.emit(false, 1.0)
			GameManager.notify_toast("Lucky Hour ended", UIKit.DIM)
	else:
		_lucky_cooldown = maxf(_lucky_cooldown - delta, 0.0)
		if _lucky_cooldown <= 0.0 and randf() < 0.0008:  # ~once every few minutes of active play
			_start_lucky_hour()


func _start_lucky_hour() -> void:
	lucky_hour_mult = 1.5 + 0.1 * float(Upgrades.prestige_rank("party_planner"))
	lucky_hour_remaining = 90.0 + 30.0 * float(Upgrades.prestige_rank("party_planner"))
	_lucky_cooldown = 300.0
	lucky_hour_changed.emit(true, lucky_hour_mult)
	GameManager.notify_toast("🍀 LUCKY HOUR!  x%.1f income" % lucky_hour_mult, UIKit.GREEN)
	AudioManager.play_level_up()


func income_event_multiplier() -> float:
	return lucky_hour_mult if lucky_hour_remaining > 0.0 else 1.0


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
	}


func from_dict(data: Dictionary) -> void:
	last_daily_day = int(data.get("last_daily_day", -1))
	daily_streak = int(data.get("daily_streak", 0))
	daily_changed.emit()
