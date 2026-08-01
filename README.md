# CasinoIdle

An incremental idle clicker game built with **Godot 4**.

## Current Playable Prototype (v0.1)

You can already play a working version!

### Features right now:
- **Chips** currency
- **3-Reel Slot Machine** with spin + auto-spin
- Win multipliers (including jackpot on three 7s)
- **Player Level + EXP**
- **Skill Points** (earned on level up)
- **Prestige system** (resets progress for permanent multiplier)
- Save / Load (auto-saves on close)
- Debug buttons for testing

### How to run
1. Clone the repo
2. Open the project in **Godot 4.3+**
3. Press Play

### Controls
- **SPIN** — play the slot machine (costs 10 chips)
- **AUTO** — toggle auto-spin
- **Prestige** — available at Level 10 or 5,000 total chips earned
- Debug buttons at the bottom for quick testing

---

## Concept (Full Vision)

Play (and eventually auto-play) a variety of gambling minigames to earn money and experience.

- Slot machines
- Dice games
- Card games
- Coin Pusher
- Claw Machine
- Roulette
- Scratch tickets
- And more over time

Earn EXP → Level up → Gain Skill Points → Unlock a large skill tree.  
Prestige to gain permanent bonuses and unlock new content.

## Tech Stack

- **Engine**: Godot 4
- **Language**: GDScript
- **Target**: Windows (primary), with Linux/Mac support planned

## Project Structure

```
CasinoIdle/
├── autoload/              # Global systems (GameManager, SaveManager)
├── scenes/                # Main and other scenes
├── scripts/               # Shared / utility scripts
├── minigames/             # Each gambling game lives here
├── ui/                    # Reusable UI components
├── data/                  # Balance data, machine configs, etc.
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
├── project.godot
└── ...
```

---

*This project is under active development. Prototype is playable — feedback welcome!*
