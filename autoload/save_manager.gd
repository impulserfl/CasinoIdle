extends Node

signal offline_earnings(amount: float, seconds: float, capped: bool)
signal slots_changed

const SLOT_COUNT := 3
const SAVE_VERSION := 3
const AUTOSAVE_INTERVAL := 20.0
const ACTIVE_SLOT_PATH := "user://casino_active_slot.txt"

var pending_offline: Dictionary = {}
var _autosave_timer := 0.0
var _loaded := false
var active_slot := 0


func _ready() -> void:
	active_slot = _read_active_slot()
	load_game()
	_loaded = true


func _process(delta: float) -> void:
	if not _loaded:
		return
	_autosave_timer += delta
	var settings_changed := Settings.consume_dirty()
	if _autosave_timer >= AUTOSAVE_INTERVAL or settings_changed:
		_autosave_timer = 0.0
		save_game(true)


func slot_path(slot: int) -> String:
	return "user://casino_idle_slot_%d.cfg" % clampi(slot, 0, SLOT_COUNT - 1)


func backup_path(slot: int) -> String:
	return "user://casino_idle_slot_%d.bak" % clampi(slot, 0, SLOT_COUNT - 1)


func _read_active_slot() -> int:
	if not FileAccess.file_exists(ACTIVE_SLOT_PATH):
		# Migrate legacy single save into slot 0.
		if FileAccess.file_exists("user://casino_idle_save.cfg"):
			var old := FileAccess.open("user://casino_idle_save.cfg", FileAccess.READ)
			if old != null:
				var bytes := old.get_buffer(old.get_length())
				old.close()
				var neu := FileAccess.open(slot_path(0), FileAccess.WRITE)
				if neu != null:
					neu.store_buffer(bytes)
					neu.close()
		return 0
	var f := FileAccess.open(ACTIVE_SLOT_PATH, FileAccess.READ)
	if f == null:
		return 0
	var v := int(f.get_as_text().strip_edges())
	f.close()
	return clampi(v, 0, SLOT_COUNT - 1)


func _write_active_slot(slot: int) -> void:
	active_slot = clampi(slot, 0, SLOT_COUNT - 1)
	var f := FileAccess.open(ACTIVE_SLOT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(str(active_slot))
		f.close()


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func any_slot_exists() -> bool:
	for i in range(SLOT_COUNT):
		if slot_exists(i):
			return true
	return false


func slot_info(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"empty": true, "slot": slot, "label": "Empty Slot"}
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return {"empty": true, "slot": slot, "label": "Corrupt Slot", "corrupt": true}
	var chips := float(config.get_value("run", "chips", 0.0))
	var level := int(config.get_value("run", "level", 1))
	var prestiges := int(config.get_value("meta_progress", "prestige_count", 0))
	var saved_at := float(config.get_value("meta", "saved_at", 0.0))
	var when := ""
	if saved_at > 0.0:
		var dt := Time.get_datetime_dict_from_unix_time(int(saved_at))
		when = "%04d-%02d-%02d  %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
	return {
		"empty": false,
		"slot": slot,
		"chips": chips,
		"level": level,
		"prestiges": prestiges,
		"saved_at": saved_at,
		"when": when,
		"label": "Lv %d  ·  %s chips" % [level, Fmt.chips(chips)],
		"active": slot == active_slot,
	}


func all_slot_info() -> Array:
	var out: Array = []
	for i in range(SLOT_COUNT):
		out.append(slot_info(i))
	return out


func select_slot(slot: int, load_now: bool = true) -> void:
	if _loaded:
		save_game(true)
	_write_active_slot(slot)
	if load_now:
		_reset_runtime_state()
		load_game()
	slots_changed.emit()


func delete_slot(slot: int) -> void:
	var path := slot_path(slot)
	var bak := backup_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)
	if slot == active_slot:
		_reset_runtime_state()
		GameManager.broadcast()
	slots_changed.emit()


func start_new_in_slot(slot: int) -> void:
	if _loaded:
		save_game(true)
	delete_slot(slot)
	_write_active_slot(slot)
	_reset_runtime_state()
	GameManager.broadcast()
	Upgrades.changed.emit()
	GameUpgrades.changed.emit()
	Casino.changed.emit()
	save_game(true)
	slots_changed.emit()


func _reset_runtime_state() -> void:
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
	Events.pending_event = {}
	Events.buff_remaining = 0.0
	Events.lucky_hour_remaining = 0.0
	GameManager.reset_run()
	pending_offline = {}


func save_game(silent: bool = false) -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("meta", "saved_at", Time.get_unix_time_from_system())
	config.set_value("meta", "slot", active_slot)
	config.set_value("run", "chips", GameManager.chips)
	config.set_value("run", "run_chips_earned", GameManager.run_chips_earned)
	config.set_value("run", "experience", GameManager.experience)
	config.set_value("run", "level", GameManager.level)
	config.set_value("run", "skill_points", GameManager.skill_points)
	config.set_value("run", "tables_played", GameManager.run_tables_played)
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

	var path := slot_path(active_slot)
	if FileAccess.file_exists(path):
		var prev := FileAccess.open(path, FileAccess.READ)
		if prev != null:
			var bytes := prev.get_buffer(prev.get_length())
			prev.close()
			var bak := FileAccess.open(backup_path(active_slot), FileAccess.WRITE)
			if bak != null:
				bak.store_buffer(bytes)
				bak.close()

	var err := config.save(path)
	if err != OK:
		push_error("CasinoIdle: failed to save slot %d (error %d)" % [active_slot, err])
		return
	if not silent:
		GameManager.notify_toast("Saved to slot %d" % (active_slot + 1), UIKit.GREEN, "save")
		AudioManager.play_click()
	slots_changed.emit()


func load_game() -> void:
	var config := ConfigFile.new()
	var path := slot_path(active_slot)
	var err := config.load(path)
	if err != OK:
		err = config.load(backup_path(active_slot))
		if err == OK:
			push_warning("CasinoIdle: slot %d restored from backup." % active_slot)
	if err != OK:
		# Also try legacy path once
		err = config.load("user://casino_idle_save.cfg")
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
	GameManager.run_tables_played = _as_dict(config.get_value("run", "tables_played", {}))
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
	push_warning("CasinoIdle: migrated a v1 save to multi-slot.")


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
	delete_slot(active_slot)
	_reset_runtime_state()
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
