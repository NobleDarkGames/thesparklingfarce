# Test Suite Cleanup - Phase 4 Implementation Plan

## Overview

This plan addresses issues identified during Phase 3 agent reviews:
- GridSetup fixture deployment for AI and battle integration tests
- SignalTracker fixture deployment for registry unit tests
- Signal cleanup in unit tests (memory leak prevention)
- Test classification corrections
- Anti-pattern fixes

**Reference**: `docs/testing-reference.md` for classification criteria.

**Prerequisite**: Phase 3 from `docs/plans/test-suite-cleanup-phase3.md` should be complete.

---

## Task Summary

| Priority | Task | Files Affected | Parallel? |
|----------|------|----------------|-----------|
| High | 4.1 Deploy GridSetup fixture | 13 integration tests | Yes (after 4.1.1) |
| High | 4.2 Deploy SignalTracker fixture | 6 unit tests | Yes |
| High | 4.3 Fix signal cleanup in registries | 3 unit tests | Yes |
| High | 4.4 Move test_collapse_section.gd | 1 test file | Independent |
| Medium | 4.5 Fix silent pass anti-pattern | 1 test file | Independent |
| Medium | 4.6 Create AI Test Base Class | New fixture | Sequential |
| Medium | 4.7 Add is_instance_valid() check | 1 test file | Independent |
| Low | 4.8 Remove trivial font assertions | 1 test file | Independent |
| Low | 4.9 Consolidate signal tracking pattern | 3 test files | Parallelizable |

---

## Phase 4.1: Deploy GridSetup Fixture (High Priority)

### Problem Analysis

13 integration tests have duplicate grid/tilemap setup code (~15 lines each):

```gdscript
# Duplicated pattern in each AI test
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid

func before() -> void:
    _tilemap_layer = TileMapLayer.new()
    _tileset = TileSet.new()
    _tilemap_layer.tile_set = _tileset
    _units_container.add_child(_tilemap_layer)

    _grid_resource = Grid.new()
    _grid_resource.grid_size = Vector2i(20, 15)
    _grid_resource.cell_size = 32
    GridManager.setup_grid(_grid_resource, _tilemap_layer)

func _cleanup_tilemap() -> void:
    if _tilemap_layer and is_instance_valid(_tilemap_layer):
        _tilemap_layer.queue_free()
        _tilemap_layer = null
    _tileset = null
    _grid_resource = null
```

The `tests/fixtures/grid_setup.gd` fixture already exists and encapsulates this pattern.

### Task 4.1.1: Verify GridSetup Fixture API

**File**: `tests/fixtures/grid_setup.gd`

Existing fixture API:
```gdscript
class_name GridSetup
extends RefCounted

var tilemap_layer: TileMapLayer
var tileset: TileSet
var grid_resource: Grid

func create_grid(parent: Node, grid_size: Vector2i = Vector2i(20, 15), cell_size: int = 32) -> void
func cleanup() -> void
```

**No changes needed** - fixture API matches test requirements.

### Task 4.1.2: Update AI Integration Tests (10 files)

**Files to update**:

| File | Current Lines | After Fixture |
|------|---------------|---------------|
| `tests/integration/ai/test_aoe_targeting.gd` | 48-58, 254-260 | ~10 lines |
| `tests/integration/ai/test_cautious_engagement.gd` | Similar | ~10 lines |
| `tests/integration/ai/test_defensive_positioning.gd` | Similar | ~10 lines |
| `tests/integration/ai/test_healer_prioritization.gd` | Similar | ~10 lines |
| `tests/integration/ai/test_opportunistic_targeting.gd` | Similar | ~10 lines |
| `tests/integration/ai/test_ranged_ai_positioning.gd` | Similar | ~10 lines |
| `tests/integration/ai/test_retreat_behavior.gd` | Similar | ~10 lines |
| `tests/integration/ai/test_stationary_guard.gd` | Similar | ~10 lines |
| `tests/integration/ai/test_terrain_advantage.gd` | Similar | ~10 lines |
| `tests/integration/ai/test_tactical_debuff.gd` | Similar | ~10 lines |

