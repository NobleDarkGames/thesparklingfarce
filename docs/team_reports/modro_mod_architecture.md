# Mod Architecture Review - The Sparkling Farce
**Reviewer**: Modro (AI Mod Architect)
**Date**: 2025-11-26
**Scope**: Complete modding capability assessment
**Codebase Version**: git commit 27a1c81

---

## EXECUTIVE SUMMARY

**Overall Moddability Score: 7/10**

The Sparkling Farce demonstrates STRONG fundamentals for a moddable platform. The mod system architecture (ModLoader, ModRegistry, ModManifest) is well-designed with proper priority-based loading and resource override support. However, several HARDCODED values and MISSING_HOOK points limit total conversion potential. The cinematic command executor pattern is EXEMPLARY and should be replicated across other systems.

**Critical Path to 9/10**: Address hardcoded combat formulas, add UI theming system, implement custom stat system support.

---

## SECTION 1: MOD SYSTEM CORE ARCHITECTURE

### GOOD_PATTERN: ModLoader/ModRegistry Architecture
**Files**:
- `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd`
- `/home/user/dev/sparklingfarce/core/mod_system/mod_registry.gd`
- `/home/user/dev/sparklingfarce/core/mod_system/mod_manifest.gd`

**Assessment**: EXCELLENT mod loading infrastructure.

Strengths:
- Priority-based loading (0-9999) enables proper override layering
- Alphabetical tiebreaker ensures deterministic cross-platform behavior
- Dependencies are checked before load
- Resource source tracking (`_resource_sources`) enables debugging conflicts
- `get_mods_by_priority_descending()` useful for conflict resolution

```
RESOURCE_TYPE_DIRS = {
    "characters": "character",
    "classes": "class",
    "items": "item",
    "abilities": "ability",
    "dialogues": "dialogue",
    "cinematics": "cinematic",
    "parties": "party",
    "battles": "battle"
}
```

### INFLEXIBLE: Fixed Resource Type Directories
**File**: `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd` (lines 19-28)

**Issue**: The `RESOURCE_TYPE_DIRS` constant is hardcoded. Mods cannot add new resource types without engine modification.

**Recommendation**: Make this data-driven:
```gdscript
# In mod.json, allow:
"custom_resource_types": {
    "quests": "quest",
    "factions": "faction",
    "weather_effects": "weather"
}
```

ModLoader should merge custom types from manifests into the discovery list.

### MISSING_HOOK: No Mod Lifecycle Callbacks
**File**: `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd`

**Issue**: Mods cannot execute initialization code when loaded. No `on_load()` or `on_unload()` hooks.

**Impact**: Mods needing to register custom systems (signal handlers, autoloads, editor extensions) have no entry point.

**Recommendation**: Add optional script reference in mod.json:
```json
"scripts": {
    "on_load": "scripts/init.gd",
    "on_unload": "scripts/cleanup.gd"
}
```

---

## SECTION 2: RESOURCE DATA DEFINITIONS

### GOOD_PATTERN: Resource-Based Content
**Files**: `/home/user/dev/sparklingfarce/core/resources/*.gd`

All content types use Godot Resource classes with `@export` properties:
- `CharacterData` - Characters with stats, appearance, equipment
- `ClassData` - Classes with growth rates, equipment restrictions, abilities
- `ItemData` - Items with stat modifiers and effects
- `AbilityData` - Abilities with targeting and effects
- `BattleData` - Complete battle scenarios
- `DialogueData` - Dialogue sequences with branching
- `CinematicData` - Scripted cutscenes

**Strengths**:
- Fully editable in Godot Inspector
- Serializable to `.tres` files
- Override-friendly via mod priority

### HARDCODED: Fixed Stat Names
**File**: `/home/user/dev/sparklingfarce/core/resources/character_data.gd` (lines 9-17)

```gdscript
@export var base_hp: int = 10
@export var base_mp: int = 5
@export var base_strength: int = 5
@export var base_defense: int = 5
@export var base_agility: int = 5
@export var base_intelligence: int = 5
@export var base_luck: int = 5
```

