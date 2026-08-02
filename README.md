# CasinoIdle

### [Play it in your browser](https://impulserfl.github.io/CasinoIdle/)

An incremental idle casino sim built with **Godot 4**.

You don't just play the machines — you **own the floor**. Properties earn chips
every second from NPC patrons; you gamble those chips across eighteen tables for
EXP and jackpots; levels buy skills; and prestige trades the whole run for
permanent bonuses.

---

## v0.6

### The core loop

```
Casino floor  ──earns──▶  Chips  ──wagered──▶  EXP  ──▶  Levels  ──▶  Skill points
     ▲                                                                     │
     └──────────────────────── bought with chips ◀───── better income ◀────┘

                    Prestige  ──▶  Gold chips  ──▶  Permanent upgrades
```

### Features

- **Casino floor** — 12 property tiers from Penny Slots to an Orbital Casino,
  with `x1 / x10 / x25 / MAX` bulk buying and payback-time readouts.
- **Eighteen tables** — slots, roulette, dice, scratch cards, higher/lower,
  blackjack, plinko, coin flip, money wheel, crash, keno, baccarat, video poker,
  casino war, coin pusher, claw machine, darts and fishing.
- **Three upgrade trees** — 20 skills, 21 prestige ranks, and six upgrades on
  every one of the eighteen tables (108 in total).
- **29 achievements**, each granting +1% casino income.
- **Offline progress** with a welcome-back summary and an upgradeable time cap.
- **Rare floor events** on a 45 minute cooldown, daily bonuses, and Lucky Hours.
- Autosave every 20s, a backup save file, and versioned save migration.
- A settings panel with 16 options across audio, presentation, table behaviour
  and notifications.

### How to run

**In a browser:** <https://impulserfl.github.io/CasinoIdle/> — rebuilt and
redeployed automatically on every push to `main`.

**Locally:**

1. Clone the repo
2. Open the project in **Godot 4.3+**
3. Press Play

---

## Economy design

The one rule everything else follows:

> **Gambling is never a source of chips.** Every table sits below 100% RTP,
> permanently. Chips come from the casino floor; wagering converts chips into
> EXP and jackpot chances at a known, small cost.

This is deliberate. If table returns could reach break-even, holding down AUTO
would be free infinite money and every other system would stop mattering. So:

- Anything that multiplies chip gains (`Golden Touch`, `Floor Manager`,
  achievements, prestige count) applies to **passive income only**.
- The only levers that touch table returns are `GameManager.rtp_bonus()` and the
  per-table `rtp` upgrade. They are summed into `Minigame.rtp_budget()` and
  hard-clamped by `MAX_EFFECTIVE_RTP = 0.99`.
- The bonus is delivered as a **stake refund on a losing round**, sized so that
  `base_rtp + loss_probability * refund_chance == effective_rtp` exactly. That
  is why each table declares both `base_rtp` and its true loss rate — they are
  load-bearing constants, not documentation.

### Every choice is volatility, never value

Picking a keno spot count, a darts zone, a crash cash-out target, a fishing
depth, a money wheel segment or a baccarat side changes *the shape of the risk*
and nothing else. Each option is priced to the same return as its neighbours.
Where a payout depends on the board — higher/lower prices its odds from the card
on the table — it is derived as `(base_rtp - P(tie)) / P(win)` rather than
picked by eye.

No table pays a "win" worth less than the stake.

### Verified odds

Every figure below is re-derived from the constants as actually written in the
scripts, in-engine, on every build:

| Table | RTP | House edge | Notes |
|---|---|---|---|
| Baccarat | 97.76% | 2.24% | Player, Banker and Tie all priced identically |
| Roulette | 97.30% | 2.70% | European single zero; all ten bet types are 36/37 |
| Dice | 95.00% | 5.00% | All six bets priced identically |
| Coin Flip | 95.00% | 5.00% | 1.9x on a fair coin |
| Blackjack | 94.34% | 5.66% | Exact over the full state tree |
| Crash | 94.00% | 6.00% | Identical at every cash-out target |
| Slots | 93.86% | 6.14% | Weighted reels; three sevens is 1 in 100,545 |
| Plinko | 93.00% | 7.00% | Centre slot pays nothing |
| War | 93.05% | 6.95% | A tie goes to war for free |
| Higher / Lower | 92.00% | 8.00% | Priced from the card shown |
| Money Wheel | 92.00% | 8.00% | Identical on every segment |
| Darts | 92.00% | 8.00% | Identical at every aim |
| Video Poker | 92.00% | 8.00% | One deal, no draw; any pair pays |
| Keno | 91.00% | 9.00% | Identical at every spot count |
| Fishing | 91.00% | 9.00% | Identical at every depth |
| Scratch Cards | 91.74% | 8.26% | Top prize 4,900x |
| Coin Pusher | 90.00% | 10.00% | |
| Claw Machine | 88.00% | 12.00% | Arcade odds, the worst on the floor |

### Pacing

Simulated against the real generator table, buying greedily by payback time:

| Milestone | First run |
|---|---|
| 100K lifetime chips | ~10 min |
| 1M lifetime chips | ~20 min |
| Prestige unlocked | ~60 min |
| 1B lifetime chips | ~1.9 h |
| 1T lifetime chips | ~8.3 h |