**Pattern transformation**:

**Before** (test_aoe_targeting.gd lines 34-58, 254-260):
```gdscript
# Resources to clean up
var _tilemap_layer: TileMapLayer
var _tileset: TileSet
var _grid_resource: Grid

func before() -> void:
    _targets_hit.clear()
    _units_container = Node2D.new()
    add_child(_units_container)

    # Create minimal TileMapLayer for GridManager
    _tilemap_layer = TileMapLayer.new()
    _tileset = TileSet.new()
    _tilemap_layer.tile_set = _tileset
    _units_container.add_child(_tilemap_layer)

    # Setup grid
    _grid_resource = Grid.new()
    _grid_resource.grid_size = Vector2i(20, 15)
    _grid_resource.cell_size = 32
    GridManager.setup_grid(_grid_resource, _tilemap_layer)

func _cleanup_tilemap() -> void:
    if _tilemap_layer and is_instance_valid(_tilemap_layer):
        _tilemap_layer.queue_free()
        _tilemap_layer = null
    _tileset = null
    _grid_resource = null
```

**After**:
```gdscript
const GridSetupScript = preload("res://tests/fixtures/grid_setup.gd")

var _grid_setup: GridSetup

func before() -> void:
    _targets_hit.clear()
    _units_container = Node2D.new()
    add_child(_units_container)

    # Setup grid using shared fixture
    _grid_setup = GridSetupScript.new()
    _grid_setup.create_grid(_units_container)

func after() -> void:
    _cleanup_units()
    _grid_setup.cleanup()
    _grid_setup = null
    # ... rest of cleanup ...
```

**Removal checklist per file**:
- [ ] Remove `var _tilemap_layer: TileMapLayer`
- [ ] Remove `var _tileset: TileSet`
- [ ] Remove `var _grid_resource: Grid`
- [ ] Remove `_cleanup_tilemap()` function entirely
- [ ] Add `const GridSetupScript = preload(...)`
- [ ] Add `var _grid_setup: GridSetup`
- [ ] Replace grid setup block with `_grid_setup.create_grid(_units_container)`
- [ ] Replace `_cleanup_tilemap()` call with `_grid_setup.cleanup()`

### Task 4.1.3: Update Battle Integration Tests (3 files)

**Files**:
- `tests/integration/battle/test_battle_flow.gd`
- `tests/integration/battle/test_turn_manager.gd`
- `tests/integration/battle/test_experience_manager.gd`

Apply same pattern transformation as AI tests.

---

## Phase 4.2: Deploy SignalTracker Fixture (High Priority)

### Problem Analysis

Multiple unit tests implement manual signal tracking with `_signal_received` boolean pattern:

```gdscript
# Current pattern (duplicated in each file)
var _signal_received: bool = false

func _on_registrations_changed() -> void:
    _signal_received = true

func test_register_emits_signal() -> void:
    _signal_received = false
    _registry.registrations_changed.connect(_on_registrations_changed)
    _registry.register_from_config(...)
    assert_bool(_signal_received).is_true()
```

The `tests/fixtures/signal_tracker.gd` fixture provides a cleaner pattern.

### Task 4.2.1: Update Registry Unit Tests (3 files)

**Files**:
- `tests/unit/registries/test_ai_mode_registry.gd` (lines 454, 457, 463, 482, 496)
- `tests/unit/registries/test_tileset_registry.gd` (lines 404, 407, 413, 432)
- `tests/unit/registries/test_ai_brain_registry.gd` (lines 387, 390, 396, 415)

**Pattern transformation**:

**Before** (test_ai_mode_registry.gd):
```gdscript
var _signal_received: bool = false

func _on_registrations_changed() -> void:
    _signal_received = true

func test_register_from_config_emits_signal() -> void:
    _signal_received = false
    _registry.registrations_changed.connect(_on_registrations_changed)

    var config: Dictionary = {
        "berserk": {"display_name": "Berserk"}
    }
    _registry.register_from_config("test_mod", config)

    assert_bool(_signal_received).is_true()
```

