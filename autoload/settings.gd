extends Node

## Player preferences that are not part of the run state.
## Persisted by SaveManager under the [settings] section.

signal changed()

var auto_spin_sfx: bool = true
var confirm_prestige: bool = true
var _dirty := false


func mark_dirty() -> void:
	_dirty = true
	changed.emit()


func consume_dirty() -> bool:
	var was := _dirty
	_dirty = false
	return was


func to_dict() -> Dictionary:
	return {
		"master_volume": AudioManager.master_volume,
		"sfx_volume": AudioManager.sfx_volume,
		"muted": AudioManager.muted,
		"auto_spin_sfx": auto_spin_sfx,
		"confirm_prestige": confirm_prestige,
	}


func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	AudioManager.master_volume = float(data.get("master_volume", 0.85))
	AudioManager.sfx_volume = float(data.get("sfx_volume", 1.0))
	AudioManager.muted = bool(data.get("muted", false))
	auto_spin_sfx = bool(data.get("auto_spin_sfx", true))
	confirm_prestige = bool(data.get("confirm_prestige", true))
	changed.emit()
