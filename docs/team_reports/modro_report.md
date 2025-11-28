# Modro's Comprehensive Moddability Architecture Review

**Date:** November 28, 2025
**Reviewer:** Modro (Mod Architecture Specialist)
**Project:** The Sparkling Farce
**Scope:** Full codebase modding architecture evaluation

---

## Executive Summary

The Sparkling Farce demonstrates a **fundamentally sound modding architecture** with excellent foundations for content extensibility. The mod system already supports priority-based loading, resource overrides, and mod isolation. However, there are critical gaps in **behavior modding** (formulas, game mechanics) and **total conversion support** that would limit ambitious modders. This report provides a systematic evaluation with concrete recommendations.

**Overall Moddability Score: 7.5/10**

---

## 1. Mod System Architecture

### Current Implementation

The mod system consists of three core components:

| Component | File | Purpose |
|-----------|------|---------|
| ModLoader | `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd` | Discovery, priority sorting, resource loading |
| ModRegistry | `/home/user/dev/sparklingfarce/core/mod_system/mod_registry.gd` | Central lookup, override tracking, source attribution |
| ModManifest | `/home/user/dev/sparklingfarce/core/mod_system/mod_manifest.gd` | Manifest parsing, validation, metadata |

### Strengths

1. **Priority-Based Load Order (0-9999)**: Well-designed priority system with clear ranges for base game (0-99), user mods (100-8999), and total conversions (9000-9999). Alphabetical tiebreaker ensures cross-platform consistency.

2. **Resource Override System**: Later mods automatically override earlier mods' resources with the same ID. Override tracking enables debugging ("Mod X overriding resource Y from mod Z").

3. **Dependency Management**: Explicit dependency declarations prevent load-order issues. Dependencies must load before dependents.

4. **JSON + .tres Support**: CinematicData and CampaignData support JSON loading, enabling text-editor-based content creation.

5. **Scene Registration**: Mods can register custom scenes (e.g., `opening_cinematic`, `main_menu`) that override base game scenes.

6. **Type Registry System**: Extensible type registries for:
   - Equipment types (weapons, armor)
   - Environment types (weather, time of day)
   - Unit categories
   - Animation offset types

### Critical Issues

**Issue 1: Combat Formulas are Hardcoded**

Location: `/home/user/dev/sparklingfarce/core/systems/combat_calculator.gd`

```gdscript
# Lines 13-19 - Constants that should be data-driven
const DAMAGE_VARIANCE_MIN: float = 0.9
const DAMAGE_VARIANCE_MAX: float = 1.1
const BASE_HIT_CHANCE: int = 80
const BASE_CRIT_CHANCE: int = 5
const COUNTER_DAMAGE_MULTIPLIER: float = 0.75
```

These values cannot be modified by mods without editing engine code. A total conversion wanting Fire Emblem-style hit rates or Final Fantasy damage formulas would be blocked.

**Issue 2: Autoload Singletons are Immutable**

All game systems are hardcoded autoloads in `project.godot`:
```
BattleManager, TurnManager, CombatCalculator, ExperienceManager, etc.
```

Mods cannot replace these systems with custom implementations. A mod wanting custom turn order logic or different XP formulas must wait for the base game to add config options.

**Issue 3: Limited Script Modding**

AIBrain is the only scriptable extension point. Other systems (combat resolution, movement, targeting) lack plugin hooks.

---

## 2. Content Extensibility

### Supported Content Types

| Type | Data-Driven | Editor Support | Override Support |
|------|-------------|----------------|------------------|
| Characters | Yes (.tres) | Yes | Yes |
| Classes | Yes (.tres) | Yes | Yes |
| Items | Yes (.tres) | Yes | Yes |
| Abilities | Yes (.tres) | Yes | Yes |
| Battles | Yes (.tres) | Yes | Yes |
| Dialogues | Yes (.tres) | Yes | Yes |
| Cinematics | Yes (.tres/.json) | Partial | Yes |
| Campaigns | Yes (.json) | No | Yes |
| AI Brains | Yes (.gd scripts) | No | Yes |
| Parties | Yes (.tres) | Yes | Yes |

### Content Addition Process

1. Create mod folder in `mods/`
2. Add `mod.json` manifest
3. Place resources in `data/<type>/` directories
4. Resources auto-discovered and registered on load

