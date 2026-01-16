# Test Suite Cleanup - Phase 5 Implementation Plan

## Overview

Phase 5 focuses on three categories of improvements identified in the Phase 4 review:
- New fixtures to reduce duplication in AI and combat tests
- Consistency fixes for test isolation (constants, signal tracking)
- Coverage gaps for high-value, easily testable systems

**Reference**: `docs/testing-reference.md` for classification criteria.

**Prerequisite**: Phase 4 from `docs/plans/test-suite-cleanup-phase4.md` should be complete.

---

## Task Summary

| Priority | Task | Agent | Files Affected | Dependencies |
|----------|------|-------|----------------|--------------|
| High | 5.1 Create AIBehaviorFactory fixture | Agent A | New fixture + 10 AI tests | None |
| High | 5.2 Create UnitStatsFactory fixture | Agent B | New fixture | None |
| High | 5.3 Replace `_base_game` literals with constants | Agent C | 7 unit tests | None |
| High | 5.4 Migrate party/battle tests to SignalTracker | Agent D | 2 integration tests | None |
| Medium | 5.5 Document autoload dependencies in fixtures | Agent A | 4 fixture files | After 5.1 |
| Medium | 5.6 Add GridManager integration tests | Agent B | New test file | After 5.2 |
| Medium | 5.7 Add GameState unit tests | Agent C | New test file | After 5.3 |

---

## Agent Work Assignments

### Agent A: AI Behavior Infrastructure

Tasks: 5.1, 5.5

**Focus**: Create AIBehaviorFactory and document fixture dependencies.

### Agent B: Combat Stats Infrastructure

Tasks: 5.2, 5.6

**Focus**: Create UnitStatsFactory and add GridManager tests.

### Agent C: Constants and GameState Coverage

Tasks: 5.3, 5.7

**Focus**: Replace hardcoded mod IDs and add GameState tests.

### Agent D: Signal Tracking Migration

Task: 5.4

**Focus**: Migrate remaining manual signal tracking to SignalTracker fixture.

---

## Phase 5.1: Create AIBehaviorFactory Fixture (High Priority)

### Problem Analysis

All 10 AI tests create AIBehaviorData resources with duplicated setup patterns:

```gdscript
# Duplicated in each AI test file
func _create_opportunistic_behavior() -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = "test_opportunistic"
    behavior.display_name = "Test Opportunistic"
    behavior.role = "aggressive"
    behavior.behavior_mode = "opportunistic"
    behavior.retreat_enabled = false
    behavior.use_healing_items = false
    behavior.use_attack_items = false
    behavior.threat_weights = {
        "wounded_target": 2.0,
        "proximity": 0.3
    }
    return behavior
```

Each test creates slight variations with 10-15 lines of setup code.

### Task 5.1.1: Create AIBehaviorFactory Fixture

**File**: `tests/fixtures/ai_behavior_factory.gd`

