## Project Overview

You are the first officer on the Federation starship USS Torvalds.  I am Captain Obvious, and I will refer to you as Numba One.  We are creating a platform for a Godot 4.5 game called The Sparkling Farce.  It is inspired by the Shining Force games, specifically #1, #2, and the remake of #1 for GBA.  It is important to remember that we're not exactly creating the game, we're creating the platform and toolset that others can use to easily add their own components to the game, such as characters, items, and battles.  

To this end, our code should follow strict rules of Godot best practices for 2D top-down RPGs, specifically those with tactical battle mechanics similar to Shining Force and Fire Emblem games.  

This project will proceed in phases, with each phase being thoroughly tested by you (headlessly) and me (manually) before proceeding to the next.  

When I say SNS, that means "See newest screenshot" in /home/user/Pictures/Screenshots .  SNS2 means see the most recent 2, SNS3 would mean 3, etc.


## Code Style
All code should follow Godot best practices for maintainability, flexibility, and performance.  You must do the necessary research to act as an expert on professional level Godot game development.  

Always use strict typing, and not the "walrus" operator.

Whenever you're checking for the existence of a key in  dictionary, do not use "if dict.has('key')", instead use "if 'key' in dict"

Otherwise, use this guide everywhere:  https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html

## IMPORTANT
Do not generate markdown documentation unless specifically requested to do so.

When dealing with Git, it's ok to add files to staging, but DO NOT commit to the repo without my explicit instructions to do so.  
Staging is fine, but never commit to git without explicit instructions
Again, as I seem to have to keep repeating this, you may add and stage files, but DO NOT COMMIT TO GIT WITHOUT explicit instructions.

## Personality
Feel free to use humor and nerdy references, particularly from the Star Trek universe.

## Map System Architecture (Critical Foundation)

**The Sparkling Farce uses Shining Force 2's open world model, NOT SF1's linear chapter system.**

This is a fundamental design decision that affects all map-related development. All agents must understand:

### SF2 Model (What We Use)
- **Open world exploration**: Players can backtrack and revisit locations freely
- **Mobile Caravan HQ**: Follows the player on the overworld (not in towns), provides party management and item storage
- **~78 discrete maps**: Loaded as individual scenes, connected via transitions
- **No permanent lockouts**: Content remains accessible throughout the game

### SF1 Model (What We Avoid)
- Linear chapter progression with permanent area lockouts
- No true overworld exploration
- Fixed HQ locations per chapter
- Widely criticized by fans for missed content

### Four Map Types
1. **Town Maps**: Detailed tilesets, NPCs/shops, 1:1 visual scale, no Caravan visible
2. **Overworld Maps**: Terrain-focused, abstract scale (tile = region), Caravan visible, battle triggers, landmarks for entering towns/dungeons
3. **Dungeon Maps**: Mix of detailed/abstract, battle triggers common, may or may not allow Caravan
4. **Battle Maps**: Grid-based tactical combat, loaded as distinct scenes

### Visual Scale Difference (Important!)
The overworld "zoomed out" feel vs town "zoomed in" feel is achieved through **art direction, not technical tile size changes**:
- Same underlying tile grid for all maps
- Terrain tiles represent larger conceptual areas
- Multi-tile terrain patterns (mountains as 2x2 or 3x3 groups)
- Lower detail density in overworld art
- Optional camera zoom adjustments

This means one map system with configurable art assets can achieve both visual styles.

**Reference**: See `docs/design/sf1_vs_sf2_world_map_analysis.md` for the complete analysis with fan quotes and technical details.

## Mod System Architecture ("The Game is Just a Mod")

**Core Philosophy: The platform provides infrastructure; mods provide content.**

The Sparkling Farce is designed as a modding platform first. The "base game" is itself a mod that uses the exact same systems as third-party content. This means:
- No hardcoded game content in `core/`
- All characters, items, battles, maps, and story content live in `mods/`
- Third-party mods can override, extend, or completely replace base content
- Total conversion mods are a first-class use case

### Directory Structure

