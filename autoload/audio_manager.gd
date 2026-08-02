extends Node

## A small additive synthesiser, so the game ships sound without shipping audio
## files.
##
## The previous version was one sine wave per effect, rebuilt sample by sample
## on *every* play — a jackpot tone meant six thousand GDScript iterations in
## the middle of a spin. Everything here is rendered once at boot into an
## AudioStreamWAV and then replayed from cache, and each effect is a stack of
## voices with real envelopes rather than a bare tone.

enum Sfx {
	CLICK, SPIN, WIN_SMALL, WIN_MEDIUM, WIN_BIG, JACKPOT,
	LEVEL_UP, PRESTIGE, BUY, ERROR, REFUND, TICK,
}

const SAMPLE_RATE := 22050
const POOL_SIZE := 12

## Equal-temperament note table. Building effects out of intervals rather than
## arbitrary frequencies is what stops them sounding like error beeps.
const A4 := 440.0

var master_volume: float = 0.85
var sfx_volume: float = 1.0
var muted: bool = false
## When false every play_* call is a no-op — used by the headless smoke test.
var enabled: bool = true

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _cache: Dictionary = {}


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_all()
	_apply_volumes()


## Semitones from A4. note(3) is C5, note(0) is A4.
static func note(semitones: float) -> float:
	return A4 * pow(2.0, semitones / 12.0)


# ===========================================================================
# VOICE MODEL
# ===========================================================================

## One oscillator with an ADSR envelope. `f1` glides the pitch across the
## voice's life when it differs from `f0`.
static func voice(wave: String, f0: float, start: float, dur: float, amp: float,
		attack := 0.004, decay := 0.05, sustain := 0.7, release := 0.10,
		f1 := -1.0) -> Dictionary:
	return {
		"wave": wave, "f0": f0, "f1": f1 if f1 > 0.0 else f0,
		"start": start, "dur": dur, "amp": amp,
		"a": attack, "d": decay, "s": sustain, "r": release,
	}


static func _envelope(t: float, dur: float, a: float, d: float, s: float, r: float) -> float:
	if t < 0.0 or t > dur + r:
		return 0.0
	if t < a:
		return t / maxf(a, 0.0001)
	if t < a + d:
		return 1.0 - (1.0 - s) * ((t - a) / maxf(d, 0.0001))
	if t < dur:
		return s
	return s * (1.0 - (t - dur) / maxf(r, 0.0001))


static func _wave_sample(wave: String, phase: float) -> float:
	match wave:
		"sine":
			return sin(phase)
		"square":
			return 1.0 if fmod(phase, TAU) < PI else -1.0
		"tri":
			var x := fmod(phase, TAU) / TAU
			return 4.0 * absf(x - 0.5) - 1.0
		"saw":
			return 2.0 * (fmod(phase, TAU) / TAU) - 1.0
		"noise":
			return randf() * 2.0 - 1.0
	return sin(phase)


func _render(voices: Array) -> AudioStreamWAV:
	var total := 0.0
	for v in voices:
		total = maxf(total, float(v["start"]) + float(v["dur"]) + float(v["r"]))
	total += 0.01
	var count := int(SAMPLE_RATE * total)
	var buffer := PackedFloat32Array()
	buffer.resize(count)

	for v in voices:
		var wave := String(v["wave"])
		var f0 := float(v["f0"])
		var f1 := float(v["f1"])
		var start_i := int(float(v["start"]) * SAMPLE_RATE)
		var life := float(v["dur"]) + float(v["r"])
		var life_i := int(life * SAMPLE_RATE)
		var amp := float(v["amp"])
		var phase := 0.0
		for i in range(life_i):
			var idx := start_i + i
			if idx < 0 or idx >= count:
				continue
			var t := float(i) / float(SAMPLE_RATE)
			var env := _envelope(t, float(v["dur"]), float(v["a"]), float(v["d"]),
				float(v["s"]), float(v["r"]))
			if env <= 0.0:
				continue
			var freq := lerpf(f0, f1, clampf(t / maxf(life, 0.0001), 0.0, 1.0))
			phase += TAU * freq / float(SAMPLE_RATE)
			buffer[idx] += _wave_sample(wave, phase) * env * amp

	# Soft-clip rather than hard-clamp so stacked voices stay musical.
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var s: float = buffer[i]
		s = s / (1.0 + absf(s) * 0.6)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


# ===========================================================================
# THE KIT
# ===========================================================================