**Issue**: Stats are hardcoded property names. A total conversion wanting different stats (e.g., "Tech", "Psi", "Reflex" for sci-fi) cannot add them without engine modification.

**Recommendation**: Replace with Dictionary-based stats:
```gdscript
@export var base_stats: Dictionary = {
    "hp": 10,
    "mp": 5,
    "strength": 5,
    # Modders can add: "tech": 10, "psi": 5
}
```

Same pattern needed in:
- `ClassData.gd` (growth rates)
- `ItemData.gd` (stat modifiers)
- `UnitStats` component
- `CombatCalculator.gd`
- `ExperienceManager.gd` (level-up stat increases)

### HARDCODED: Fixed Item Types
**File**: `/home/user/dev/sparklingfarce/core/resources/item_data.gd` (lines 7-12)

```gdscript
enum ItemType {
    WEAPON,
    ARMOR,
    CONSUMABLE,
    KEY_ITEM
}
```

**Issue**: Cannot add new item categories (e.g., "ACCESSORY", "MOUNT", "CARD") without engine modification.

**Recommendation**: Replace enum with String and validate against registered types:
```gdscript
@export var item_type: String = "weapon"  # Modder-defined types allowed
```

### HARDCODED: Fixed Movement Types
**File**: `/home/user/dev/sparklingfarce/core/resources/class_data.gd` (lines 7-11)

```gdscript
enum MovementType {
    WALKING,
    FLYING,
    FLOATING
}
```

**Impact**: No aquatic units, no underground burrowing, no teleporting movement types.

**Recommendation**: String-based with registered movement handlers.

### HARDCODED: Victory/Defeat Conditions
**File**: `/home/user/dev/sparklingfarce/core/resources/battle_data.gd` (lines 8-24)

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

**Positive**: `CUSTOM` exists with `custom_victory_script: GDScript` support (line 58).

**Issue**: `CUSTOM` requires GDScript which may not load from mods properly in exported builds.

**Recommendation**: Document the custom script loading pattern. Ensure mod scripts can be loaded at runtime.

---

## SECTION 3: COMBAT SYSTEM EXTENSIBILITY

### HARDCODED: Combat Formulas
**File**: `/home/user/dev/sparklingfarce/core/systems/combat_calculator.gd`

**Critical Issue**: All combat formulas are hardcoded constants and functions.

```gdscript
const DAMAGE_VARIANCE_MIN: float = 0.9
const DAMAGE_VARIANCE_MAX: float = 1.1
const BASE_HIT_CHANCE: int = 80
const BASE_CRIT_CHANCE: int = 5
const COUNTER_DAMAGE_MULTIPLIER: float = 0.75
```

Physical damage formula (line 25):
```gdscript
var base_damage: int = attacker_stats.strength - defender_stats.defense
```

**Impact**:
- Cannot create games with different combat math (percentage-based, elemental, rock-paper-scissors)
- Cannot add damage types or resistances
- Total conversions BLOCKED from changing fundamental combat feel

**Recommendation**: Create `CombatConfig` resource:
```gdscript
class_name CombatConfig extends Resource

@export var damage_formula: String = "attacker.strength - defender.defense"
@export var hit_formula: String = "80 + (attacker.agility - defender.agility) * 2"
@export var damage_variance: Vector2 = Vector2(0.9, 1.1)
```

Or use a plugin/strategy pattern for combat calculators.

### HARDCODED: Turn Priority Formula
**File**: `/home/user/dev/sparklingfarce/core/systems/turn_manager.gd` (lines 7-11)

```gdscript
const AGI_VARIANCE_MIN: float = 0.875
const AGI_VARIANCE_MAX: float = 1.125
const AGI_OFFSET_MIN: int = -1
const AGI_OFFSET_MAX: int = 1
```

**Issue**: Turn order is always AGI-based. Cannot implement:
- Pure player-first/enemy-first phases
- Speed tiers
- CTB (Conditional Turn-Based) systems

