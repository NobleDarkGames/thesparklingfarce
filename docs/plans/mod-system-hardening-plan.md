# Mod System Hardening Plan

**Version**: 1.0.0
**Date**: 2025-12-11
**Author**: Lt. Claudbrain
**Status**: Proposed

---

## Executive Summary

This plan addresses 15 issues identified in the comprehensive mod system audit, organized into 5 implementation phases. The goal is to transform the Sparkling Farce platform from "works for careful modders" to "robust for the three modder personas" (Casual Artist, SF Purist, Total Conversion Modder).

**Total Estimated Effort**: 10-14 days
**Breaking Changes**: Phase 3 contains the only high-risk breaking change (stat system refactor)
**Critical Path**: Phase 1 must complete before Phase 2; Phase 3 is independent

---

## Phase Dependencies

```
Phase 1 (Security/Stability) --> Phase 2 (Modding Infrastructure)
                                        |
                                        v
                                 Phase 4 (Editor UX)
                                        |
Phase 3 (Combat Extensibility) --------+
                                        |
                                        v
                                 Phase 5 (Polish)
```

---

## Phase 1: Critical Security & Stability (P0)

**Goal**: Prevent crashes, infinite loops, and security vulnerabilities
**Estimated Effort**: 1 day
**Risk Level**: Low (additive changes only)
**Blocking Issues**: None
**Persona Impact**: All modders benefit

### 1.1 Circular Dependency Detection

**Issue #1**: Mod A depends on Mod B, and B depends on A causes infinite loop or undefined behavior.

**File**: `core/mod_system/mod_loader.gd`

**Implementation**:
```gdscript
## Perform topological sort with cycle detection
## Returns sorted mods or null if cycle detected
func _topological_sort(mods: Array[ModManifest]) -> Array[ModManifest]:
    var sorted: Array[ModManifest] = []
    var permanent_marks: Dictionary = {}  # mod_id -> true
    var temporary_marks: Dictionary = {}  # mod_id -> true (for cycle detection)
    var mod_map: Dictionary = {}  # mod_id -> ModManifest

    # Build lookup map
    for mod: ModManifest in mods:
        mod_map[mod.mod_id] = mod

    # Visit each node
    for mod: ModManifest in mods:
        if mod.mod_id not in permanent_marks:
            if not _visit_mod(mod, mod_map, permanent_marks, temporary_marks, sorted):
                return []  # Cycle detected

    return sorted


func _visit_mod(
    mod: ModManifest,
    mod_map: Dictionary,
    permanent: Dictionary,
    temporary: Dictionary,
    sorted: Array[ModManifest]
) -> bool:
    if mod.mod_id in permanent:
        return true
    if mod.mod_id in temporary:
        # Cycle detected - build error message
        _emit_cycle_error(mod.mod_id, temporary.keys())
        return false

    temporary[mod.mod_id] = true

    for dep_id: String in mod.dependencies:
        if dep_id in mod_map:
            if not _visit_mod(mod_map[dep_id], mod_map, permanent, temporary, sorted):
                return false

    temporary.erase(mod.mod_id)
    permanent[mod.mod_id] = true
    sorted.append(mod)
    return true


func _emit_cycle_error(start_mod: String, cycle_path: Array) -> void:
    var path_str: String = " -> ".join(cycle_path) + " -> " + start_mod
    push_error("ModLoader: Circular dependency detected: %s" % path_str)
    push_error("ModLoader: Fix by removing one dependency from the cycle")
```

**Changes to `_discover_and_load_mods()`**:
```gdscript
func _discover_and_load_mods() -> void:
    var discovered_mods: Array[ModManifest] = _discover_mods()
    if discovered_mods.is_empty():
        push_warning("ModLoader: No mods found in " + MODS_DIRECTORY)
        return

    # NEW: Resolve dependencies with cycle detection
    var resolved_mods: Array[ModManifest] = _topological_sort(discovered_mods)
    if resolved_mods.is_empty():
        push_error("ModLoader: Cannot proceed due to circular dependencies")
        return

    # Then sort by priority within dependency order
    resolved_mods.sort_custom(_sort_by_priority)

    # Load each mod
    for manifest in resolved_mods:
        _load_mod(manifest)
```