**After**:
```gdscript
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

var _tracker: SignalTracker

func before_test() -> void:
    # ... existing setup ...
    _tracker = SignalTrackerScript.new()

func after_test() -> void:
    if _tracker:
        _tracker.disconnect_all()
        _tracker = null

func test_register_from_config_emits_signal() -> void:
    _tracker.track(_registry.registrations_changed)

    var config: Dictionary = {
        "berserk": {"display_name": "Berserk"}
    }
    _registry.register_from_config("test_mod", config)

    assert_bool(_tracker.was_emitted("registrations_changed")).is_true()
```

**Benefits**:
- Automatic cleanup via `disconnect_all()`
- Emission counting with `emission_count()`
- Argument inspection with `was_emitted_with()`
- No manual callback functions needed

### Task 4.2.2: Update Editor Unit Tests (3 files)

**Files**:
- `tests/unit/editor/test_collapse_section.gd` (lines 212-219, 221-227)
- `tests/unit/editor/test_resource_picker.gd` (lines 156-160)
- `tests/unit/editor/test_editor_tab_registry.gd` (lines 455-458, 462-468)

Same pattern transformation as registry tests.

---

## Phase 4.3: Fix Signal Cleanup in Unit Tests (High Priority)

### Problem Analysis

These tests connect signals in test functions but never disconnect in `after_test()`:

| File | Signal Connection Lines | Issue |
|------|-------------------------|-------|
| `test_ai_mode_registry.gd` | 463, 482, 496 | No disconnect in after_test |
| `test_tileset_registry.gd` | 413, 432 | No disconnect in after_test |
| `test_ai_brain_registry.gd` | 396, 415 | No disconnect in after_test |

Without cleanup, subsequent tests may receive signals from previous test's connections, causing flaky tests.

### Task 4.3.1: Add Signal Cleanup

**Option A (Recommended)**: Deploy SignalTracker (Task 4.2) which handles cleanup automatically.

**Option B (Manual)**: If SignalTracker migration is deferred, add manual cleanup:

```gdscript
# Add to each file
var _connected_signals: Array[Dictionary] = []

func _connect_for_test(sig: Signal, callable: Callable) -> void:
    sig.connect(callable)
    _connected_signals.append({"signal": sig, "callable": callable})

func after_test() -> void:
    for conn: Dictionary in _connected_signals:
        if conn.signal.is_connected(conn.callable):
            conn.signal.disconnect(conn.callable)
    _connected_signals.clear()

# In tests:
func test_register_from_config_emits_signal() -> void:
    _signal_received = false
    _connect_for_test(_registry.registrations_changed, _on_registrations_changed)
    # ...
```

**Recommendation**: Complete Task 4.2 first, which makes this task unnecessary.

---

## Phase 4.4: Move Misclassified Test (High Priority)

### Problem Analysis

`tests/unit/editor/test_collapse_section.gd` uses scene tree operations that make it an integration test:
- Line 21: `add_child(_section)` - adds node to scene tree
- Line 23: `await get_tree().process_frame` - waits for engine processing
- Line 335: `add_child(collapsed_section)` - creates additional scene tree nodes

Per `docs/testing-reference.md`:
> Does it access an autoload singleton? ... Does it instantiate a scene (.tscn)? ... YES -> Integration test

### Task 4.4.1: Move Test File

**Current location**: `tests/unit/editor/test_collapse_section.gd`
**New location**: `tests/integration/editor/test_collapse_section.gd`

```bash
# Execution
mkdir -p tests/integration/editor
git mv tests/unit/editor/test_collapse_section.gd tests/integration/editor/
```

**No code changes required** - only file relocation.

---

## Phase 4.5: Fix Silent Pass Anti-Pattern (Medium Priority)

### Problem Analysis

`tests/integration/mod_system/test_tileset_resolution.gd` has tests that return early without assertions:

```gdscript
# Lines 63-68, 84-87, 104-107, etc.
func test_has_tileset_is_case_insensitive() -> void:
    var names: Array[String] = ModLoader.get_tileset_names()
    if names.is_empty():
        # Skip this test if no tilesets registered (still valid)
        return  # SILENT PASS - no assertion!

    # ... actual test ...
```

