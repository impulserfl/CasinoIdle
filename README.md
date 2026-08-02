# CasinoIdle

### ▶ [Play it in your browser](https://impulserfl.github.io/CasinoIdle/)

An incremental idle casino sim built with **Godot 4**.

You don't just play the machines — you **own the floor**. Properties earn chips
every second from NPC patrons; you gamble those chips across four minigames to
earn EXP and chase jackpots; levels buy skills; and prestige trades the whole run
for permanent bonuses.

---

## v0.2

### The core loop

```
Casino floor  ──earns──▶  Chips  ──wagered──▶  EXP  ──▶  Levels  ──▶  Skill points
     ▲                                                                     │
     └──────────────────────── bought with chips ◀───── better income ◀────┘

                    Prestige  ──▶  Gold chips  ──▶  Permanent upgrades
```

### Features

- **Casino floor** — 10 property tiers from Penny Slots to a Casino Cruiser,
  with `x1 / x10 / x25 / MAX` bulk buying and the classic 1.15^n cost curve.
- **Four minigames** — Slot Machine, Roulette, Dice Table, Scratch Cards.
- **Skill tree** — 7 skills bought with level-up points (reset on prestige).
- **Prestige tree** — 9 permanent upgrades bought with gold chips.
- **24 achievements**, each granting +1% casino income.
- **Offline progress** with a welcome-back summary and an upgradeable time cap.
- **Autosave** every 20s, a backup save file, and versioned save migration.
- Big-number formatting (`1.23K` → `4.56Sx`), floating win text, reel/ball
  animations, toasts.

### How to run

**In a browser:** <https://impulserfl.github.io/CasinoIdle/> — rebuilt and
redeployed automatically on every push to `main`.

**Locally:**

1. Clone the repo
2. Open the project in **Godot 4.3+**
3. Press Play

---

## Build & CI

`.github/workflows/web.yml` runs on every push and PR to `main`. It installs a
real Godot 4.3 binary plus export templates and then:

1. **Verifies the balance tables** — `tools/verify_balance.py`
2. **Imports the project**
3. **Smoke-tests it headlessly** — boots the actual main scene for 600 frames
   and fails the build if Godot logs any script error. This is the real
   compile/run check: every autoload, panel and minigame `_ready()` executes.
4. **Checks the save round-trip** — asserts a `version=2` save was written on
   shutdown
5. **Exports the web build** and verifies `index.{html,js,wasm,pck}` are non-empty
6. **Deploys to GitHub Pages** (only from `main`)

### One-time setup

Pages must be pointed at Actions or the deploy step fails:

> **Settings → Pages → Build and deployment → Source: _GitHub Actions_**

### Web-specific details worth knowing

- **Renderer.** Browsers only have WebGL 2, so `project.godot` sets
  `renderer/rendering_method.web="gl_compatibility"`. Desktop stays on Forward+.
  A Forward+ web build exports fine and then renders nothing.
- **Threads are off** (`variant/thread_support=false`). Threaded builds need
  `SharedArrayBuffer`, which needs COOP/COEP headers, which GitHub Pages does
  not send. A threaded build fails to boot on Pages.
- **Emoji fonts.** The UI is entirely emoji — reels, dice, property icons. A
  browser gives Godot no system fonts, so CI fetches Noto Emoji into
  `assets/fonts/` and `autoload/font_setup.gd` registers it as a fallback.
  It is not committed (see `.gitignore`); a plain desktop checkout just uses the
  OS emoji font, and the autoload no-ops when the file is absent.
- **Saving.** Closing a browser tab never delivers `WM_CLOSE_REQUEST`, so
  `SaveManager` also saves on focus-out, app-pause and exit-tree, on top of the
  20s autosave.
- **`export_presets.cfg` is committed** (most Godot `.gitignore` templates
  exclude it) because headless export needs the Web preset to exist.

---

## Economy design

The one rule everything else follows:

> **Gambling is never a source of chips.** Every minigame sits below 100% RTP,
> permanently. Chips come from the casino floor; wagering converts chips into
> EXP and jackpot chances at a known, small cost.

