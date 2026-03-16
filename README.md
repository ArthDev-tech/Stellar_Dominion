# Stellar Dominion

A **4X space strategy** game built with **Godot 4** and **GDScript**. Inspired by Stellaris, with deliberate design divergences—not a clone.

## Requirements

- **Godot 4.x** (4.5 or compatible). [Download Godot](https://godotengine.org/download)

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/ArthDev-tech/Stellar_Dominion.git
   cd Stellar_Dominion
   ```
2. Open the project in Godot 4 (open `project.godot`).
3. Run the main scene (main menu → galaxy setup → game).

## Project Overview

- **Engine:** Godot 4, GDScript only.
- **Design:** Inspector-first: balance and data are tuned via `@export` and Resources (`.tres`), not hardcoded.
- **Architecture:** Node composition, autoloads for cross-cutting systems, and an `EventBus` for cross-scene signals.

### Main Systems

| Area | Description |
|------|-------------|
| **Galaxy** | Hyperlane map, star systems, fleet icons, galaxy generation and precursors |
| **Empire & Economy** | Colonies, resources, monthly tick, refinement, jobs, buildings |
| **Leaders & Council** | Leader roster, council positions, agendas |
| **Tech** | Research tree, tech cards, unlock checks |
| **Ships** | Ship design, fleets, space stations, resource stations |

### Folder Structure (high level)

```
stellar_dominion/
├── core/           # GameState, EventBus, GalaxyManager, SelectionManager, etc.
├── empire/         # Empire, colonies, research
├── economy/        # Economy manager, game resources
├── galaxy/scripts/ # Galaxy generation, star systems, hyperlanes, planets
├── leaders/        # Leaders, council, traits, agendas
├── ships/          # Ship/fleet data, design manager, stations
├── buildings/     # Building configs, jobs, job assignment
├── scenes/         # Main menu, galaxy view, planet view, UI
├── ui/             # Overlays, panels, tech tree
├── data/           # JSON and .tres data (techs, buildings, resources, etc.)
└── assets/         # Art, music, themes
```

## Contributing

Open an issue or pull request on GitHub. Follow existing code style: `snake_case` for variables/functions, `PascalCase` for classes and node names.

## License

All rights reserved (or add your preferred license).
