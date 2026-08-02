extends Node

## Lightweight SFX manager using generated tones so the game has feedback
## without shipping audio assets. Volumes and mute state are persisted via
## SaveManager settings.

enum Sfx {
	CLICK,
	SPIN,
	WIN_SMALL,
	WIN_MEDIUM,
	WIN_BIG,
	JACKPOT,
	LEVEL_UP,
	PRESTIGE,
	BUY,
	ERROR,
	REFUND,
}

var master_volume: float = 0.85:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_apply_volumes()

var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_volumes()

var muted: bool = false:
	set(v):
		muted = v
		_apply_volumes()

## When false, all play_* calls no-op (useful for silent auto-play testing).
var enabled: bool = true

var _players: Array[AudioStreamPlayer] = []
var _bus_idx: int = 0
const POOL_SIZE := 8


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_apply_volumes()


func _apply_volumes() -> void:
	var linear := 0.0 if muted else master_volume * sfx_volume
	# Godot volume_db: 0 = full, -80 ≈ silent
	var db := linear_to_db(maxf(linear, 0.0001)) if linear > 0.0 else -80.0
	for p in _players:
		p.volume_db = db


func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	# All busy — steal the first
	return _players[0]


func play(kind: Sfx) -> void:
	if not enabled or muted or master_volume <= 0.0 or sfx_volume <= 0.0:
		return
	var spec := _spec(kind)
	if spec.is_empty():
		return
	var player := _get_player()
	player.stream = _make_tone(spec)
	player.pitch_scale = float(spec.get("pitch", 1.0))
	player.play()


func play_click() -> void:
	play(Sfx.CLICK)


func play_spin() -> void:
	play(Sfx.SPIN)


func play_win(multiplier: float) -> void:
	if multiplier >= 50.0:
		play(Sfx.JACKPOT)
	elif multiplier >= 10.0:
		play(Sfx.WIN_BIG)
	elif multiplier >= 3.0:
		play(Sfx.WIN_MEDIUM)
	else:
		play(Sfx.WIN_SMALL)


func play_level_up() -> void:
	play(Sfx.LEVEL_UP)


func play_prestige() -> void:
	play(Sfx.PRESTIGE)


func play_buy() -> void:
	play(Sfx.BUY)


func play_error() -> void:
	play(Sfx.ERROR)


func play_refund() -> void:
	play(Sfx.REFUND)


# ===========================================================================
# TONE GENERATION
# ===========================================================================

func _spec(kind: Sfx) -> Dictionary:
	match kind:
		Sfx.CLICK:
			return {"freq": 880.0, "ms": 35, "vol": 0.25, "pitch": 1.0}
		Sfx.SPIN:
			return {"freq": 220.0, "ms": 50, "vol": 0.18, "pitch": 1.15}
		Sfx.WIN_SMALL:
			return {"freq": 523.25, "ms": 90, "vol": 0.30, "pitch": 1.0}   # C5
		Sfx.WIN_MEDIUM:
			return {"freq": 659.25, "ms": 120, "vol": 0.35, "pitch": 1.0}  # E5
		Sfx.WIN_BIG:
			return {"freq": 783.99, "ms": 160, "vol": 0.40, "pitch": 1.0}  # G5
		Sfx.JACKPOT:
			return {"freq": 1046.5, "ms": 280, "vol": 0.45, "pitch": 1.0}  # C6
		Sfx.LEVEL_UP:
			return {"freq": 698.46, "ms": 180, "vol": 0.35, "pitch": 1.1}
		Sfx.PRESTIGE:
			return {"freq": 440.0, "ms": 320, "vol": 0.40, "pitch": 0.85}
		Sfx.BUY:
			return {"freq": 660.0, "ms": 70, "vol": 0.28, "pitch": 1.05}
		Sfx.ERROR:
			return {"freq": 160.0, "ms": 100, "vol": 0.30, "pitch": 0.9}
		Sfx.REFUND:
			return {"freq": 392.0, "ms": 110, "vol": 0.28, "pitch": 1.0}
	return {}


## Builds a short mono sine (with quick attack/release) as an AudioStreamWAV.
func _make_tone(spec: Dictionary) -> AudioStreamWAV:
	var freq: float = float(spec.get("freq", 440.0))
	var ms: float = float(spec.get("ms", 80.0))
	var vol: float = float(spec.get("vol", 0.3))
	var sample_rate := 22050
	var sample_count := int(sample_rate * ms / 1000.0)
	var data := PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit mono

	var attack := int(sample_rate * 0.008)
	var release := int(sample_rate * 0.020)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var env := 1.0
		if i < attack:
			env = float(i) / float(maxi(attack, 1))
		elif i > sample_count - release:
			env = float(sample_count - i) / float(maxi(release, 1))
		var sample := int(clampf(sin(TAU * freq * t) * vol * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
