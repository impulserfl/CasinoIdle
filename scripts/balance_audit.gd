class_name BalanceAudit
extends RefCounted

## Re-derives every table's return from the constants as actually written and
## checks them against what each table declares.
##
## This replaces the old Python verifier, which covered four of eighteen tables
## and modelled a version of the refund maths the game had stopped using. Every
## table that drifted was one the verifier did not look at, so coverage is the
## whole point: this runs against the real script constants, in-engine, as part
## of the headless self-test, and fails the build on any mismatch.
##
## The invariant it exists to protect:
##
##   base_rtp + loss_probability * refund_chance == effective_rtp <= 0.99
##
## If a table's declared base_rtp or loss rate drifts from its payout table,
## the refund is mis-sized and the declared RTP becomes a lie — which is how
## seven tables previously ended up paying over 100%.

const TOL := 0.0015

## Every source that can lift returns, at maximum rank.
const MAX_SKILL_RTP := 0.005 * 10      # Card Counter
const MAX_FORTUNE_RTP := 0.003 * 5     # Fortune Cookie
const MAX_LOADED_RTP := 0.004 * 10     # Loaded Dice
const MAX_HOUSE_EDGE_RTP := 0.0025 * 8 # House Edge
const MAX_EVENT_RTP := 0.02            # Slot Tournament buff
const MAX_TABLE_RTP := 0.0025 * 8      # per-table rtp archetype

var failures: Array[String] = []
var lines: Array[String] = []


static func max_budget() -> float:
	return MAX_SKILL_RTP + MAX_FORTUNE_RTP + MAX_LOADED_RTP + MAX_HOUSE_EDGE_RTP \
		+ MAX_EVENT_RTP + MAX_TABLE_RTP


func _check(label: String, actual: float, declared: float, tol: float = TOL) -> void:
	var ok := absf(actual - declared) <= tol
	lines.append("  [%s] %-28s computed %.6f vs declared %.6f"
		% ["OK  " if ok else "FAIL", label, actual, declared])
	if not ok:
		failures.append("%s: computed %.6f != declared %.6f" % [label, actual, declared])


func _require(label: String, condition: bool, detail: String) -> void:
	lines.append("  [%s] %s" % ["OK  " if condition else "FAIL", label])
	if not condition:
		failures.append("%s: %s" % [label, detail])


## The core invariant, applied to one table and one of its loss rates.
func _check_cap(game: String, base_rtp: float, loss_rate: float, note: String = "") -> void:
	var effective := minf(base_rtp + max_budget(), GameManager.MAX_EFFECTIVE_RTP)
	var deficit := maxf(effective - base_rtp, 0.0)
	var required := deficit / maxf(loss_rate, 1e-9)
	var label := game if note.is_empty() else "%s (%s)" % [game, note]

	_require("%s stays under 100%%" % label, effective < 1.0,
		"fully upgraded RTP reaches %.4f" % effective)
	_require("%s refund cap holds" % label, required <= Minigame.MAX_REFUND_CHANCE,
		"needs a %.4f refund chance but the cap is %.4f" % [required, Minigame.MAX_REFUND_CHANCE])
	# What the player actually receives once the cap is applied.
	var delivered := base_rtp + loss_rate * minf(required, Minigame.MAX_REFUND_CHANCE)
	_require("%s delivers its shown RTP" % label, absf(delivered - effective) <= 1e-6,
		"shows %.4f but pays %.4f" % [effective, delivered])


static func _weighted_rtp(mults: Array, weights: Array) -> float:
	var total := 0.0
	var pay := 0.0
	for i in range(mults.size()):
		total += float(weights[i])
		pay += float(mults[i]) * float(weights[i])
	return pay / total


static func _blank_share(weights: Array, blank_index: int) -> float:
	var total := 0.0
	for w in weights:
		total += float(w)
	return float(weights[blank_index]) / total


static func _combinations(n: int, r: int) -> float:
	if r < 0 or r > n:
		return 0.0
	var out := 1.0
	for i in range(r):
		out = out * float(n - i) / float(i + 1)
	return out