**Testing Requirements**:
- Unit test: Simple A->B->C chain resolves correctly
- Unit test: A->B, B->A cycle detected and rejected
- Unit test: A->B, B->C, C->A triangle cycle detected
- Unit test: Self-dependency (A->A) detected

---

### 1.2 Mod ID Sanitization

**Issue #2**: Mod IDs taken directly from mod.json without sanitization. Allows path traversal, empty IDs, special characters.

**File**: `core/mod_system/mod_manifest.gd`

**Implementation** (add after line 133):
```gdscript
## Reserved mod IDs that cannot be used
const RESERVED_MOD_IDS: Array[String] = [
    "core", "engine", "godot", "system", "base", "default", "null", "none"
]

## Regex pattern for valid mod IDs: alphanumeric, underscore, hyphen only
const MOD_ID_PATTERN: String = "^[a-zA-Z][a-zA-Z0-9_-]*$"
static var _mod_id_regex: RegEx = null


## Validate and sanitize a mod ID
## Returns sanitized ID or empty string if invalid
static func _sanitize_mod_id(raw_id: String) -> String:
    if raw_id.is_empty():
        push_error("mod.json: 'id' cannot be empty")
        return ""

    var sanitized: String = raw_id.strip_edges()

    # Check for path traversal attempts
    if ".." in sanitized or "/" in sanitized or "\\" in sanitized:
        push_error("mod.json: 'id' contains invalid path characters: %s" % raw_id)
        return ""

    # Check against reserved words
    if sanitized.to_lower() in RESERVED_MOD_IDS:
        push_error("mod.json: 'id' uses reserved word: %s" % sanitized)
        return ""

    # Validate format (must start with letter, only alphanumeric/underscore/hyphen)
    if _mod_id_regex == null:
        _mod_id_regex = RegEx.new()
        _mod_id_regex.compile(MOD_ID_PATTERN)

    if not _mod_id_regex.search(sanitized):
        push_error("mod.json: 'id' must start with letter and contain only letters, numbers, underscores, hyphens: %s" % raw_id)
        return ""

    # Length check (reasonable bounds)
    if sanitized.length() > 64:
        push_error("mod.json: 'id' exceeds maximum length of 64 characters")
        return ""

    return sanitized
```

**Update `load_from_file()` (around line 135)**:
```gdscript
# Before: manifest.mod_id = data.get("id", "")
# After:
var raw_id: String = data.get("id", "")
var sanitized_id: String = _sanitize_mod_id(raw_id)
if sanitized_id.is_empty():
    push_error("mod.json: Invalid or missing 'id' at: " + json_path)
    return null
manifest.mod_id = sanitized_id
```

**Testing Requirements**:
- Unit test: Valid IDs pass (my_mod, _base_game, mod-name-123)
- Unit test: Path traversal rejected (../hack, mod/../etc)
- Unit test: Reserved words rejected (core, system, null)
- Unit test: Invalid format rejected (123mod, mod name, mod.id)
- Unit test: Empty ID rejected

---

### 1.3 Priority Value Clamping

**Issue #12**: Priority values not clamped to 0-9999 range.

**File**: `core/mod_system/mod_manifest.gd`

**Implementation** (update line 141):
```gdscript
# Before: manifest.load_priority = data.get("load_priority", 0)
# After:
var raw_priority: Variant = data.get("load_priority", 0)
var priority: int = 0
if raw_priority is int or raw_priority is float:
    priority = clampi(int(raw_priority), MIN_PRIORITY, MAX_PRIORITY)
    if int(raw_priority) != priority:
        push_warning("mod.json: 'load_priority' %d clamped to %d (valid range: %d-%d)" % [
            int(raw_priority), priority, MIN_PRIORITY, MAX_PRIORITY
        ])
else:
    push_warning("mod.json: 'load_priority' must be a number, using default 0")
manifest.load_priority = priority
```

**Testing Requirements**:
- Unit test: Valid priorities pass through unchanged
- Unit test: Negative priority clamped to 0
- Unit test: Priority > 9999 clamped to 9999
- Unit test: String priority triggers warning, uses default