This is a **best-in-class** content pipeline. Modders can add new characters, classes, items, and battles without touching any engine code.

### Content Limitations

**Maps require scene files**: Maps are PackedScene references, not pure data. Modders must use Godot editor to create maps (cannot use external tools).

**Sprite sheets have no abstraction layer**: Character sprites reference Texture2D directly. No sprite definition files that would allow palette swaps or animation remapping.

---

## 3. Data-Driven Design Analysis

### Excellent Examples

**CharacterData** (`/home/user/dev/sparklingfarce/core/resources/character_data.gd`):
- All stats, appearance, equipment are exported properties
- Character UID system for stable references
- Biography text for lore content

**BattleData** (`/home/user/dev/sparklingfarce/core/resources/battle_data.gd`):
- Map scene, spawn points, enemy configurations
- Victory/defeat conditions with multiple types
- Pre/post battle dialogues
- Environmental settings (weather, time of day)
- Custom victory/defeat scripts via GDScript reference

**CinematicData** (`/home/user/dev/sparklingfarce/core/resources/cinematic_data.gd`):
- Command-based scripting system
- 16 command types covering movement, camera, dialog, audio
- JSON-loadable for text-based editing
- Extensible command pattern

### Problem Areas

**ExperienceConfig** is not mod-loadable:
```gdscript
# experience_manager.gd line 72-75
func _ready() -> void:
    if config == null:
        var ExperienceConfigClass: GDScript = load("res://core/resources/experience_config.gd")
        config = ExperienceConfigClass.new()
```
Mods cannot provide their own XP configuration. The manager loads a hardcoded default.

**Victory/Defeat Conditions Enum** (`battle_data.gd` lines 8-24):
```gdscript
enum VictoryCondition {
    DEFEAT_ALL_ENEMIES,
    DEFEAT_BOSS,
    SURVIVE_TURNS,
    REACH_LOCATION,
    PROTECT_UNIT,
    CUSTOM
}
```
Only 6 victory types. While CUSTOM exists with `custom_victory_script`, the enum itself cannot be extended by mods. Mods wanting "COLLECT_ALL_ITEMS" or "REACH_MULTIPLE_LOCATIONS" must use CUSTOM.

---

## 4. Mod Isolation Analysis

### Current Isolation Mechanisms

1. **Namespaced Resources**: Resources identified by `mod_id/resource_id` internally
2. **Source Tracking**: `ModRegistry.get_resource_source()` returns providing mod
3. **Priority Separation**: Clear ranges prevent accidental conflicts
4. **Type Registry Separation**: Mod registrations tracked by mod_id

### Potential Conflict Points

**Flag/Variable Namespace Collision**:

GameState flags are global:
```gdscript
# game_state.gd
var story_flags: Dictionary = {}
```

Two mods using flag `"chapter_2_complete"` would conflict. Recommended: Namespace convention `"modid_flagname"`.

**Resource ID Collision**:

If two mods create `classes/knight.tres`, higher priority wins silently. The lower-priority knight is lost. Recommended: Detection and warning for unintentional overrides.

**Audio Path Collision**:

AudioManager uses relative paths:
```gdscript
AudioManager.play_music("battle_theme", 1.0)
```

All mods' `battle_theme.ogg` would compete. Last-loaded wins.

---

## 5. API Surfaces for Modders

### Extension Points

| System | Extension Method | Power Level |
|--------|------------------|-------------|
| AI Behaviors | Subclass AIBrain | High - full control of AI decisions |
| Campaign Flow | register_node_processor(), register_custom_handler() | High - add new node types |
| Custom Types | mod.json custom_types section | Medium - extend enums |
| Scene Override | mod.json scenes section | Medium - replace key scenes |
| Resource Override | Same resource ID, higher priority | High - replace any content |
| Cinematics | JSON command sequences | Medium - scripted sequences |

### Missing Extension Points

1. **Combat Resolution**: No hook between damage calculation and application
2. **Turn Order**: No hook to modify initiative calculations
3. **Targeting**: No hook for custom targeting rules
4. **Status Effects**: No plugin system for custom effects
5. **Movement Costs**: Hardcoded terrain penalties in GridManager
6. **Equipment Effects**: No on-equip/on-attack callbacks