The simulator buys optimally every second, so real play runs slower than that
rather than faster. Later runs compound hard.

---

## Build & CI

`.github/workflows/web.yml` runs on every push and PR to `main`. It installs a
real Godot 4.3 binary plus export templates and then:

1. **Imports the project**
2. **Boot check** — loads the main scene and fails on any script error
3. **Balance audit, icon check and table self-test** (`--selftest`) — the real
   gate, see below
4. **Checks the save round-trip** — asserts a `version=2` save was written
5. **Exports the web build** and verifies `index.{html,js,wasm,pck}` are
   non-empty
6. **Deploys to GitHub Pages** (only from `main`)

### The self-test

`godot --headless --path . --selftest` is the correctness gate and runs
identically on a developer machine and in CI. It:

- runs `scripts/balance_audit.gd`, which re-derives every table's RTP and loss
  rate from that table's own constants and asserts they match what it declares,
  that the fully-upgraded RTP stays under 100%, that the refund cap never binds,
  and that the RTP shown to the player is the RTP actually delivered — 300+
  assertions in total;
- checks that every icon named by the generator, upgrade, skill, prestige,
  achievement and event tables resolves to a real sprite;
- plays six rounds at all eighteen tables, so the betting, payout and settle
  paths execute rather than just the constructors.

This replaced a Python verifier that covered four of the eighteen tables. Every
table that had drifted from its declared odds was one the old verifier never
looked at, which is the entire argument for checking all of them.

### One-time setup

Pages must be pointed at Actions or the deploy step fails:

> **Settings → Pages → Build and deployment → Source: _GitHub Actions_**

### Web-specific details worth knowing

- **Renderer.** Browsers only have WebGL 2, so `project.godot` sets
  `renderer/rendering_method.web="gl_compatibility"`. Desktop stays on Forward+.
  A Forward+ web build exports fine and then renders nothing.
- **Threads are off** (`variant/thread_support=false`). Threaded builds need
  `SharedArrayBuffer`, which needs COOP/COEP headers, which GitHub Pages does
  not send.
- **No font dependency.** Every icon, card suit and die face is a sprite in
  `assets/sprites/`, and all UI text is ASCII. The UI used to be built from
  emoji, which meant a browser — where Godot gets no system fonts — rendered the
  game as tofu boxes unless CI subset and bundled a Noto fallback at export
  time. That machinery is gone.
- **Saving.** Closing a browser tab never delivers `WM_CLOSE_REQUEST`, so
  `SaveManager` also saves on focus-out, app-pause and exit-tree, on top of the
  20s autosave.
- **`export_presets.cfg` is committed** (most Godot `.gitignore` templates
  exclude it) because headless export needs the Web preset to exist.

---

## Project structure

```
CasinoIdle/
├── autoload/              # Global singletons, loaded in this order:
│   ├── audio_manager.gd   #   additive synth, streams rendered once at boot
│   ├── settings.gd        #   preferences, declared once in SPEC
│   ├── game_manager.gd    #   currency, EXP, prestige, stats, multipliers
│   ├── upgrades.gd        #   skill tree + prestige tree
│   ├── game_upgrades.gd   #   the six upgrades on every table
│   ├── casino.gd          #   idle generators (the income layer)
│   ├── achievements.gd    #   29 achievements + unlock checks
│   ├── events.gd          #   daily bonus, Lucky Hours, floor events
│   └── save_manager.gd    #   versioned save/load, autosave, offline progress
├── scripts/
│   ├── fmt.gd             # Fmt — number/time formatting
│   ├── minigame.gd        # Minigame — betting, auto-play, the RTP cap
│   └── balance_audit.gd   # BalanceAudit — the odds verifier
├── minigames/             # One file per table, each `extends Minigame`
├── ui/
│   ├── icons.gd           # Icons — sprite registry
│   ├── ui_kit.gd          # UIKit — palette + widget builders
│   ├── fx.gd              # FX — floating text, pulses, shakes
│   └── *_panel.gd         # Casino / Skills / Prestige / Records / Settings
├── scenes/
│   ├── main.tscn          # Entry point: a bare Control + main.gd
│   └── main.gd            # Builds the layout, hosts the self-test
├── assets/sprites/        # 91 icons, drawn as flat geometry
└── project.godot
```

### Why the UI is built in code

`main.tscn` is intentionally almost empty — every panel, button and label is
constructed in GDScript. Node paths therefore cannot drift out of sync with the
scripts that use them (no `$VBox/Reels/Reel1` to silently break on a rename),
and the entire layout shows up as a readable diff in review.

### Saves

`user://casino_idle_save.cfg`, with `user://casino_idle_save.bak` kept as the
previous good copy. Saves carry a `version`; v1 prototype saves are migrated
automatically. Derived values are recomputed on load rather than trusted, so
changing a formula never leaves an old save running the old maths.

---

## Roadmap

- Statistics graphs over time
- More floor events and a seasonal calendar
- Steam/mobile export polish

## Tech Stack

- **Engine**: Godot 4.3+
- **Language**: GDScript
- **Target**: Web primary, Windows/Linux/Mac supported

---

*Feedback welcome — see CONTRIBUTING.md.*
