# The Sparkling Farce Mod System

**Status**: ACTIVE
**Last Updated**: November 24, 2025

---

## Overview

The Sparkling Farce uses a powerful mod system that allows content creators to add, modify, and override game content without touching engine code. The mod system is built on Godot's Resource system and follows a priority-based loading order.

## Architecture

### Core Components

1. **ModLoader** (`core/mod_system/mod_loader.gd`) - Autoload singleton
   - Discovers mods in `mods/` directory
   - Loads mods in priority order
   - Populates ModRegistry with all resources

2. **ModManifest** (`core/mod_system/mod_manifest.gd`) - Resource
   - Represents mod metadata from `mod.json`
   - Defines load priority, dependencies, and content paths

3. **ModRegistry** (`core/mod_system/mod_registry.gd`) - Registry
   - Central lookup for all game resources
   - Organizes resources by type (character, class, item, etc.)
   - Tracks which mod provided each resource

### Directory Structure

```
mods/
├── _base_game/           # Official core content (priority 0-99)
│   ├── mod.json
│   ├── data/
│   │   ├── characters/
│   │   ├── classes/
│   │   ├── items/
│   │   ├── abilities/
│   │   ├── parties/
│   │   └── battles/
│   └── assets/
├── my_campaign/          # User campaign mod (priority 100-8999)
│   ├── mod.json
│   ├── data/
│   └── assets/
└── total_conversion/     # High-priority override (priority 9000-9999)
    ├── mod.json
    ├── data/
    └── assets/
```

---

## Mod Priority System

### Priority Ranges (0-9999)

The mod system uses a numerical priority system to determine load order and override behavior:

| Range | Purpose | Examples |
|-------|---------|----------|
| **0-99** | Official game content from core development team | `base_game` (0), `official_dlc` (50) |
| **100-8999** | User mods and community content | `guardiana_campaign` (500), `custom_characters` (1000) |
| **9000-9999** | High-priority and total conversion mods | `complete_overhaul` (9000) |

### Load Order Rules

1. **Lower priority loads FIRST** (can be overridden by higher priority)
2. **Higher priority loads LAST** (overrides previous mods)
3. **Same priority?** Alphabetical by `mod_id` (consistent cross-platform)

**Example Load Order:**
```
base_game (0)              → Loads first
community_pack (100)       → Can override base_game
guardiana_saga (500)       → Can override community_pack
manarina_quest (500)       → Loads after guardiana (alphabetical: g < m)
total_conversion (9000)    → Overrides everything
```

### Why This System?

- **Predictable**: Same load order on all platforms
- **Flexible**: 10,000 priority slots for maximum compatibility
- **Clear Intent**: Priority ranges make mod purpose obvious
- **Stackable**: Multiple mods can coexist and layer properly

---

## Creating a Mod

### 1. Create Mod Directory

Create a new folder in `mods/` with your mod's identifier:

```bash
mkdir mods/my_awesome_mod
```

### 2. Create mod.json

Every mod requires a `mod.json` manifest file:

```json
{
  "id": "my_awesome_mod",
  "name": "My Awesome Mod",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "An amazing mod that adds new content to The Sparkling Farce",
  "godot_version": "4.5",
  "dependencies": [],
  "load_priority": 500,
  "content": {
    "data_path": "data/",
    "assets_path": "assets/"
  },
  "overrides": [],
  "tags": ["campaign", "characters"]
}
```

#### Required Fields

- **id**: Unique identifier (snake_case, no spaces)
- **name**: Display name for the mod

#### Optional Fields

- **version**: Semantic version (default: "1.0.0")
- **author**: Creator's name
- **description**: What the mod does
- **godot_version**: Target Godot version (default: "4.5")
- **dependencies**: Array of mod IDs that must load first
- **load_priority**: 0-9999 (default: 0)
- **content.data_path**: Relative path to data folder (default: "data/")
- **content.assets_path**: Relative path to assets folder (default: "assets/")
- **overrides**: Array of resource IDs this mod replaces
- **tags**: Array of category tags

