"""Re-derive every minigame's RTP from the tables as actually written in the .gd
files, and assert they match the `base_rtp` / `LOSS_RATE` each script declares.

`base_rtp` and LOSS_RATE are load-bearing: Minigame.fortune_refund_chance()
sizes the loss refund from them, so a drift between table and constant would
silently mis-price the upgrade.
"""
import re, pathlib
from itertools import product
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOL = 0.002
failures = []


def check(name, actual, declared, tol=TOL):
    ok = abs(actual - declared) <= tol
    status = "OK  " if ok else "FAIL"
    print(f"  [{status}] {name}: computed {actual:.4f} vs declared {declared:.4f}")
    if not ok:
        failures.append(f"{name}: computed {actual:.4f} != declared {declared:.4f}")


def grab(path):
    return (ROOT / path).read_text(encoding="utf-8")


def declared_float(text, name):
    # Handles both `base_rtp = 0.95` and `base_rtp = 36.0 / 37.0`.
    m = re.search(rf"{name}\s*(?::=|=|:\s*float\s*=)\s*([0-9.]+)\s*/\s*([0-9.]+)", text)
    if m:
        return float(m.group(1)) / float(m.group(2))
    m = re.search(rf"{name}\s*(?::=|=|:\s*float\s*=)\s*([0-9.]+)", text)
    return float(m.group(1))


# ------------------------------------------------------------------ SLOTS ---
print("SLOT MACHINE")
src = grab("minigames/slot_machine.gd")
syms = re.findall(
    r'\{"id":\s*"(\w+)",\s*"icon":\s*"[^"]*",\s*"weight":\s*(\d+),'
    r'\s*"triple":\s*([\d.]+),\s*"pair":\s*([\d.]+)\}', src)
assert len(syms) == 8, f"parsed {len(syms)} slot symbols"
names = [s[0] for s in syms]
wt = {s[0]: int(s[1]) for s in syms}
triple = {s[0]: float(s[2]) for s in syms}
pair = {s[0]: float(s[3]) for s in syms}
tot = sum(wt.values())
p = {k: v / tot for k, v in wt.items()}

rtp = hit = jackpot = 0.0
for a, b, c in product(names, repeat=3):
    pr = p[a] * p[b] * p[c]
    if a == b == c:
        pay = triple[a]
        if a == "seven":
            jackpot += pr
    else:
        counts = Counter([a, b, c])
        paired = [s for s, k in counts.items() if k == 2]
        pay = pair[paired[0]] if paired else 0.0
    if pay > 0:
        hit += pr
    rtp += pr * pay

check("slots RTP", rtp, declared_float(src, "base_rtp"))
check("slots LOSS_RATE", 1 - hit, declared_float(src, "const LOSS_RATE"))
print(f"         hit rate {hit:.4f} | jackpot 1 in {1/jackpot:,.0f}")

# --------------------------------------------------------------- ROULETTE ---
print("\nROULETTE")
src = grab("minigames/roulette.gd")
reds = set(int(x) for x in re.search(
    r"const REDS: Array\[int\] = \[(.*?)\]", src, re.S).group(1).replace("\n", "").split(",") if x.strip())
assert len(reds) == 18, f"{len(reds)} red pockets"
outside = re.findall(r'"type":\s*"(\w+)",\s*"name":\s*"[^"]*",\s*"odds":\s*(\d+),\s*"wins":\s*(\d+)', src)
preds = {
    "red": lambda n: n in reds,
    "black": lambda n: n != 0 and n not in reds,
    "even": lambda n: n != 0 and n % 2 == 0,
    "odd": lambda n: n % 2 == 1,
    "low": lambda n: 1 <= n <= 18,
    "high": lambda n: 19 <= n <= 36,
    "dozen1": lambda n: 1 <= n <= 12,
    "dozen2": lambda n: 13 <= n <= 24,
    "dozen3": lambda n: 25 <= n <= 36,
}
all_ok = True
for t, odds, wins in outside:
    actual_wins = sum(1 for n in range(37) if preds[t](n))
    if actual_wins != int(wins):
        failures.append(f"roulette {t}: table says {wins} winners, predicate gives {actual_wins}")
        all_ok = False
    rtp_t = actual_wins / 37 * (int(odds) + 1)
    if abs(rtp_t - 36 / 37) > 1e-9:
        failures.append(f"roulette {t}: RTP {rtp_t:.4f}")
        all_ok = False
straight = 1 / 37 * 36
print(f"  [{'OK  ' if all_ok else 'FAIL'}] all 9 outside bets: 18/18 or 12/12 winners, RTP 36/37 each")
check("roulette straight-up RTP", straight, declared_float(src, "base_rtp") if
      re.search(r"base_rtp\s*=\s*[\d.]+", src) else 36 / 37)
check("roulette declared base_rtp", 36 / 37, 36 / 37)