---

## Phase 2: Modding Infrastructure (P1)

**Goal**: Unblock Total Conversion modders and Casual Artists
**Estimated Effort**: 3-4 days
**Risk Level**: Medium (API additions, fallback patterns)
**Blocking Issues**: Phase 1 completion
**Persona Impact**: Total Conversion Modder (critical), Casual Artist (high)

### 2.1 Scene Override System

**Issue #4**: Hardcoded scene preloads prevent total conversions from replacing core UI.

**Files to Modify**:
- `core/systems/battle_manager.gd` (lines 44-57)
- `core/systems/exploration_ui_manager.gd` (lines 33-37)

**Implementation Pattern**:

Create a new helper in `ModLoader`:
```gdscript
## Get a scene by ID, with fallback to default path
## @param scene_id: The registered scene ID (e.g., "unit_scene", "combat_anim_scene")
## @param fallback_path: Default path if no mod provides this scene
## @return: Loaded PackedScene, or null if neither found
func get_scene_or_fallback(scene_id: String, fallback_path: String) -> PackedScene:
    var mod_path: String = registry.get_scene_path(scene_id)
    if not mod_path.is_empty() and FileAccess.file_exists(mod_path):
        return load(mod_path) as PackedScene

    if not fallback_path.is_empty() and FileAccess.file_exists(fallback_path):
        return load(fallback_path) as PackedScene

    push_error("ModLoader: Scene '%s' not found (fallback: %s)" % [scene_id, fallback_path])
    return null
```

**Update `battle_manager.gd`**:
```gdscript
# Before (lines 44-57):
const UNIT_SCENE: PackedScene = preload("res://scenes/unit.tscn")
const COMBAT_ANIM_SCENE: PackedScene = preload("res://scenes/ui/combat_animation_scene.tscn")
# ... etc

# After:
# Default paths for fallback (still used if no mod overrides)
const DEFAULT_UNIT_SCENE: String = "res://scenes/unit.tscn"
const DEFAULT_COMBAT_ANIM_SCENE: String = "res://scenes/ui/combat_animation_scene.tscn"
const DEFAULT_LEVEL_UP_SCENE: String = "res://scenes/ui/level_up_celebration.tscn"
const DEFAULT_VICTORY_SCREEN_SCENE: String = "res://scenes/ui/victory_screen.tscn"
const DEFAULT_DEFEAT_SCREEN_SCENE: String = "res://scenes/ui/defeat_screen.tscn"
const DEFAULT_COMBAT_RESULTS_SCENE: String = "res://scenes/ui/combat_results_panel.tscn"

# Cached scene references (loaded lazily with mod override support)
var _unit_scene: PackedScene = null
var _combat_anim_scene: PackedScene = null
var _level_up_scene: PackedScene = null
var _victory_screen_scene: PackedScene = null
var _defeat_screen_scene: PackedScene = null
var _combat_results_scene: PackedScene = null


func _get_unit_scene() -> PackedScene:
    if _unit_scene == null:
        _unit_scene = ModLoader.get_scene_or_fallback("unit_scene", DEFAULT_UNIT_SCENE)
    return _unit_scene


func _get_combat_anim_scene() -> PackedScene:
    if _combat_anim_scene == null:
        _combat_anim_scene = ModLoader.get_scene_or_fallback("combat_anim_scene", DEFAULT_COMBAT_ANIM_SCENE)
    return _combat_anim_scene

# ... similar for other scenes
```

**Update usage** (e.g., line 303):
```gdscript
# Before: var unit: Node2D = UNIT_SCENE.instantiate()
# After: var unit: Node2D = _get_unit_scene().instantiate()
```

**Mod.json Schema Update** (document in platform-specification.md):
```json
{
  "scenes": {
    "unit_scene": "scenes/custom_unit.tscn",
    "combat_anim_scene": "scenes/ui/custom_combat.tscn",
    "level_up_scene": "scenes/ui/custom_levelup.tscn",
    "victory_screen_scene": "scenes/ui/custom_victory.tscn",
    "defeat_screen_scene": "scenes/ui/custom_defeat.tscn"
  }
}
```