---

## 6. Resource Override System

### Current Behavior

Override detection in ModRegistry:
```gdscript
# mod_registry.gd line 41-43
if resource_id in _resources_by_type[resource_type]:
    var existing_mod: String = _resource_sources.get(resource_id, "unknown")
    print("ModRegistry: Mod '%s' overriding resource '%s' from mod '%s'" % [mod_id, resource_id, existing_mod])
```

This is console-only logging. Users have no visibility into what's being overridden.

### Recommendations

1. **Override Manifest Validation**: Compare declared `overrides` in mod.json against actual overrides. Warn on undeclared overrides.

2. **Conflict Report**: Generate report of all override chains at load time.

3. **Selective Override Opt-out**: Allow mods to declare certain resources as "final" (not overridable).

---

## 7. Editor Tooling (Sparkling Editor)

### Current Coverage

The Sparkling Editor (`/home/user/dev/sparklingfarce/addons/sparkling_editor/`) provides:

| Editor | Resource Type | Features |
|--------|---------------|----------|
| CharacterEditor | CharacterData | Create, edit, delete, reference checking |
| ClassEditor | ClassData | Create, edit, delete, growth rates |
| ItemEditor | ItemData | Create, edit, delete, stat modifiers |
| AbilityEditor | AbilityData | Create, edit, delete |
| BattleEditor | BattleData | Create, edit, delete, unit placement |
| DialogueEditor | DialogueData | Create, edit, delete, branching |
| PartyEditor | PartyData | Create, edit, delete, party composition |

### Editor Strengths

1. **Mod-Aware**: Operates on active mod's directory, not global
2. **Cross-Mod Protection**: Warns before saving to different mod's files
3. **Reference Checking**: Prevents deletion of referenced resources
4. **Base Class Pattern**: `BaseResourceEditor` enables consistent UX

### Editor Gaps

| Missing Editor | Needed For |
|----------------|------------|
| CinematicEditor | Visual command sequencing |
| CampaignEditor | Node graph editing |
| AIBrainEditor | Visual AI behavior trees |
| MapEditor | Tilemap + spawn point editing |
| TilesetEditor | Custom tileset configuration |

The biggest gap is **Campaign editing**. CampaignData JSON files must be edited manually. A visual node graph editor would dramatically improve the modder experience.

---

## 8. Total Conversion Capability Assessment

### What Total Conversions Could Achieve Today

1. Replace all characters, classes, items, abilities
2. Replace all dialogues and cinematics
3. Replace all battle scenarios
4. Replace UI scenes (main menu, save selector)
5. Create custom AI behaviors
6. Add new equipment/weather/unit types

### What Total Conversions CANNOT Do

1. **Change Combat Formulas**: Damage = ATK - DEF is hardcoded
2. **Change Turn Order System**: Initiative-based turns not possible
3. **Add New Resource Types**: Only 9 predefined types in RESOURCE_TYPE_DIRS
4. **Change Movement System**: Pathfinding algorithm is fixed
5. **Add Custom Stat Types**: Only 7 stats (HP, MP, STR, DEF, AGI, INT, LCK)
6. **Change Experience Curve**: Level-up XP thresholds hardcoded

### Genre Conversion Feasibility

| Target Genre | Feasibility | Blockers |
|--------------|-------------|----------|
| Fire Emblem-style SRPG | High (85%) | Weapon triangle system, support bonuses |
| Final Fantasy Tactics | Medium (60%) | Elevation, facing direction combat |
| Advance Wars | Medium (50%) | Production buildings, fog of war |
| XCOM-like | Low (30%) | Cover system, percentage-based accuracy |
| Action RPG | Not Possible | Real-time combat, collision system |

---

## 9. Documentation Requirements

### What Modders Need

1. **Mod Creation Guide**: Step-by-step first mod tutorial
2. **Resource Schema Reference**: All fields for each resource type
3. **Extension Points Catalog**: What can be extended and how
4. **Signal Reference**: All signals mods can connect to
5. **Cinematic Command Reference**: All commands with parameters
6. **AI Brain Authoring Guide**: Context dictionary contents, helper methods
7. **Best Practices**: Naming conventions, folder structure, testing

### Current Documentation State

