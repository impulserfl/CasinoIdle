extends Node

signal offline_earnings(amount: float, seconds: float, capped: bool)

const SAVE_PATH := "user://casino_idle_save.cfg"
const BACKUP_PATH := "user://casino_idle_save.bak"
const SAVE_VERSION := 2
const AUTOSAVE_INTERVAL := 20.0

var pending_offline: Dictionary = {}
var _autosave_timer := 0.0
var _loaded := false


func _ready() -> void:
	load_game()
	_loaded = true


func _process(delta: float) -> void:
	if not _loaded:
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL or Settings.consume_dirty():
		_autosave_timer = 0.0
		save_game(true)


func save_game(silent: bool = false) -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("meta", "saved_at", Time.get_unix_time_from_system())
	config.set_value("run", "chips", GameManager.chips)
	config.set_value("run", "run_chips_earned", GameManager.run_chips_earned)
	config.set_value("run", "experience", GameManager.experience)
	config.set_value("run", "level", GameManager.level)
	config.set_value("run", "skill_points", GameManager.skill_points)
	config.set_value("meta_progress", "prestige_count", GameManager.prestige_count)
	config.set_value("meta_progress", "gold_chips", GameManager.gold_chips)
	config.set_value("upgrades", "skills", Upgrades.skill_levels)
	config.set_value("upgrades", "prestige", Upgrades.prestige_levels)
	config.set_value("upgrades", "tables", GameUpgrades.levels)
	config.set_value("casino", "owned", Casino.owned)
	config.set_value("achievements", "unlocked", Achievements.unlocked_ids)
	config.set_value("achievements", "flags", Achievements._flags)
	config.set_value("stats", "data", GameManager.stats)
	config.set_value("settings", "data", Settings.to_dict())
	config.set_value("events", "data", Events.to_dict())

	if FileAccess.file_exists(SAVE_PATH):
		var prev := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if prev != null:
			var bytes := prev.get_buffer(prev.get_length())
			prev.close()
			var bak := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if bak != null:
				bak.store_buffer(bytes)
				bak.close()

	var err := config.save(SAVE_PATH)
	if err != OK:
		push_error("CasinoIdle: failed to save (error %d)" % err)
		return
	if not silent:
		GameManager.notify_toast("Game saved", UIKit.GREEN)
		AudioManager.play_click()


func load_game() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		err = config.load(BACKUP_PATH)
		if err == OK:
			push_warning("CasinoIdle: primary save unreadable, restored from backup.")
	if err != OK:
		GameManager.broadcast()
		return

	var version := int(config.get_value("meta", "version", 1))
	if version < 2:
		_migrate_v1(config)
	else:
		_load_v2(config)

	Settings.from_dict(_as_dict(config.get_value("settings", "data", {})))
	Events.from_dict(_as_dict(config.get_value("events", "data", {})))

	GameManager.broadcast()
	Upgrades.changed.emit()
	GameUpgrades.changed.emit()
	Casino.changed.emit()
	_apply_offline_progress(float(config.get_value("meta", "saved_at", 0.0)))


func _load_v2(config: ConfigFile) -> void:
	GameManager.chips = float(config.get_value("run", "chips", GameManager.BASE_START_CHIPS))
	GameManager.run_chips_earned = float(config.get_value("run", "run_chips_earned", 0.0))
	GameManager.experience = float(config.get_value("run", "experience", 0.0))
	GameManager.level = int(config.get_value("run", "level", 1))
	GameManager.skill_points = int(config.get_value("run", "skill_points", 0))
	GameManager.prestige_count = int(config.get_value("meta_progress", "prestige_count", 0))
	GameManager.gold_chips = float(config.get_value("meta_progress", "gold_chips", 0.0))
	Upgrades.skill_levels = _as_dict(config.get_value("upgrades", "skills", {}))
	Upgrades.prestige_levels = _as_dict(config.get_value("upgrades", "prestige", {}))
	GameUpgrades.levels = _as_dict(config.get_value("upgrades", "tables", {}))
	Casino.owned = _as_dict(config.get_value("casino", "owned", {}))
	Achievements.unlocked_ids = _as_dict(config.get_value("achievements", "unlocked", {}))
	Achievements._flags = _as_dict(config.get_value("achievements", "flags", {}))
	var loaded_stats := _as_dict(config.get_value("stats", "data", {}))
	var stats := GameManager.default_stats()
	for key in loaded_stats:
		stats[key] = loaded_stats[key]
	GameManager.stats = stats


func _migrate_v1(config: ConfigFile) -> void:
	GameManager.chips = float(config.get_value("player", "chips", GameManager.BASE_START_CHIPS))
	var earned := float(config.get_value("player", "total_chips_earned", 0.0))
	GameManager.run_chips_earned = earned
	GameManager.experience = float(config.get_value("player", "exp", 0.0))
	GameManager.level = int(config.get_value("player", "level", 1))
	GameManager.skill_points = int(config.get_value("player", "skill_points", 0))
	GameManager.prestige_count = int(config.get_value("player", "prestige_level", 0))
	GameManager.gold_chips = 0.0
	GameManager.stats = GameManager.default_stats()
	GameManager.stats["lifetime_chips_earned"] = earned
	GameManager.stats["prestiges"] = GameManager.prestige_count
	push_warning("CasinoIdle: migrated a v1 save to v2.")
	GameManager.notify_toast("Save migrated to v2", UIKit.BLUE)


func _as_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _apply_offline_progress(saved_at: float) -> void:
	if saved_at <= 0.0:
		return
	var now := Time.get_unix_time_from_system()
	var elapsed := float(now) - saved_at
	if elapsed < 60.0:
		return
	var cap := GameManager.offline_cap_seconds()
	var capped := elapsed > cap
	var effective := minf(elapsed, cap)
	var earned := Casino.income_per_second() * effective * GameManager.offline_efficiency()
	if earned <= 0.0:
		return
	GameManager.add_chips(earned)
	pending_offline = {"amount": earned, "seconds": elapsed, "capped": capped, "cap": cap}
	offline_earnings.emit(earned, elapsed, capped)


func claim_offline_report() -> Dictionary:
	var report := pending_offline
	pending_offline = {}
	return report


func wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	GameManager.prestige_count = 0
	GameManager.gold_chips = 0.0
	GameManager.stats = GameManager.default_stats()
	Upgrades.skill_levels.clear()
	Upgrades.prestige_levels.clear()
	GameUpgrades.levels.clear()
	Casino.owned.clear()
	Achievements.unlocked_ids.clear()
	Achievements._flags.clear()
	Events.last_daily_day = -1
	Events.daily_streak = 0
	GameManager.reset_run()
	GameManager.broadcast()
	Upgrades.changed.emit()
	GameUpgrades.changed.emit()
	Casino.changed.emit()
	Achievements.check_all()
	save_game(true)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, \
		NOTIFICATION_WM_GO_BACK_REQUEST, \
		NOTIFICATION_CRASH, \
		NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_EXIT_TREE:
			if _loaded:
				save_game(true)