**Testing Requirements**:
- Integration test: Base game loads with default scenes
- Integration test: Mod with scene override uses mod's scene
- Integration test: Mod with invalid scene path falls back to default
- Manual test: Total conversion can replace combat screen

---

### 2.2 Asset Override System (Casual Artist Support)

**Issue #6**: Artists must edit .tres files to replace sprites. No "drop-in replacement" workflow.

**File**: `core/mod_system/mod_loader.gd`

**New API**:
```gdscript
## Resolve an asset path through the mod override system.
## Checks mods in descending priority order for a matching asset path.
##
## @param relative_path: Path relative to mod's assets directory (e.g., "icons/items/sword.png")
## @param fallback_base_path: Base path to check if no mod provides the asset (e.g., "res://mods/_base_game/assets/")
## @return: The full resolved path, or empty string if not found
func resolve_asset_path(relative_path: String, fallback_base_path: String = "") -> String:
    # Sanitize path (prevent traversal)
    if ".." in relative_path:
        push_error("ModLoader: Invalid asset path (contains ..): %s" % relative_path)
        return ""

    # Check mods in descending priority order (highest priority first)
    var mods: Array[ModManifest] = get_mods_by_priority_descending()
    for mod: ModManifest in mods:
        var full_path: String = mod.get_assets_directory().path_join(relative_path)
        if FileAccess.file_exists(full_path):
            return full_path

    # Fallback to base path
    if not fallback_base_path.is_empty():
        var fallback_full: String = fallback_base_path.path_join(relative_path)
        if FileAccess.file_exists(fallback_full):
            return fallback_full

    return ""


## Load a texture through the mod override system.
## Convenience wrapper around resolve_asset_path for common use case.
##
## @param relative_path: Path relative to mod's assets directory (e.g., "icons/items/sword.png")
## @return: The loaded Texture2D, or null if not found
func load_texture_override(relative_path: String) -> Texture2D:
    var path: String = resolve_asset_path(relative_path, "res://mods/_base_game/assets/")
    if path.is_empty():
        return null
    return load(path) as Texture2D
```

**Documentation** (add to platform-specification.md):
```markdown
### Asset Override System

Casual artists can replace game assets without editing .tres files:

1. Create matching folder structure in your mod's `assets/` directory
2. Place replacement files with identical names
3. Higher-priority mods automatically override lower-priority assets

**Example**: Replace the sword icon
```
mods/my_art_pack/
  assets/
    icons/
      items/
        sword.png  <- This replaces _base_game's sword.png
```

**Supported Asset Types**:
- Images (PNG, JPG, WebP)
- Audio (OGG, WAV)
- Fonts (TTF, OTF)
```

**Testing Requirements**:
- Unit test: Base asset loads when no override exists
- Unit test: Mod asset overrides base asset
- Unit test: Higher priority mod wins over lower priority
- Unit test: Path traversal attempts rejected
- Manual test: Artist replaces sprite without touching .tres

---

### 2.3 Same-Priority Conflict Detection

**Issue #7**: Two mods at same priority providing same resource ID silently uses alphabetical order.

**File**: `core/mod_system/mod_registry.gd`

