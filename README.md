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
├── autoload/          # Global systems (GameManager, SaveManager, etc.)
├── scenes/            # All .tscn scene files
├── scripts/           # Reusable scripts
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
├── project.godot
├── icon.svg
├── LICENSE
└── README.md
```

## Current Status

Repository is fully initialized and ready for development.

- Godot 4 project configured
- Basic folder structure in place
- Autoload stubs created
- MIT License added
- Issue labels set up

Next step: Design the core systems and begin implementing the first minigames.

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
