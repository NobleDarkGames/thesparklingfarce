# Test Suite Fix Plan

This plan addresses architectural issues identified in the test suite, organized by priority.

---

## Phase 1: Critical Fixes (Unit/Integration Boundary Violations)

These unit tests access autoload singletons, violating the "unit tests have no dependencies" rule from `docs/testing-reference.md`. They should be moved to `tests/integration/`.

### Files to Move

| Current Location | Target Location | Autoloads Used |
|------------------|-----------------|----------------|
| `tests/unit/interactables/test_interactable_data.gd` | `tests/integration/interactables/test_interactable_data.gd` | `GameState` |
| `tests/unit/battle/test_battle_rewards.gd` | `tests/integration/battle/test_battle_rewards.gd` | `BattleManager`, `SaveManager` |
| `tests/unit/battle/test_victory_defeat_conditions.gd` | `tests/integration/battle/test_victory_defeat_conditions.gd` | `BattleManager` |
| `tests/unit/triggers/test_trigger_key_items.gd` | `tests/integration/triggers/test_trigger_key_items.gd` | `PartyManager` |
| `tests/unit/storage/test_save_manager.gd` | `tests/integration/storage/test_save_manager.gd` | `SaveManager`, `GameState` |
| `tests/unit/mod_system/test_namespaced_flags.gd` | `tests/integration/mod_system/test_namespaced_flags.gd` | `GameState` |
| `tests/unit/mod_system/test_tileset_resolution.gd` | `tests/integration/mod_system/test_tileset_resolution.gd` | `ModLoader` |
| `tests/unit/cinematics/test_grant_items_executor.gd` | `tests/integration/cinematics/test_grant_items_executor.gd` | `SaveManager` |

### Migration Steps

For each file:
1. Create target directory if needed: `mkdir -p tests/integration/<category>/`
2. Move file: `git mv tests/unit/<category>/<file> tests/integration/<category>/<file>`
3. Verify test still runs: `./run_tests.sh tests/integration/<category>/<file>`

### Borderline Cases (Keep in Unit with Refactoring)

These tests could remain as unit tests if refactored to use dependency injection:

| File | Current Issue | Refactoring Option |
|------|---------------|-------------------|
| `tests/unit/equipment/test_unit_stats_equipment.gd` | Uses `ModLoader.registry` and `ModLoader.status_effect_registry` | Create test-local mock registry |
| `tests/unit/audio/test_audio_manager_mod_path.gd` | Uses `ModLoader` and `AudioManager` | Test API existence only (acceptable for interface verification) |

---

## Phase 2: Timer Anti-Patterns

Replace `get_tree().create_timer().timeout` with GdUnit4's `await_millis()` for cleaner, more reliable async testing.

### Files Requiring Timer Conversion

#### Integration Tests (High Priority)

| File | Line(s) | Current | Replacement |
|------|---------|---------|-------------|
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 47 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 133 | `await get_tree().create_timer(0.3).timeout` | `await await_millis(300)` |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 149 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 188 | `await get_tree().create_timer(0.3).timeout` | `await await_millis(300)` |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 202 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 245 | `await get_tree().create_timer(1.0).timeout` | `await await_millis(1000)` |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 260 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 300 | `await get_tree().create_timer(0.2).timeout` | `await await_millis(200)` |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 308 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 356 | `await get_tree().create_timer(0.5).timeout` | `await await_millis(500)` |
| `tests/integration/battle/test_battle_flow.gd` | 167 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/battle/test_battle_flow.gd` | 204 | `await get_tree().create_timer(0.2).timeout` | `await await_millis(200)` |
| `tests/integration/ai/test_defensive_positioning.gd` | 104 | `await get_tree().create_timer(0.2).timeout` | `await await_millis(200)` |
| `tests/integration/ai/test_cautious_engagement.gd` | 98 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/ai/test_retreat_behavior.gd` | 104 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/ai/test_stationary_guard.gd` | 89 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/ai/test_healer_prioritization.gd` | 109 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/ai/test_opportunistic_targeting.gd` | 111 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/ai/test_tactical_debuff.gd` | 94 | `await get_tree().create_timer(0.1).timeout` | `await await_millis(100)` |
| `tests/integration/ai/test_aoe_targeting.gd` | 117 | `await get_tree().create_timer(0.2).timeout` | `await await_millis(200)` |