```gdscript
## Shared test fixture for creating AIBehaviorData resources
##
## Provides preset behaviors for common AI test scenarios:
## - Aggressive (attacks nearest)
## - Opportunistic (prioritizes wounded)
## - Defensive (protects allies)
## - Support (healer prioritization)
## - Stationary (guard behavior)
## - Cautious (retreat when threatened)
## - Tactical (debuff focused)
##
## Dependencies: None (pure resource creation)
##
## Usage:
##   var behavior: AIBehaviorData = AIBehaviorFactory.create_aggressive("test_attacker")
##   var custom: AIBehaviorData = AIBehaviorFactory.create_custom({
##       "behavior_id": "my_test",
##       "behavior_mode": "opportunistic",
##       "threat_weights": {"wounded_target": 2.0}
##   })
class_name AIBehaviorFactory
extends RefCounted


## Create an aggressive behavior (attacks nearest enemy)
static func create_aggressive(behavior_id: String = "test_aggressive") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test Aggressive"
    behavior.role = "aggressive"
    behavior.behavior_mode = "aggressive"
    behavior.retreat_enabled = false
    behavior.use_healing_items = false
    behavior.use_attack_items = false
    return behavior


## Create an opportunistic behavior (prioritizes wounded targets)
static func create_opportunistic(behavior_id: String = "test_opportunistic") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test Opportunistic"
    behavior.role = "aggressive"
    behavior.behavior_mode = "opportunistic"
    behavior.retreat_enabled = false
    behavior.use_healing_items = false
    behavior.use_attack_items = false
    behavior.threat_weights = {
        "wounded_target": 2.0,
        "proximity": 0.3
    }
    return behavior


## Create a defensive behavior (tank, draws aggro)
static func create_defensive(behavior_id: String = "test_defensive") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test Defensive"
    behavior.role = "defensive"
    behavior.behavior_mode = "defensive"
    behavior.retreat_enabled = false
    behavior.use_healing_items = true
    behavior.use_attack_items = false
    behavior.threat_weights = {
        "proximity": 1.0,
        "threat_to_allies": 2.0
    }
    return behavior


## Create a support behavior (healer prioritization)
static func create_support(behavior_id: String = "test_support") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test Support"
    behavior.role = "support"
    behavior.behavior_mode = "support"
    behavior.retreat_enabled = true
    behavior.use_healing_items = true
    behavior.use_attack_items = false
    behavior.heal_threshold = 0.5  # Heal allies below 50% HP
    behavior.threat_weights = {
        "ally_hp_critical": 3.0
    }
    return behavior


## Create a stationary guard behavior (doesn't move unless attacked)
static func create_stationary(behavior_id: String = "test_stationary") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test Stationary Guard"
    behavior.role = "defensive"
    behavior.behavior_mode = "stationary"
    behavior.retreat_enabled = false
    behavior.use_healing_items = false
    behavior.use_attack_items = false
    behavior.guard_position = true
    return behavior


## Create a cautious behavior (retreats when HP low)
static func create_cautious(behavior_id: String = "test_cautious") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test Cautious"
    behavior.role = "aggressive"
    behavior.behavior_mode = "cautious"
    behavior.retreat_enabled = true
    behavior.retreat_threshold = 0.3  # Retreat below 30% HP
    behavior.use_healing_items = true
    behavior.use_attack_items = false
    return behavior


## Create a retreat behavior (always retreats)
static func create_retreat(behavior_id: String = "test_retreat") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test Retreater"
    behavior.role = "cautious"
    behavior.behavior_mode = "retreat"
    behavior.retreat_enabled = true
    behavior.retreat_threshold = 1.0  # Always retreat
    behavior.use_healing_items = false
    behavior.use_attack_items = false
    return behavior


## Create a tactical/debuff behavior (prioritizes debuffs)
static func create_tactical(behavior_id: String = "test_tactical") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test Tactical"
    behavior.role = "aggressive"
    behavior.behavior_mode = "tactical"
    behavior.retreat_enabled = false
    behavior.use_healing_items = false
    behavior.use_attack_items = true
    behavior.prefer_debuffs = true
    behavior.threat_weights = {
        "high_threat": 2.0
    }
    return behavior


## Create an AoE mage behavior (prioritizes clustered targets)
static func create_aoe_mage(behavior_id: String = "test_aoe_mage") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test AoE Mage"
    behavior.role = "aggressive"
    behavior.behavior_mode = "aoe_focused"
    behavior.retreat_enabled = false
    behavior.use_healing_items = false
    behavior.use_attack_items = false
    behavior.prefer_aoe = true
    behavior.threat_weights = {
        "cluster_size": 3.0,
        "proximity": 0.2
    }
    return behavior


## Create a terrain-seeker behavior (seeks advantageous terrain)
static func create_terrain_seeker(behavior_id: String = "test_terrain_seeker") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test Terrain Seeker"
    behavior.role = "aggressive"
    behavior.behavior_mode = "aggressive"
    behavior.seek_terrain_advantage = true
    behavior.retreat_enabled = false
    behavior.use_healing_items = false
    behavior.use_attack_items = false
    return behavior


## Create an archer/ranged behavior (maintains distance)
static func create_ranged(behavior_id: String = "test_ranged") -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = behavior_id
    behavior.display_name = "Test Ranged"
    behavior.role = "aggressive"
    behavior.behavior_mode = "opportunistic"
    behavior.retreat_enabled = false
    behavior.use_healing_items = false
    behavior.use_attack_items = false
    behavior.preferred_range = 3
    behavior.maintain_distance = true
    behavior.threat_weights = {
        "wounded_target": 1.5,
        "proximity": 0.5
    }
    return behavior


## Create a custom behavior with specified options
## Options can include any AIBehaviorData property
static func create_custom(options: Dictionary) -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()

    # Required fields with defaults
    behavior.behavior_id = options.get("behavior_id", "test_custom")
    behavior.display_name = options.get("display_name", "Test Custom")
    behavior.role = options.get("role", "aggressive")
    behavior.behavior_mode = options.get("behavior_mode", "aggressive")

    # Optional fields
    if "retreat_enabled" in options:
        behavior.retreat_enabled = options.retreat_enabled
    if "retreat_threshold" in options:
        behavior.retreat_threshold = options.retreat_threshold
    if "use_healing_items" in options:
        behavior.use_healing_items = options.use_healing_items
    if "use_attack_items" in options:
        behavior.use_attack_items = options.use_attack_items
    if "heal_threshold" in options:
        behavior.heal_threshold = options.heal_threshold
    if "guard_position" in options:
        behavior.guard_position = options.guard_position
    if "prefer_debuffs" in options:
        behavior.prefer_debuffs = options.prefer_debuffs
    if "prefer_aoe" in options:
        behavior.prefer_aoe = options.prefer_aoe
    if "seek_terrain_advantage" in options:
        behavior.seek_terrain_advantage = options.seek_terrain_advantage
    if "preferred_range" in options:
        behavior.preferred_range = options.preferred_range
    if "maintain_distance" in options:
        behavior.maintain_distance = options.maintain_distance
    if "threat_weights" in options:
        behavior.threat_weights = options.threat_weights

    return behavior
```

### Task 5.1.2: Update AI Tests to Use Factory