This silently passes when the precondition fails, hiding potential issues.

### Task 4.5.1: Add Proper Skip Mechanism

**Option A (GdUnit4 skip)**:
```gdscript
func test_has_tileset_is_case_insensitive() -> void:
    var names: Array[String] = ModLoader.get_tileset_names()
    if names.is_empty():
        # Use GdUnit4's skip annotation approach via assertion message
        assert_bool(true).override_failure_message("SKIPPED: No tilesets registered").is_true()
        return

    # ... actual test ...
```

**Option B (Explicit precondition assertion)**:
```gdscript
func test_has_tileset_is_case_insensitive() -> void:
    var names: Array[String] = ModLoader.get_tileset_names()
    # Fail explicitly if precondition not met
    assert_array(names).override_failure_message(
        "Test requires at least one tileset registered"
    ).is_not_empty()

    var first_name: String = names[0]
    # ... rest of test ...
```

**Recommendation**: Option B - explicit failures are better than hidden skips.

**Affected functions** (all follow same pattern):
- `test_has_tileset_is_case_insensitive()` (line 63)
- `test_get_tileset_is_case_insensitive()` (line 84)
- `test_get_tileset_source_returns_mod_id()` (line 104)
- `test_get_tileset_returns_tileset_resource()` (line 120)
- `test_get_tileset_path_returns_valid_path()` (line 133)
- `test_tileset_is_lazy_loaded()` (line 152)

---

## Phase 4.6: Create AI Test Base Class (Medium Priority)

### Problem Analysis

All 10 AI tests share identical patterns:
- Grid/TileMapLayer setup (~15 lines)
- `_cleanup_units()` function (~15 lines)
- `_cleanup_tilemap()` function (~8 lines)
- `_cleanup_resources()` function (~5 lines)
- Combat signal handler
- AI context building (~10 lines)

Total duplicated code: ~53 lines per file = 530 lines across 10 files.

### Task 4.6.1: Create AITestBase Fixture

**File**: `tests/fixtures/ai_test_base.gd`