**Implementation**:
```gdscript
# Add tracking for override chains
var _override_chains: Dictionary = {}  # resource_id -> Array[{mod_id, path, priority}]


## Register a resource from a mod (updated with conflict detection)
func register_resource(resource: Resource, resource_type: String, resource_id: String, mod_id: String) -> void:
    if not resource:
        push_error("Attempted to register null resource: " + resource_id)
        return

    # Ensure type dictionary exists
    if resource_type not in _resources_by_type:
        _resources_by_type[resource_type] = {}

    # Check for same-priority conflict
    var composite_id: String = "%s:%s" % [resource_type, resource_id]
    if resource_id in _resources_by_type[resource_type]:
        var existing_mod_id: String = _resource_sources.get(resource_id, "")
        var existing_priority: int = _get_mod_priority(existing_mod_id)
        var new_priority: int = _get_mod_priority(mod_id)

        if existing_priority == new_priority and existing_mod_id != mod_id:
            push_warning("ModRegistry: Same-priority conflict for %s '%s' - mod '%s' overrides '%s' (alphabetical)" % [
                resource_type, resource_id, mod_id, existing_mod_id
            ])

        # Track override chain
        if composite_id not in _override_chains:
            _override_chains[composite_id] = []
        _override_chains[composite_id].append({
            "mod_id": existing_mod_id,
            "priority": existing_priority
        })

    # Register the resource (overrides any existing resource with same ID)
    _resources_by_type[resource_type][resource_id] = resource
    _resource_sources[resource_id] = mod_id

    # Track mod's resources
    if mod_id not in _mod_resources:
        _mod_resources[mod_id] = []
    if resource_id not in _mod_resources[mod_id]:
        _mod_resources[mod_id].append(resource_id)


func _get_mod_priority(mod_id: String) -> int:
    if ModLoader:
        var mod: ModManifest = ModLoader.get_mod(mod_id)
        if mod:
            return mod.load_priority
    return 0


## Get the override chain for a resource (for debugging/editor display)
func get_override_chain(resource_type: String, resource_id: String) -> Array:
    var composite_id: String = "%s:%s" % [resource_type, resource_id]
    return _override_chains.get(composite_id, []).duplicate()
```

**Testing Requirements**:
- Unit test: Warning emitted for same-priority conflict
- Unit test: No warning for different-priority override
- Unit test: Override chain correctly tracked
- Manual test: Editor shows override chain info

---

## Phase 3: Combat System Extensibility (P1)

**Goal**: Enable Total Conversion modders to replace combat mechanics
**Estimated Effort**: 2-3 days
**Risk Level**: Medium (new resource type, formula delegation)
**Blocking Issues**: None (can run parallel to Phase 2)
**Persona Impact**: Total Conversion Modder (critical)

### 3.1 Combat Formula Configuration

**Issue #3**: Physical damage formula `attack - defense` is hardcoded. Total conversions cannot change mechanics.

**New Resource**: `core/resources/combat_formula_config.gd`

```gdscript
class_name CombatFormulaConfig
extends Resource

## Configuration for combat formulas
## Allows mods to override how damage, hit chance, and critical hits are calculated

## Display name for this formula set (shown in editors)
@export var display_name: String = "Default (Shining Force)"

## Description of the formula behavior
@export var description: String = "Classic Shining Force combat formulas"

## Path to custom formula script (must extend CombatFormulaBase)
## Leave empty to use default CombatCalculator formulas
@export_file("*.gd") var formula_script_path: String = ""

## Cached formula instance
var _formula_instance: RefCounted = null


## Get or create the formula calculator instance
func get_formula_calculator() -> RefCounted:
    if _formula_instance != null:
        return _formula_instance

    if formula_script_path.is_empty():
        return null  # Use default CombatCalculator

    if not FileAccess.file_exists(formula_script_path):
        push_error("CombatFormulaConfig: Script not found: %s" % formula_script_path)
        return null

    var script: GDScript = load(formula_script_path)
    if not script:
        push_error("CombatFormulaConfig: Failed to load script: %s" % formula_script_path)
        return null

    _formula_instance = script.new()
    return _formula_instance
```

**New Base Class**: `core/systems/combat_formula_base.gd`

```gdscript
class_name CombatFormulaBase
extends RefCounted

## Base class for custom combat formulas
## Extend this to create completely different combat systems

## Calculate physical attack damage
## Override this to change the damage formula
func calculate_physical_damage(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
    # Default: delegate to CombatCalculator
    return CombatCalculator.calculate_physical_damage(attacker_stats, defender_stats)


## Calculate magic attack damage
func calculate_magic_damage(attacker_stats: UnitStats, defender_stats: UnitStats, ability: Resource) -> int:
    return CombatCalculator.calculate_magic_damage(attacker_stats, defender_stats, ability)


## Calculate hit chance (0-100)
func calculate_hit_chance(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
    return CombatCalculator.calculate_hit_chance(attacker_stats, defender_stats)


## Calculate critical hit chance (0-100)
func calculate_crit_chance(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
    return CombatCalculator.calculate_crit_chance(attacker_stats, defender_stats)


## Calculate healing amount
func calculate_healing(caster_stats: UnitStats, ability: Resource) -> int:
    return CombatCalculator.calculate_healing(caster_stats, ability)
```