**Files to update** (10 total):
- `tests/integration/ai/test_aoe_targeting.gd`
- `tests/integration/ai/test_cautious_engagement.gd`
- `tests/integration/ai/test_defensive_positioning.gd`
- `tests/integration/ai/test_healer_prioritization.gd`
- `tests/integration/ai/test_opportunistic_targeting.gd`
- `tests/integration/ai/test_ranged_ai_positioning.gd`
- `tests/integration/ai/test_retreat_behavior.gd`
- `tests/integration/ai/test_stationary_guard.gd`
- `tests/integration/ai/test_terrain_advantage.gd`
- `tests/integration/ai/test_tactical_debuff.gd`

**Pattern transformation**:

**Before** (test_opportunistic_targeting.gd):
```gdscript
func _create_opportunistic_behavior() -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorData.new()
    behavior.behavior_id = "test_opportunistic"
    behavior.display_name = "Test Opportunistic"
    behavior.role = "aggressive"
    behavior.behavior_mode = "opportunistic"
    behavior.retreat_enabled = false
    behavior.use_healing_items = false
    behavior.use_attack_items = false
    behavior.threat_weights = {
        "wounded_target": 2.0,
        "proximity": 0.3
    }
    _created_behaviors.append(behavior)
    return behavior
```

**After**:
```gdscript
const AIBehaviorFactoryScript = preload("res://tests/fixtures/ai_behavior_factory.gd")

func _create_opportunistic_behavior() -> AIBehaviorData:
    var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_opportunistic()
    _created_behaviors.append(behavior)
    return behavior
```

**Removal checklist per file**:
- [ ] Add `const AIBehaviorFactoryScript = preload(...)`
- [ ] Replace behavior creation code with factory call
- [ ] Remove duplicate behavior setup logic
- [ ] Keep `_created_behaviors.append()` for cleanup tracking

**Estimated line savings**: ~12 lines per file = 120 lines across 10 files.

---

## Phase 5.2: Create UnitStatsFactory Fixture (High Priority)

### Problem Analysis

Combat and status effect tests frequently create units with specific stat configurations. The CharacterFactory handles character creation but tests often need fine-grained stat control for combat math verification.

### Task 5.2.1: Create UnitStatsFactory Fixture

**File**: `tests/fixtures/unit_stats_factory.gd`

```gdscript
## Shared test fixture for creating units with specific stat configurations
##
## Useful for combat, status effect, and equipment tests that need
## predictable stat values for calculation verification.
##
## Dependencies:
## - CharacterFactory (for base character creation)
## - UnitFactory (for unit spawning)
## - GridManager autoload (must be initialized for unit placement)
##
## Usage:
##   var tank: Unit = UnitStatsFactory.create_tank(container, Vector2i(5, 5))
##   var glass_cannon: Unit = UnitStatsFactory.create_glass_cannon(container, Vector2i(6, 5))
class_name UnitStatsFactory
extends RefCounted


const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")


## Create a balanced unit (moderate stats across the board)
static func create_balanced(
    parent: Node,
    cell: Vector2i,
    faction: String = "player",
    name: String = "Balanced"
) -> Unit:
    var character: CharacterData = CharacterFactoryScript.create_character(name, {
        "hp": 50,
        "mp": 20,
        "strength": 15,
        "defense": 15,
        "agility": 15,
        "intelligence": 15,
        "luck": 10
    })
    return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a tank unit (high HP and defense, low speed)
static func create_tank(
    parent: Node,
    cell: Vector2i,
    faction: String = "player",
    name: String = "Tank"
) -> Unit:
    var character: CharacterData = CharacterFactoryScript.create_character(name, {
        "hp": 100,
        "mp": 10,
        "strength": 20,
        "defense": 30,
        "agility": 5,
        "intelligence": 10,
        "luck": 5
    })
    return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a glass cannon (high attack, low HP/defense)
static func create_glass_cannon(
    parent: Node,
    cell: Vector2i,
    faction: String = "player",
    name: String = "GlassCannon"
) -> Unit:
    var character: CharacterData = CharacterFactoryScript.create_character(name, {
        "hp": 25,
        "mp": 30,
        "strength": 35,
        "defense": 5,
        "agility": 20,
        "intelligence": 20,
        "luck": 10
    })
    return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a speedster (high agility, moderate other stats)
static func create_speedster(
    parent: Node,
    cell: Vector2i,
    faction: String = "player",
    name: String = "Speedster"
) -> Unit:
    var character: CharacterData = CharacterFactoryScript.create_character(name, {
        "hp": 40,
        "mp": 15,
        "strength": 15,
        "defense": 10,
        "agility": 30,
        "intelligence": 15,
        "luck": 15
    })
    return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a mage (high intelligence/MP, low physical stats)
static func create_mage(
    parent: Node,
    cell: Vector2i,
    faction: String = "player",
    name: String = "Mage"
) -> Unit:
    var character: CharacterData = CharacterFactoryScript.create_character(name, {
        "hp": 30,
        "mp": 50,
        "strength": 8,
        "defense": 8,
        "agility": 12,
        "intelligence": 30,
        "luck": 12
    })
    return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a healer (moderate stats, high MP)
static func create_healer(
    parent: Node,
    cell: Vector2i,
    faction: String = "player",
    name: String = "Healer"
) -> Unit:
    var character: CharacterData = CharacterFactoryScript.create_character(name, {
        "hp": 35,
        "mp": 40,
        "strength": 10,
        "defense": 12,
        "agility": 15,
        "intelligence": 25,
        "luck": 8
    })
    return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a wounded unit (starts at low HP percentage)
static func create_wounded(
    parent: Node,
    cell: Vector2i,
    faction: String = "player",
    name: String = "Wounded",
    hp_percent: float = 0.25
) -> Unit:
    var unit: Unit = create_balanced(parent, cell, faction, name)
    var max_hp: int = unit.character_data.base_hp
    unit.current_hp = int(max_hp * hp_percent)
    return unit


## Create a unit with specific stats (full control)
static func create_with_stats(
    parent: Node,
    cell: Vector2i,
    stats: Dictionary,
    faction: String = "player",
    name: String = "Custom"
) -> Unit:
    var character: CharacterData = CharacterFactoryScript.create_character(name, stats)
    return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a pair of combatants for damage calculation tests
## Returns {"attacker": Unit, "defender": Unit}
static func create_combat_pair(
    parent: Node,
    attacker_stats: Dictionary,
    defender_stats: Dictionary,
    attacker_cell: Vector2i = Vector2i(5, 5),
    defender_cell: Vector2i = Vector2i(6, 5)
) -> Dictionary:
    var attacker: Unit = create_with_stats(
        parent, attacker_cell, attacker_stats, "enemy", "Attacker"
    )
    var defender: Unit = create_with_stats(
        parent, defender_cell, defender_stats, "player", "Defender"
    )
    return {"attacker": attacker, "defender": defender}
```

