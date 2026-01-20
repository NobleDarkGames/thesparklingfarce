# Status: COMPLETED

This plan has been fully implemented as of January 2026.

---

# Test Suite Cleanup Implementation Plan

## Overview

This plan addresses test organization issues identified in the test suite review. The goal is to ensure tests are correctly categorized (unit vs integration), reduce code duplication through shared fixtures, and eliminate anti-patterns.

## Reference

See `docs/testing-reference.md` for the decision matrix on test placement:
- **Unit tests**: Single class/function, no autoloads, no scenes
- **Integration tests**: Multiple systems, may access autoloads/scenes

---

## Phase 1: Critical - Move Misclassified Tests (Sequential)

These tests access autoloads but are located in `tests/unit/`. They must be moved to `tests/integration/`.

### Task 1.1: Move test_unit_stats_equipment.gd

**Current location**: `tests/unit/equipment/test_unit_stats_equipment.gd`
**New location**: `tests/integration/equipment/test_unit_stats_equipment.gd`

**Why it's an integration test**:
- Lines 17-18: Accesses `ModLoader.status_effect_registry` and `ModLoader.registry`
- Line 66-68: Uses `ModLoader.registry.register_resource()`
- Line 311: Uses `ModLoader.registry.get_item()`
- Line 323: Uses `ModLoader.registry.get_item()` indirectly via `load_equipment_from_save()`

**Steps**:
1. Move the file: `mv tests/unit/equipment/test_unit_stats_equipment.gd tests/integration/equipment/`
2. Move the UID file: `mv tests/unit/equipment/test_unit_stats_equipment.gd.uid tests/integration/equipment/`
3. Update class_name if needed (currently `TestUnitStatsEquipment` - fine as-is)

**Verification**:
```bash
GODOT_BIN=~/Downloads/Godot_v4.5.1-stable_linux.x86_64/Godot_v4.5.1-stable_linux.x86_64
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/equipment/test_unit_stats_equipment.gd"
```

### Task 1.2: Move test_audio_manager_mod_path.gd

**Current location**: `tests/unit/audio/test_audio_manager_mod_path.gd`
**New location**: `tests/integration/audio/test_audio_manager_mod_path.gd`

**Why it's an integration test**:
- Line 19: Accesses `ModLoader.has_signal()`
- Line 24: Accesses `ModLoader.has_method()`
- Line 29: Calls `ModLoader.resolve_asset_path()`
- Lines 48-66: Accesses `AudioManager` autoload directly
- Lines 74-81, 88-125: Accesses `AudioManager` constants and methods

**Steps**:
1. Create directory: `mkdir -p tests/integration/audio/`
2. Move the file: `mv tests/unit/audio/test_audio_manager_mod_path.gd tests/integration/audio/`
3. Move the UID file: `mv tests/unit/audio/test_audio_manager_mod_path.gd.uid tests/integration/audio/`
4. Remove empty unit directory if no other files: `rmdir tests/unit/audio/` (if empty)

**Verification**:
```bash
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/audio/test_audio_manager_mod_path.gd"
```

---

## Phase 2: High Priority - Shared Fixtures & Organization (Parallelizable)

### Task 2.1: Create character_factory.gd

**Location**: `tests/fixtures/character_factory.gd`

This consolidates 13+ duplicate `_create_character()` implementations across tests.