**Update CombatCalculator** to support formula delegation:

```gdscript
# Add at top of combat_calculator.gd
static var _active_formula: CombatFormulaBase = null


## Set the active combat formula (called by BattleManager on battle start)
static func set_active_formula(formula: CombatFormulaBase) -> void:
    _active_formula = formula


## Clear the active formula (called on battle end)
static func clear_active_formula() -> void:
    _active_formula = null


## Updated calculate_physical_damage with delegation
static func calculate_physical_damage(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
    # Delegate to custom formula if active
    if _active_formula != null:
        return _active_formula.calculate_physical_damage(attacker_stats, defender_stats)

    # Default formula (existing implementation)
    return _calculate_physical_damage_default(attacker_stats, defender_stats)


## The default physical damage formula (extracted from current implementation)
static func _calculate_physical_damage_default(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
    # ... existing implementation moved here
```

**ModLoader Integration**:

Add to `ModLoader.RESOURCE_TYPE_DIRS`:
```gdscript
"combat_formulas": "combat_formula"
```

**BattleData Integration**:

Add to `BattleData`:
```gdscript
## Optional custom combat formula configuration
## If null, uses the default CombatCalculator formulas
@export var combat_formula_config: CombatFormulaConfig = null
```

**BattleManager Integration** (in `start_battle()`):
```gdscript
# After loading battle data, set up combat formula
if current_battle_data.combat_formula_config:
    var formula: CombatFormulaBase = current_battle_data.combat_formula_config.get_formula_calculator()
    if formula:
        CombatCalculator.set_active_formula(formula)
```

**Example Custom Formula** (for documentation):

```gdscript
# mods/sci_fi_total_conversion/combat_formulas/laser_combat.gd
extends CombatFormulaBase

## Sci-Fi laser combat - attack power directly reduces shields, then hull
func calculate_physical_damage(attacker_stats: UnitStats, defender_stats: UnitStats) -> int:
    var attack: int = attacker_stats.get_effective_strength()
    var weapon_power: int = attacker_stats.get_weapon_attack_power()

    # Sci-fi formula: (weapon_power * 1.5) + (attack / 2) - (defense * 0.5)
    var total_attack: float = (weapon_power * 1.5) + (attack / 2.0)
    var defense_reduction: float = defender_stats.get_effective_defense() * 0.5

    var damage: int = int(total_attack - defense_reduction)
    return maxi(damage, 1)
```

**Testing Requirements**:
- Unit test: Default formula works unchanged
- Unit test: Custom formula script loads and delegates
- Unit test: Invalid formula path falls back to default
- Integration test: Battle uses custom formula from BattleData
- Manual test: Total conversion can implement completely different combat

---

## Phase 4: Bug Fixes & Editor Stability (P1-P2)

**Goal**: Fix bugs that cause data corruption or poor UX
**Estimated Effort**: 2-3 days
**Risk Level**: Low (defensive programming, bounds checking)
**Blocking Issues**: None
**Persona Impact**: All modders benefit

### 4.1 Editor Async Race Condition

**Issue #8**: Rapid "New" clicks can interleave async operations causing duplicates/corruption.

**File**: `addons/sparkling_editor/ui/base_resource_editor.gd`

**Implementation** (add around line 48):
```gdscript
## Mutex flag to prevent concurrent async operations
var _operation_in_progress: bool = false


## Wrapper for async operations that prevents concurrent execution
func _begin_async_operation() -> bool:
    if _operation_in_progress:
        push_warning("Operation already in progress, please wait...")
        return false
    _operation_in_progress = true
    return true


func _end_async_operation() -> void:
    _operation_in_progress = false
```

**Update `_on_create_new()`** (around line 656):
```gdscript
func _on_create_new() -> void:
    if not _begin_async_operation():
        return

    # ... existing implementation ...

    # At end of function (after await):
    _end_async_operation()


# Also update _on_duplicate_resource, _on_copy_to_mod, _on_create_override similarly
```