---

## Phase 5.3: Replace `_base_game` Literals with Constants (High Priority)

### Problem Analysis

7 unit tests use hardcoded `"_base_game"` string literals instead of test-specific mod IDs:

| File | Occurrences |
|------|-------------|
| `tests/unit/editor/test_resource_picker.gd` | Multiple |
| `tests/unit/registries/test_ai_brain_registry.gd` | Multiple |
| `tests/unit/registries/test_tileset_registry.gd` | Multiple |
| `tests/unit/editor/test_editor_event_bus.gd` | Multiple |
| `tests/unit/editor/test_sparkling_editor_utils.gd` | Multiple |
| `tests/unit/promotion/test_promotion_manager.gd` | Multiple |
| `tests/unit/equipment/test_character_save_equipment.gd` | Multiple |

Using `_base_game` makes tests dependent on game content and harder to isolate.

### Task 5.3.1: Add TEST_MOD_ID Constants

**Pattern transformation**:

**Before**:
```gdscript
func test_register_resources() -> void:
    _registry.register_from_config("_base_game", config)
    var resource: Resource = ModLoader.registry.get_resource("tileset", "_base_game:forest")
```

**After**:
```gdscript
const TEST_MOD_ID: String = "_test_tileset_registry"

func test_register_resources() -> void:
    _registry.register_from_config(TEST_MOD_ID, config)
    var resource: Resource = ModLoader.registry.get_resource("tileset", TEST_MOD_ID + ":forest")

func after() -> void:
    # Clean up test mod resources
    if ModLoader and ModLoader.registry:
        ModLoader.registry.clear_mod_resources(TEST_MOD_ID)
```

**Implementation checklist per file**:
- [ ] Add `const TEST_MOD_ID: String = "_test_<test_name>"`
- [ ] Replace all `"_base_game"` with `TEST_MOD_ID`
- [ ] Update resource ID references (e.g., `"_base_game:item"` -> `TEST_MOD_ID + ":item"`)
- [ ] Add cleanup in `after()` to clear test mod resources

**Files to update**:
1. `tests/unit/editor/test_resource_picker.gd` - Use `"_test_resource_picker"`
2. `tests/unit/registries/test_ai_brain_registry.gd` - Use `"_test_ai_brain_registry"`
3. `tests/unit/registries/test_tileset_registry.gd` - Use `"_test_tileset_registry"`
4. `tests/unit/editor/test_editor_event_bus.gd` - Use `"_test_editor_event_bus"`
5. `tests/unit/editor/test_sparkling_editor_utils.gd` - Use `"_test_editor_utils"`
6. `tests/unit/promotion/test_promotion_manager.gd` - Use `"_test_promotion_manager"`
7. `tests/unit/equipment/test_character_save_equipment.gd` - Use `"_test_equipment_save"`

---

## Phase 5.4: Migrate Party/Battle Tests to SignalTracker (High Priority)

### Problem Analysis

`tests/integration/party/test_party_manager.gd` uses manual signal tracking:

```gdscript
# Manual signal connection (lines 45-50)
PartyManager.member_added.connect(_on_member_added)
PartyManager.member_departed.connect(_on_member_departed)
PartyManager.member_rejoined.connect(_on_member_rejoined)
PartyManager.item_transferred.connect(_on_item_transferred)
PartyManager.member_inventory_changed.connect(_on_inventory_changed)

# Manual disconnection (lines 54-64)
if PartyManager.member_added.is_connected(_on_member_added):
    PartyManager.member_added.disconnect(_on_member_added)
# ... repeated for each signal
```

This pattern is verbose and error-prone. SignalTracker provides automatic cleanup.