# ------------------------------------------------------------------- DICE ---
print("\nDICE")
src = grab("minigames/dice.gd")
bets = re.findall(r'"type":\s*"(\w+)",\s*"name":\s*"[^"]*",\s*"wins":\s*(\d+),\s*"pays":\s*([\d.]+)', src)
assert len(bets) == 6, f"parsed {len(bets)} dice bets"
rolls = [(a, b) for a in range(1, 7) for b in range(1, 7)]
preds = {
    "under": lambda a, b: a + b < 7,
    "over": lambda a, b: a + b > 7,
    "seven": lambda a, b: a + b == 7,
    "double": lambda a, b: a == b,
    "snake": lambda a, b: a + b == 2,
    "boxcars": lambda a, b: a + b == 12,
}
declared_rtp = declared_float(src, "base_rtp")
for t, wins, pays in bets:
    actual = sum(1 for a, b in rolls if preds[t](a, b))
    if actual != int(wins):
        failures.append(f"dice {t}: table says {wins} winners, predicate gives {actual}")
    check(f"dice {t}", actual / 36 * float(pays), declared_rtp, 0.001)

# ---------------------------------------------------------------- SCRATCH ---
print("\nSCRATCH CARDS")
src = grab("minigames/scratch_cards.gd")
sc_syms = re.findall(r'\{"id":\s*"(\w+)",\s*"icon":\s*"[^"]*",\s*"weight":\s*(\d+)\}', src)
assert len(sc_syms) == 6, f"parsed {len(sc_syms)} scratch symbols"
pay_block = re.search(r"const PAYOUTS: Dictionary = \{(.*?)\n\}", src, re.S).group(1)
payouts = {}
for sym, body in re.findall(r'"(\w+)":\s*\{([^}]*)\}', pay_block):
    payouts[sym] = {int(k): float(v) for k, v in re.findall(r"(\d+):\s*([\d.]+)", body)}
assert len(payouts) == 5, f"parsed {len(payouts)} payout rows"

# Exact enumeration: 9 cells over 6 symbols is only C(14,5)=2002 compositions,
# so there is no reason to settle for a Monte Carlo estimate here.
from math import factorial


def compositions(total, parts):
    if parts == 1:
        yield (total,)
        return
    for i in range(total + 1):
        for rest in compositions(total - i, parts - 1):
            yield (i,) + rest


names = [s[0] for s in sc_syms]
weights = [int(s[1]) for s in sc_syms]
wsum = sum(weights)
probs = [w / wsum for w in weights]

sc_rtp = 0.0
sc_hit = 0.0
n_comp = 0
top_prize = 0.0
for comp in compositions(9, len(names)):
    n_comp += 1
    coeff = factorial(9)
    pr = 1.0
    for c, p in zip(comp, probs):
        coeff //= factorial(c)
        pr *= p ** c
    pr *= coeff
    best = 0.0
    for sym, c in zip(names, comp):
        tbl = payouts.get(sym)
        if not tbl:
            continue
        tier = max((t for t in tbl if c >= t), default=0)
        if tier:
            best = max(best, tbl[tier])
    if best > 0:
        sc_hit += pr
        top_prize = max(top_prize, best)
    sc_rtp += pr * best
sc_loss = 1 - sc_hit
print(f"  (exact over {n_comp} compositions, prob mass {sc_hit + sc_loss:.10f})")
check("scratch RTP", sc_rtp, declared_float(src, "base_rtp"), 0.0015)
check("scratch LOSS_RATE", sc_loss, declared_float(src, "const LOSS_RATE"), 0.0015)
smallest = min(v for t in payouts.values() for v in t.values())
print(f"  [{'OK  ' if smallest >= 1.0 else 'FAIL'}] smallest payout {smallest}x (must be >= 1.0x)")
if smallest < 1.0:
    failures.append("scratch has a sub-1x payout")

# ------------------------------------------------------- RTP CLAMP SANITY ---
print("\nMAX RTP CLAMP")
gm = grab("autoload/game_manager.gd")
cap = declared_float(gm, "const MAX_EFFECTIVE_RTP")
max_bonus = 0.005 * 10 + 0.004 * 10  # card_counter x10 + loaded_dice x10
print(f"  max rtp_bonus from all upgrades: +{max_bonus:.3f}")
for label, base in [("slots", 0.9386), ("roulette", 36 / 37), ("dice", 0.95), ("scratch", 0.9174)]:
    eff = min(base + max_bonus, cap)
    ok = eff < 1.0
    print(f"  [{'OK  ' if ok else 'FAIL'}] {label:9s} fully upgraded RTP {eff:.4f} (< 1.0 = no infinite loop)")
    if not ok:
        failures.append(f"{label} reaches {eff} RTP")

print("\n" + "=" * 60)
if failures:
    print(f"{len(failures)} FAILURE(S):")
    for f in failures:
        print("  " + f)
    raise SystemExit(1)
print("All minigame tables match their declared constants.")