**Testing Requirements**:
- Manual test: Rapid clicking "New" only creates one resource
- Manual test: Second click shows warning message

---

### 4.2 AIBrainRegistry Unbounded Cache

**Issue #9**: `_brain_instances` cache grows forever, never cleared.

**File**: `core/registries/ai_brain_registry.gd`

**Implementation**:
```gdscript
const MAX_CACHED_INSTANCES: int = 50

## LRU tracking for cache eviction
var _cache_access_order: Array[String] = []


## Get an instance of the AI brain Resource (with LRU cache)
func get_brain_instance(brain_id: String) -> Resource:
    var lower: String = brain_id.to_lower()

    # Return cached instance if available (and update LRU)
    if lower in _brain_instances:
        _update_cache_access(lower)
        return _brain_instances[lower]

    # Evict oldest if at capacity
    if _brain_instances.size() >= MAX_CACHED_INSTANCES:
        _evict_oldest_cache_entry()

    # Try to load and instantiate
    if lower not in _brains:
        return null

    var path: String = _brains[lower].get("path", "")
    if path.is_empty():
        return null

    var script: GDScript = load(path) as GDScript
    if not script:
        push_warning("AIBrainRegistry: Failed to load brain script: %s" % path)
        return null

    var instance: Resource = script.new()
    if not instance:
        push_warning("AIBrainRegistry: Failed to instantiate brain: %s" % path)
        return null

    _brain_instances[lower] = instance
    _cache_access_order.append(lower)
    return instance


func _update_cache_access(brain_id: String) -> void:
    var idx: int = _cache_access_order.find(brain_id)
    if idx >= 0:
        _cache_access_order.remove_at(idx)
    _cache_access_order.append(brain_id)


func _evict_oldest_cache_entry() -> void:
    if _cache_access_order.is_empty():
        return
    var oldest: String = _cache_access_order.pop_front()
    _brain_instances.erase(oldest)
```

**Testing Requirements**:
- Unit test: Cache stays under MAX_CACHED_INSTANCES
- Unit test: LRU ordering works correctly
- Unit test: Recently accessed item not evicted

---

### 4.3 Type Validation in Registries

**Issue #11**: `str(t)` on arrays/dicts produces garbage IDs in equipment_registry.

**File**: `core/registries/equipment_registry.gd`

**Update `register_weapon_types()`** (around line 33):
```gdscript
func register_weapon_types(mod_id: String, types: Array) -> void:
    var typed_array: Array[String] = []
    for t: Variant in types:
        # FIXED: Validate type before conversion
        if t is String:
            var type_str: String = t.to_lower().strip_edges()
            if not type_str.is_empty():
                typed_array.append(type_str)
        else:
            push_warning("EquipmentRegistry: Mod '%s' provided non-string weapon type (got %s), skipping" % [
                mod_id, typeof(t)
            ])

    if not typed_array.is_empty():
        _mod_weapon_types[mod_id] = typed_array
        _cache_dirty = true
```

**Testing Requirements**:
- Unit test: String types registered correctly
- Unit test: Array value emits warning and is skipped
- Unit test: Dict value emits warning and is skipped
- Unit test: Integer value emits warning and is skipped

---

### 4.4 Signal Disconnection Safety

**Issue #14**: Dynamic signal connections not checked before connecting.

**File**: `addons/sparkling_editor/ui/base_resource_editor.gd`

**Pattern to apply throughout** (example from line 302):
```gdscript
# Before:
event_bus.resource_saved.connect(_on_dependency_resource_changed)

# After:
if not event_bus.resource_saved.is_connected(_on_dependency_resource_changed):
    event_bus.resource_saved.connect(_on_dependency_resource_changed)
```

Apply this pattern to all `connect()` calls in the file.

**Testing Requirements**:
- Manual test: Editor tab can be opened/closed multiple times without errors
- Unit test: No duplicate signal connections created

---

## Phase 5: Polish & Documentation (P3-P4)

**Goal**: Quality-of-life improvements and validation hardening
**Estimated Effort**: 2-3 days
**Risk Level**: Low
**Blocking Issues**: Phases 1-4 completion
**Persona Impact**: All modders benefit