### Task 5.4.1: Migrate test_party_manager.gd

**File**: `tests/integration/party/test_party_manager.gd`

**Pattern transformation**:

**Before** (lines 17-22, 45-64):
```gdscript
# Signal tracking
var _member_added_events: Array[CharacterData] = []
var _member_departed_events: Array[Dictionary] = []
var _member_rejoined_events: Array[String] = []
var _item_transferred_events: Array[Dictionary] = []
var _inventory_changed_events: Array[String] = []

func before() -> void:
    # ... setup ...
    PartyManager.member_added.connect(_on_member_added)
    PartyManager.member_departed.connect(_on_member_departed)
    # ... etc ...

func after() -> void:
    if PartyManager.member_added.is_connected(_on_member_added):
        PartyManager.member_added.disconnect(_on_member_added)
    # ... repeated for each ...
```

**After**:
```gdscript
const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

var _tracker: SignalTracker

func before() -> void:
    # ... existing setup ...
    _tracker = SignalTrackerScript.new()

    # Track signals with custom callbacks for argument inspection
    _tracker.track_with_callback(PartyManager.member_added, _on_member_added)
    _tracker.track_with_callback(PartyManager.member_departed, _on_member_departed)
    _tracker.track_with_callback(PartyManager.member_rejoined, _on_member_rejoined)
    _tracker.track_with_callback(PartyManager.item_transferred, _on_item_transferred)
    _tracker.track_with_callback(PartyManager.member_inventory_changed, _on_inventory_changed)

func after() -> void:
    # Automatic disconnection for all tracked signals
    if _tracker:
        _tracker.disconnect_all()
        _tracker = null
    # ... rest of cleanup ...
```

**Benefits**:
- Automatic disconnection via `disconnect_all()`
- No manual `is_connected()` checks needed
- Consistent pattern with other tests
- Callback functions preserved for argument inspection

**Note**: This test uses callbacks to collect signal arguments into arrays. The `track_with_callback()` method preserves this behavior while adding automatic cleanup.

### Task 5.4.2: Review Battle Integration Tests

Check `tests/integration/battle/` for similar patterns:

```bash
grep -r "_signal_received\|_connected_signals" tests/integration/battle/
```

Apply same migration pattern to any files using manual signal tracking.

---

## Phase 5.5: Document Autoload Dependencies in Fixtures (Medium Priority)

### Problem Analysis

Test fixtures interact with autoloads but don't document these dependencies. This leads to confusion when tests fail due to uninitialized singletons.

### Task 5.5.1: Add Dependency Documentation

**Files to update**:

1. **`tests/fixtures/grid_setup.gd`**
```gdscript
## Shared test fixture for grid/tilemap setup
##
## Dependencies (autoloads that must be initialized):
## - GridManager: Called via GridManager.setup_grid()
##
## Usage:
##   var grid_setup: GridSetup = GridSetup.new()
##   grid_setup.create_grid(parent_node)
##   # ... run test ...
##   grid_setup.cleanup()
```

2. **`tests/fixtures/unit_factory.gd`**
```gdscript
## Shared test fixture for spawning Unit nodes
##
## Dependencies (autoloads that must be initialized):
## - GridManager: Called via GridManager.set_cell_occupied()
##
## Note: Grid must be set up via GridSetup before spawning units
```

3. **`tests/fixtures/character_factory.gd`**
```gdscript
## Shared test fixture for creating CharacterData resources
##
## Dependencies: None (pure resource creation)
##
## Note: Characters are RefCounted resources that don't need
## explicit cleanup. They're garbage collected when unreferenced.
```

4. **`tests/fixtures/signal_tracker.gd`**
```gdscript
## Reusable utility for tracking signal emissions in tests
##
## Dependencies: None (pure RefCounted utility)
##
## IMPORTANT: Call disconnect_all() in after_test() to prevent
## signal connections persisting between tests.
```

---

## Phase 5.6: Add GridManager Integration Tests (Medium Priority)

### Problem Analysis

GridManager is a critical autoload used by all battle/AI tests but has no dedicated test coverage. Current testing is indirect through AI and battle tests.

**File**: `core/systems/grid_manager.gd`

**Key methods to test**:
- `setup_grid()` - Grid initialization
- `get_tile_size()` - Tile size queries
- `set_cell_occupied()` / `is_cell_occupied()` - Occupancy tracking
- `get_path()` - A* pathfinding
- `get_reachable_cells()` - Movement range calculation
- `get_cells_in_range()` - Attack range calculation
- `world_to_grid()` / `grid_to_world()` - Coordinate conversion

### Task 5.6.1: Create GridManager Test File

**File**: `tests/integration/grid/test_grid_manager.gd`