### GOOD_PATTERN: AIBrain System
**Files**:
- `/home/user/dev/sparklingfarce/core/resources/ai_brain.gd`
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/ai_aggressive.gd`

**Excellent Pattern**: AI behavior is fully data-driven via Resource subclasses.

```gdscript
func execute(unit: Node2D, context: Dictionary) -> void:
    # Modders implement custom behavior
```

Mods can create entirely new AI behaviors by extending `AIBrain`:
- Defensive AI, support AI, boss AI
- Faction-specific behavior
- Environmental awareness

**No changes needed** - this is the model for other systems.

---

## SECTION 4: CINEMATIC SYSTEM (EXEMPLARY)

### GOOD_PATTERN: Command Executor Registry
**Files**:
- `/home/user/dev/sparklingfarce/core/systems/cinematics_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_command_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/*.gd`

**EXEMPLARY PATTERN** - This is how all extensible systems should work.

The cinematic system uses a registry pattern:
```gdscript
var _command_executors: Dictionary = {}  # command_type -> executor

func register_command_executor(command_type: String, executor: CinematicCommandExecutor) -> void:
    _command_executors[command_type] = executor
```

Mods can register custom commands:
```gdscript
CinematicsManager.register_command_executor("custom_effect", MyCustomExecutor.new())
```

**Strengths**:
- Completely extensible without engine modification
- Clear base class to extend (`CinematicCommandExecutor`)
- Built-in commands serve as examples
- `interrupt()` method for cleanup during skip

**Recommendation**: Document this pattern prominently. Replicate for:
- Combat actions (Attack, Magic, Item, Wait + custom)
- Status effects
- UI widgets

### MISSING_HOOK: No Mod Init for Executor Registration
**Issue**: When would a mod register its custom executors?

Currently mods have no code entry point. They can provide `.tres` data but cannot run initialization scripts.

**Recommendation**: Implement the mod lifecycle hooks mentioned in Section 1. Allow:
```gdscript
# mods/my_mod/scripts/init.gd
func _on_mod_loaded() -> void:
    CinematicsManager.register_command_executor("my_effect", MyEffectExecutor.new())
```

---

## SECTION 5: EXPERIENCE/PROGRESSION SYSTEM

### GOOD_PATTERN: ExperienceConfig Resource
**File**: `/home/user/dev/sparklingfarce/core/resources/experience_config.gd`

XP settings are properly externalized to a resource:
- `enable_participation_xp`, `participation_radius`, `participation_multiplier`
- `kill_bonus_multiplier`, `max_xp_per_action`
- `level_diff_xp_table` (Dictionary mapping level difference to XP)
- Anti-spam settings
- Support action XP (heal, buff, debuff)

**Strengths**: Most XP tuning is data-driven.

### HARDCODED: Stat Growth in Level-Up
**File**: `/home/user/dev/sparklingfarce/core/systems/experience_manager.gd` (lines 302-329)

```gdscript
var stats_to_grow: Array[String] = ["hp", "mp", "strength", "defense", "agility", "intelligence", "luck"]

for stat_name in stats_to_grow:
    var growth_rate: int = class_data.get_growth_rate(stat_name)
    var increase: int = _calculate_stat_increase(growth_rate)

    match stat_name:
        "hp":
            unit.stats.max_hp += increase
        # ... hardcoded for each stat
```

**Issue**: Same stat hardcoding problem. Custom stats won't level up.

---

## SECTION 6: DIALOG SYSTEM

### GOOD_PATTERN: DialogueData Resource
**File**: `/home/user/dev/sparklingfarce/core/resources/dialogue_data.gd`

Dialogues are fully data-driven:
- Lines stored as Dictionary array
- Branching choices with `next_dialogue` references
- Box positioning options
- Audio references

### MISSING_HOOK: No Dialog Event Hooks
**File**: `/home/user/dev/sparklingfarce/core/systems/dialog_manager.gd`

**Issue**: No hooks for mods to inject behavior:
- Custom text effects (shake, color, delay)
- Conditional line display based on game state
- Custom portrait expression system
- Voice acting integration points

Signals exist but are for UI, not for mod interception:
```gdscript
signal dialog_started(dialogue_data: DialogueData)
signal line_changed(line_index: int, line_data: Dictionary)
```

**Recommendation**: Add pre/post hooks:
```gdscript
signal before_line_display(line_data: Dictionary)  # Mods can modify
signal after_line_display(line_data: Dictionary)
```

---

## SECTION 7: MOD CONFLICT ANALYSIS

### CONFLICT_RISK: Resource ID Collisions
**Current Behavior**: Last-loaded mod wins (highest priority).

**Issue**: Two mods both adding `characters/knight.tres` will silently override. Only console warning appears:
```gdscript
print("ModRegistry: Mod '%s' overriding resource '%s' from mod '%s'" % [mod_id, resource_id, existing_mod])
```

**Impact**: Users may not realize content is being replaced.

**Recommendation**:
1. Add `strict_mode` option that errors on unintended overrides
2. Require explicit `overrides` declaration in mod.json for intentional overrides
3. Consider namespacing: `mod_id:resource_id`

### CONFLICT_RISK: Signal Handler Stacking
**Issue**: If multiple mods connect to the same signal (via lifecycle hooks), all handlers run. May cause unexpected behavior.

**Recommendation**: Document signal ownership. Consider priority for signal handlers.

### GOOD_PATTERN: Mod Priority Ranges
```
0-99:      Official content
100-8999:  User mods
9000-9999: Total conversions
```

This is well-designed. Total conversions can reliably override everything.

---

## SECTION 8: EDITOR INTEGRATION (SPARKLING EDITOR)

### INFLEXIBLE: Minimal Editor Addon
**Directory**: `/home/user/dev/sparklingfarce/addons/sparkling_editor/`

Current addon is minimal:
- `editor_event_bus.gd` - Signal bus
- `editor_plugin.gd` - Basic plugin setup
- `ui/` - Some UI components

**Issue**: No evidence of:
- Visual tileset editor for mods
- Character/class editor panels
- Battle scenario designer
- Dialogue tree visual editor
- Cinematic sequence builder

**Impact**: Modders must manually edit `.tres` files or use raw Godot Inspector. High friction.

**Recommendation**: Priority editor tools needed:
1. Character creator with stat preview
2. Battle map designer with enemy placement
3. Dialogue tree visualizer
4. Cinematic timeline editor

---

## SECTION 9: TOTAL CONVERSION CAPABILITY ASSESSMENT

### Can a modder create a sci-fi action RPG?

| Requirement | Status | Blocker |
|-------------|--------|---------|
| Replace all art | YES | None - asset override works |
| Replace all audio | YES | None - asset override works |
| Change combat formulas | NO | HARDCODED in CombatCalculator |
| Add new stat types | NO | HARDCODED stat names |
| Change movement types | NO | HARDCODED enum |
| Custom item categories | NO | HARDCODED enum |
| Custom AI behaviors | YES | AIBrain pattern works |
| Custom cinematics | YES | Executor registry works |
| Custom UI themes | PARTIAL | Scene override possible, no theming system |
| Custom turn system | NO | HARDCODED AGI-based turns |
| Custom victory conditions | PARTIAL | CUSTOM exists but script loading unclear |

**Verdict**: 60% total conversion capable. Combat system is the primary blocker.

---

## SECTION 10: PRIORITIZED RECOMMENDATIONS

### P0 - Critical for Platform Promise

1. **Implement CombatConfig Resource**
   - Move all combat formulas to data
   - Allow formula strings or strategy pattern
   - File: Create `/home/user/dev/sparklingfarce/core/resources/combat_config.gd`

2. **Implement Dictionary-Based Stats**
   - Replace fixed stat properties with stat Dictionary
   - Update all systems that reference stats
   - Files: `character_data.gd`, `class_data.gd`, `item_data.gd`, `combat_calculator.gd`, `experience_manager.gd`

3. **Add Mod Lifecycle Hooks**
   - `on_load()` / `on_unload()` script support in mod.json
   - Enable runtime code registration
   - File: `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd`

### P1 - Important for Usability

4. **Allow Custom Resource Types**
   - Make `RESOURCE_TYPE_DIRS` extensible via mod.json
   - File: `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd`

5. **Implement Status Effect Registry**
   - Follow cinematic executor pattern
   - Enable custom status effects without engine modification

6. **Add Combat Action Registry**
   - Replicate cinematic executor pattern for battle actions
   - Enable custom actions beyond Attack/Magic/Item/Wait

### P2 - Quality of Life

7. **Improve Conflict Detection**
   - Warn on unintended overrides
   - Support `strict_mode` for debugging

8. **Create Visual Editors**
   - Character/Class editor
   - Battle designer
   - Dialogue tree editor

9. **Document Extension Points**
   - Create modding guide
   - Provide mod templates
   - Example mods for common use cases

---

## APPENDIX: FILE REFERENCE INDEX

### Core Mod System
- `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd` - Mod discovery and loading
- `/home/user/dev/sparklingfarce/core/mod_system/mod_registry.gd` - Resource registry
- `/home/user/dev/sparklingfarce/core/mod_system/mod_manifest.gd` - Manifest parsing

### Resource Definitions (Content Schemas)
- `/home/user/dev/sparklingfarce/core/resources/character_data.gd`
- `/home/user/dev/sparklingfarce/core/resources/class_data.gd`
- `/home/user/dev/sparklingfarce/core/resources/item_data.gd`
- `/home/user/dev/sparklingfarce/core/resources/ability_data.gd`
- `/home/user/dev/sparklingfarce/core/resources/battle_data.gd`
- `/home/user/dev/sparklingfarce/core/resources/dialogue_data.gd`
- `/home/user/dev/sparklingfarce/core/resources/cinematic_data.gd`
- `/home/user/dev/sparklingfarce/core/resources/ai_brain.gd`
- `/home/user/dev/sparklingfarce/core/resources/experience_config.gd`

### Game Systems (Engine Code)
- `/home/user/dev/sparklingfarce/core/systems/battle_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/combat_calculator.gd`
- `/home/user/dev/sparklingfarce/core/systems/turn_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/grid_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/experience_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/dialog_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematics_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/ai_controller.gd`
- `/home/user/dev/sparklingfarce/core/systems/game_state.gd`

### Exemplary Extension Pattern
- `/home/user/dev/sparklingfarce/core/systems/cinematic_command_executor.gd` - Base class
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/*.gd` - Built-in executors

### Mod Content Examples
- `/home/user/dev/sparklingfarce/mods/_base_game/` - Official reference mod
- `/home/user/dev/sparklingfarce/mods/_sandbox/` - Testing mod
- `/home/user/dev/sparklingfarce/mods/base_game/ai_brains/` - Custom AI examples

---

## METADATA FOR AI AGENTS

```yaml
review_type: mod_architecture
score: 7/10
blocking_issues:
  - hardcoded_combat_formulas
  - hardcoded_stat_names
  - no_mod_lifecycle_hooks
exemplary_patterns:
  - cinematic_command_executor_registry
  - ai_brain_resource_pattern
  - mod_priority_system
recommended_next_actions:
  - implement_combat_config_resource
  - implement_dictionary_stats
  - add_mod_on_load_hooks
files_needing_refactor:
  - /home/user/dev/sparklingfarce/core/systems/combat_calculator.gd
  - /home/user/dev/sparklingfarce/core/resources/character_data.gd
  - /home/user/dev/sparklingfarce/core/resources/class_data.gd
  - /home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd
```

---

*Report generated by Modro, Mod Architecture Specialist*
*"Every design decision either empowers modders or constrains them."*