### 3. Add Content

Create your content in the mod's data directory:

```
mods/my_awesome_mod/
├── mod.json
├── data/
│   ├── characters/
│   │   └── hero.tres
│   ├── classes/
│   │   └── knight.tres
│   └── items/
│       └── legendary_sword.tres
└── assets/
    ├── sprites/
    └── portraits/
```

All `.tres` resource files in recognized directories are automatically loaded.

### 4. Test Your Mod

1. Launch the game in Godot
2. Check the console for: `ModLoader: Discovered mod 'My Awesome Mod' (my_awesome_mod)`
3. Verify: `ModLoader: Mod 'My Awesome Mod' loaded successfully (X resources)`

---

## Priority Selection Guide

### Choosing the Right Priority

**Official Content (0-99):**
```json
"load_priority": 0   // Base game, loads first
"load_priority": 10  // Official patches
"load_priority": 50  // Official DLC
```

**User Mods (100-8999):**
```json
"load_priority": 100  // Testing/sandbox
"load_priority": 500  // Small content additions
"load_priority": 1000 // Campaign mods
"load_priority": 2000 // Large overhaul mods
```

**Total Conversions (9000-9999):**
```json
"load_priority": 9000 // Complete game overhaul
"load_priority": 9500 // Ultimate override mod
"load_priority": 9999 // Absolute highest priority
```

### Best Practices

1. **Leave room for expansion** - Use increments of 100 or more
2. **Document dependencies** - If your mod requires another, list it
3. **Use overrides array** - Declare when you're replacing base content
4. **Test priority conflicts** - If multiple mods clash, adjust priorities

---

## Resource Overriding

### How Overrides Work

When multiple mods provide resources with the **same ID**, the **highest priority** mod wins.

**Example:**
```
base_game (priority 0):
  characters/max.tres → "Max" (base stats)

power_mod (priority 500):
  characters/max.tres → "Max" (buffed stats)

Result: "Max" from power_mod is used in-game
```

### Explicit Override Declaration

Declare overrides in `mod.json` for clarity:

```json
{
  "id": "rebalance_mod",
  "load_priority": 1000,
  "overrides": ["characters/max", "items/sword"]
}
```

This helps users understand what your mod changes.

---

## Dependencies

### Declaring Dependencies

If your mod requires another mod to function:

```json
{
  "id": "expansion_pack",
  "dependencies": ["base_game", "community_framework"],
  "load_priority": 1500
}
```

**Rules:**
- Dependencies must be loaded BEFORE your mod
- Missing dependencies cause load failure with error message
- Dependencies are checked by mod ID

### Dependency Load Order

```json
// community_framework.json
{
  "id": "community_framework",
  "load_priority": 200
}

// my_expansion.json
{
  "id": "my_expansion",
  "dependencies": ["community_framework"],
  "load_priority": 1000
}
```

Even though `my_expansion` has higher priority, `community_framework` loads first (dependency requirement).

---

## Advanced: UI Customization (Future)

### Planned Features

Future versions will allow mods to customize:

```
mods/my_mod/
├── ui_overrides/
│   ├── opening_cinematic.tscn    # Custom opening
│   ├── main_menu_background.png  # Menu background
│   └── main_menu_music.ogg       # Title music
└── mod_config.tres
    ├── title_override: "My Campaign"
    └── subtitle: "A Sparkling Farce Adventure"
```

The game will check mods in **descending priority order** and use the first override found.

---

## Technical Details

### Validation

ModLoader validates all mods on startup:

**Errors that prevent loading:**
- Missing `mod.json`
- Invalid JSON syntax
- Missing required fields (`id`, `name`)
- Priority out of range (< 0 or > 9999)
- Missing dependency