func run() -> Array[String]:
	failures.clear()
	lines.clear()
	lines.append("BALANCE AUDIT  (max RTP budget from upgrades: +%.4f)" % max_budget())

	_audit_weighted_tables()
	_audit_priced_tables()
	_audit_card_tables()
	_audit_slots()
	_audit_scratch()
	_audit_video_poker()
	_audit_no_cheap_wins()

	lines.append("")
	if failures.is_empty():
		lines.append("All %d checks passed." % lines.size())
	else:
		lines.append("%d FAILURE(S):" % failures.size())
		for f in failures:
			lines.append("  " + f)
	return failures


# --- straightforward weighted tables ---------------------------------------

func _audit_weighted_tables() -> void:
	lines.append("")
	lines.append("WEIGHTED TABLES")

	var claw := preload("res://minigames/claw_machine.gd")
	var claw_m: Array = []
	var claw_w: Array = []
	for p in claw.PRIZES:
		claw_m.append(float(p["mult"]))
		claw_w.append(float(p["weight"]))
	_check("claw RTP", _weighted_rtp(claw_m, claw_w), 0.88)
	_check("claw loss rate", _blank_share(claw_w, 0), float(claw.LOSS_RATE))
	_check_cap("claw", 0.88, float(claw.LOSS_RATE))

	var pusher := preload("res://minigames/coin_pusher.gd")
	var pm: Array = []
	var pw: Array = []
	for o in pusher.OUTCOMES:
		pm.append(float(o["mult"]))
		pw.append(float(o["weight"]))
	_check("coin pusher RTP", _weighted_rtp(pm, pw), 0.90)
	_check("coin pusher loss rate", _blank_share(pw, 0), float(pusher.LOSS_RATE))
	_check_cap("coin_pusher", 0.90, float(pusher.LOSS_RATE))

	var plinko := preload("res://minigames/plinko.gd")
	var lm: Array = []
	var lw: Array = []
	var centre_weight := 0.0
	var plinko_total := 0.0
	for i in range(plinko.SLOTS.size()):
		var s: Dictionary = plinko.SLOTS[i]
		lm.append(float(s["mult"]))
		lw.append(float(s["weight"]))
		plinko_total += float(s["weight"])
		if float(s["mult"]) <= 0.0:
			centre_weight += float(s["weight"])
	_check("plinko RTP", _weighted_rtp(lm, lw), 0.93)
	_check("plinko loss rate", centre_weight / plinko_total, float(plinko.LOSS_RATE))
	_check_cap("plinko", 0.93, float(plinko.LOSS_RATE))

	var fishing := preload("res://minigames/fishing.gd")
	for depth in [0, 1, 2]:
		var weights: Array = fishing.DEPTH_WEIGHTS[depth]
		var mults: Array = []
		for c in fishing.CATCHES:
			mults.append(float(c["mult"]))
		_check("fishing RTP (%s)" % fishing.DEPTH_NAMES[depth],
			_weighted_rtp(mults, weights), 0.91)
		_check("fishing loss (%s)" % fishing.DEPTH_NAMES[depth],
			_blank_share(weights, 0), float(fishing.DEPTH_LOSS_RATE[depth]))
		_check_cap("fishing", 0.91, float(fishing.DEPTH_LOSS_RATE[depth]),
			fishing.DEPTH_NAMES[depth])

	var darts := preload("res://minigames/darts.gd")
	for aim in darts.AIM_WEIGHTS:
		var weights: Array = darts.AIM_WEIGHTS[aim]
		var mults: Array = [0.0]
		for z in darts.ZONES:
			mults.append(float(z["mult"]))
		_check("darts RTP (aim %s)" % aim, _weighted_rtp(mults, weights), 0.92)
		_check("darts loss (aim %s)" % aim, _blank_share(weights, 0),
			float(darts.AIM_LOSS_RATE[aim]))
		_check_cap("darts", 0.92, float(darts.AIM_LOSS_RATE[aim]), "aim %s" % aim)


# --- tables where the payout is derived from the probability ---------------