```gdscript
## Base class for AI integration tests
##
## Provides shared setup/cleanup for AI behavior testing:
## - Grid and TileMapLayer setup via GridSetup fixture
## - Unit spawning and cleanup via UnitFactory
## - Combat signal tracking
## - AI context building
##
## Usage:
##   extends AITestBase
##
##   func before() -> void:
##       super.before()  # Sets up grid, container
##       # ... spawn units for your test ...
##
##   func after() -> void:
##       # ... cleanup your units ...
##       super.after()  # Cleans up grid, container
class_name AITestBase
extends GdUnitTestSuite


const GridSetupScript = preload("res://tests/fixtures/grid_setup.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")

# Shared infrastructure
var _units_container: Node2D
var _grid_setup: GridSetup

# Combat tracking
var _combat_occurred: bool = false
var _last_attacker: Unit = null
var _last_defender: Unit = null
var _last_damage: int = 0

# Resources to track for cleanup
var _created_characters: Array[CharacterData] = []
var _created_classes: Array[ClassData] = []
var _created_behaviors: Array[AIBehaviorData] = []
var _created_abilities: Array[AbilityData] = []


func before() -> void:
    _reset_tracking()

    # Create units container
    _units_container = Node2D.new()
    add_child(_units_container)

    # Setup grid
    _grid_setup = GridSetupScript.new()
    _grid_setup.create_grid(_units_container)

    # Connect combat signal
    if not BattleManager.combat_resolved.is_connected(_on_combat_resolved):
        BattleManager.combat_resolved.connect(_on_combat_resolved)


func after() -> void:
    # Disconnect combat signal
    if BattleManager.combat_resolved.is_connected(_on_combat_resolved):
        BattleManager.combat_resolved.disconnect(_on_combat_resolved)

    # Cleanup grid
    if _grid_setup:
        _grid_setup.cleanup()
        _grid_setup = null

    # Cleanup container
    if _units_container and is_instance_valid(_units_container):
        _units_container.queue_free()
        _units_container = null

    # Clear tracked resources
    _created_characters.clear()
    _created_classes.clear()
    _created_behaviors.clear()
    _created_abilities.clear()


func _reset_tracking() -> void:
    _combat_occurred = false
    _last_attacker = null
    _last_defender = null
    _last_damage = 0


func _on_combat_resolved(attacker: Unit, defender: Unit, damage: int, _hit: bool, _crit: bool) -> void:
    _combat_occurred = true
    _last_attacker = attacker
    _last_defender = defender
    _last_damage = damage


## Build standard AI context dictionary
func build_ai_context(player_units: Array, enemy_units: Array, turn_number: int = 1) -> Dictionary:
    return {
        "player_units": player_units,
        "enemy_units": enemy_units,
        "neutral_units": [],
        "turn_number": turn_number,
        "unit_hp_percent": 100.0,
        "ai_delays": {"after_movement": 0.0, "before_attack": 0.0}
    }


## Execute AI turn for a unit and wait for completion
func execute_ai_turn(unit: Unit) -> void:
    var context: Dictionary = build_ai_context(
        BattleManager.player_units,
        BattleManager.enemy_units
    )

    var ConfigurableAIBrainScript: GDScript = load("res://core/systems/ai/configurable_ai_brain.gd")
    var brain: AIBrain = ConfigurableAIBrainScript.get_instance()
    await brain.execute_with_behavior(unit, context, unit.ai_behavior)

    # Wait for movement to complete
    var wait_start: float = Time.get_ticks_msec()
    while unit.is_moving() and (Time.get_ticks_msec() - wait_start) < 3000:
        await get_tree().process_frame


## Cleanup a unit using UnitFactory
func cleanup_unit(unit: Unit) -> void:
    UnitFactoryScript.cleanup_unit(unit)


## Track a character for cleanup
func track_character(character: CharacterData) -> void:
    _created_characters.append(character)


## Track a class for cleanup
func track_class(class_data: ClassData) -> void:
    _created_classes.append(class_data)


## Track a behavior for cleanup
func track_behavior(behavior: AIBehaviorData) -> void:
    _created_behaviors.append(behavior)


## Track an ability for cleanup
func track_ability(ability: AbilityData) -> void:
    _created_abilities.append(ability)
```

### Task 4.6.2: Migrate AI Tests to Base Class

**Example migration** (test_aoe_targeting.gd):

**Before** (~268 lines):
```gdscript
class_name TestAoeTargeting
extends GdUnitTestSuite

# ... 50 lines of setup/cleanup code ...
# ... 218 lines of test code ...
```

**After** (~180 lines):
```gdscript
class_name TestAoeTargeting
extends AITestBase

# Units specific to this test
var _mage_unit: Unit
var _isolated_target: Unit
var _cluster_targets: Array[Unit] = []

# Tracking specific to this test
var _mage_initial_mp: int = 0
var _targets_hit: Array[Unit] = []


func before() -> void:
    super.before()  # Sets up grid, container, combat tracking
    _targets_hit.clear()


func after() -> void:
    cleanup_unit(_mage_unit)
    _mage_unit = null
    for target: Unit in _cluster_targets:
        cleanup_unit(target)
    _cluster_targets.clear()
    cleanup_unit(_isolated_target)
    _isolated_target = null
    super.after()


# ... test methods remain largely unchanged ...
```

**Estimated line savings**: ~90 lines per file = 900 lines across 10 files.

---

## Phase 4.7: Add is_instance_valid() Check (Medium Priority)

### Problem Analysis

`tests/unit/editor/test_collapse_section.gd` lines 27-29:

```gdscript
func after_test() -> void:
    if _section:
        _section.queue_free()  # Missing is_instance_valid() check
        _section = null
```

If `_section` was already freed (e.g., by a test that calls `queue_free()`), this will cause an error.

### Task 4.7.1: Add Validity Check

**Before**:
```gdscript
func after_test() -> void:
    if _section:
        _section.queue_free()
        _section = null
```

**After**:
```gdscript
func after_test() -> void:
    if _section and is_instance_valid(_section):
        _section.queue_free()
    _section = null
```

---

## Phase 4.8: Remove Trivial Font Size Assertions (Low Priority)

