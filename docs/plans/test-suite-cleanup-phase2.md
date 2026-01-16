# Test Suite Cleanup - Phase 2 Implementation Plan

## Overview

This plan addresses remaining test organization issues identified by the engineering review team:
- Major Testo (test architecture)
- Chief Engineer O'Brien (system impact analysis)
- Ensign Eager (detailed line-by-line audit)

**Reference**: `docs/testing-reference.md` for classification criteria.

**Prerequisite**: Phase 1 from `docs/plans/test-suite-cleanup.md` should be complete (fixtures created, initial moves done).

---

## Phase 2.1: Misclassified Tests - Move to Integration (Sequential)

These tests access autoloads but reside in `tests/unit/`. Per the testing reference decision matrix:
> "Does it access an autoload singleton? YES -> Integration test"

### Task 2.1.1: Move test_dialog_manager.gd

**Current location**: `tests/unit/dialogue/test_dialog_manager.gd`
**New location**: `tests/integration/dialogue/test_dialog_manager.gd`

**Why it's an integration test**:
- Line 68: `if DialogManager:` - accesses DialogManager autoload
- Line 70-73: Directly manipulates `DialogManager.current_state`, `DialogManager.current_dialogue`, etc.
- Line 81: `DialogManager.current_state`
- Line 87+: All tests interact directly with the DialogManager singleton

**Dependencies identified**:
- DialogManager autoload (singleton)
- DialogueData resource class (no autoload - OK)

**Steps**:
```bash
# 1. Create directory if needed
mkdir -p tests/integration/dialogue/

# 2. Move the file
mv tests/unit/dialogue/test_dialog_manager.gd tests/integration/dialogue/

# 3. Move the UID file
mv tests/unit/dialogue/test_dialog_manager.gd.uid tests/integration/dialogue/

# 4. Check if unit/dialogue/ can be removed (only if empty)
rmdir tests/unit/dialogue/ 2>/dev/null || echo "Directory not empty, keeping"
```

**Verification**:
```bash
GODOT_BIN=~/Downloads/Godot_v4.5.1-stable_linux.x86_64/Godot_v4.5.1-stable_linux.x86_64
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/dialogue/test_dialog_manager.gd"
```

---

### Task 2.1.2: Move test_cinematics_manager_actors.gd

**Current location**: `tests/unit/cinematics/test_cinematics_manager_actors.gd`
**New location**: `tests/integration/cinematics/test_cinematics_manager_actors.gd`

**Why it's an integration test**:
- Line 67-84: `_save_manager_state()` and `_restore_manager_state()` directly access `CinematicsManager` autoload
- Line 69: `CinematicsManager.current_state`
- Line 70: `CinematicsManager.current_cinematic`
- Line 78-84: Manipulates `CinematicsManager._spawned_actor_nodes`, `_registered_actors`, etc.
- Line 94-97: Calls `CinematicsManager.is_cinematic_active()`, `skip_cinematic()`
- Entire test file interacts with CinematicsManager singleton

**Dependencies identified**:
- CinematicsManager autoload (singleton)
- CinematicData resource class
- CinematicActor component class

**Steps**:
```bash
# 1. Move the file (directory already exists)
mv tests/unit/cinematics/test_cinematics_manager_actors.gd tests/integration/cinematics/

# 2. Move the UID file
mv tests/unit/cinematics/test_cinematics_manager_actors.gd.uid tests/integration/cinematics/
```

**Verification**:
```bash
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/cinematics/test_cinematics_manager_actors.gd"
```

---

## Phase 2.2: Trivial Assertions - Replace with Meaningful Tests (Parallelizable)

These tests use `assert_bool(true).is_true()` which provides no verification value.

### Task 2.2.1: Fix test_cinematics_manager_actors.gd:420

**File**: `tests/integration/cinematics/test_cinematics_manager_actors.gd` (after Phase 2.1 move)
**Line**: 420

**Current code**:
```gdscript
func test_register_null_actor_is_ignored() -> void:
    CinematicsManager.register_actor(null)

    # Should not crash or add anything
    assert_bool(true).is_true()
```

**Issue**: Tests that null is handled gracefully, but assertion doesn't verify anything.

**Fixed code**:
```gdscript
func test_register_null_actor_is_ignored() -> void:
    var count_before: int = CinematicsManager._registered_actors.size()

    CinematicsManager.register_actor(null)

    # Verify null was ignored (count unchanged)
    assert_int(CinematicsManager._registered_actors.size()).is_equal(count_before)
```