- `MOD_SYSTEM.md` - Good overview but lacks technical depth
- No API reference documentation
- No modding tutorials
- No example mods with annotations

---

## 10. Recommendations

### Priority 1: Critical (Blocks Total Conversions)

**R1.1: Create CombatConfig Resource**

Move all combat constants to a data-driven config:

```gdscript
# core/resources/combat_config.gd
class_name CombatConfig
extends Resource

@export var damage_variance_min: float = 0.9
@export var damage_variance_max: float = 1.1
@export var base_hit_chance: int = 80
@export var base_crit_chance: int = 5
@export var counter_damage_multiplier: float = 0.75
@export var damage_formula: String = "attacker.strength - defender.defense"
```

Load from mods with highest priority.

**R1.2: Plugin System for Core Systems**

Create registration pattern for system overrides:

```gdscript
# mod_loader.gd
func register_system_override(system_name: String, implementation: Node) -> void
    # Allows mods to replace TurnManager, CombatCalculator, etc.
```

**R1.3: Extensible Resource Type Registry**

Allow mods to define new resource types:

```json
// mod.json
{
  "custom_resource_types": {
    "mount": "data/mounts/",
    "terrain_modifier": "data/terrain/"
  }
}
```

### Priority 2: Important (Improves Mod Power)

**R2.1: Combat Event Hooks**

Add signals for mod injection:

```gdscript
# combat_calculator.gd
signal pre_damage_calculated(attacker, defender, base_damage)
signal post_damage_calculated(attacker, defender, final_damage)
signal pre_hit_roll(attacker, defender, hit_chance)
signal post_combat_resolved(result: CombatResult)
```

**R2.2: Status Effect Plugin System**

Create extensible status effect architecture:

```gdscript
# core/resources/status_effect.gd
class_name StatusEffect
extends Resource

@export var effect_id: String
@export var duration: int
func on_turn_start(unit: Node2D) -> void: pass
func on_turn_end(unit: Node2D) -> void: pass
func on_damage_dealt(unit: Node2D, damage: int) -> int: return damage
func on_damage_received(unit: Node2D, damage: int) -> int: return damage
```

**R2.3: Dynamic Stat System**

Replace hardcoded stats with dictionary:

```gdscript
# unit_stats.gd
var stats: Dictionary = {
    "hp": 10, "mp": 5, "strength": 5, ...
}
# Mods can add: stats["morale"] = 100
```

### Priority 3: Quality of Life

**R3.1: Campaign Node Graph Editor**

Visual tool for creating CampaignData with:
- Drag-and-drop nodes
- Visual connection of branches
- Inline preview of battles/scenes

**R3.2: Mod Conflict Detector**

At load time, generate report:
```
=== Mod Conflict Report ===
[WARNING] classes/knight.tres overridden by mod_b (was mod_a)
[INFO] Declared override: characters/hero.tres by mod_c
[ERROR] Undeclared override: items/sword.tres by mod_d
```

**R3.3: Mod Sandbox Mode**

Test mods in isolation:
```gdscript
ModLoader.enable_sandbox_mode("my_mod_id")
# Only loads base_game + my_mod_id
```

---

## 11. Mod Isolation Recommendations

1. **Require Namespace Prefixes**: Enforce `modid_` prefix on flags, variables
2. **Resource UID Validation**: Warn if two mods define same non-override resource
3. **Dependency Version Pinning**: Support `"dependencies": {"base_game": ">=0.2.0"}`
4. **Load Order Report**: On startup, print exact load order for debugging

---

## Conclusion

The Sparkling Farce has excellent bones for modding. The content pipeline (characters, classes, items, battles) is polished and mod-friendly. The priority system, registry pattern, and editor tooling demonstrate genuine commitment to mod support.

The critical gaps are in **behavior modding**. Combat formulas, game systems, and stat structures are hardcoded in ways that limit total conversions. Addressing the Priority 1 recommendations would elevate this from "good content modding" to "true total conversion platform."

The investment required is moderate - approximately 2-3 development cycles to implement the plugin architecture and config systems. The return would be a modding platform comparable to Wargroove or Battle for Wesnoth.

---

**Modro**
*Mod Architecture Specialist*
*"If it's hardcoded, it's a limitation. If it's data-driven, it's a feature."*