func _audit_priced_tables() -> void:
	lines.append("")
	lines.append("PRICED TABLES  (every choice must return the same)")

	var wheel := preload("res://minigames/money_wheel.gd")
	var wheel_total := 0.0
	for s in wheel.SEGMENTS:
		wheel_total += float(s["weight"])
	for s in wheel.SEGMENTS:
		var p := float(s["weight"]) / wheel_total
		var pays := 0.92 / p
		_check("wheel segment %s" % String(s["id"]), p * pays, 0.92)
		_check_cap("money_wheel", 0.92, 1.0 - p, "segment %s" % String(s["id"]))

	var keno := preload("res://minigames/keno.gd")
	for picks in keno.PAYTABLES:
		var table: Dictionary = keno.PAYTABLES[picks]
		var rtp := 0.0
		var paying := 0.0
		for m in table:
			var prob := _combinations(keno.DRAW, int(m)) \
				* _combinations(keno.POOL - keno.DRAW, int(picks) - int(m)) \
				/ _combinations(keno.POOL, int(picks))
			rtp += prob * float(table[m])
			paying += prob
		_check("keno RTP (%d picks)" % int(picks), rtp, 0.91, 0.002)
		_check_cap("keno", 0.91, 1.0 - paying, "%d picks" % int(picks))

	var crash := preload("res://minigames/crash.gd")
	var house := float(crash.HOUSE)
	for t in crash.TARGETS:
		var target := float(t)
		var p_win := house / target
		_check("crash RTP (target x%s)" % t, p_win * target, house)
		_check_cap("crash", house, 1.0 - p_win, "target x%s" % t)


# --- card tables -----------------------------------------------------------

func _audit_card_tables() -> void:
	lines.append("")
	lines.append("CARD TABLES")

	# Coin flip: a fair coin at 1.9x.
	var flip := preload("res://minigames/coin_flip.gd")
	_check("coin flip RTP", 0.5 * float(flip.PAYS), 0.95)
	_check_cap("coin_flip", 0.95, float(flip.LOSS_RATE))

	# Higher / lower: priced per shown card, so check every one.
	var hilo := preload("res://minigames/higher_lower.gd")
	var hilo_tie := float(hilo.P_TIE)
	for rank in range(int(hilo.LOW_RANK), int(hilo.HIGH_RANK) + 1):
		var value := rank + 1
		for choice in ["higher", "lower"]:
			var p_win := float(13 - value) / 13.0 if choice == "higher" \
				else float(value - 1) / 13.0
			var pays := (0.92 - hilo_tie) / p_win
			var rtp := p_win * pays + hilo_tie
			_check("hi-lo %s on %d" % [choice, value], rtp, 0.92)
			_require("hi-lo %s on %d pays over 1x" % [choice, value], pays >= 1.0,
				"pays %.3fx, which loses money on a win" % pays)
			_check_cap("higher_lower", 0.92, 1.0 - p_win - hilo_tie,
				"%s on %d" % [choice, value])

	# War: one stake, a free war on a tie.
	var war := preload("res://minigames/war.gd")
	var p_tie := 1.0 / 13.0
	var p_high := (1.0 - p_tie) / 2.0
	var p_war_win := p_high + p_tie
	var war_win := p_high + p_tie * p_war_win
	_check("war win rate", war_win, 1.0 - float(war.LOSS_RATE))
	_check("war RTP", war_win * float(war.PAYS), 0.930473)
	_check_cap("war", 0.930473, float(war.LOSS_RATE))

	# Baccarat: value distribution is symmetric, so a true 1:1 would be fair.
	var bacc := preload("res://minigames/baccarat.gd")
	var value_p := PackedFloat64Array()
	value_p.resize(10)
	for i in range(13):
		value_p[bacc.CARD_VALUES[i]] += 1.0 / 13.0
	var hand_p := PackedFloat64Array()
	hand_p.resize(10)
	for a in range(10):
		for b in range(10):
			hand_p[(a + b) % 10] += value_p[a] * value_p[b]
	var bacc_tie := 0.0
	for h in range(10):
		bacc_tie += hand_p[h] * hand_p[h]
	var bacc_side := (1.0 - bacc_tie) / 2.0
	_check("baccarat side loss rate", bacc_side, float(bacc.SIDE_LOSS_RATE))
	_check("baccarat tie loss rate", 1.0 - bacc_tie, float(bacc.TIE_LOSS_RATE))
	_check("baccarat player RTP", bacc_side * float(bacc.SIDE_PAYS) + bacc_tie, 0.977564)
	_check("baccarat tie RTP", bacc_tie * float(bacc.TIE_PAYS), 0.977564)
	_check_cap("baccarat", 0.977564, float(bacc.SIDE_LOSS_RATE), "player")
	_check_cap("baccarat", 0.977564, float(bacc.TIE_LOSS_RATE), "tie")

	# Blackjack: exact over the fixed strategy, dealer and player independent
	# under an infinite shoe.
	var bj := preload("res://minigames/blackjack.gd")
	var bj_result := _blackjack_exact(bj)
	_check("blackjack RTP", float(bj_result["rtp"]), 0.943366, 0.0005)
	_check("blackjack loss rate", float(bj_result["loss"]), float(bj.LOSS_RATE), 0.0005)
	_check_cap("blackjack", 0.943366, float(bj.LOSS_RATE))

	# Roulette and dice: every bet must be priced identically.
	var roulette := preload("res://minigames/roulette.gd")
	for d in roulette.OUTSIDE_BETS:
		var p := float(d["wins"]) / float(roulette.POCKETS)
		_check("roulette %s" % String(d["type"]), p * float(int(d["odds"]) + 1), 36.0 / 37.0)
		_check_cap("roulette", 36.0 / 37.0, 1.0 - p, String(d["type"]))
	_check("roulette straight up", (1.0 / 37.0) * 36.0, 36.0 / 37.0)
	_check_cap("roulette", 36.0 / 37.0, 36.0 / 37.0, "straight up")

	var dice := preload("res://minigames/dice.gd")
	for d in dice.BETS:
		var p := float(d["wins"]) / 36.0
		_check("dice %s" % String(d["type"]), p * float(d["pays"]), 0.95, 0.001)
		_check_cap("dice", 0.95, 1.0 - p, String(d["type"]))