```gdscript
## GridManager Integration Tests
##
## Tests the GridManager autoload functionality:
## - Grid setup and initialization
## - Occupancy tracking
## - A* pathfinding
## - Movement range calculation
## - Coordinate conversion
class_name TestGridManager
extends GdUnitTestSuite


const GridSetupScript = preload("res://tests/fixtures/grid_setup.gd")
const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")

var _grid_setup: GridSetup
var _container: Node2D


func before() -> void:
    _container = Node2D.new()
    add_child(_container)

    _grid_setup = GridSetupScript.new()
    _grid_setup.create_grid(_container, Vector2i(10, 10), 32)


func after() -> void:
    # Clean up any units
    for child: Node in _container.get_children():
        if child is Unit:
            UnitFactoryScript.cleanup_unit(child)

    _grid_setup.cleanup()
    _grid_setup = null

    if _container and is_instance_valid(_container):
        _container.queue_free()
    _container = null


# =============================================================================
# SETUP TESTS
# =============================================================================

func test_setup_grid_initializes_grid_reference() -> void:
    assert_object(GridManager.grid).is_not_null()


func test_setup_grid_initializes_tilemap_reference() -> void:
    assert_object(GridManager.tilemap).is_not_null()


func test_get_tile_size_returns_cell_size() -> void:
    var tile_size: int = GridManager.get_tile_size()

    assert_int(tile_size).is_equal(32)


# =============================================================================
# OCCUPANCY TESTS
# =============================================================================

func test_set_cell_occupied_marks_cell() -> void:
    var character: CharacterData = CharacterFactoryScript.create_character("Test")
    var unit: Unit = UnitFactoryScript.spawn_unit(character, Vector2i(5, 5), "player", _container)

    var is_occupied: bool = GridManager.is_cell_occupied(Vector2i(5, 5))

    assert_bool(is_occupied).is_true()


func test_is_cell_occupied_returns_false_for_empty_cell() -> void:
    var is_occupied: bool = GridManager.is_cell_occupied(Vector2i(0, 0))

    assert_bool(is_occupied).is_false()


func test_get_unit_at_returns_occupying_unit() -> void:
    var character: CharacterData = CharacterFactoryScript.create_character("Test")
    var unit: Unit = UnitFactoryScript.spawn_unit(character, Vector2i(3, 3), "player", _container)

    var found_unit: Unit = GridManager.get_unit_at(Vector2i(3, 3))

    assert_object(found_unit).is_same(unit)


func test_get_unit_at_returns_null_for_empty_cell() -> void:
    var found_unit: Unit = GridManager.get_unit_at(Vector2i(9, 9))

    assert_object(found_unit).is_null()


# =============================================================================
# PATHFINDING TESTS
# =============================================================================

func test_get_path_returns_valid_path() -> void:
    var path: Array[Vector2i] = GridManager.get_path(Vector2i(0, 0), Vector2i(3, 0))

    assert_array(path).is_not_empty()
    assert_object(path[0]).is_equal(Vector2i(0, 0))
    assert_object(path[-1]).is_equal(Vector2i(3, 0))


func test_get_path_avoids_occupied_cells() -> void:
    # Place a blocker unit
    var character: CharacterData = CharacterFactoryScript.create_character("Blocker")
    var _blocker: Unit = UnitFactoryScript.spawn_unit(character, Vector2i(2, 0), "enemy", _container)

    # Path should go around
    var path: Array[Vector2i] = GridManager.get_path(Vector2i(0, 0), Vector2i(4, 0))

    # Should not contain the blocked cell
    assert_bool(Vector2i(2, 0) in path).is_false()


func test_get_path_returns_empty_for_unreachable_destination() -> void:
    # Completely surround a cell
    var positions: Array[Vector2i] = [
        Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4),
        Vector2i(4, 5),                 Vector2i(6, 5),
        Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6)
    ]
    for pos: Vector2i in positions:
        var char: CharacterData = CharacterFactoryScript.create_character("Wall")
        var _wall: Unit = UnitFactoryScript.spawn_unit(char, pos, "enemy", _container)

    var path: Array[Vector2i] = GridManager.get_path(Vector2i(0, 0), Vector2i(5, 5))

    assert_array(path).is_empty()


# =============================================================================
# MOVEMENT RANGE TESTS
# =============================================================================

func test_get_reachable_cells_returns_cells_within_range() -> void:
    var cells: Array[Vector2i] = GridManager.get_reachable_cells(Vector2i(5, 5), 2)

    # Should include origin
    assert_bool(Vector2i(5, 5) in cells).is_true()
    # Should include adjacent
    assert_bool(Vector2i(5, 4) in cells).is_true()
    assert_bool(Vector2i(5, 6) in cells).is_true()
    # Should NOT include diagonal (manhattan distance)
    assert_bool(Vector2i(6, 6) in cells).is_false()


func test_get_reachable_cells_excludes_occupied_cells() -> void:
    var character: CharacterData = CharacterFactoryScript.create_character("Blocker")
    var _blocker: Unit = UnitFactoryScript.spawn_unit(character, Vector2i(5, 4), "enemy", _container)

    var cells: Array[Vector2i] = GridManager.get_reachable_cells(Vector2i(5, 5), 2)

    assert_bool(Vector2i(5, 4) in cells).is_false()


# =============================================================================
# COORDINATE CONVERSION TESTS
# =============================================================================

func test_world_to_grid_converts_coordinates() -> void:
    var grid_pos: Vector2i = GridManager.world_to_grid(Vector2(80, 64))

    # 80 / 32 = 2.5 -> 2, 64 / 32 = 2
    assert_int(grid_pos.x).is_equal(2)
    assert_int(grid_pos.y).is_equal(2)


func test_grid_to_world_converts_coordinates() -> void:
    var world_pos: Vector2 = GridManager.grid_to_world(Vector2i(3, 4))

    # 3 * 32 + 16 (center) = 112, 4 * 32 + 16 = 144
    assert_float(world_pos.x).is_equal(112.0)
    assert_float(world_pos.y).is_equal(144.0)
```