---

### Task 2.2.2: Fix test_spawn_entity_executor.gd:133,186,435

**File**: `tests/unit/cinematics/test_spawn_entity_executor.gd`
**Lines**: 133, 186, 435

These are marked as intentional skips with comments indicating integration coverage exists.

**Current code (line 133)**:
```gdscript
func test_spawn_entity_with_valid_actor_id() -> void:
    # SKIP: Requires full scene tree context (current_scene must exist)
    # The executor accesses manager.get_tree().current_scene to add spawned entities
    # Covered by: tests/integration/cinematics/test_cinematic_spawn_flow.gd
    assert_bool(true).is_true()  # Explicit pass to indicate intentional skip
```

**Recommended fix**: Use GdUnit4's skip annotation or rename to indicate skip:

**Option A - Comment-based skip (preferred for visibility)**:
```gdscript
func test_spawn_entity_with_valid_actor_id_REQUIRES_SCENE_TREE() -> void:
    # SKIP: Requires full scene tree context (current_scene must exist)
    # The executor accesses manager.get_tree().current_scene to add spawned entities
    # Covered by: tests/integration/cinematics/test_cinematic_spawn_flow.gd
    pass  # Intentional skip - see comment above
```

**Option B - Delete entirely (if coverage exists elsewhere)**:
If `tests/integration/cinematics/test_cinematic_spawn_flow.gd` thoroughly covers these cases, delete the skipped tests to reduce noise.

**Recommendation**: Delete lines 129-133, 182-186, and 431-435 since integration tests provide the real coverage. Update file header to note which tests were moved to integration.

---

### Task 2.2.3: Fix test_aoe_targeting.gd:140

**File**: `tests/integration/ai/test_aoe_targeting.gd`
**Line**: 140

**Current code**:
```gdscript
    # AI should either:
    # 1. Cast AoE on cluster (hit 2+ targets)
    # 2. Use basic attack if AoE minimum not met
    # Either way, should NOT waste AoE on isolated target alone
    if spell_cast and hit_isolated and hit_cluster_count < 2:
        # This is the failure case - wasted AoE on isolated
        fail("Wasted AoE on isolated target instead of cluster")
    else:
        # Some valid action was taken
        assert_bool(true).is_true()
```

**Issue**: The else branch doesn't verify the expected behavior occurred.

**Fixed code**:
```gdscript
    # AI should either:
    # 1. Cast AoE on cluster (hit 2+ targets)
    # 2. Use basic attack if AoE minimum not met
    # Either way, should NOT waste AoE on isolated target alone
    if spell_cast and hit_isolated and hit_cluster_count < 2:
        # This is the failure case - wasted AoE on isolated
        fail("Wasted AoE on isolated target instead of cluster")
    elif spell_cast:
        # Spell was cast - verify it hit the cluster (2+ targets)
        assert_int(hit_cluster_count).is_greater_equal(2).override_failure_message(
            "AoE spell cast but only hit %d cluster targets (expected 2+)" % hit_cluster_count
        )
    else:
        # No spell cast - AI used basic attack (acceptable when minimum not met)
        # Verify isolated target was attacked (closest enemy)
        assert_bool(hit_isolated or hit_cluster_count > 0).is_true().override_failure_message(
            "AI took no offensive action"
        )
```

---

### Task 2.2.4: Fix test_save_manager.gd:47

**File**: `tests/integration/storage/test_save_manager.gd`
**Line**: 47

**Current code**:
```gdscript
func test_sync_handles_null_current_save() -> void:
    # Set current_save to null
    SaveManager.current_save = null

    # Should not crash - just early return with a warning
    SaveManager.sync_current_save_state()

    # If we got here without crashing, the test passes
    assert_bool(true).is_true()
```

**Issue**: Tests crash-safety but assertion doesn't verify state.

**Fixed code**:
```gdscript
func test_sync_handles_null_current_save() -> void:
    # Set current_save to null
    SaveManager.current_save = null

    # Should not crash - just early return with a warning
    SaveManager.sync_current_save_state()

    # Verify current_save remained null (wasn't accidentally created)
    assert_object(SaveManager.current_save).is_null()
```

---

## Phase 2.3: Code Duplication - Migrate to Shared Fixtures (Parallelizable)

The fixtures from Phase 1 (`CharacterFactory`, `UnitFactory`, `GridSetup`) exist. Now migrate tests to use them.

### Duplicate Function Inventory

