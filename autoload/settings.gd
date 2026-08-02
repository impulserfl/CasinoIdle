extends Node

## Player preferences. Not part of run state — these survive prestige, and only
## a save wipe clears them.
##
## Each preference is a real property so the rest of the game can read
## `Settings.fast_animations` and have it type-check. SPEC is the matching
## metadata table: the settings panel builds itself from it and SaveManager
## round-trips it, so neither keeps a second list that can drift out of sync.

signal changed()

# --- audio ---
var master_volume: float = 0.85
var sfx_volume: float = 1.0
var muted: bool = false
var auto_spin_sfx: bool = true

# --- presentation ---
var show_float_text: bool = true
var screen_shake: bool = true
var fast_animations: bool = false
var compact_rows: bool = false
var show_payback: bool = true

# --- tables ---
var confirm_prestige: bool = true
var stop_auto_on_jackpot: bool = false
var stop_auto_on_tab: bool = true
var keep_bet_on_switch: bool = false

# --- notifications ---
var toast_level: bool = true
var toast_achievement: bool = true
var toast_event: bool = true

const SPEC: Array[Dictionary] = [
	{"key": "master_volume", "kind": "slider", "group": "Audio", "default": 0.85,
		"name": "Master volume", "desc": "Overall output level."},
	{"key": "sfx_volume", "kind": "slider", "group": "Audio", "default": 1.0,
		"name": "Effects volume", "desc": "Table and interface sounds."},
	{"key": "muted", "kind": "toggle", "group": "Audio", "default": false,
		"name": "Mute everything", "desc": "Silence output without changing your levels."},
	{"key": "auto_spin_sfx", "kind": "toggle", "group": "Audio", "default": true,
		"name": "Sound during auto-play", "desc": "Turn off to keep long auto sessions quiet."},

	{"key": "show_float_text", "kind": "toggle", "group": "Presentation", "default": true,
		"name": "Floating win text", "desc": "Show the drifting +chips number on a win."},
	{"key": "screen_shake", "kind": "toggle", "group": "Presentation", "default": true,
		"name": "Screen shake", "desc": "Shake the table on a big win."},
	{"key": "fast_animations", "kind": "toggle", "group": "Presentation", "default": false,
		"name": "Skip animations", "desc": "Resolve every round instantly. Much faster auto-play."},
	{"key": "compact_rows", "kind": "toggle", "group": "Presentation", "default": false,
		"name": "Compact floor rows", "desc": "Fit more properties on screen at once."},
	{"key": "show_payback", "kind": "toggle", "group": "Presentation", "default": true,
		"name": "Show payback time", "desc": "How long a property takes to pay for itself."},

	{"key": "confirm_prestige", "kind": "toggle", "group": "Tables", "default": true,
		"name": "Confirm prestige", "desc": "Require a second press before resetting the run."},
	{"key": "stop_auto_on_jackpot", "kind": "toggle", "group": "Tables", "default": false,
		"name": "Stop auto on a jackpot", "desc": "Halt auto-play whenever a jackpot lands."},
	{"key": "stop_auto_on_tab", "kind": "toggle", "group": "Tables", "default": true,
		"name": "Stop auto when you leave", "desc": "Switching tabs halts a running table."},
	{"key": "keep_bet_on_switch", "kind": "toggle", "group": "Tables", "default": false,
		"name": "Carry your bet between tables", "desc": "Reuse the same stake at the next table."},

	{"key": "toast_level", "kind": "toggle", "group": "Notifications", "default": true,
		"name": "Level-up messages", "desc": "Announce each new level and skill point."},
	{"key": "toast_achievement", "kind": "toggle", "group": "Notifications", "default": true,
		"name": "Achievement messages", "desc": "Announce achievements as they unlock."},
	{"key": "toast_event", "kind": "toggle", "group": "Notifications", "default": true,
		"name": "Event messages", "desc": "Announce Lucky Hours and floor events."},
]

## Shared bet, used when `keep_bet_on_switch` is on.
var carried_bet: float = 0.0

var _dirty := false


func _ready() -> void:
	_apply_audio()


func spec_for(key: String) -> Dictionary:
	for entry in SPEC:
		if String(entry["key"]) == key:
			return entry
	return {}


func groups() -> Array:
	var out: Array = []
	for entry in SPEC:
		var g := String(entry["group"])
		if not out.has(g):
			out.append(g)
	return out


func specs_in(group: String) -> Array:
	var out: Array = []
	for entry in SPEC:
		if String(entry["group"]) == group:
			out.append(entry)
	return out


func value(key: String) -> Variant:
	return get(key)


func set_value(key: String, new_value: Variant) -> void:
	if spec_for(key).is_empty():
		return
	if get(key) == new_value:
		return
	set(key, new_value)
	if key in ["master_volume", "sfx_volume", "muted"]:
		_apply_audio()
	mark_dirty()


func toggle(key: String) -> void:
	set_value(key, not bool(get(key)))


func reset_to_defaults() -> void:
	for entry in SPEC:
		set(String(entry["key"]), entry["default"])
	_apply_audio()
	mark_dirty()


func _apply_audio() -> void:
	AudioManager.apply_levels(master_volume, sfx_volume, muted)


func mark_dirty() -> void:
	_dirty = true
	changed.emit()


func consume_dirty() -> bool:
	var was := _dirty
	_dirty = false
	return was


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for entry in SPEC:
		var key := String(entry["key"])
		out[key] = get(key)
	return out


func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	for entry in SPEC:
		var key := String(entry["key"])
		if not data.has(key):
			continue
		var want: Variant = data[key]
		# Guard against a save written by an older build with a different type.
		if typeof(want) == typeof(entry["default"]):
			set(key, want)
	_apply_audio()
	changed.emit()