### Problem Analysis

`tests/unit/ui/test_monogram_font_compliance.gd` has tests that verify constants:

```gdscript
func test_size_16_is_allowed() -> void:
    assert_bool(16 in ALLOWED_SIZES).is_true()

func test_size_24_is_allowed() -> void:
    assert_bool(24 in ALLOWED_SIZES).is_true()
# ... etc for 32, 48, 64, and non-multiples
```

These test that a constant array contains specific values - documentation masquerading as tests.

### Task 4.8.1: Remove Trivial Tests

**Remove these functions** (lines 135-159):
- `test_size_16_is_allowed()`
- `test_size_24_is_allowed()`
- `test_size_32_is_allowed()`
- `test_size_48_is_allowed()`
- `test_size_64_is_allowed()`
- `test_non_multiple_of_8_is_not_allowed()`

**Keep**: `test_all_font_sizes_are_monogram_compliant()` - the actual useful test that scans the codebase.

**Alternative**: Add a comment block documenting allowed sizes instead:

```gdscript
## Allowed Monogram font sizes (all multiples of 8, Monogram's base unit):
## - 16: Default body text
## - 24: Subheadings
## - 32: Headings
## - 48: Large titles
## - 64: Extra large display
const ALLOWED_SIZES: Array[int] = [16, 24, 32, 48, 64]
```

---

## Phase 4.9: Consolidate Signal Tracking Pattern (Low Priority)

### Problem Analysis

Three integration tests implement identical `_connected_signals` + `_connect_signal()` pattern:

- `tests/integration/battle/test_battle_rewards.gd` (lines 42-43, 85-88)
- `tests/integration/shop/test_shop_manager.gd` (similar pattern)
- `tests/integration/dialogue/test_dialog_manager.gd` (similar pattern)

This duplicates SignalTracker functionality.

### Task 4.9.1: Migrate to SignalTracker

**Before** (test_battle_rewards.gd):
```gdscript
var _connected_signals: Array[Dictionary] = []

func after_test() -> void:
    for connection: Dictionary in _connected_signals:
        var sig: Signal = connection.signal_ref
        var callable: Callable = connection.callable
        if sig.is_connected(callable):
            sig.disconnect(callable)
    _connected_signals.clear()

func _connect_signal(sig: Signal, callable: Callable) -> void:
    sig.connect(callable)
    _connected_signals.append({"signal_ref": sig, "callable": callable})

func test_pre_battle_rewards_signal_emitted() -> void:
    _reset_signal_tracking()
    _connect_signal(GameEventBus.pre_battle_rewards, _on_pre_battle_rewards)
    # ...
```

**After**:
```gdscript
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

var _tracker: SignalTracker

func before_test() -> void:
    # ... existing setup ...
    _tracker = SignalTrackerScript.new()

func after_test() -> void:
    _tracker.disconnect_all()
    _tracker = null
    # ... existing cleanup ...

func test_pre_battle_rewards_signal_emitted() -> void:
    _tracker.track(GameEventBus.pre_battle_rewards)
    # ... trigger action ...
    assert_bool(_tracker.was_emitted("pre_battle_rewards")).is_true()
```

**Note**: test_battle_rewards.gd needs to keep the custom callback pattern because it inspects signal arguments. SignalTracker's `was_emitted_with()` can handle this but may require refactoring.

---

## Execution Order

```
Phase 4.1-4.4 (High Priority - Parallelizable)
    |
    +-- Task 4.1: Deploy GridSetup fixture (13 files)
    +-- Task 4.2: Deploy SignalTracker fixture (6 files)
    +-- Task 4.3: Fix signal cleanup (handled by 4.2)
    +-- Task 4.4: Move test_collapse_section.gd
    |
    v
Phase 4.5-4.7 (Medium Priority - Parallelizable)
    |
    +-- Task 4.5: Fix silent pass anti-pattern (1 file)
    +-- Task 4.6: Create AI Test Base Class (new fixture + 10 files)
    +-- Task 4.7: Add is_instance_valid() check (1 file)
    |
    v
Phase 4.8-4.9 (Low Priority - Parallelizable)
    |
    +-- Task 4.8: Remove trivial font assertions (1 file)
    +-- Task 4.9: Consolidate signal tracking (3 files)
```

