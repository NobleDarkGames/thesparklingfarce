# Test Suite Cleanup - Phase 3 Implementation Plan

## Overview

This plan addresses issues identified during Phase 2 agent reviews:
- Signal-based AI test waits (replacing fixed `await_millis()` delays)
- SignalTracker utility class for reusable signal assertions
- Test coverage gaps (StatusEffectManager integration)
- test_party_manager.gd factory migration

**Reference**: `docs/testing-reference.md` for classification criteria.

**Prerequisite**: Phase 2 from `docs/plans/test-suite-cleanup-phase2.md` should be complete.

---

## Phase 3.1: Signal-Based AI Waits (Sequential - Core Infrastructure)

### Problem Analysis

Current AI tests use `await_millis(100)` to wait for AI decisions:

```gdscript
# Current pattern in tests/integration/ai/*.gd
await _execute_attacker_turn()
await await_millis(100)  # Hope 100ms is enough
assert_bool(_combat_occurred).is_true()
```

This is fragile because:
- Slow CI environments may need longer waits
- Fast systems waste time waiting
- No guarantee AI actually finished

### Task 3.1.1: Add `turn_completed` Signal to AIController

**File**: `core/systems/ai_controller.gd`

The AIController already has a clean structure. Add a signal that fires after AI execution completes:

**Current code (lines 20-66)**:
```gdscript
## Called by TurnManager when enemy/neutral unit's turn starts
func process_enemy_turn(unit: Unit) -> void:
    # ... existing code ...

    if TurnManager.active_unit == unit:
        TurnManager.end_unit_turn(unit)
```

**Updated code**:
```gdscript
## Emitted when AI turn processing completes (for test synchronization)
signal turn_completed(unit: Unit)

## Called by TurnManager when enemy/neutral unit's turn starts
func process_enemy_turn(unit: Unit) -> void:
    if not unit:
        push_error("AIController: Cannot process turn for null unit")
        return

    if not unit.is_alive():
        # Dead units don't act, end turn immediately
        TurnManager.end_unit_turn(unit)
        turn_completed.emit(unit)  # Signal even for skipped turns
        return

    # Delay before enemy starts acting (gives player time to see whose turn it is)
    # Skip in headless mode for faster automated testing
    if delay_before_turn_start > 0 and not TurnManager.is_headless:
        await get_tree().create_timer(delay_before_turn_start).timeout

    # Build context for AI decision-making
    var context: Dictionary = _build_ai_context()

    # Pass delay settings to AI brain via context (0 in headless mode)
    if TurnManager.is_headless:
        context["ai_delays"] = {
            "after_movement": 0.0,
            "before_attack": 0.0,
        }
    else:
        context["ai_delays"] = {
            "after_movement": delay_after_movement,
            "before_attack": delay_before_attack,
        }

    # Execute AI behavior - prefer new AIBehaviorData system
    var brain: AIBrain = ConfigurableAIBrainScript.get_instance()

    if unit.ai_behavior:
        await brain.execute_with_behavior(unit, context, unit.ai_behavior)
    else:
        push_warning("AIController: Unit %s has no ai_behavior assigned, using default aggressive" % UnitUtils.get_display_name(unit))
        await brain.execute_async(unit, context)

    # Emit signal BEFORE ending turn (so tests can check state)
    turn_completed.emit(unit)

    # End turn (only if not already ended by BattleManager during attack)
    if TurnManager.active_unit == unit:
        TurnManager.end_unit_turn(unit)
```