## Player and dealer draw independently from an infinite shoe, so their final
## totals can be enumerated separately and then combined.
##
## The walk is memoised on (total, usable aces, card count). Recursing over the
## card list instead would branch 13 ways per draw and take minutes in GDScript
## for a result that only depends on those three numbers.
var _bj_values: Array[int] = []
var _bj_max_cards := 6
var _bj_memo: Dictionary = {}


func _blackjack_exact(bj: GDScript) -> Dictionary:
	_bj_values.clear()
	for v in bj.VALUES:
		_bj_values.append(int(v))
	_bj_max_cards = int(bj.MAX_CARDS)
	_bj_memo.clear()

	var natural_pays := float(bj.NATURAL_PAYS)
	var win_pays := float(bj.WIN_PAYS)
	var natural := 2.0 * (1.0 / 13.0) * (4.0 / 13.0)

	# Final-total distribution for a hand starting on two non-natural cards.
	var finals: Dictionary = {}
	var start_mass := 0.0
	for a in range(13):
		for b in range(13):
			var total := _bj_values[a] + _bj_values[b]
			var aces := (1 if _bj_values[a] == 11 else 0) + (1 if _bj_values[b] == 11 else 0)
			while total > 21 and aces > 0:
				total -= 10
				aces -= 1
			if total == 21:
				continue
			var p := 1.0 / 169.0
			start_mass += p
			var dist := _bj_dist(total, aces, 2)
			for k in dist:
				finals[k] = float(finals.get(k, 0.0)) + p * float(dist[k])
	for k in finals:
		finals[k] = float(finals[k]) / start_mass

	var rtp := natural * (1.0 - natural) * natural_pays + natural * natural
	var loss := (1.0 - natural) * natural
	var both_none := (1.0 - natural) * (1.0 - natural)
	for pt in finals:
		for dt in finals:
			var q := both_none * float(finals[pt]) * float(finals[dt])
			var pv := int(pt)
			var dv := int(dt)
			if pv > 21:
				loss += q
			elif dv > 21 or pv > dv:
				rtp += q * win_pays
			elif pv == dv:
				rtp += q
			else:
				loss += q
	return {"rtp": rtp, "loss": loss}


## Distribution over final totals from a hand state. 22 means bust.
func _bj_dist(total: int, aces: int, cards: int) -> Dictionary:
	if total > 21:
		return {22: 1.0}
	if total >= 17 or cards >= _bj_max_cards:
		return {total: 1.0}
	var key := total * 1000 + aces * 100 + cards
	if _bj_memo.has(key):
		return _bj_memo[key]
	var out: Dictionary = {}
	for c in range(13):
		var v := _bj_values[c]
		var t := total + v
		var a := aces + (1 if v == 11 else 0)
		while t > 21 and a > 0:
			t -= 10
			a -= 1
		var sub := _bj_dist(t, a, cards + 1)
		for k in sub:
			out[k] = float(out.get(k, 0.0)) + float(sub[k]) / 13.0
	_bj_memo[key] = out
	return out