**_create_character() duplicates (15 files)**:
| File | Line | Signature | Priority |
|------|------|-----------|----------|
| `tests/integration/ai/test_aoe_targeting.gd` | 143 | `(name, hp, mp, str, def, agi)` | HIGH |
| `tests/integration/ai/test_cautious_engagement.gd` | 179 | `(name, hp, mp, str, def, agi)` | HIGH |
| `tests/integration/ai/test_defensive_positioning.gd` | 125 | `(name, hp, mp, str, def, agi)` | HIGH |
| `tests/integration/ai/test_healer_prioritization.gd` | 128 | `(name, hp, mp, str, def, agi)` | HIGH |
| `tests/integration/ai/test_opportunistic_targeting.gd` | 121 | `(name, hp, mp, str, def, agi)` | HIGH |
| `tests/integration/ai/test_ranged_ai_positioning.gd` | 135 | `(name, hp, mp, str, def, agi)` | HIGH |
| `tests/integration/ai/test_retreat_behavior.gd` | 125 | `(name, hp, mp, str, def, agi)` | HIGH |
| `tests/integration/ai/test_stationary_guard.gd` | 146 | `(name, hp, mp, str, def, agi)` | HIGH |
| `tests/integration/ai/test_tactical_debuff.gd` | 112 | `(name, hp, mp, str, def, agi)` | HIGH |
| `tests/integration/ai/test_terrain_advantage.gd` | 153 | `(name, hp, mp, str, def, agi)` | HIGH |
| `tests/integration/battle/test_battle_flow.gd` | 144 | `(name, hp, mp, str, def, agi)` | MEDIUM |
| `tests/integration/experience/test_experience_manager.gd` | 532 | `(name, hp, mp, str, def, agi, level)` | MEDIUM |
| `tests/integration/party/test_party_manager.gd` | 632 | `(name, is_hero)` | LOW (different signature) |
| `tests/integration/turn/test_turn_manager.gd` | 466 | `(name, hp, mp, str, def, agi, is_hero)` | MEDIUM |

**_spawn_unit() duplicates (13 files)**:
| File | Line | Priority |
|------|------|----------|
| `tests/integration/ai/test_aoe_targeting.gd` | 233 | HIGH |
| `tests/integration/ai/test_cautious_engagement.gd` | 223 | HIGH |
| `tests/integration/ai/test_defensive_positioning.gd` | 211 | HIGH |
| `tests/integration/ai/test_healer_prioritization.gd` | 216 | HIGH |
| `tests/integration/ai/test_opportunistic_targeting.gd` | 167 | HIGH |
| `tests/integration/ai/test_ranged_ai_positioning.gd` | 177 | HIGH |
| `tests/integration/ai/test_retreat_behavior.gd` | 168 | HIGH |
| `tests/integration/ai/test_stationary_guard.gd` | 190 | HIGH |
| `tests/integration/ai/test_tactical_debuff.gd` | 206 | HIGH |
| `tests/integration/ai/test_terrain_advantage.gd` | 179 | HIGH |
| `tests/integration/battle/test_battle_flow.gd` | 184 | MEDIUM |
| `tests/integration/experience/test_experience_manager.gd` | 565 | MEDIUM |
| `tests/integration/turn/test_turn_manager.gd` | 492 | MEDIUM |

---

### Task 2.3.1: Migrate AI Tests to Shared Fixtures (10 files)

**Priority**: HIGH (most duplication, similar patterns)

All 10 AI test files follow the same pattern. Use `test_aoe_targeting.gd` as the template:

**Before (test_aoe_targeting.gd)**:
```gdscript
func _create_character(p_name: String, hp: int, mp: int, str_val: int, def_val: int, agi: int) -> CharacterData:
    var character: CharacterData = CharacterData.new()
    character.character_name = p_name
    character.base_hp = hp
    character.base_mp = mp
    character.base_strength = str_val
    character.base_defense = def_val
    character.base_agility = agi
    character.base_intelligence = 10
    character.base_luck = 5
    character.starting_level = 1

    var basic_class: ClassData = ClassData.new()
    basic_class.display_name = "Fighter"
    basic_class.movement_type = ClassData.MovementType.WALKING
    basic_class.movement_range = 4

    character.character_class = basic_class

    # Track for cleanup
    _created_characters.append(character)
    _created_classes.append(basic_class)

    return character


func _spawn_unit(character: CharacterData, cell: Vector2i, p_faction: String, p_ai_behavior: AIBehaviorData) -> Unit:
    var unit_scene: PackedScene = load("res://scenes/unit.tscn")
    var unit: Unit = unit_scene.instantiate() as Unit
    unit.initialize(character, p_faction, p_ai_behavior)
    unit.grid_position = cell
    unit.position = Vector2(cell.x * 32, cell.y * 32)
    _units_container.add_child(unit)
    GridManager.set_cell_occupied(cell, unit)
    return unit
```