**Impact Assessment**:
- Non-breaking change (adds signal, doesn't modify existing behavior)
- Signal is emitted for all cases (early return, normal completion)
- Emitted BEFORE `end_unit_turn` so tests can check state while unit is still active

**Verification**:
```bash
GODOT_BIN=~/Downloads/Godot_v4.5.1-stable_linux.x86_64/Godot_v4.5.1-stable_linux.x86_64
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/ai"
```

---

### Task 3.1.2: Update AI Tests to Use Signal Wait

**Pattern change for all AI tests**:

**Before (fragile)**:
```gdscript
func test_attacker_prioritizes_wounded_over_closer_target() -> void:
    # ... setup ...
    await _execute_attacker_turn()
    await await_millis(100)  # Fragile fixed delay
    assert_bool(_combat_occurred).is_true()
```

**After (reliable)**:
```gdscript
func test_attacker_prioritizes_wounded_over_closer_target() -> void:
    # ... setup ...
    await _execute_attacker_turn()
    # Wait for AI to finish (reliable, no arbitrary delays)
    await await_signal_on(AIController, "turn_completed", [], 2000)
    assert_bool(_combat_occurred).is_true()
```

**Files to update (10 files, parallelizable after 3.1.1)**:

| File | Line with `await_millis` |
|------|--------------------------|
| `tests/integration/ai/test_aoe_targeting.gd` | 115 |
| `tests/integration/ai/test_cautious_engagement.gd` | ~265 |
| `tests/integration/ai/test_defensive_positioning.gd` | 107 |
| `tests/integration/ai/test_healer_prioritization.gd` | 114 |
| `tests/integration/ai/test_opportunistic_targeting.gd` | 112 |
| `tests/integration/ai/test_retreat_behavior.gd` | 108 |
| `tests/integration/ai/test_stationary_guard.gd` | 232 |
| `tests/integration/ai/test_tactical_debuff.gd` | 102 |
| `tests/integration/battle/test_battle_flow.gd` | (verify usage) |

**Note**: `await_signal_on()` is a GdUnit4 built-in that waits for a signal with timeout.

---

## Phase 3.2: SignalTracker Utility Class (Parallelizable)

### Task 3.2.1: Create SignalTracker Fixture

**File**: `tests/fixtures/signal_tracker.gd`

This utility tracks signal emissions for flexible assertions in tests.

```gdscript
## Reusable utility for tracking signal emissions in tests
##
## Usage:
##   var tracker: SignalTracker = SignalTracker.new()
##   tracker.track(my_object.some_signal)
##   # ... trigger action ...
##   assert_bool(tracker.was_emitted("some_signal")).is_true()
##   assert_int(tracker.emission_count("some_signal")).is_equal(2)
##   tracker.disconnect_all()  # Cleanup
class_name SignalTracker
extends RefCounted


## Structure to store emission data
class EmissionRecord:
    var signal_name: String
    var arguments: Array
    var timestamp: float

    func _init(p_signal_name: String, p_arguments: Array) -> void:
        signal_name = p_signal_name
        arguments = p_arguments
        timestamp = Time.get_ticks_msec() / 1000.0


## All tracked connections (for cleanup)
var _connections: Array[Dictionary] = []

## All recorded emissions
var _emissions: Array[EmissionRecord] = []


## Track a signal for emissions
## Automatically creates appropriate callback based on signal arity
func track(sig: Signal) -> void:
    var signal_name: String = sig.get_name()
    var object: Object = sig.get_object()

    # Create a callable that captures emissions
    # We use a lambda that accepts any number of args via Callable.bindv workaround
    var callback: Callable = func(arg1 = null, arg2 = null, arg3 = null, arg4 = null) -> void:
        var args: Array = []
        if arg1 != null:
            args.append(arg1)
        if arg2 != null:
            args.append(arg2)
        if arg3 != null:
            args.append(arg3)
        if arg4 != null:
            args.append(arg4)
        _record_emission(signal_name, args)

    sig.connect(callback)
    _connections.append({
        "signal": sig,
        "callable": callback
    })


## Record an emission internally
func _record_emission(signal_name: String, arguments: Array) -> void:
    _emissions.append(EmissionRecord.new(signal_name, arguments))


## Check if a signal was emitted at least once
func was_emitted(signal_name: String) -> bool:
    for emission: EmissionRecord in _emissions:
        if emission.signal_name == signal_name:
            return true
    return false


## Get total emission count for a signal
func emission_count(signal_name: String) -> int:
    var count: int = 0
    for emission: EmissionRecord in _emissions:
        if emission.signal_name == signal_name:
            count += 1
    return count


## Get all emissions for a signal (for detailed assertions)
func get_emissions(signal_name: String) -> Array[EmissionRecord]:
    var result: Array[EmissionRecord] = []
    for emission: EmissionRecord in _emissions:
        if emission.signal_name == signal_name:
            result.append(emission)
    return result


## Check if signal was emitted with specific arguments
## Uses shallow equality comparison
func was_emitted_with(signal_name: String, expected_args: Array) -> bool:
    for emission: EmissionRecord in _emissions:
        if emission.signal_name == signal_name:
            if _arrays_equal(emission.arguments, expected_args):
                return true
    return false


## Helper for array comparison
func _arrays_equal(a: Array, b: Array) -> bool:
    if a.size() != b.size():
        return false
    for i: int in range(a.size()):
        if a[i] != b[i]:
            return false
    return true


## Clear all recorded emissions (useful between test phases)
func clear_emissions() -> void:
    _emissions.clear()


## Disconnect all tracked signals (MUST call in after_test)
func disconnect_all() -> void:
    for conn: Dictionary in _connections:
        var sig: Signal = conn.signal
        var callable: Callable = conn.callable
        if sig.is_connected(callable):
            sig.disconnect(callable)
    _connections.clear()
    _emissions.clear()
```

**Usage example in a test**:
```gdscript
var _tracker: SignalTracker

func before_test() -> void:
    _tracker = SignalTracker.new()
    _tracker.track(PartyManager.member_added)
    _tracker.track(PartyManager.member_departed)

func after_test() -> void:
    _tracker.disconnect_all()

func test_adding_member_emits_signal() -> void:
    var hero: CharacterData = _create_character("Hero")
    PartyManager.add_member(hero)

    assert_bool(_tracker.was_emitted("member_added")).is_true()
    assert_int(_tracker.emission_count("member_added")).is_equal(1)
```

**Comparison to existing pattern in test_party_manager.gd**:

The current test uses manual signal tracking:
```gdscript
# Current (verbose, repeated in each test file)
var _member_added_events: Array[CharacterData] = []

func _on_member_added(character: CharacterData) -> void:
    _member_added_events.append(character)

# In test:
assert_int(_member_added_events.size()).is_equal(1)
```

SignalTracker is more reusable but the existing pattern is already clean. **Recommendation**: Create SignalTracker but don't mandate migration - use for new tests.

---

## Phase 3.3: Coverage Gaps (Parallelizable after 3.1)

### Task 3.3.1: InputManager Testability Assessment

**DEFERRED - Complexity too high for this phase**

**Reasoning**:
- InputManager (`core/systems/input_manager.gd`) is 2284 lines with complex state machine
- Heavy dependencies: GridManager, BattleManager, AudioManager, camera, multiple menus
- Testing would require mocking or full scene integration
- Low ROI: Most input paths are exercised through battle flow tests

**If revisited later**, approach would be:
1. Create InputManagerTestHarness scene with minimal mocks
2. Test state transitions independently of actual input events
3. Focus on edge cases (stale signal rejection, state guards)

---

### Task 3.3.2: StatusEffectManager Integration Tests

**File to create**: `tests/integration/status_effects/test_status_effect_manager.gd`

**Scope**: Test status effect application, duration, and expiration during battle.

**Key systems involved**:
- `core/systems/battle_manager.gd` - applies status effects
- `core/components/unit_stats.gd` - tracks active effects
- `core/resources/status_effect_data.gd` - effect definitions
- `core/registries/status_effect_registry.gd` - effect lookup

**Test outline**:
```gdscript
class_name TestStatusEffectManagerIntegration
extends GdUnitTestSuite

## Tests for status effect application, duration tracking, and expiration

const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")

var _units_container: Node2D
var _target_unit: Unit
var _test_effect: StatusEffectData

func before() -> void:
    _units_container = Node2D.new()
    add_child(_units_container)

    # Create minimal grid setup
    # ... (similar to AI tests)

func after() -> void:
    # Cleanup
    pass


func test_apply_status_effect_adds_to_unit() -> void:
    # Setup: Create unit
    var char_data: CharacterData = CharacterFactoryScript.create_character("Target")
    _target_unit = UnitFactoryScript.spawn_unit(char_data, Vector2i(5, 5), "player", _units_container)

    # Create test effect (poison, 3 turns)
    _test_effect = StatusEffectData.new()
    _test_effect.effect_id = "test_poison"
    _test_effect.display_name = "Test Poison"
    _test_effect.duration_turns = 3
    _test_effect.stat_modifiers = { "hp_per_turn": -5 }

    # Apply effect
    _target_unit.stats.apply_status_effect(_test_effect)

    # Assert
    assert_bool(_target_unit.stats.has_status_effect("test_poison")).is_true()


func test_status_effect_expires_after_duration() -> void:
    # Setup with effect that lasts 2 turns
    # ...

    # Advance 2 turns
    _target_unit.stats.on_turn_start()
    _target_unit.stats.on_turn_start()

    # Effect should be expired
    assert_bool(_target_unit.stats.has_status_effect("test_buff")).is_false()


func test_status_effect_stat_modifiers_apply() -> void:
    # Apply defense buff
    var buff: StatusEffectData = StatusEffectData.new()
    buff.effect_id = "test_def_buff"
    buff.stat_modifiers = { "defense": 5 }
    buff.duration_turns = 3

    var base_defense: int = _target_unit.stats.defense
    _target_unit.stats.apply_status_effect(buff)

    # Defense should be increased
    assert_int(_target_unit.stats.get_effective_defense()).is_equal(base_defense + 5)


func test_removing_effect_restores_stats() -> void:
    # Apply then remove, verify stats restored
    pass


func test_stacking_same_effect_refreshes_duration() -> void:
    # Apply same effect twice, verify duration is refreshed not stacked
    pass
```

**Note**: This is a template. Implementation depends on actual StatusEffectManager API which varies based on how `core/components/unit_stats.gd` handles effects.

---

## Phase 3.4: test_party_manager.gd Factory Migration (Parallelizable)

### Task 3.4.1: Migrate _create_character to CharacterFactory

**File**: `tests/integration/party/test_party_manager.gd`

**Current code (lines 632-656)**:
```gdscript
func _create_character(p_name: String, is_hero: bool = false) -> CharacterData:
    var character: CharacterData = CharacterData.new()
    character.character_name = p_name
    character.base_hp = 50
    character.base_mp = 10
    character.base_strength = 10
    character.base_defense = 10
    character.base_agility = 10
    character.base_intelligence = 10
    character.base_luck = 5
    character.starting_level = 1
    character.is_hero = is_hero
    character.ensure_uid()

    var basic_class: ClassData = ClassData.new()
    basic_class.display_name = "Warrior"
    basic_class.movement_type = ClassData.MovementType.WALKING
    basic_class.movement_range = 4

    character.character_class = basic_class

    _created_characters.append(character)
    _created_classes.append(basic_class)

    return character
```

**Issue**: Different signature from CharacterFactory (`name, is_hero` vs `name, options`).

**Solution**: Wrapper function that uses CharacterFactory internally:

```gdscript
const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")

## Create a character for party manager tests
## Wraps CharacterFactory with party-specific defaults (ensure_uid, tracking)
func _create_character(p_name: String, is_hero: bool = false) -> CharacterData:
    var character: CharacterData = CharacterFactoryScript.create_character(p_name, {
        "is_hero": is_hero,
        "hp": 50,
        "mp": 10,
        "strength": 10,
        "defense": 10,
        "agility": 10
    })
    character.ensure_uid()  # Party manager needs UIDs
    _created_characters.append(character)
    # Note: CharacterFactory creates class internally, no need to track separately
    return character
```

**Also update CharacterFactory** (Task 3.4.2):

Add `ensure_uid()` call option to CharacterFactory for tests that need it:

```gdscript
# In tests/fixtures/character_factory.gd, update create_character:
static func create_character(
    p_name: String,
    options: Dictionary = {}
) -> CharacterData:
    var character: CharacterData = CharacterData.new()
    # ... existing code ...

    # Optionally ensure UID is set (needed for PartyManager tests)
    if options.get("ensure_uid", false):
        character.ensure_uid()

    return character
```

**Migration steps**:
1. Add `ensure_uid` option to CharacterFactory
2. Update test_party_manager.gd to use wrapper or direct factory call
3. Remove old `_create_character` implementation
4. Remove `_created_classes` array (no longer needed)

---

## Execution Order

```
Phase 3.1 (Sequential - Core Infrastructure)
    |
    +-- Task 3.1.1: Add turn_completed signal to AIController
    |
    v
Phase 3.1.2 + 3.2 + 3.3.2 + 3.4 (Parallelizable after 3.1.1)
    |
    +-- Task 3.1.2: Update AI tests to use signal waits (10 files)
    +-- Task 3.2.1: Create SignalTracker fixture
    +-- Task 3.3.2: Create StatusEffectManager integration tests
    +-- Task 3.4.1: Migrate test_party_manager.gd to CharacterFactory
```

---

## Verification Checklist

### After Phase 3.1.1 (AIController Signal)

```bash
# Verify AIController still works correctly
GODOT_BIN=~/Downloads/Godot_v4.5.1-stable_linux.x86_64/Godot_v4.5.1-stable_linux.x86_64
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/ai"
```

### After Phase 3.1.2 (AI Test Updates)

```bash
# Run AI tests - should be faster (no arbitrary waits) and more reliable
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/ai"

# Verify no await_millis remains in AI tests
grep -r "await_millis" tests/integration/ai/ && echo "FAIL: await_millis still present" || echo "PASS: No await_millis"
```

### After Phase 3.2 (SignalTracker)

```bash
# Create a simple test to verify SignalTracker works
# (Could add a dedicated test_signal_tracker.gd)
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/unit"
```

### After Phase 3.3.2 (StatusEffect Tests)

```bash
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/status_effects"
```

### After Phase 3.4 (Party Manager Migration)

```bash
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/party/test_party_manager.gd"
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
| AIController signal | Low - additive change | Signal emits before turn end, won't break existing flow |
| AI test signal waits | Medium - async timing | Use generous timeout (2000ms), test individually first |
| SignalTracker | Low - new utility | Doesn't replace existing patterns, additive |
| InputManager tests | **DEFERRED** | Too complex for this phase |
| StatusEffect tests | Medium - API assumptions | Template provided, adjust to actual API |
| Party manager migration | Low - signature wrapper | Wrapper preserves existing behavior |

---

## Success Metrics

After completing Phase 3:

1. **Reliable AI tests**: No `await_millis()` in AI test files - all use `turn_completed` signal
2. **SignalTracker available**: New tests can use `SignalTracker` for cleaner signal assertions
3. **StatusEffect coverage**: Basic integration tests for status effect lifecycle
4. **Reduced duplication**: test_party_manager.gd uses CharacterFactory

---

## Deferred Items

### InputManager Testing (Task 3.3.1)

**Reason**: High complexity, low ROI for this phase.

The InputManager is a 2284-line state machine with heavy dependencies on:
- GridManager (grid state, cell queries)
- BattleManager (combat execution)
- AudioManager (sound effects)
- Camera, menus, cursor, panels

To test properly would require either:
- Full scene integration (expensive, brittle)
- Extensive mocking (complex to maintain)

**Recommendation**: Defer until a specific InputManager bug surfaces that justifies the investment. Current battle flow integration tests exercise most input paths indirectly.

---

## Dependencies

Phase 3 requires:
- Phase 2 fixtures exist:
  - `tests/fixtures/character_factory.gd` (exists)
  - `tests/fixtures/unit_factory.gd` (exists)
- AIController is not undergoing parallel modifications
- GdUnit4 `await_signal_on()` function available (standard GdUnit4 feature)
