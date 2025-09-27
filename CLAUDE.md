# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Bloons Tower Defense clone** built in **Godot 4.4** using GDScript. The game implements tower defense mechanics with bloons (balloons) moving along paths while towers attack them.

## Development Commands

### Running the Project
- **Main Command**: Open in Godot Editor or run via `godot --main-pack project.godot`
- **No Build Step**: Godot projects run directly from source
- **No Package Manager**: Uses built-in Godot resource system

### Testing
- **No Automated Tests**: This project doesn't have a formal test suite
- **Manual Testing**: Run the game and test tower placement, wave spawning, and combat mechanics

## Architecture Overview

### Core Game Loop
The game uses Godot's autoload (singleton) system for global managers:

1. **GameManager** (`autoloads/game_manager.gd`): Manages player resources (lives, cash, rounds)
2. **NodePoolManager** (`autoloads/pool_manager.gd`): Handles object pooling for performance
3. **TowerFactory** (`autoloads/tower_factory.gd`): Creates and configures tower/projectile stats
4. **WaveManager** (`main/wave_manager.gd`): Spawns bloon waves based on JSON data

### Key Systems

#### Stats-Based Architecture
- **TowerStats** & **ProjectileStats**: Resource-based stat system for all tower/projectile properties
- **BloonStats**: Defines health, speed, immunities, and child bloons for each bloon type
- **BloonFactory** (`stats/bloon_factory.gd`): Factory methods for generating all bloon variants

#### Factory Pattern
- **TowerFactory**: Generates tower stats based on upgrade paths (e.g., "120" = path1-tier2, path2-tier0, path3-tier0)
- **BloonFactory**: Creates bloon stats with proper inheritance (e.g., blue bloons spawn red bloons when popped)
- Both use callables and static methods for flexible stat generation

#### Object Pooling
- **NodePoolManager**: Reuses bloons and projectiles to avoid garbage collection spikes
- Bloons and projectiles implement `pool_reset()` methods for reinitialization

#### Upgrade System
- **Path-based upgrades**: Each tower has 3 upgrade paths with 5 tiers each
- **Cross-path restrictions**: BTD6-style rules prevent overpowered combinations (max 2 total tiers on non-primary paths when going past tier 2)
- **Dynamic reconfiguration**: Towers rebuild their projectile pools when upgraded

### File Organization

- **`main/`**: Core game scene and wave management
- **`autoloads/`**: Global singletons (GameManager, TowerFactory, etc.)
- **`stats/`**: Stat resource definitions and factory classes
- **`tower/`**: Tower behavior and upgrade logic
- **`bloon/`**: Bloon movement and health management
- **`projectile/`**: Projectile physics and damage dealing
- **`gui/`**: UI for tower placement, upgrades, and HUD
- **`data/`**: JSON wave definitions
- **`resources/`**: Godot resource files (.tres)
- **`meshes/`**: 3D models and visual assets

### Data Flow
1. **Wave Definition** (`data/waves.json`) → **WaveManager** loads and parses
2. **Bloon Spawning** → **BloonFactory** creates stats → **NodePoolManager** provides instances
3. **Tower Placement** → **TowerFactory** generates stats → **Tower** configures itself
4. **Combat** → **Tower** attacks → **Projectile** deals damage → **Bloon** takes damage or spawns children

### Physics Layers (3D)
- **Layer 1**: Bloons
- **Layer 2**: Tower Range Areas
- **Layer 3**: Projectiles
- **Layer 4**: Environment
- **Layer 5**: Placeable Ground
- **Layer 6**: Placed Towers (clickable)
- **Layer 7**: Track/Path
- **Layer 8**: Selectable Towers

## Code Patterns

### Stat Assignment
Always assign stats before calling configuration methods:
```gdscript
var stats_dict = TowerFactory.create_stats("dart-monkey", "000")
tower.stats = stats_dict.tower
tower.projectile_stats = stats_dict.projectile
tower.set_initial_state("dart-monkey", 200)  # Then configure
```

### Signal Connections
Check connections before creating to avoid duplicates:
```gdscript
if not signal_name.is_connected(callback):
    signal_name.connect(callback)
```

### Pool Management
Use `NodePoolManager.request_node(scene)` for bloons/projectiles and implement `pool_reset()` methods for cleanup.

## AI Context Generator Plugin

This project includes the "AI-Context-Generator" addon in `addons/AI-Context-Generator/` which can copy all scripts to clipboard for AI assistance. Access it via the "AI" button in the Godot editor toolbar.