---

## Phase 5.7: Add GameState Unit Tests (Medium Priority)

### Problem Analysis

GameState is a critical singleton managing story flags, trigger completion, and campaign state. It has no dedicated tests despite being used throughout the game.

**File**: `core/systems/game_state.gd`

**Key methods to test**:
- `set_flag()` / `get_flag()` / `has_flag()` - Story flags
- `mark_trigger_completed()` / `is_trigger_completed()` - One-shot triggers
- `update_campaign_data()` / `get_campaign_data()` - Campaign progress
- Signal emissions: `flag_changed`, `trigger_completed`, `campaign_data_changed`

### Task 5.7.1: Create GameState Test File

**File**: `tests/unit/state/test_game_state.gd`

```gdscript
## GameState Unit Tests
##
## Tests the GameState autoload functionality:
## - Story flag management
## - Trigger completion tracking
## - Campaign data management
## - Signal emissions
class_name TestGameState
extends GdUnitTestSuite


const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

var _tracker: SignalTracker

# Store original state for restoration
var _original_story_flags: Dictionary
var _original_completed_triggers: Dictionary
var _original_campaign_data: Dictionary


func before() -> void:
    _tracker = SignalTrackerScript.new()

    # Store original state
    _original_story_flags = GameState.story_flags.duplicate(true)
    _original_completed_triggers = GameState.completed_triggers.duplicate(true)
    _original_campaign_data = GameState.campaign_data.duplicate(true)


func after() -> void:
    # Restore original state
    GameState.story_flags = _original_story_flags
    GameState.completed_triggers = _original_completed_triggers
    GameState.campaign_data = _original_campaign_data

    if _tracker:
        _tracker.disconnect_all()
        _tracker = null


func before_test() -> void:
    # Clear state for each test
    GameState.story_flags.clear()
    GameState.completed_triggers.clear()
    GameState.campaign_data = {
        "current_chapter": 0,
        "battles_won": 0,
        "treasures_found": 0,
    }


# =============================================================================
# STORY FLAG TESTS
# =============================================================================

func test_set_flag_stores_value() -> void:
    GameState.set_flag("test_flag", true)

    assert_bool(GameState.story_flags.get("test_flag", false)).is_true()


func test_get_flag_returns_stored_value() -> void:
    GameState.story_flags["existing_flag"] = true

    var value: bool = GameState.get_flag("existing_flag")

    assert_bool(value).is_true()


func test_get_flag_returns_false_for_missing_flag() -> void:
    var value: bool = GameState.get_flag("nonexistent_flag")

    assert_bool(value).is_false()


func test_has_flag_returns_true_for_existing_flag() -> void:
    GameState.story_flags["check_flag"] = true

    var exists: bool = GameState.has_flag("check_flag")

    assert_bool(exists).is_true()


func test_has_flag_returns_false_for_missing_flag() -> void:
    var exists: bool = GameState.has_flag("missing_flag")

    assert_bool(exists).is_false()


func test_set_flag_emits_flag_changed_signal() -> void:
    _tracker.track(GameState.flag_changed)

    GameState.set_flag("signal_test", true)

    assert_bool(_tracker.was_emitted("flag_changed")).is_true()


func test_clear_flag_sets_value_to_false() -> void:
    GameState.story_flags["clear_test"] = true

    GameState.set_flag("clear_test", false)

    assert_bool(GameState.get_flag("clear_test")).is_false()


# =============================================================================
# TRIGGER COMPLETION TESTS
# =============================================================================

func test_mark_trigger_completed_stores_completion() -> void:
    GameState.mark_trigger_completed("test_trigger")

    assert_bool(GameState.completed_triggers.get("test_trigger", false)).is_true()


func test_is_trigger_completed_returns_true_for_completed() -> void:
    GameState.completed_triggers["completed_trigger"] = true

    var completed: bool = GameState.is_trigger_completed("completed_trigger")

    assert_bool(completed).is_true()


func test_is_trigger_completed_returns_false_for_incomplete() -> void:
    var completed: bool = GameState.is_trigger_completed("incomplete_trigger")

    assert_bool(completed).is_false()


func test_mark_trigger_completed_emits_signal() -> void:
    _tracker.track(GameState.trigger_completed)

    GameState.mark_trigger_completed("signal_trigger")

    assert_bool(_tracker.was_emitted("trigger_completed")).is_true()


# =============================================================================
# CAMPAIGN DATA TESTS
# =============================================================================

func test_update_campaign_data_stores_value() -> void:
    GameState.update_campaign_data("battles_won", 5)

    assert_int(GameState.campaign_data.get("battles_won", 0)).is_equal(5)


func test_get_campaign_data_returns_stored_value() -> void:
    GameState.campaign_data["treasures_found"] = 10

    var value: Variant = GameState.get_campaign_data("treasures_found")

    assert_int(value).is_equal(10)


func test_get_campaign_data_returns_default_for_missing_key() -> void:
    var value: Variant = GameState.get_campaign_data("missing_key", 42)

    assert_int(value).is_equal(42)


func test_update_campaign_data_emits_signal() -> void:
    _tracker.track(GameState.campaign_data_changed)

    GameState.update_campaign_data("current_chapter", 2)

    assert_bool(_tracker.was_emitted("campaign_data_changed")).is_true()


# =============================================================================
# EDGE CASES
# =============================================================================

func test_set_flag_with_empty_string_key() -> void:
    # Empty string keys should still work (no crash)
    GameState.set_flag("", true)

    assert_bool(GameState.get_flag("")).is_true()


func test_flag_names_are_case_sensitive() -> void:
    GameState.set_flag("TestFlag", true)
    GameState.set_flag("testflag", false)

    assert_bool(GameState.get_flag("TestFlag")).is_true()
    assert_bool(GameState.get_flag("testflag")).is_false()
```