**After (using shared fixtures)**:
```gdscript
# Remove _create_character() and _spawn_unit() functions entirely

# Update test code to use factories:
func test_aoe_mage_prefers_cluster_over_isolated() -> void:
    # Create AoE mage character
    var mage_character: CharacterData = _create_aoe_mage("AoEMage")

    # Create target characters - use CharacterFactory
    var isolated_char: CharacterData = CharacterFactory.create_combatant("Isolated", 60, 10, 12, 10, 10)
    isolated_char.is_hero = true

    var cluster_char_1: CharacterData = CharacterFactory.create_combatant("Cluster1", 60, 10, 12, 10, 10)
    cluster_char_1.is_hero = true
    var cluster_char_2: CharacterData = CharacterFactory.create_combatant("Cluster2", 60, 10, 12, 10, 10)
    var cluster_char_3: CharacterData = CharacterFactory.create_combatant("Cluster3", 60, 10, 12, 10, 10)

    # Spawn units - use UnitFactory
    _mage_unit = UnitFactory.spawn_unit(mage_character, Vector2i(5, 7), "enemy", _units_container, mage_ai)
    # ... rest unchanged
```

**Files to update (can run in parallel)**:
1. `tests/integration/ai/test_aoe_targeting.gd`
2. `tests/integration/ai/test_cautious_engagement.gd`
3. `tests/integration/ai/test_defensive_positioning.gd`
4. `tests/integration/ai/test_healer_prioritization.gd`
5. `tests/integration/ai/test_opportunistic_targeting.gd`
6. `tests/integration/ai/test_ranged_ai_positioning.gd`
7. `tests/integration/ai/test_retreat_behavior.gd`
8. `tests/integration/ai/test_stationary_guard.gd`
9. `tests/integration/ai/test_tactical_debuff.gd`
10. `tests/integration/ai/test_terrain_advantage.gd`

**Note**: Some AI tests have special character creation functions (e.g., `_create_aoe_mage()`, `_create_healer()`) that should remain as they're test-specific. Only the generic `_create_character()` and `_spawn_unit()` should be replaced.

---

### Task 2.3.2: Migrate Battle/Turn/Experience Tests (3 files)

**Priority**: MEDIUM

**Files**:
1. `tests/integration/battle/test_battle_flow.gd` (lines 144, 184)
2. `tests/integration/turn/test_turn_manager.gd` (lines 466, 492)
3. `tests/integration/experience/test_experience_manager.gd` (lines 532, 565)

Same migration pattern as AI tests.

---

### Task 2.3.3: Update Cleanup Patterns

When using `UnitFactory`, update cleanup code to use `UnitFactory.cleanup_unit()`:

**Before**:
```gdscript
func _cleanup_units() -> void:
    if _mage_unit and is_instance_valid(_mage_unit):
        GridManager.set_cell_occupied(_mage_unit.grid_position, null)
        _mage_unit.queue_free()
        _mage_unit = null
    # ... repeat for each unit
```

**After**:
```gdscript
func _cleanup_units() -> void:
    UnitFactory.cleanup_unit(_mage_unit)
    _mage_unit = null
    UnitFactory.cleanup_unit(_isolated_target)
    _isolated_target = null
    # ... or use cleanup_units() for arrays
```

---

## Phase 2.4: Performance Optimization - AI Test Waits (Parallelizable)

Replace `await_millis()` with `await_idle_frame()` where appropriate.

### await_millis Usage in AI Tests

| File | Line | Current | Recommendation |
|------|------|---------|----------------|
| `test_opportunistic_targeting.gd` | 112 | `await_millis(100)` | Keep - waiting for AI decision |
| `test_aoe_targeting.gd` | 115 | `await_millis(200)` | Reduce to 100ms or use signal |
| `test_tactical_debuff.gd` | 102 | `await_millis(100)` | Keep - waiting for AI decision |
| `test_healer_prioritization.gd` | 114 | `await_millis(100)` | Keep - waiting for AI decision |
| `test_stationary_guard.gd` | 232 | `await_millis(100)` | Keep - waiting for AI decision |
| `test_retreat_behavior.gd` | 108 | `await_millis(100)` | Keep - waiting for AI decision |
| `test_cautious_engagement.gd` | 265 | `await_millis(100)` | Keep - waiting for AI decision |
| `test_defensive_positioning.gd` | 107 | `await_millis(200)` | Reduce to 100ms |