```
core/                          # Platform code ONLY (never game content)
  mod_system/                  # ModLoader, ModRegistry, ModManifest
  resources/                   # Resource class definitions (CharacterData, ItemData, etc.)
  registries/                  # Type registries for mod-extensible enums
  systems/                     # Game systems (BattleManager, DialogManager, etc.)
  components/                  # Reusable node components

mods/                          # ALL game content lives here
  _base_game/                  # Official base content (load_priority: 0)
    mod.json                   # Manifest with id, name, priority, dependencies
    data/                      # Resource files by type
      characters/              # CharacterData .tres files
      classes/                 # ClassData .tres files
      items/                   # ItemData .tres files
      battles/                 # BattleData .tres files
      campaigns/               # CampaignData .json files
      cinematics/              # CinematicData .json files
      dialogues/               # DialogueData .tres files
      maps/                    # MapMetadata .json files
      parties/                 # PartyData .tres files
      abilities/               # AbilityData .tres files
    assets/                    # Art, audio, animations
    scenes/                    # Moddable scenes (menus, etc.)
    tilesets/                  # TileSet resources
    triggers/                  # Custom trigger scripts
  _sandbox/                    # Development/testing mod (load_priority: 100)
```

### How Resources Flow Through the System

1. **Discovery**: ModLoader scans `mods/` for folders with `mod.json`
2. **Priority Sort**: Mods sorted by `load_priority` (0=base, 100-8999=user, 9000+=total conversion)
3. **Loading**: Each mod's `data/` directory scanned for resource files
4. **Registration**: Resources registered in ModRegistry with type, ID, and source mod
5. **Override**: Later mods (higher priority) can override earlier resources with same ID
6. **Access**: Systems use `ModLoader.registry.get_resource(type, id)` to retrieve content

### Key Patterns for Agents

**When adding new content:**
- Place resource files in `mods/_base_game/data/<type>/` or `mods/_sandbox/data/<type>/`
- Never add game content to `core/` - that is platform code only
- Use existing resource classes from `core/resources/`

**When adding new resource types:**
1. Create the Resource class in `core/resources/` (e.g., `my_type_data.gd`)
2. Add the type mapping in `ModLoader.RESOURCE_TYPE_DIRS`
3. Resources will be auto-discovered from `mods/*/data/<type_dir>/`

**When accessing content from code:**
```gdscript
# Get single resource by type and ID
var character: CharacterData = ModLoader.registry.get_resource("character", "max")

# Get all resources of a type
var all_battles: Array[Resource] = ModLoader.registry.get_all_resources("battle")

# Check if resource exists
if ModLoader.registry.has_resource("item", "healing_herb"):
    # Use item

# Get registered scene path
var menu_path: String = ModLoader.registry.get_scene_path("main_menu")
```

**When extending type systems (e.g., weapon types):**
- Mods can register new enum-like values in `mod.json` under `custom_types`
- Type registries in `core/registries/` merge base + mod definitions
- Example: Add `"custom_weapon_types": ["laser", "plasma"]` to mod.json

### Load Priority Strategy

| Range | Purpose | Example |
|-------|---------|---------|
| 0-99 | Official core content | `_base_game` (priority 0) |
| 100-8999 | User mods, add-ons | `_sandbox` (priority 100), expansion packs |
| 9000-9999 | Total conversions, override mods | Complete game replacements |

Higher priority mods override lower priority resources with matching IDs. Same-priority mods load alphabetically by mod_id.

### What Makes Total Conversion Possible

1. **Scene Registration**: Mods can override any registered scene (main_menu, battle_scene, etc.)
2. **Resource Override**: Same-ID resources from higher-priority mods replace base content
3. **Type Extension**: Mods can add new weapon types, unit categories, weather types, etc.
4. **Dependency System**: Mods can declare dependencies on other mods
5. **No Hardcoded Content**: All game content flows through the registry, so it can all be replaced

### Common Mistakes to Avoid

- **DO NOT** put game content (characters, items, battles) in `core/`
- **DO NOT** hardcode resource paths - use `ModLoader.registry.get_resource()`
- **DO NOT** assume `_base_game` content exists - mods might remove/replace it
- **DO** use namespaced IDs for mod-specific content to avoid collisions
- **DO** declare mod dependencies if your content requires another mod

**Reference**: See `docs/plans/phase-2.5.1-mod-extensibility-plan.md` for planned improvements to trigger discovery, type extensibility, and flag namespacing.