---

## Execution Order

```
Phase 5.1-5.4 (High Priority - Fully Parallelizable)
    |
    +-- Agent A: Task 5.1 (AIBehaviorFactory + AI test updates)
    +-- Agent B: Task 5.2 (UnitStatsFactory)
    +-- Agent C: Task 5.3 (Replace _base_game literals)
    +-- Agent D: Task 5.4 (SignalTracker migration)
    |
    v
Phase 5.5-5.7 (Medium Priority - Parallelizable after dependencies)
    |
    +-- Agent A: Task 5.5 (Document fixture dependencies) [after 5.1]
    +-- Agent B: Task 5.6 (GridManager tests) [after 5.2]
    +-- Agent C: Task 5.7 (GameState tests) [after 5.3]
```

---

## Verification Checklist

### After Phase 5.1 (AIBehaviorFactory)

```bash
GODOT_BIN=~/Downloads/Godot_v4.5.1-stable_linux.x86_64/Godot_v4.5.1-stable_linux.x86_64

# Verify fixture exists
test -f tests/fixtures/ai_behavior_factory.gd && echo "PASS" || echo "FAIL"

# Run AI tests
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/ai"

# Verify no duplicate behavior creation
grep -r "AIBehaviorData.new()" tests/integration/ai/ | wc -l
# Should be 0 (all replaced with factory calls)
```

### After Phase 5.2 (UnitStatsFactory)

```bash
# Verify fixture exists
test -f tests/fixtures/unit_stats_factory.gd && echo "PASS" || echo "FAIL"
```

### After Phase 5.3 (Constants Migration)

```bash
# Verify no _base_game literals in unit tests
grep -r '"_base_game"' tests/unit/ && echo "FAIL: Literals remain" || echo "PASS"

# Run unit tests
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/unit"
```

### After Phase 5.4 (SignalTracker Migration)

```bash
# Run party tests
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/party"
```

### After Phase 5.6 (GridManager Tests)

```bash
# Run new GridManager tests
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/integration/grid/test_grid_manager.gd"
```

### After Phase 5.7 (GameState Tests)

```bash
# Run new GameState tests
$GODOT_BIN --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  --add "res://tests/unit/state/test_game_state.gd"
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
| 5.1 AIBehaviorFactory | Low | Static factory methods; no shared state |
| 5.2 UnitStatsFactory | Low | Builds on existing CharacterFactory/UnitFactory |
| 5.3 Constants migration | Low | Search-and-replace with cleanup verification |
| 5.4 SignalTracker migration | Low | SignalTracker's `track_with_callback` preserves existing behavior |
| 5.5 Documentation | None | Documentation only; no code changes |
| 5.6 GridManager tests | Medium | May expose GridManager edge cases; tests are non-destructive |
| 5.7 GameState tests | Medium | May expose GameState edge cases; state restoration in cleanup |

---

## Success Metrics

After completing Phase 5:

1. **AIBehaviorFactory deployed**: All 10 AI tests use factory methods (~120 lines saved)
2. **UnitStatsFactory available**: New fixture for combat/status effect tests
3. **No _base_game literals**: All unit tests use TEST_MOD_ID constants
4. **Consistent signal tracking**: PartyManager tests use SignalTracker
5. **Documented fixtures**: All 4 fixtures have dependency documentation
6. **GridManager coverage**: New integration tests for grid/pathfinding functionality
7. **GameState coverage**: New unit tests for flag/trigger/campaign management

---

## Notes

### Why Skip BattleManager/ModLoader Tests

BattleManager and ModLoader were identified as coverage gaps but are explicitly deferred:

**BattleManager**:
- Complex async state machine with many dependencies
- Tests would need full battle scene setup
- Better covered indirectly through AI and battle flow tests

**ModLoader**:
- Initialization happens before tests run
- Testing registration would conflict with actual mods
- Core functionality is implicitly tested by all other tests

### Agent Independence

Tasks 5.1-5.4 are fully independent:
- Different file sets with no overlap
- No shared state modifications
- Can run simultaneously without conflicts

Tasks 5.5-5.7 depend on their respective Phase 5.1-5.3 tasks but are independent from each other.