**Warnings (non-blocking):**
- Duplicate priorities (uses alphabetical tiebreaker)
- Empty data directories
- Undeclared overrides

### Resource Registry

All loaded resources are stored in ModRegistry:

```gdscript
# Access a specific resource
var max: CharacterData = ModLoader.registry.get_resource("character", "max")

# Get all characters
var all_chars: Array = ModLoader.registry.get_resources_of_type("character")

# Check which mod provided a resource
var provider: String = ModLoader.registry.get_resource_provider("character", "max")
# Returns: "power_mod" (highest priority mod with that resource)
```

### Mod Reloading (Development)

During development, reload mods without restarting:

```gdscript
ModLoader.reload_mods()
```

This clears the registry and re-discovers all mods.

---

## Example Mods

### Minimal Mod

```
mods/minimal_example/
├── mod.json
└── data/
    └── characters/
        └── new_hero.tres
```

```json
{
  "id": "minimal_example",
  "name": "Minimal Example Mod",
  "load_priority": 500
}
```

### Campaign Mod

```
mods/guardiana_saga/
├── mod.json
├── data/
│   ├── characters/    (10 new characters)
│   ├── classes/       (3 new classes)
│   ├── items/         (20 new items)
│   ├── battles/       (15 battle scenarios)
│   └── parties/       (campaign party configs)
└── assets/
    ├── sprites/
    ├── portraits/
    └── music/
```

```json
{
  "id": "guardiana_saga",
  "name": "The Guardiana Saga",
  "version": "2.1.0",
  "author": "Campaign Team",
  "description": "A complete 15-chapter campaign following the heroes of Guardiana",
  "dependencies": ["base_game"],
  "load_priority": 1000,
  "tags": ["campaign", "story", "guardiana"]
}
```

### Total Conversion Mod

```json
{
  "id": "cyberpunk_conversion",
  "name": "Cyberpunk Tactics",
  "version": "1.0.0",
  "author": "Conversion Team",
  "description": "Complete cyberpunk total conversion with new mechanics",
  "load_priority": 9000,
  "overrides": ["*"],
  "tags": ["total-conversion", "cyberpunk"]
}
```

---

## Troubleshooting

### "Mod failed to load"

**Check console for:**
- Syntax errors in `mod.json`
- Missing required fields
- Invalid priority value

### "Dependency not found"

**Solution:**
- Ensure dependency mod exists in `mods/`
- Check dependency mod ID matches exactly
- Verify dependency mod loads successfully

### "Resource not loading"

**Checklist:**
- File is in correct directory (`data/characters/`, etc.)
- File ends with `.tres`
- Resource is a valid Godot Resource
- No conflicting resource with same ID from higher priority mod

### Priority conflicts

If two mods have the same priority:
- They load alphabetically by mod_id
- Consider adjusting one mod's priority
- Check console for load order

---

## Future Roadmap

### Planned Features

1. **Script Modding** - Custom GDScript functionality
2. **Asset Packs** - Shared art/audio resources
3. **Mod Manager UI** - In-game mod enable/disable
4. **Workshop Integration** - Easy mod sharing
5. **Hot Reload** - Change mods without restart
6. **Conflict Detection** - Automatic compatibility checking

---

## Best Practices Summary

✅ **DO:**
- Use clear, descriptive mod IDs and names
- Choose appropriate priority for your mod type
- Declare dependencies explicitly
- Document what your mod changes
- Test with other popular mods
- Use version numbers (semantic versioning)

❌ **DON'T:**
- Use priority 0-99 (reserved for official content)
- Set priority > 9000 unless truly a total conversion
- Depend on mods not widely available
- Override without documenting in `overrides`
- Use spaces or special characters in mod ID

---

## Support

For more information:
- Check `core/mod_system/` for source code
- See `mods/_base_game/` for official examples
- Read `user_content/README.md` for content creation guide
- Consult Godot Resource documentation

Happy modding! 🎮✨