---

## Verification Checklist

### After Phase 4.1 (GridSetup Deployment)

```bash
GODOT_BIN=~/Downloads/Godot_v4.5.1-stable_linux.x86_64/Godot_v4.5.1-stable_linux.x86_64

# Run AI tests
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/ai"

# Verify no duplicate tilemap variables
grep -r "_tilemap_layer: TileMapLayer" tests/integration/ai/ && echo "FAIL: Old pattern remains" || echo "PASS"
```

### After Phase 4.2 (SignalTracker Deployment)

```bash
# Run registry unit tests
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/unit/registries"

# Verify no _signal_received pattern
grep -r "_signal_received: bool" tests/unit/registries/ && echo "FAIL: Old pattern remains" || echo "PASS"
```

### After Phase 4.4 (Test Relocation)

```bash
# Verify file moved
test -f tests/integration/editor/test_collapse_section.gd && echo "PASS: File moved" || echo "FAIL"
test ! -f tests/unit/editor/test_collapse_section.gd && echo "PASS: Old location empty" || echo "FAIL"

# Run relocated test
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/editor/test_collapse_section.gd"
```

### After Phase 4.5 (Silent Pass Fix)

```bash
# Run tileset resolution tests - should now fail or skip explicitly if no tilesets
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/mod_system/test_tileset_resolution.gd"
```

### After Phase 4.6 (AI Test Base Class)

```bash
# Run all AI tests with new base class
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/ai"

# Count lines saved
wc -l tests/integration/ai/*.gd  # Should be significantly less
```

### Full Suite Verification

```bash
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests"
```

---

## Risk Assessment

| Task | Risk | Mitigation |
|------|------|------------|
| 4.1 GridSetup deployment | Low | Fixture already exists and tested |
| 4.2 SignalTracker deployment | Low | Fixture already exists; migration is straightforward |
| 4.3 Signal cleanup | None | Handled by 4.2 |
| 4.4 Test relocation | Low | git mv preserves history; no code changes |
| 4.5 Silent pass fix | Medium | May expose tests that were silently passing |
| 4.6 AI Test Base Class | Medium | Requires careful migration; test individually |
| 4.7 is_instance_valid() | Low | Defensive change; no behavioral impact |
| 4.8 Remove trivial tests | Low | Tests provide no coverage value |
| 4.9 Signal tracking consolidation | Low | Pattern replacement; SignalTracker handles edge cases |

---

## Success Metrics

After completing Phase 4:

1. **Reduced duplication**: GridSetup fixture used in all 13 integration tests
2. **Consistent signal tracking**: SignalTracker used for all signal assertions
3. **No memory leaks**: All signal connections properly cleaned up
4. **Correct test classification**: test_collapse_section.gd in integration/
5. **No silent passes**: test_tileset_resolution.gd fails explicitly when preconditions not met
6. **AI test maintainability**: AITestBase class reduces boilerplate by ~900 lines
7. **Defensive cleanup**: All queue_free() calls guarded with is_instance_valid()

---

## Notes on Intentional Patterns

**`await_millis(100)` in AI tests**: This pattern is INTENTIONAL and should NOT be removed. The AI tests bypass AIController to test the brain directly, which means the `turn_completed` signal from AIController is never emitted. The tests use `await_millis()` to wait for the brain's async execution to complete.

If signal-based waits are desired for AI tests, the approach would require:
1. Adding a signal to the brain itself, or
2. Using the full AIController flow (which is slower and tests more than just the brain)

For now, `await_millis(100)` is the correct pattern for these specific tests.

---

## Dependencies

Phase 4 requires:
- Phase 3 fixtures exist:
  - `tests/fixtures/grid_setup.gd` (exists)
  - `tests/fixtures/signal_tracker.gd` (exists)
  - `tests/fixtures/character_factory.gd` (exists)
  - `tests/fixtures/unit_factory.gd` (exists)
- No parallel modifications to AI test files
- GdUnit4 test runner functional