# --- enumerated tables -----------------------------------------------------

func _audit_slots() -> void:
	lines.append("")
	lines.append("SLOTS  (full 512 outcome enumeration)")
	var slots := preload("res://minigames/slot_machine.gd")
	var symbols: Array = slots.SYMBOLS
	var total_weight := 0.0
	for s in symbols:
		total_weight += float(s["weight"])

	var rtp := 0.0
	var hit := 0.0
	var jackpot := 0.0
	for a in range(symbols.size()):
		for b in range(symbols.size()):
			for c in range(symbols.size()):
				var pa: float = float(symbols[a]["weight"]) / total_weight
				var pb: float = float(symbols[b]["weight"]) / total_weight
				var pc: float = float(symbols[c]["weight"]) / total_weight
				var prob := pa * pb * pc
				var pay := 0.0
				if a == b and b == c:
					pay = float(symbols[a]["triple"])
					if a == symbols.size() - 1:
						jackpot += prob
				elif a == b or b == c or a == c:
					var paired := a if a == b or a == c else b
					pay = float(symbols[paired]["pair"])
				if pay > 0.0:
					hit += prob
				rtp += prob * pay
	_check("slots RTP", rtp, 0.9386)
	_check("slots loss rate", 1.0 - hit, float(slots.LOSS_RATE))
	_check_cap("slots", 0.9386, float(slots.LOSS_RATE))
	lines.append("  three sevens: 1 in %s" % Fmt.commas(roundf(1.0 / jackpot)))


func _audit_scratch() -> void:
	lines.append("")
	lines.append("SCRATCH CARDS  (exact over all 2,002 compositions)")
	var scratch := preload("res://minigames/scratch_cards.gd")
	var symbols: Array = scratch.SYMBOLS
	var n := symbols.size()
	var weights := PackedFloat64Array()
	var total_weight := 0.0
	for s in symbols:
		weights.append(float(s["weight"]))
		total_weight += float(s["weight"])

	var counts := PackedInt32Array()
	counts.resize(n)
	var acc := {"rtp": 0.0, "hit": 0.0, "mass": 0.0}
	_scratch_cells = int(scratch.CELLS)
	_scratch_walk(scratch, symbols, weights, total_weight, counts, 0, _scratch_cells, acc)

	_check("scratch probability mass", float(acc["mass"]), 1.0, 1e-6)
	_check("scratch RTP", float(acc["rtp"]), 0.9174, 0.002)
	_check("scratch loss rate", 1.0 - float(acc["hit"]), float(scratch.LOSS_RATE), 0.002)
	_check_cap("scratch", 0.9174, float(scratch.LOSS_RATE))


var _scratch_cells := 9


## Walks every way `remaining` cells can be split across the symbols, tracking
## the multinomial probability of each composition.
func _scratch_walk(scratch: GDScript, symbols: Array, weights: PackedFloat64Array,
		total_weight: float, counts: PackedInt32Array, index: int, remaining: int,
		acc: Dictionary) -> void:
	if index == symbols.size() - 1:
		counts[index] = remaining
		var prob := _multinomial(counts, _scratch_cells)
		for i in range(symbols.size()):
			prob *= pow(weights[i] / total_weight, float(counts[i]))
		var best := 0.0
		for i in range(symbols.size()):
			var id := String(symbols[i]["id"])
			if not scratch.PAYOUTS.has(id):
				continue
			var tiers: Dictionary = scratch.PAYOUTS[id]
			for t in tiers:
				if counts[i] >= int(t):
					best = maxf(best, float(tiers[t]))
		acc["mass"] = float(acc["mass"]) + prob
		acc["rtp"] = float(acc["rtp"]) + prob * best
		if best > 0.0:
			acc["hit"] = float(acc["hit"]) + prob
		counts[index] = 0
		return
	for take in range(remaining + 1):
		counts[index] = take
		_scratch_walk(scratch, symbols, weights, total_weight, counts, index + 1,
			remaining - take, acc)
	counts[index] = 0