**Content**:
```gdscript
## Shared test fixture for creating CharacterData resources
##
## Usage:
##   var char: CharacterData = CharacterFactory.create_character("Hero", {
##       "hp": 50, "mp": 10, "strength": 15, "defense": 10, "agility": 10
##   })
class_name CharacterFactory
extends RefCounted


## Create a CharacterData with the specified name and stats
## Options dictionary keys: hp, mp, strength, defense, agility, intelligence, luck, level, is_hero
static func create_character(
    p_name: String,
    options: Dictionary = {}
) -> CharacterData:
    var character: CharacterData = CharacterData.new()
    character.character_name = p_name
    character.base_hp = options.get("hp", 50)
    character.base_mp = options.get("mp", 10)
    character.base_strength = options.get("strength", 10)
    character.base_defense = options.get("defense", 10)
    character.base_agility = options.get("agility", 10)
    character.base_intelligence = options.get("intelligence", 10)
    character.base_luck = options.get("luck", 5)
    character.starting_level = options.get("level", 1)
    character.is_hero = options.get("is_hero", false)

    # Create default class if not provided
    var class_data: ClassData = options.get("class_data", null)
    if class_data == null:
        class_data = _create_default_class()
    character.character_class = class_data

    return character


## Create a minimal ClassData for testing
static func _create_default_class() -> ClassData:
    var class_data: ClassData = ClassData.new()
    class_data.display_name = "Warrior"
    class_data.movement_type = ClassData.MovementType.WALKING
    class_data.movement_range = 4
    class_data.hp_growth = 60
    class_data.mp_growth = 20
    class_data.strength_growth = 50
    class_data.defense_growth = 40
    class_data.agility_growth = 30
    class_data.intelligence_growth = 20
    class_data.luck_growth = 20
    return class_data


## Create a character with specific combat stats (shorthand)
static func create_combatant(
    p_name: String,
    hp: int,
    mp: int,
    strength: int,
    defense: int,
    agility: int,
    level: int = 1
) -> CharacterData:
    return create_character(p_name, {
        "hp": hp,
        "mp": mp,
        "strength": strength,
        "defense": defense,
        "agility": agility,
        "level": level
    })
```

### Task 2.2: Create unit_factory.gd

**Location**: `tests/fixtures/unit_factory.gd`

This consolidates 13+ duplicate `_spawn_unit()` implementations.

**Content**:
```gdscript
## Shared test fixture for spawning Unit nodes
##
## Usage:
##   var unit: Unit = UnitFactory.spawn_unit(character, Vector2i(5, 5), "player", container)
class_name UnitFactory
extends RefCounted


const UNIT_SCENE_PATH: String = "res://scenes/unit.tscn"


## Spawn a unit at the specified grid cell
## Returns the spawned Unit node (caller is responsible for cleanup)
static func spawn_unit(
    character: CharacterData,
    cell: Vector2i,
    faction: String,
    parent: Node,
    ai_behavior: AIBehaviorData = null,
    register_with_grid: bool = true
) -> Unit:
    var unit_scene: PackedScene = load(UNIT_SCENE_PATH)
    var unit: Unit = unit_scene.instantiate() as Unit
    unit.initialize(character, faction, ai_behavior)
    unit.grid_position = cell
    unit.position = Vector2(cell.x * 32, cell.y * 32)
    parent.add_child(unit)

    if register_with_grid:
        GridManager.set_cell_occupied(cell, unit)

    return unit


## Clean up a unit and unregister from grid
static func cleanup_unit(unit: Unit) -> void:
    if unit and is_instance_valid(unit):
        GridManager.set_cell_occupied(unit.grid_position, null)
        unit.queue_free()


## Clean up multiple units
static func cleanup_units(units: Array) -> void:
    for unit in units:
        cleanup_unit(unit)
```

### Task 2.3: Create grid_setup.gd

**Location**: `tests/fixtures/grid_setup.gd`

This consolidates duplicate grid/tilemap setup across tests.

**Content**:
```gdscript
## Shared test fixture for setting up Grid and TileMapLayer
##
## Usage:
##   var setup: GridSetup = GridSetup.new()
##   setup.create_grid(parent_node, Vector2i(20, 15))
##   # ... run tests ...
##   setup.cleanup()
class_name GridSetup
extends RefCounted


var tilemap_layer: TileMapLayer
var tileset: TileSet
var grid_resource: Grid


## Create a minimal grid setup for testing
func create_grid(
    parent: Node,
    grid_size: Vector2i = Vector2i(20, 15),
    cell_size: int = 32
) -> void:
    tileset = TileSet.new()
    tilemap_layer = TileMapLayer.new()
    tilemap_layer.tile_set = tileset
    parent.add_child(tilemap_layer)

    grid_resource = Grid.new()
    grid_resource.grid_size = grid_size
    grid_resource.cell_size = cell_size
    GridManager.setup_grid(grid_resource, tilemap_layer)


## Clean up the grid setup
func cleanup() -> void:
    if tilemap_layer and is_instance_valid(tilemap_layer):
        tilemap_layer.queue_free()
        tilemap_layer = null
    tileset = null
    grid_resource = null
```