#### Unit Tests (Lower Priority)

| File | Line | Current | Replacement |
|------|------|---------|-------------|
| `tests/unit/editor/test_editor_event_bus.gd` | 274 | `await get_tree().create_timer(0.15).timeout` | `await await_millis(150)` |

**Note**: The timer in `test_editor_event_bus.gd` is testing debounce behavior, so it legitimately needs to wait for the debounce delay. However, `await_millis()` is still preferred for GdUnit4 compatibility.

---

## Phase 3: Node2D Integration Test Migration

These integration tests extend `Node2D` instead of `GdUnitTestSuite`. They should be converted to use GdUnit4's test infrastructure for better lifecycle management and reporting.

### Files Requiring Migration

| File | Test Count | Special Considerations |
|------|------------|------------------------|
| `tests/integration/ai/test_defensive_positioning.gd` | ~5 | Uses GridManager, requires grid setup |
| `tests/integration/ai/test_ranged_ai_positioning.gd` | ~4 | Range-based AI calculations |
| `tests/integration/ai/test_cautious_engagement.gd` | ~4 | AI behavior testing |
| `tests/integration/ai/test_aoe_targeting.gd` | ~5 | AOE pattern calculations |
| `tests/integration/ai/test_terrain_advantage.gd` | ~4 | Terrain modifier testing |
| `tests/integration/ai/test_retreat_behavior.gd` | ~4 | AI flee logic |
| `tests/integration/ai/test_opportunistic_targeting.gd` | ~4 | Target selection logic |
| `tests/integration/ai/test_stationary_guard.gd` | ~3 | Guard behavior |
| `tests/integration/ai/test_healer_prioritization.gd` | ~5 | Heal target selection |
| `tests/integration/ai/test_tactical_debuff.gd` | ~4 | Debuff application logic |
| `tests/integration/cinematics/test_cinematic_spawn_flow.gd` | 5 | CinematicsManager, GridManager setup, signal connections |
| `tests/integration/battle/test_battle_flow.gd` | ~6 | Full battle lifecycle |

### Migration Pattern

Convert from:
```gdscript
extends Node2D

func _ready() -> void:
    await _run_all_tests()
    get_tree().quit(exit_code)

func _test_something() -> void:
    # test logic
```

To:
```gdscript
class_name TestSomething
extends GdUnitTestSuite

func before() -> void:
    # Setup (formerly in _ready before tests)

func after() -> void:
    # Cleanup (formerly before quit)

func test_something() -> void:
    # Same test logic
```

### Considerations by Test

1. **AI Tests** (`test_defensive_positioning.gd`, etc.):
   - Require GridManager setup in `before()`
   - Create mock units with specific positions
   - May need `auto_free()` for created nodes

2. **Cinematic Spawn Flow** (`test_cinematic_spawn_flow.gd`):
   - Complex signal connections
   - TileMapLayer setup for GridManager
   - Timeout protection (convert to GdUnit4 timeout)

3. **Battle Flow** (`test_battle_flow.gd`):
   - Full battle state machine
   - Multiple phase transitions
   - Save/restore of BattleManager state

---

## Phase 4: Signal Cleanup

### Cinematic Spawn Flow Signal Disconnection

**File**: `tests/integration/cinematics/test_cinematic_spawn_flow.gd`

**Issue**: Signals connected in `_ready()` are never disconnected, causing potential issues with repeated test runs.

**Current Code** (lines 42-44):
```gdscript
CinematicsManager.cinematic_started.connect(_on_cinematic_started)
CinematicsManager.cinematic_ended.connect(_on_cinematic_ended)
CinematicsManager.command_executed.connect(_on_command_executed)
```