### Task 2.4.1: Standardize AI Wait Times

**Recommendation**: These waits exist to allow AI processing to complete. Rather than replacing with `await_idle_frame()` (which may not be sufficient), standardize on 100ms and document why.

**Changes needed**:
1. `test_aoe_targeting.gd:115` - Change `await_millis(200)` to `await_millis(100)`
2. `test_defensive_positioning.gd:107` - Change `await_millis(200)` to `await_millis(100)`

**Add comment template**:
```gdscript
# Wait for AI decision processing (100ms is sufficient for turn evaluation)
await await_millis(100)
```

### Task 2.4.2: Consider Signal-Based Waits (Future Enhancement)

For better reliability, AI tests could wait for signals instead of fixed delays:

```gdscript
# Future enhancement - wait for AI to complete turn
# await await_signal_on(brain, "turn_completed", [], 2000)
```

This requires adding a `turn_completed` signal to the AI brain system (out of scope for this cleanup).

---

## Execution Order

```
Phase 2.1 (Sequential - test moves)
    |
    +-- Task 2.1.1: Move test_dialog_manager.gd
    +-- Task 2.1.2: Move test_cinematics_manager_actors.gd
    |
    v
Phase 2.2 (Parallelizable - fix assertions)
    |
    +-- Task 2.2.1: Fix test_cinematics_manager_actors.gd:420     --|
    +-- Task 2.2.2: Fix test_spawn_entity_executor.gd skips       --+-- Can run in parallel
    +-- Task 2.2.3: Fix test_aoe_targeting.gd:140                 --|
    +-- Task 2.2.4: Fix test_save_manager.gd:47                   --|
    |
    v
Phase 2.3 (Parallelizable - migrate to fixtures)
    |
    +-- Task 2.3.1: Migrate AI tests (10 files)                   --|
    +-- Task 2.3.2: Migrate Battle/Turn/Experience tests          --+-- Can run in parallel
    +-- Task 2.3.3: Update cleanup patterns                       --|
    |
    v
Phase 2.4 (Parallelizable - performance)
    |
    +-- Task 2.4.1: Standardize AI wait times
```

---

## Verification Checklist

### After Phase 2.1 (Test Moves)

```bash
# Verify moved tests run correctly
GODOT_BIN=~/Downloads/Godot_v4.5.1-stable_linux.x86_64/Godot_v4.5.1-stable_linux.x86_64

$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/dialogue/test_dialog_manager.gd"

$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/cinematics/test_cinematics_manager_actors.gd"
```

### After Phase 2.2 (Assertion Fixes)

```bash
# Run specific test files to verify assertion changes work
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/cinematics/test_cinematics_manager_actors.gd" \
  --add "res://tests/unit/cinematics/test_spawn_entity_executor.gd" \
  --add "res://tests/integration/ai/test_aoe_targeting.gd" \
  --add "res://tests/integration/storage/test_save_manager.gd"
```

### After Phase 2.3 (Fixture Migration)

```bash
# Run all AI tests to verify fixture usage
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/ai"
```

### Full Suite Verification

```bash
# Run complete test suite
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

---

## Risk Assessment

| Task | Risk | Mitigation |
|------|------|------------|
| Moving test files | UID files might break references | Move .uid files alongside .gd files |
| Removing skip tests | Loss of documentation intent | Add comment in integration test noting coverage |
| Fixture migration | Tests may rely on subtle differences | Compare fixture defaults to existing inline code |
| Wait time reduction | Tests may become flaky | Start conservative (100ms), reduce if stable |

---

## Success Metrics

After completing Phase 2:

1. **Zero misclassified tests**: All tests accessing autoloads are in `tests/integration/`
2. **Zero trivial assertions**: No `assert_bool(true).is_true()` without justification
3. **Reduced duplication**: AI tests use `CharacterFactory` and `UnitFactory`
4. **Consistent performance**: All AI tests use 100ms waits

---

## Dependencies

- Phase 1 fixtures must exist:
  - `tests/fixtures/character_factory.gd` (exists)
  - `tests/fixtures/unit_factory.gd` (exists)
  - `tests/fixtures/grid_setup.gd` (exists)

- Integration test directories must exist:
  - `tests/integration/dialogue/` (create if needed)
  - `tests/integration/cinematics/` (exists)
