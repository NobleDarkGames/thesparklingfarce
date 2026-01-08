---
name: content-placement
description: Where to place game content vs platform code. Use when creating new files or moving existing code.
---

## Content Placement Rules

The Sparkling Farce separates **platform code** from **game content**. This is fundamental to the mod system.

### The Golden Rule

> **Game content NEVER goes in `core/`.** The base game is just a mod.

### Directory Structure

```
sparklingfarce/
├── core/                    # Platform code ONLY
│   ├── systems/             # Autoload singletons
│   ├── resources/           # Resource class definitions
│   ├── components/          # Reusable node components
│   ├── registries/          # Type registries
│   ├── mod_system/          # ModLoader, ModRegistry
│   └── utils/               # Utility functions
│
├── mods/                    # ALL game content
│   ├── demo_campaign/       # Demo content (priority 100)
│   │   ├── mod.json
│   │   ├── data/
│   │   │   ├── characters/
│   │   │   ├── items/
│   │   │   ├── abilities/
│   │   │   ├── battles/
│   │   │   └── ...
│   │   ├── maps/
│   │   ├── cinematics/
│   │   └── assets/
│   │
│   ├── _platform_defaults/  # Core fallbacks (priority -1)
│   └── _starter_kit/        # Development assets
│
└── scenes/                  # UI scenes, battle scenes, etc.
```

### What Goes Where

| Content Type | Location | Example |
|--------------|----------|---------|
| Character definitions | `mods/*/data/characters/` | `max.tres`, `sarah.tres` |
| Item definitions | `mods/*/data/items/` | `wooden_sword.tres` |
| Ability definitions | `mods/*/data/abilities/` | `fireball.tres` |
| Battle configurations | `mods/*/data/battles/` | `intro_battle.tres` |
| Map metadata | `mods/*/data/maps/` | `hometown.tres` |
| Dialogue | `mods/*/data/dialogues/` | `intro_dialogue.tres` |
| Cinematics | `mods/*/cinematics/` | `opening.json` |
| Character sprites | `mods/*/assets/characters/` | `max.png` |
| Tilesets | `mods/*/tilesets/` | `forest.tres` |
| Audio | `mods/*/audio/` | `battle_theme.ogg` |

### What Goes in `core/`

| Content Type | Location | Example |
|--------------|----------|---------|
| Resource class scripts | `core/resources/` | `character_data.gd` |
| Manager singletons | `core/systems/` | `battle_manager.gd` |
| Reusable components | `core/components/` | `unit.gd` |
| Type registries | `core/registries/` | `equipment_registry.gd` |
| Utility functions | `core/utils/` | `dict_utils.gd` |

### Mod Priority System

| Priority Range | Use For |
|----------------|---------|
| -1 to -100 | Platform defaults (fallbacks) |
| 0 to 99 | Official content |
| 100 to 8999 | User mods |
| 9000+ | Total conversions |

Higher priority mods override lower priority ones for the same resource ID.

### Creating New Content

1. **New character?** → `mods/demo_campaign/data/characters/`
2. **New item?** → `mods/demo_campaign/data/items/`
3. **New resource type?** → `core/resources/` (class definition only)
4. **New manager?** → `core/systems/`
5. **New UI component?** → `scenes/ui/components/`

### Testing Content

Use `mods/_sandbox/` for experimental content that shouldn't ship:

```
mods/_sandbox/
├── mod.json           # priority: 9999 (loads last, overrides everything)
└── data/
    └── characters/
        └── test_hero.tres
```