This is deliberate. If minigame returns could be pushed to or past break-even,
holding down AUTO would be free infinite money and every other system would stop
mattering. So:

- Anything that multiplies chip gains (`Golden Touch`, `Floor Manager`,
  achievements, prestige count) applies to **passive income only**.
- The **only** lever that touches minigame returns is `GameManager.rtp_bonus()`,
  and it is hard-clamped by `MAX_EFFECTIVE_RTP = 0.99` in `Minigame`. With every
  RTP upgrade maxed, all four games converge on 99% and never reach 100%.
- The bonus is delivered as a **stake refund on a losing round**, sized so that
  `base_rtp + refund == effective_rtp` exactly. That is why each minigame
  declares both `base_rtp` and its loss rate — they are load-bearing constants,
  not documentation.

### Verified odds

Every table is computed from the constants as actually written in the scripts,
not hand-waved:

| Game | RTP | House edge | Hit rate | Notes |
|---|---|---|---|---|
| Roulette | 97.30% | 2.70% | varies | European single zero; all 10 bet types are exactly 36/37 |
| Dice Table | 95.00% | 5.00% | varies | All 6 bets priced to identical RTP — choice is pure volatility |
| Slot Machine | 93.86% | 6.14% | 45.35% | Weighted reels; three sevens is 1 in 100,545 |
| Scratch Cards | 91.74% | 8.26% | 27.57% | Top prize 4,900x; no winning tier pays below 1.0x |

Slots and roulette are enumerated exhaustively (512 and 37 outcomes); scratch
cards are enumerated exactly over all 2,002 ways 9 cells fall across 6 symbols.

### Pacing

Simulated against the real generator table, buying greedily by rate-per-chip:

| Milestone | First run |
|---|---|
| Prestige unlocked | ~17 min |
| 1M lifetime chips | ~1.3 h |
| 1B lifetime chips | ~11 h |
| Sports Book tier | ~24 h |

Later runs compound hard — at a x5 income multiplier prestige comes back in
~3.4 min, at x25 in ~38 s.

---

## Project structure

```
CasinoIdle/
├── autoload/              # Global singletons, loaded in this order:
│   ├── game_manager.gd    #   currency, EXP, prestige, stats, derived multipliers
│   ├── upgrades.gd        #   skill tree + prestige tree definitions and state
│   ├── casino.gd          #   idle generators (the income layer)
│   ├── achievements.gd    #   24 achievements + unlock checks
│   └── save_manager.gd    #   versioned save/load, autosave, offline progress
├── scripts/
│   ├── fmt.gd             # Fmt — number/time formatting
│   └── minigame.gd        # Minigame — shared base: betting, auto-play, RTP cap
├── minigames/             # One file per game, each `extends Minigame`
├── ui/
│   ├── ui_kit.gd          # UIKit — palette + widget builders
│   ├── fx.gd              # FX — floating text, pulses, shakes
│   └── *_panel.gd         # Casino / Skills / Prestige / Records panels
├── scenes/
│   ├── main.tscn          # Entry point: a bare Control + main.gd
│   └── main.gd            # Builds the whole layout
├── data/, assets/
└── project.godot
```

### Why the UI is built in code

`main.tscn` is intentionally almost empty — every panel, button and label is
constructed in GDScript. Node paths therefore cannot drift out of sync with the
scripts that use them (no `$VBox/Reels/Reel1` to silently break on a rename), and
the entire layout shows up as a readable diff in review.

### Saves

`user://casino_idle_save.cfg`, with `user://casino_idle_save.bak` kept as the
previous good copy. Saves carry a `version`; v1 prototype saves are migrated
automatically. Derived values (like the old `prestige_multiplier`) are
recomputed on load rather than trusted, so changing a formula never leaves an old
save running the old maths.

---

## Roadmap

- Sound and music
- More minigames: coin pusher, claw machine, blackjack, poker
- Deeper skill tree with branching paths
- Statistics graphs over time
- Steam/mobile export polish

## Tech Stack

- **Engine**: Godot 4.3+
- **Language**: GDScript
- **Target**: Windows primary, Linux/Mac supported

---

*Feedback welcome — see CONTRIBUTING.md.*