### Task 2.4: Move test_equipment_type_registry.gd to registries/

**Current location**: `tests/unit/test_equipment_type_registry.gd`
**New location**: `tests/unit/registries/test_equipment_type_registry.gd`

**Steps**:
1. Move file: `mv tests/unit/test_equipment_type_registry.gd tests/unit/registries/`
2. Move UID: `mv tests/unit/test_equipment_type_registry.gd.uid tests/unit/registries/`

**Verification**:
```bash
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/unit/registries/test_equipment_type_registry.gd"
```

---

## Phase 3: Medium Priority - Fix Trivial Pass Assertions (Parallelizable)

These tests use `assert_bool(true).is_true()` which provides no value. Each needs evaluation:

### Task 3.1: Fix test_audio_manager_mod_path.gd (3 instances)

**File**: `tests/integration/audio/test_audio_manager_mod_path.gd` (after Phase 1 move)

**Lines 156-177** (three test functions):
```gdscript
func test_audio_manager_enable_layer_invalid_does_not_crash() -> void:
    AudioManager.enable_layer(-1)
    AudioManager.enable_layer(99)
    assert_bool(true).is_true()  # Line 161

func test_audio_manager_disable_layer_invalid_does_not_crash() -> void:
    AudioManager.disable_layer(-1)
    AudioManager.disable_layer(99)
    assert_bool(true).is_true()  # Line 169

func test_audio_manager_set_layer_volume_invalid_does_not_crash() -> void:
    AudioManager.set_layer_volume(-1, 0.5)
    AudioManager.set_layer_volume(99, 0.5)
    assert_bool(true).is_true()  # Line 177
```

**Fix**: These are legitimate "no crash" smoke tests. Replace with explicit success assertions:
```gdscript
func test_audio_manager_enable_layer_invalid_does_not_crash() -> void:
    # Test that invalid layer indices are handled gracefully (no crash)
    AudioManager.enable_layer(-1)
    AudioManager.enable_layer(99)
    # Verify no crash occurred and layers remain valid
    assert_int(AudioManager.get_layer_count()).is_greater_equal(0)

func test_audio_manager_disable_layer_invalid_does_not_crash() -> void:
    # Test that invalid layer indices are handled gracefully (no crash)
    AudioManager.disable_layer(-1)
    AudioManager.disable_layer(99)
    # Verify no crash occurred and layers remain valid
    assert_int(AudioManager.get_layer_count()).is_greater_equal(0)

func test_audio_manager_set_layer_volume_invalid_does_not_crash() -> void:
    # Test that invalid layer indices are handled gracefully (no crash)
    AudioManager.set_layer_volume(-1, 0.5)
    AudioManager.set_layer_volume(99, 0.5)
    # Verify no crash occurred and layers remain valid
    assert_int(AudioManager.get_layer_count()).is_greater_equal(0)
```

### Task 3.2: Fix test_dialog_manager.gd (1 instance)

**File**: `tests/unit/dialogue/test_dialog_manager.gd`
**Line 237**:
```gdscript
func test_max_depth_enforced() -> void:
    # ...setup code...
    for i: int in range(DialogManager.MAX_DIALOG_CHAIN_DEPTH + 1):
        if not DialogManager.is_dialog_active():
            break
        DialogManager.on_text_reveal_finished()
        DialogManager.advance_dialog()
    assert_bool(true).is_true()  # Test that we didn't crash
```

**Fix**: Assert the actual depth limit behavior:
```gdscript
func test_max_depth_enforced() -> void:
    # ...setup code unchanged...

    var depth_reached: int = 0
    for i: int in range(DialogManager.MAX_DIALOG_CHAIN_DEPTH + 2):
        if not DialogManager.is_dialog_active():
            break
        depth_reached = i + 1
        DialogManager.on_text_reveal_finished()
        DialogManager.advance_dialog()

    # Verify we stopped at or before max depth (didn't crash or infinite loop)
    assert_int(depth_reached).is_less_equal(DialogManager.MAX_DIALOG_CHAIN_DEPTH + 1)
    assert_bool(DialogManager.is_dialog_active()).is_false()
```