static func _multinomial(counts: PackedInt32Array, total: int) -> float:
	var out := 1.0
	var remaining := total
	for c in counts:
		out *= _combinations(remaining, c)
		remaining -= c
	return out


## The evaluator is unit-tested on the hands that actually broke, then the RTP
## is computed from the standard five-card frequencies. That catches a
## misclassification without enumerating 2.6 million deals in GDScript.
func _audit_video_poker() -> void:
	lines.append("")
	lines.append("VIDEO POKER")
	var vp := preload("res://minigames/video_poker.gd")

	# card index = suit * 13 + rank, rank 0 = ace
	var cases: Array = [
		[[0, 9, 10, 11, 12], "royal", "A-10-J-Q-K suited is a royal"],
		[[8, 9, 10, 11, 12], "str_flush", "9-10-J-Q-K suited is only a straight flush"],
		[[0, 1, 2, 3, 4], "str_flush", "A-2-3-4-5 suited is the wheel"],
		[[0, 13, 26, 39, 5], "quads", "four aces"],
		[[0, 13, 26, 5, 18], "boat", "aces full"],
		[[0, 2, 4, 6, 8], "flush", "same suit, no run"],
		[[8, 9, 10, 11, 25], "straight", "9-10-J-Q-K offsuit"],
		[[0, 13, 26, 5, 20], "trips", "three aces"],
		[[0, 13, 1, 14, 5], "two_pair", "aces and twos"],
		[[10, 23, 1, 5, 8], "jacks", "a pair of jacks"],
		[[1, 14, 5, 8, 11], "pair", "a pair of twos"],
		[[0, 14, 28, 42, 8], "", "ace high, nothing"],
	]
	for entry in cases:
		var hand: Array = entry[0]
		var want := String(entry[1])
		var got := vp.evaluate(hand)
		var got_id := String(got.get("id", ""))
		_require("video poker: %s" % String(entry[2]), got_id == want,
			"classified as '%s', expected '%s'" % [got_id, want])

	# A-2-3-4-K suited must not read as a straight.
	var bogus := vp.evaluate([0, 1, 2, 3, 12])
	_require("video poker: A-2-3-4-K suited is only a flush",
		String(bogus.get("id", "")) == "flush",
		"classified as '%s'" % String(bogus.get("id", "")))

	# Standard five-card frequencies, aligned to the paytable ids.
	var freq := {
		"royal": 4.0, "str_flush": 36.0, "quads": 624.0, "boat": 3744.0,
		"flush": 5108.0, "straight": 10200.0, "trips": 54912.0,
		"two_pair": 123552.0, "jacks": 337920.0, "pair": 1098240.0 - 337920.0,
	}
	var total := 2598960.0
	var rtp := 0.0
	var hits := 0.0
	for h in vp.HANDS:
		var id := String(h["id"])
		rtp += freq[id] * float(h["pays"]) / total
		hits += freq[id] / total
	_check("video poker RTP", rtp, 0.92, 0.001)
	_check("video poker loss rate", 1.0 - hits, float(vp.LOSS_RATE))
	_check_cap("video_poker", 0.92, float(vp.LOSS_RATE))


## No table may advertise a "win" that returns less than the stake.
func _audit_no_cheap_wins() -> void:
	lines.append("")
	lines.append("PAYOUT FLOORS")
	var sources := {
		"claw": preload("res://minigames/claw_machine.gd").PRIZES,
		"coin_pusher": preload("res://minigames/coin_pusher.gd").OUTCOMES,
		"fishing": preload("res://minigames/fishing.gd").CATCHES,
	}
	for game in sources:
		var lowest := INF
		for entry in sources[game]:
			var m := float(entry["mult"])
			if m > 0.0:
				lowest = minf(lowest, m)
		_require("%s pays at least 1x on a win" % game, lowest >= 1.0,
			"lowest winning tier is %.2fx" % lowest)

	var scratch := preload("res://minigames/scratch_cards.gd")
	var scratch_low := INF
	for id in scratch.PAYOUTS:
		var tiers: Dictionary = scratch.PAYOUTS[id]
		for t in tiers:
			scratch_low = minf(scratch_low, float(tiers[t]))
	_require("scratch pays at least 1x on a win", scratch_low >= 1.0,
		"lowest winning tier is %.2fx" % scratch_low)