func _build_all() -> void:
	# A soft wooden click: a short mid sine with a noise transient on top.
	_cache[Sfx.CLICK] = _render([
		voice("sine", note(15), 0.0, 0.020, 0.30, 0.001, 0.012, 0.25, 0.030),
		voice("noise", 1.0, 0.0, 0.008, 0.10, 0.001, 0.006, 0.0, 0.010),
	])

	# Reels starting: filtered noise with a falling body.
	_cache[Sfx.SPIN] = _render([
		voice("noise", 1.0, 0.0, 0.055, 0.12, 0.004, 0.030, 0.35, 0.040),
		voice("tri", note(-9), 0.0, 0.060, 0.16, 0.003, 0.030, 0.40, 0.050, note(-14)),
	])

	# A single detent tick, used by the reels and the wheel.
	_cache[Sfx.TICK] = _render([
		voice("square", note(24), 0.0, 0.010, 0.10, 0.001, 0.006, 0.2, 0.014),
	])

	# Wins are a major triad, extended as the multiplier climbs. Same root each
	# time so consecutive wins sound like one instrument rather than a scale.
	_cache[Sfx.WIN_SMALL] = _render([
		voice("sine", note(3), 0.00, 0.09, 0.26, 0.004, 0.05, 0.6, 0.10),
		voice("sine", note(7), 0.05, 0.11, 0.22, 0.004, 0.05, 0.6, 0.12),
	])
	_cache[Sfx.WIN_MEDIUM] = _render([
		voice("sine", note(3), 0.00, 0.09, 0.26, 0.004, 0.05, 0.6, 0.10),
		voice("sine", note(7), 0.05, 0.10, 0.24, 0.004, 0.05, 0.6, 0.11),
		voice("sine", note(10), 0.10, 0.14, 0.24, 0.004, 0.05, 0.6, 0.16),
		voice("tri", note(-9), 0.00, 0.20, 0.08, 0.006, 0.08, 0.5, 0.12),
	])
	_cache[Sfx.WIN_BIG] = _render([
		voice("sine", note(3), 0.00, 0.09, 0.26, 0.004, 0.05, 0.6, 0.10),
		voice("sine", note(7), 0.06, 0.09, 0.26, 0.004, 0.05, 0.6, 0.10),
		voice("sine", note(10), 0.12, 0.10, 0.26, 0.004, 0.05, 0.6, 0.12),
		voice("sine", note(15), 0.18, 0.22, 0.28, 0.004, 0.06, 0.6, 0.22),
		voice("tri", note(-9), 0.00, 0.34, 0.10, 0.008, 0.10, 0.5, 0.16),
	])

	# Jackpot: the full arpeggio, a shimmer above it and a low swell beneath.
	var jackpot: Array = [
		voice("tri", note(-21), 0.00, 0.50, 0.14, 0.010, 0.12, 0.6, 0.30),
		voice("sine", note(-9), 0.00, 0.50, 0.10, 0.010, 0.12, 0.6, 0.30),
	]
	var ladder := [3, 7, 10, 15, 19, 22, 27]
	for i in range(ladder.size()):
		jackpot.append(voice("sine", note(ladder[i]), 0.05 * i, 0.10, 0.24,
			0.003, 0.05, 0.55, 0.18))
	for i in range(5):
		jackpot.append(voice("sine", note(31 + i * 5), 0.34 + 0.045 * i, 0.05, 0.11,
			0.002, 0.03, 0.4, 0.16))
	_cache[Sfx.JACKPOT] = _render(jackpot)

	# Level up: a confident rising fifth with a bright octave on top.
	_cache[Sfx.LEVEL_UP] = _render([
		voice("sine", note(3), 0.00, 0.10, 0.26, 0.004, 0.05, 0.65, 0.12),
		voice("sine", note(10), 0.09, 0.20, 0.28, 0.004, 0.06, 0.65, 0.22),
		voice("sine", note(15), 0.09, 0.20, 0.14, 0.004, 0.06, 0.65, 0.22),
		voice("tri", note(-9), 0.00, 0.28, 0.09, 0.008, 0.10, 0.5, 0.16),
	])

	# Prestige: a slow low swell resolving up an octave. Deliberately the
	# longest sound in the game — it only fires when a run ends.
	_cache[Sfx.PRESTIGE] = _render([
		voice("tri", note(-21), 0.00, 0.55, 0.18, 0.10, 0.20, 0.75, 0.35, note(-14)),
		voice("sine", note(-9), 0.10, 0.50, 0.14, 0.08, 0.18, 0.70, 0.35),
		voice("sine", note(3), 0.30, 0.42, 0.16, 0.05, 0.14, 0.70, 0.35),
		voice("sine", note(15), 0.50, 0.38, 0.12, 0.04, 0.12, 0.60, 0.35),
	])

	# Buy: a two-part "ka-chink", low body then a coin-bright tail.
	_cache[Sfx.BUY] = _render([
		voice("square", note(-2), 0.000, 0.022, 0.14, 0.001, 0.014, 0.3, 0.030),
		voice("sine", note(19), 0.030, 0.035, 0.20, 0.002, 0.020, 0.4, 0.060),
		voice("sine", note(26), 0.030, 0.045, 0.10, 0.002, 0.020, 0.4, 0.070),
	])

	# Error: a short dissonant buzz. A minor second is unpleasant on purpose.
	_cache[Sfx.ERROR] = _render([
		voice("square", note(-14), 0.0, 0.10, 0.16, 0.003, 0.04, 0.6, 0.08),
		voice("square", note(-13), 0.0, 0.10, 0.12, 0.003, 0.04, 0.6, 0.08),
	])

	# Refund: gentle, resolving downward so it reads as consolation not reward.
	_cache[Sfx.REFUND] = _render([
		voice("sine", note(10), 0.00, 0.09, 0.20, 0.006, 0.05, 0.6, 0.10),
		voice("sine", note(3), 0.07, 0.16, 0.20, 0.006, 0.06, 0.6, 0.16),
	])


# ===========================================================================
# PLAYBACK
# ===========================================================================

func apply_levels(master: float, sfx: float, is_muted: bool) -> void:
	master_volume = clampf(master, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	muted = is_muted
	_apply_volumes()


func _apply_volumes() -> void:
	var linear := 0.0 if muted else master_volume * sfx_volume
	var db := -80.0 if linear <= 0.0 else linear_to_db(linear)
	for p in _players:
		p.volume_db = db


func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	# Everything is busy: round-robin so the same voice is not always stolen.
	_next_player = (_next_player + 1) % _players.size()
	return _players[_next_player]


func play(kind: Sfx) -> void:
	if not enabled or muted or master_volume <= 0.0 or sfx_volume <= 0.0:
		return
	if not _cache.has(kind):
		return
	var player := _get_player()
	player.stream = _cache[kind]
	player.play()


func play_click() -> void:
	play(Sfx.CLICK)


func play_spin() -> void:
	play(Sfx.SPIN)


func play_tick() -> void:
	play(Sfx.TICK)


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