### Task 3.3: Fix test_experience_manager.gd (1 instance)

**File**: `tests/integration/experience/test_experience_manager.gd`
**Line 474**:
```gdscript
func test_invalidate_party_level_cache() -> void:
    ExperienceManager.invalidate_party_level_cache()
    assert_bool(true).is_true()
```

**Fix**: This is a smoke test. Make it more meaningful by testing observable behavior:
```gdscript
func test_invalidate_party_level_cache() -> void:
    # First call to get party level should compute it
    var _level_before: int = ExperienceManager.get_average_party_level()

    # Invalidate the cache
    ExperienceManager.invalidate_party_level_cache()

    # Next call should recompute (smoke test - verify no crash)
    var level_after: int = ExperienceManager.get_average_party_level()
    assert_int(level_after).is_greater_equal(0)
```

**Note**: If `get_average_party_level()` doesn't exist, keep as smoke test but add comment:
```gdscript
func test_invalidate_party_level_cache() -> void:
    # Smoke test: verify cache invalidation doesn't crash
    # The cache is internal state; we verify the method is callable
    ExperienceManager.invalidate_party_level_cache()
    # Method completed without error
    assert_bool(ExperienceManager != null).is_true()
```

### Task 3.4: Fix additional trivial assertions (as identified)

**Other files with `assert_bool(true).is_true()`**:

| File | Line | Action |
|------|------|--------|
| `tests/unit/cinematics/test_cinematics_manager_actors.gd` | 420 | Evaluate context |
| `tests/unit/cinematics/test_spawn_entity_executor.gd` | 133, 186, 435 | Marked as intentional skips - consider using GdUnit4 skip mechanism |
| `tests/integration/ai/test_aoe_targeting.gd` | 140 | Evaluate context |
| `tests/integration/storage/test_save_manager.gd` | 47 | Evaluate context |

**Recommendation for intentional skips**: Replace with proper skip:
```gdscript
# Instead of:
assert_bool(true).is_true()  # Explicit pass to indicate intentional skip

# Use GdUnit4's skip mechanism (if available) or clear naming:
func test_SKIP_feature_not_implemented() -> void:
    # This test is intentionally skipped until feature X is implemented
    pass
```

---

## Phase 4: Performance - Fix Excessive Delays (Sequential)

### Task 4.1: Optimize test_cinematic_spawn_flow.gd

**File**: `tests/integration/cinematics/test_cinematic_spawn_flow.gd`

**Current issues**:
- Line 48: `await await_millis(100)` in `before()`
- Line 63, 85, 129, 162, 199, 235, 268, 272: Multiple 100-300ms waits
- Line 194: 1000ms wait for movement

**Analysis**:
The test uses fixed delays to wait for cinematic operations. This is fragile and slow.

**Recommended fix**: Use signal-based waiting where possible:

```gdscript
# BEFORE (slow, fragile):
await await_millis(300)

# AFTER (fast, reliable):
# Wait for cinematic to end with timeout
if CinematicsManager.is_cinematic_active():
    await await_signal_on(CinematicsManager, "cinematic_ended", [], 5000)
```

**Specific changes**:

1. **before() cleanup wait** (line 48):
   - Change from: `await await_millis(100)`
   - Change to: `await await_idle_frame()` (sufficient for autoload stabilization)

2. **before_test() skip wait** (lines 82-89):
   ```gdscript
   # BEFORE:
   if CinematicsManager.is_cinematic_active():
       CinematicsManager.skip_cinematic()
       await await_millis(200)
   await get_tree().process_frame

   # AFTER:
   if CinematicsManager.is_cinematic_active():
       CinematicsManager.skip_cinematic()
       await await_signal_on(CinematicsManager, "cinematic_ended", [], 2000)
   await await_idle_frame()
   ```