**Required Fix**: Add cleanup before `get_tree().quit()` in `_print_results()`:
```gdscript
func _print_results() -> void:
    # Disconnect signals
    if CinematicsManager.cinematic_started.is_connected(_on_cinematic_started):
        CinematicsManager.cinematic_started.disconnect(_on_cinematic_started)
    if CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
        CinematicsManager.cinematic_ended.disconnect(_on_cinematic_ended)
    if CinematicsManager.command_executed.is_connected(_on_command_executed):
        CinematicsManager.command_executed.disconnect(_on_command_executed)

    # ... rest of method
```

**Better Fix** (when migrated to GdUnitTestSuite): Use `after()` lifecycle hook for cleanup.

---

## Phase 5: Coverage Gaps (Future Work)

### Untested Core Systems

Priority 1 (Critical gameplay systems):
| System | File | Notes |
|--------|------|-------|
| `TurnManager` | `core/systems/turn_manager.gd` | Turn order, phase transitions |
| `ExperienceManager` | `core/systems/experience_manager.gd` | XP distribution, level-ups |
| `PartyManager` | `core/systems/party_manager.gd` | Party composition, member access |
| `EquipmentManager` | `core/systems/equipment_manager.gd` | Equip/unequip logic |

Priority 2 (Important supporting systems):
| System | File | Notes |
|--------|------|-------|
| `SceneManager` | `core/systems/scene_manager.gd` | Scene transitions, loading |
| `TriggerManager` | `core/systems/trigger_manager.gd` | Event trigger evaluation |
| `CinematicsManager` | `core/systems/cinematics_manager.gd` | Cinematic playback (partial coverage exists) |
| `CameraController` | `core/systems/camera_controller.gd` | Camera movement, bounds |
| `CaravanController` | `core/systems/caravan_controller.gd` | Party following, formation |

Priority 3 (Utility systems):
| System | File | Notes |
|--------|------|-------|
| `LocalizationManager` | `core/systems/localization_manager.gd` | Text lookup, fallbacks |
| `TextInterpolator` | `core/systems/text_interpolator.gd` | Variable replacement in strings |
| `RandomManager` | `core/systems/random_manager.gd` | Seeded RNG |
| `SettingsManager` | `core/systems/settings_manager.gd` | User preferences |

### Untested Registries

| Registry | File | Notes |
|----------|------|-------|
| `EquipmentRegistry` | `core/registries/equipment_registry.gd` | Equipment lookup |
| `StatusEffectRegistry` | `core/registries/status_effect_registry.gd` | Effect management |
| `TerrainRegistry` | `core/registries/terrain_registry.gd` | Terrain type definitions |
| `UnitCategoryRegistry` | `core/registries/unit_category_registry.gd` | Unit type groupings |
| `AnimationOffsetRegistry` | `core/registries/animation_offset_registry.gd` | Sprite animation timing |

---

## Implementation Order

1. **Phase 1** - Move misclassified unit tests to integration (low risk, immediate clarity) ✅ DONE
2. **Phase 4** - Fix signal cleanup in cinematic spawn flow (prevents test interference) ✅ DONE
3. **Phase 3** - Migrate Node2D tests to GdUnitTestSuite (most effort, best long-term) ✅ DONE
   - All 10 AI integration tests migrated
   - test_cinematic_spawn_flow.gd migrated (5 test cases)
   - test_battle_flow.gd migrated (1 test case)
4. **Phase 2** - Convert timer anti-patterns (improves reliability) ✅ DONE (via Phase 3)
   - All timer anti-patterns converted to `await await_millis()` during GdUnitTestSuite migrations
5. **Phase 5** - Add coverage for untested systems (future work)

---

## Verification

After each phase, run the full test suite:
```bash
GODOT_BIN=~/Downloads/Godot_v4.5.1-stable_linux.x86_64/Godot_v4.5.1-stable_linux.x86_64 \
$GODOT_BIN --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode --add "res://tests"
```

All tests should pass, and the HTML report in `reports/` should show proper categorization.