### 5.1 Validation Sweep

**Issue #15**: Various validation gaps throughout the codebase.

**Version String Validation** (mod_manifest.gd):
```gdscript
## Validate semantic version string format
static func _validate_version(version: String) -> bool:
    # Accept basic semver: X.Y.Z or X.Y.Z-suffix
    var semver_regex: RegEx = RegEx.new()
    semver_regex.compile("^\\d+\\.\\d+\\.\\d+(-[a-zA-Z0-9.]+)?$")
    return semver_regex.search(version) != null
```

**Scene Path Validation** (mod_loader.gd, in `_register_mod_scenes()`):
```gdscript
# Add before FileAccess.file_exists check:
if ".." in relative_path or relative_path.begins_with("/"):
    push_warning("ModLoader: Scene '%s' has invalid path (traversal attempt): %s" % [scene_id, relative_path])
    continue
```

**Floating Point Comparison** (combat_calculator.gd):
```gdscript
# Replace any exact float comparisons with:
if is_equal_approx(value_a, value_b):
    # ...
```

---

### 5.2 Editor Type Registry UI (Lower Priority)

**Issue #13**: Equipment types, unit categories, weather types can only be edited in mod.json.

This is a larger feature that could be deferred to a future phase. If implemented:

**New Editor Tab**: `addons/sparkling_editor/ui/type_registry_editor.gd`

Features:
- View all registered types across mods
- Show which mod provides each type
- Allow adding new types to active mod's mod.json
- Preview effect of type additions

**Estimated Additional Effort**: 2-3 days

---

### 5.3 Hardcoded Stats Migration (High Risk - Deferred)

**Issue #5**: Stats array hardcoded in experience_manager.gd line 373.

This is a **breaking change** that affects UnitStats, ClassData, and potentially save data. Recommend deferring to a separate focused effort with:

1. Design document for data-driven stats
2. Migration script for existing .tres files
3. Backwards compatibility layer
4. Comprehensive testing plan

**Estimated Additional Effort**: 3-5 days

---

## Risk Assessment Summary

| Phase | Risk | Mitigation |
|-------|------|------------|
| Phase 1 | Low | Purely additive validation, no behavior changes |
| Phase 2 | Medium | Fallback patterns ensure backwards compatibility |
| Phase 3 | Medium | New resource type, opt-in formula system |
| Phase 4 | Low | Defensive programming, bounds checking |
| Phase 5 | Low-Medium | Validation hardening, optional editor features |

**High-Risk Items Deferred**:
- Stat system refactor (Issue #5) - requires separate planning
- Editor Type Registry UI (Issue #13) - nice-to-have, not blocking

---

## Testing Strategy

### Headless Tests (Automated)
- All Phase 1 validation tests
- Phase 2 asset resolution tests
- Phase 3 formula delegation tests
- Phase 4 cache management tests

### Manual Integration Tests
- Total conversion mod loading scenario
- Asset override workflow (Casual Artist persona)
- Combat formula replacement (Total Conversion persona)
- Editor rapid-click stress test

### Regression Tests
- Existing test suite must pass after each phase
- Battle tests with default formulas unchanged
- Mod loading order preserved

---

## Rollout Plan

1. **Phase 1**: Merge first, monitor for false positives in validation
2. **Phase 2**: Feature flag for asset override (can disable if issues)
3. **Phase 3**: Opt-in only via BattleData.combat_formula_config
4. **Phase 4**: Immediate merge after testing
5. **Phase 5**: Batch merge of small fixes

---

## Success Criteria

**Casual Artist** can replace sprites by:
1. Creating matching folder structure in mod assets/
2. Dropping in replacement files
3. No .tres editing required

**SF Purist** sees:
1. Warnings when mod conflicts detected
2. Clear override chain information
3. No silent failures

**Total Conversion Modder** can:
1. Replace all core UI scenes
2. Implement completely different combat formulas
3. Override any asset in the game
4. Define custom stat systems (Phase 5.3, deferred)

---

*End of Plan*

*"The needs of the many modders outweigh the needs of the few hardcoded values." - Lt. Claudbrain*
