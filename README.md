# CasinoIdle

An incremental idle clicker game built with **Godot 4**.

## Concept

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
├── .github/ISSUE_TEMPLATE/
├── project.godot
├── icon.svg
├── LICENSE
├── CONTRIBUTING.md
└── README.md
```

## Current Status

Repository is fully initialized and production-ready for development.

- Godot 4 project configured
- Clean folder structure
- Autoload stubs
- MIT License
- Issue templates + labels
- EditorConfig
- Contributing guide

**Next step**: Design core systems and implement the first minigames.

## Planned Features

- Multiple unlockable gambling machines
- Idle / auto-play systems
- Player leveling + Skill Tree
- Prestige system
- Offline progress
- Local save system
- Clean, polished UI

---

*This project is under active development.*