3. **Test completion waits** (throughout):
   ```gdscript
   # BEFORE:
   await await_millis(300)

   # AFTER:
   await await_signal_on(CinematicsManager, "cinematic_ended", [], 5000)
   ```

4. **Movement test wait** (line 194):
   - Keep longer timeout but use signal:
   ```gdscript
   # Wait for movement to complete or cinematic to end
   await await_signal_on(CinematicsManager, "cinematic_ended", [], 5000)
   ```

**Full refactored test example**:
```gdscript
func test_actors_array_spawn() -> void:
    var cinematic: CinematicData = CinematicData.new()
    cinematic.cinematic_id = "actors_array_test"
    cinematic.cinematic_name = "Actors Array Test"
    cinematic.disable_player_input = false
    cinematic.can_skip = true
    cinematic.add_actor("soldier_a", [3, 5], "down")
    cinematic.add_actor("soldier_b", [7, 5], "left")
    cinematic.add_wait(0.1)

    var result: bool = CinematicsManager.play_cinematic_from_resource(cinematic)
    assert_bool(result).is_true()

    # Wait for natural completion instead of fixed delay
    await await_signal_on(CinematicsManager, "cinematic_ended", [], 5000)

    # Cleanup is automatic after cinematic_ended
```

---

## Execution Order

```
Phase 1 (Critical - Sequential)
    |
    +-- Task 1.1: Move test_unit_stats_equipment.gd
    +-- Task 1.2: Move test_audio_manager_mod_path.gd
    |
    v
Phase 2 (High Priority - Parallelizable)
    |
    +-- Task 2.1: Create character_factory.gd    --|
    +-- Task 2.2: Create unit_factory.gd         --+-- Can run in parallel
    +-- Task 2.3: Create grid_setup.gd           --|
    +-- Task 2.4: Move test_equipment_type_registry.gd
    |
    v
Phase 3 (Medium Priority - Parallelizable)
    |
    +-- Task 3.1: Fix test_audio_manager_mod_path.gd  --|
    +-- Task 3.2: Fix test_dialog_manager.gd          --+-- Can run in parallel
    +-- Task 3.3: Fix test_experience_manager.gd      --|
    +-- Task 3.4: Evaluate remaining trivial assertions
    |
    v
Phase 4 (Performance - Sequential)
    |
    +-- Task 4.1: Optimize test_cinematic_spawn_flow.gd
```

---

## Verification Checklist

After all phases complete:

### Full Test Suite Run
```bash
GODOT_BIN=~/Downloads/Godot_v4.5.1-stable_linux.x86_64/Godot_v4.5.1-stable_linux.x86_64
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests"
```

### Verify No Orphaned Files
```bash
# Check for .uid files without corresponding .gd
find tests/ -name "*.uid" | while read uid; do
  gd="${uid%.uid}"
  [ ! -f "$gd" ] && echo "Orphaned: $uid"
done
```

### Verify Directory Structure
```bash
# Expected structure after cleanup:
tests/
  fixtures/
    character_factory.gd
    unit_factory.gd
    grid_setup.gd
  integration/
    audio/
      test_audio_manager_mod_path.gd
    equipment/
      test_unit_stats_equipment.gd
    ...
  unit/
    registries/
      test_equipment_type_registry.gd
      test_ai_brain_registry.gd
      ...
    audio/  (removed if empty)
    ...
```

---

## Risk Assessment

| Task | Risk | Mitigation |
|------|------|------------|
| Moving test files | UID files might break | Move .uid files alongside .gd files |
| Shared fixtures | Tests may have subtle differences | Start with most common pattern, allow overrides |
| Signal-based waits | Tests may hang if signal never fires | Always include timeout parameter |
| Removing trivial assertions | May hide actual test failures | Review each case; add meaningful assertions |

---

## Future Recommendations

1. **Migrate tests to use shared fixtures**: After Phase 2, gradually update existing tests to use `CharacterFactory`, `UnitFactory`, and `GridSetup` instead of inline duplicates.

2. **Add lint check for trivial assertions**: Consider adding a CI check that warns on `assert_bool(true).is_true()`.

3. **Document test patterns**: Add examples of correct fixture usage to `docs/testing-reference.md`.
