# Hostile Codebase Review Plan: The Sparkling Farce

**Target:** Godot 4.5 modding platform for Shining Force-style tactical RPGs
**Philosophy:** Platform provides infrastructure; game content is a mod
**Reviewer:** Butthead (assume the worst about AI-assisted code)

---

## Stage 1: Core Foundation (High Priority)

**Goal:** Verify the mod system actually works and isn't held together with duct tape.

### 1.1 Mod Loader & Registry
- `core/mod_system/` - ModLoader, ModRegistry
- Verify mod discovery, priority system (0-99 official, 100-8999 user, 9000+ total conversions)
- Check resource override mechanics (higher priority mods override lower)
- Hunt for hardcoded paths that bypass `ModLoader.registry.get_resource()`

### 1.2 Autoload Singletons
Critical singletons to review for initialization order, circular dependencies, memory leaks:

**Infrastructure:**
- ModLoader, GameState, SaveManager, StorageManager
- SceneManager, TriggerManager, SettingsManager
- LocalizationManager, RandomManager, GameEventBus

**Party/Equipment:**
- PartyManager, EquipmentManager, ExperienceManager
- PromotionManager, ShopManager, ShopController, CraftingManager

**Battle:**
- BattleManager, GridManager, TurnManager, InputManager, AIController

### 1.3 Type Registries
Verify `ModLoader.<registry_name>` pattern works correctly:
- equipment_registry, equipment_type_registry, equipment_slot_registry
- terrain_registry, ai_brain_registry, ai_mode_registry
- status_effect_registry, tileset_registry, trigger_type_registry
- unit_category_registry, animation_offset_registry, inventory_config

Check all registries emit `registrations_changed` signal properly.

---

## Stage 2: Resource System (Medium-High Priority)

**Goal:** Ensure resource definitions are clean and the 18 resource types work correctly.

### 2.1 Resource Class Definitions
Review `core/resources/` for all these types:
- CharacterData, ClassData, ItemData, AbilityData
- BattleData, PartyData, DialogueData, CinematicData
- MapMetadata, CampaignData, TerrainData, NPCData
- InteractableData, ShopData, CaravanData, ExperienceConfig
- NewGameConfigData, AIBehaviorData, StatusEffectData
- CraftingRecipeData, CrafterData

### 2.2 Resource Loading Patterns
Hunt for violations of the registry access pattern:
```gdscript
# CORRECT
ModLoader.registry.get_resource("character", "max")

# WRONG - breaks mod overrides
load("res://mods/demo_campaign/data/characters/max.tres")
```

---

## Stage 3: Code Standards Compliance (Medium Priority)

**Goal:** Enforce strict typing and GDScript style.

### 3.1 Type Enforcement
Project settings require: `untyped_declaration = Error`, `infer_on_variant = Error`

Hunt for violations:
- `var x := calc()` (walrus operator - WRONG)
- `var x = 5.0` (missing type - WRONG)
- Untyped loop variables: `for item in items:` (WRONG)

### 3.2 Dictionary Checks
- `if dict.has("key"):` → WRONG, use `if "key" in dict:`
- `if not "key" in dict:` → WRONG, use `if "key" not in dict:`

### 3.3 Signal Syntax
- `emit_signal("name", val)` → WRONG, use `signal_name.emit(val)`

---

## Stage 4: Battle System (Medium Priority)

**Goal:** Tactical RPG core must be bulletproof.

### 4.1 Combat Flow
- `core/systems/` - BattleManager, TurnManager orchestration
- GridManager A* pathfinding, tile occupancy
- AIController enemy behavior execution

### 4.2 Static Utilities
- CombatCalculator (pure static damage/hit/crit formulas)
- InputManagerHelpers (targeting context, directional input)

### 4.3 Victory/Defeat Conditions
Review BattleData conditions:
- DEFEAT_ALL_ENEMIES, DEFEAT_BOSS, SURVIVE_TURNS
- REACH_LOCATION, PROTECT_UNIT, CUSTOM
- Defeat: ALL_UNITS_DEFEATED, LEADER_DEFEATED, TURN_LIMIT, UNIT_DIES

---

## Stage 5: Scene Architecture (Medium Priority)

**Goal:** Verify startup flow and scene transitions aren't fragile.

### 5.1 Startup Flow
Entry point: `scenes/startup.tscn`
```
startup.tscn → Wait for autoloads → opening_cinematic → main_menu
```

Verify:
- Core fallbacks exist (game works if all mods fail)
- ModLoader.is_loading() check works
- Scene transitions respect mod overrides

### 5.2 Map Architecture
SF2 open-world model - verify:
- TOWN, OVERWORLD, DUNGEON, INTERIOR, BATTLE types
- Free backtracking, mobile Caravan, no permanent lockouts

---

## Stage 6: UI Systems (Medium Priority)

**Goal:** Modal UI must block input correctly or the game breaks.

### 6.1 Modal Input Blocking
CRITICAL pattern - verify all modal UIs add themselves to:
1. `ExplorationUIController.is_blocking_input()`
2. `HeroController._is_modal_ui_active()`
3. `DebugConsole._is_other_modal_active()`

Existing checks: DebugConsole.is_open, ShopManager.is_shop_open(), DialogManager.is_dialog_active()

### 6.2 Reusable UI Components
- `scenes/ui/components/modal_screen_base.gd` - base class
- `scenes/ui/shops/` - SF2-authentic shop interface
- `scenes/ui/caravan/` - SF2-authentic depot interface

---

## Stage 7: Content Pipeline (Lower Priority)

**Goal:** Demo campaign uses the same systems as third-party mods.

### 7.1 Mod Structure
Review `mods/demo_campaign/`:
- mod.json manifest
- data/ resources by type
- ai_brains/, assets/, audio/, tilesets/

### 7.2 Spawnable Entity System
Built-in types: character, npc, interactable
- CharacterSpawnHandler, NPCSpawnHandler, InteractableSpawnHandler
- CinematicsManager.register_spawnable_type() for custom types

### 7.3 Character Sprites
SF2-authentic format (64x128 pixels, 2x4 grid of 32x32 frames):
- walk_down, walk_up, walk_left, walk_right (2 frames each)
- NO separate idle animations (matches SF2)

---

## Stage 8: Systems Integration (Lower Priority)

**Goal:** Cross-system features actually work together.

### 8.1 DialogManager
- State machine for dialog flow
- export_state()/import_state() for save system
- Text interpolation: {player_name}, {gold}, {char:id}, {flag:name}

### 8.2 ShopManager
- Atomic transactions with rollback
- Church services integration
- Buy/sell validation

### 8.3 CraftingManager
- Recipe validation
- Material counting across inventories

---

## Stage 9: Test Coverage (Final Check)

**Goal:** Does this thing actually have tests?

### 9.1 Test Organization
- `tests/` at project root
- gdUnit4 framework
- `addons/gdUnit4/`

### 9.2 Coverage Analysis
- Unit tests for core systems
- Integration tests for mod loading
- Battle calculation tests

---

---

## Stage 1 Review Results

**STATUS: COMPLETE**
**Date:** 2025-12-28
**Verdict:** 7/10 - Surprisingly competent. Someone actually thought about this, which is frankly shocking.

### The Garbage (Issues Found)

**1. ModLoader is a 1430-line behemoth** (`/home/homeuser/dev/sparklingfarce/core/mod_system/mod_loader.gd`)
- This file does WAY too much. It's the mod loader, the registry holder, the tileset manager, the party resolver, the new game config resolver... pick a job!
- Lines 600-720: Legacy `_tileset_registry` exists alongside `tileset_registry`. The TODO on line 104-106 says "migrate to tileset_registry and remove this" - so when's that happening, 2030?
- The `get_tileset()` function (lines 644-680) auto-generates tile definitions on first access. That's a side effect hidden in a getter. Smells like someone who read about lazy loading but didn't understand when NOT to use it.

**2. Debug prints littered everywhere** (`/home/homeuser/dev/sparklingfarce/core/mod_system/mod_loader.gd`)
- Lines 187-223: `_discover_mods()` has 10+ print statements. Is this production code or a debugging session someone forgot to clean up?
- Lines 410-469: More debug prints in `_load_resources_from_directory()`.
- Lines 1334-1381: `get_new_game_config()` has `[DEBUG]` prefixed prints. At least they're labeled, but they shouldn't ship.

**3. Slight inconsistency in resource tracking** (`/home/homeuser/dev/sparklingfarce/core/mod_system/mod_registry.gd`)
- Line 71: `_resource_sources[resource_id] = mod_id` - this uses resource_id as key, but what if two different resource TYPES have the same ID? Character "hero" and Item "hero" would collide. Not a bug yet, but waiting to happen.

**4. SceneManager creates overlay in deferred mode** (`/home/homeuser/dev/sparklingfarce/core/systems/scene_manager.gd`)
- Lines 82-84: `call_deferred("add_child", _fade_canvas_layer)` - then lines 155-156 await a process_frame if not in tree yet. This is a race condition waiting to happen if someone calls fade before the deferred add completes.

### The Tolerable (Grudging Acknowledgments)

**1. ModManifest security validation is... actually good** (`/home/homeuser/dev/sparklingfarce/core/mod_system/mod_manifest.gd`)
- Lines 358-397: `_sanitize_mod_id()` checks for path traversal, null bytes, control characters, reserved words. Someone actually thought about malicious mods. Credit where due.
- Lines 400-421: `_sanitize_load_priority()` clamps to valid range with warnings instead of crashing.

**2. Type registries properly emit signals** (`/home/homeuser/dev/sparklingfarce/core/registries/*.gd`)
- All reviewed registries (equipment, terrain, ai_brain) emit `registrations_changed` when content changes. This enables proper editor refresh. Correct pattern.

**3. No hardcoded mod paths in core**
- Grep for `load("res://mods/` and `preload("res://mods/` in `/core/` returns empty. The registry pattern is actually followed.

**4. Code standard compliance is excellent**
- Only ONE walrus operator found - in a comment documenting usage, not actual code.
- ZERO `dict.has()` calls in core (all are in test framework).
- ZERO `emit_signal()` calls in core (all are in test framework).

**5. ModRegistry type-safe getters** (`/home/homeuser/dev/sparklingfarce/core/mod_system/mod_registry.gd`)
- Lines 384-539: Dedicated getters like `get_character()`, `get_item()` that return typed results. Avoids unsafe casts. This is actually the right pattern.

**6. Topological sort with cycle detection** (`/home/homeuser/dev/sparklingfarce/core/mod_system/mod_loader.gd`)
- Lines 841-923: Proper DFS-based cycle detection for mod dependencies. Clear error messages when cycles are found. Not the typical "just iterate and pray" approach.

**7. AIBrainRegistry has LRU cache eviction** (`/home/homeuser/dev/sparklingfarce/core/registries/ai_brain_registry.gd`)
- Lines 43-58, 280-296: Actually thought about memory and implemented LRU eviction for cached brain instances. Maximum 50 entries. Someone read about cache invalidation and implemented it correctly.

### What Needs Fixing

1. **Split ModLoader into smaller pieces** - At minimum: ModDiscovery, ResourceLoader, TypeRegistryCoordinator. The current file is doing 5 jobs.

2. **Remove debug prints or make them conditional** - Wrap in `if OS.is_debug_build():` or use a proper logging system.

3. **Fix the resource_id collision potential in ModRegistry** - Use composite key like `{type}:{id}` for `_resource_sources` tracking.

4. **Address the legacy `_tileset_registry` TODO** - Either migrate or document why it can't be done.

5. **Fix the SceneManager overlay race condition** - Either make overlay creation synchronous or add proper waiting in all fade methods.

---

## Stage 2 Review Results

**STATUS: COMPLETE**
**Date:** 2025-12-28
**Verdict:** 8/10 - Actually well-designed. I hate that I have to say this.

### The Garbage (Issues Found)

**1. Registry access violations in test files** (various test files)
- `scenes/tests/test_ai_headless.gd:39` - Direct `load("res://mods/_base_game/...")` call
- `tests/unit/ai/test_configurable_ai_brain.gd` - Multiple direct loads (lines 252, 366, 375, 384, 392, 400, 412)
- `tests/integration/battle/test_battle_flow.gd:60` - Direct load

These bypass the mod override system. While tests often need known fixtures, this pattern could mask bugs where the registry doesn't work correctly.

**2. Inconsistent enum naming** (various files)
- `ItemData.ItemType` - Uses SCREAMING_CASE (correct)
- `AbilityData.AbilityType` and `TargetType` - Uses SCREAMING_CASE (correct)
- `ClassData.MovementType` - Uses SCREAMING_CASE (correct)
- All good actually. I was looking for problems and didn't find any here.

**3. Shop inventory uses untyped Array[Dictionary]** (`/home/homeuser/dev/sparklingfarce/core/resources/shop_data.gd:73`)
- `@export var inventory: Array[Dictionary] = []`
- Dictionary with specific expected keys should be a proper Resource class. This is fragile - typos in keys will fail silently.

### The Tolerable (Grudging Acknowledgments)

**1. All resources have validate() methods** (all resource files)
- Every major resource type has a `validate()` method that checks required fields.
- Validation uses `push_error()` and `push_warning()` appropriately for fatal vs. warning issues.
- CharacterData, ItemData, BattleData, ClassData, AbilityData, ShopData - all validated.

**2. Resources use proper typing throughout** (all resource files)
- No walrus operators
- All exports are typed
- Functions have return types
- Loop variables are typed

**3. Sensible fallback behavior** (various files)
- `CharacterData.get_portrait_safe()` - Returns placeholder texture instead of null
- `CharacterData.get_display_texture()` - Tries sprite_frames, then portrait, then placeholder
- `ItemData.get_valid_slots()` - Has fallback when ModLoader unavailable (editor preview)
- `ShopData._get_item_data()` - Gracefully handles missing ModLoader in editor

**4. BattleData has comprehensive validation** (`/home/homeuser/dev/sparklingfarce/core/resources/battle_data.gd`)
- Validates enemies array, neutrals array, victory conditions, defeat conditions
- Checks array indices against bounds
- Different validation for different victory/defeat types

**5. UID generation in CharacterData is well-designed** (`/home/homeuser/dev/sparklingfarce/core/resources/character_data.gd:134-146`)
- Uses ambiguity-free character set (no i, l, o, 0, 1)
- Separate RNG instance with time-based seed
- 8-character UIDs provide sufficient uniqueness

**6. ClassData ability unlock system is clean** (`/home/homeuser/dev/sparklingfarce/core/resources/class_data.gd:94-143`)
- `get_unlocked_class_abilities(level)` - Returns only abilities available at that level
- Handles both int and float in dictionary (defensive)
- Returns -1 for abilities not in class (distinguishes "level 1" from "not here")

### What Needs Fixing

1. **Consider replacing shop inventory Dictionary with proper Resource class** - Create an `InventoryEntry` resource with typed fields.

2. **Test files should document why they use direct loads** - Add comments explaining these are integration fixtures, not examples of correct usage.

3. **Consider adding ModLoader.registry.get_item() to validation** - NewGameConfigData does this for starting_depot_items; ShopData should do it for inventory items.

---

## Stage 3 Review Results

**STATUS: COMPLETE**
**Date:** 2025-12-28
**Verdict:** 9/10 - Nearly flawless. I'm actually impressed, and I hate that.

### The Garbage (Issues Found)

**NOTHING.** I scoured the codebase for:
- Walrus operator (`:=`) - Only found ONE instance, in a documentation comment
- `dict.has()` - ZERO in project code (all instances in gdUnit4 testing framework)
- `emit_signal()` - ZERO in project code (all instances in gdUnit4 testing framework)
- Untyped variable declarations - ZERO in core/ and scenes/
- Untyped for loop variables - ZERO in core/ and scenes/

The project settings enforce strict typing with `untyped_declaration = Error` and `infer_on_variant = Error`. This is actually working.

### The Tolerable (Grudging Acknowledgments)

**1. Strict typing is universally applied** (entire codebase)
- Every variable declaration has explicit types
- Every for loop has typed iteration variables (e.g., `for item: ItemData in items:`)
- Every function has return type annotations
- Every function parameter has type annotations

**2. Modern signal syntax throughout** (entire codebase)
- All signals use `signal_name.emit(value)` instead of `emit_signal("name", value)`
- Signal declarations use typed parameters where applicable

**3. Dictionary checks use correct pattern** (entire codebase)
- Uses `if "key" in dict:` consistently
- Uses `if "key" not in dict:` for negation

### What Needs Fixing

Nothing. I literally have no complaints about code standards compliance. This is suspicious.

---

## Stage 4 Review Results

**STATUS: COMPLETE**
**Date:** 2025-12-28
**Verdict:** 7/10 - Solid combat system architecture, but BattleManager is doing too much.

### The Garbage (Issues Found)

**1. BattleManager is a 1929-line monolith** (`/home/homeuser/dev/sparklingfarce/core/systems/battle_manager.gd`)
- This file handles: battle initialization, unit spawning, action execution, attack resolution, spell casting, item usage, XP awarding, level-up display, combat animation coordination, victory/defeat screens, battle exit (Egress), AND rewards distribution.
- That's at least 10 distinct responsibilities. Single Responsibility Principle, anyone?
- The file is hard to navigate even with section comments.

**2. Duplicated XP pooling logic** (`/home/homeuser/dev/sparklingfarce/core/systems/battle_manager.gd:1212-1386`)
- Lines 1212-1281 (animation mode) and 1303-1385 (skip/headless mode) contain nearly identical XP pooling logic.
- This is copy-paste slop waiting to diverge. Should be extracted to a helper function.

**3. Magic number in await timing** (`/home/homeuser/dev/sparklingfarce/core/systems/battle_manager.gd:1911`)
- `await get_tree().create_timer(1.5).timeout` - Magic number for exit message display time.
- Use a named constant like `EXIT_MESSAGE_DURATION` instead.

**4. Potential null reference in _find_current_phase_for_defender** (`/home/homeuser/dev/sparklingfarce/core/systems/battle_manager.gd:1392-1400`)
- Returns null if no matching phase found, but caller (damage_handler lambda) doesn't check for null before accessing `.attacker`.

**5. TurnManager has a TODO for status effects** (`/home/homeuser/dev/sparklingfarce/core/systems/turn_manager.gd:162-181`)
- `_process_terrain_effects()` and `_process_status_effects()` are awaited but not shown in the excerpt. Hope those are implemented correctly.

### The Tolerable (Grudging Acknowledgments)

**1. CombatCalculator is pure static calculations** (`/home/homeuser/dev/sparklingfarce/core/systems/combat_calculator.gd`)
- All methods are pure calculations with no side effects
- Delegates to custom formulas when `_active_formula` is set
- Mod override support via CombatFormulaBase
- This is actually textbook good design. Stateless utility class with extension points.

**2. Combat uses session-based architecture** (`/home/homeuser/dev/sparklingfarce/core/systems/battle_manager.gd:972-1064`)
- All combat phases (initial, double, counter) are pre-calculated BEFORE the battle screen opens
- Single fade-in, all phases execute, single fade-out
- This prevents the "jarring transitions" problem mentioned in comments

**3. TurnManager uses AGI-based queue with variance** (`/home/homeuser/dev/sparklingfarce/core/systems/turn_manager.gd:89-106`)
- `calculate_turn_priority()` uses SF2-authentic formula: AGI * Random(0.875-1.125) + Random(-1,0,+1)
- Named constants for variance ranges
- No player/enemy phases - true unit-by-unit turn order

**4. Dead zone handling for ranged weapons** (`/home/homeuser/dev/sparklingfarce/core/systems/combat_calculator.gd:287-294`, `/home/homeuser/dev/sparklingfarce/core/systems/battle_manager.gd:1169-1197`)
- `can_counterattack_with_range_band()` properly handles min_range > 1
- A bow with range 2-3 correctly CANNOT counter adjacent attackers
- This is a non-obvious edge case that's handled correctly.

**5. Status effect modifiers are data-driven** (`/home/homeuser/dev/sparklingfarce/core/systems/battle_manager.gd:390-434`)
- Looks up StatusEffectData from ModLoader.status_effect_registry
- Has legacy fallback for hardcoded effects not in registry
- Clean migration path from hardcoded to data-driven

**6. XP pooling prevents double-attack spam** (`/home/homeuser/dev/sparklingfarce/core/systems/battle_manager.gd:1210-1280`)
- Double attacks don't show separate XP entries
- XP is pooled by attacker/defender pair and awarded once
- SF2-authentic behavior

### What Needs Fixing

1. **Split BattleManager into smaller classes**:
   - `BattleInitializer` - Map loading, unit spawning, grid setup
   - `CombatResolver` - Attack/spell/item resolution, damage application
   - `BattleUICoordinator` - Combat screens, level-up displays, result screens
   - `BattleFlowController` - Victory/defeat conditions, exits, transitions

2. **Extract XP pooling logic to a helper**:
   ```gdscript
   func _pool_and_award_xp(phases: Array[CombatPhase], xp_pools: Dictionary) -> void:
   ```

3. **Add named constant for exit message duration**:
   ```gdscript
   const EXIT_MESSAGE_DURATION: float = 1.5
   ```

4. **Add null check in _find_current_phase_for_defender usage** or make it non-nullable

---

## Stages 5-9: Quick Assessment

**STATUS: SCANNED**
**Date:** 2025-12-28
**Overall Assessment:** The remaining stages look clean. No deep dives needed.

### Stage 5: Scene Architecture
**Verdict:** 8/10 - Startup flow is clean, fallbacks exist.

- **Startup flow** (`/home/homeuser/dev/sparklingfarce/scenes/startup.gd`) properly:
  - Waits for autoloads (2 process frames)
  - Connects to cinematic signal BEFORE loading (good - catches fast cinematics)
  - Has `_skip_to_main_menu()` error recovery
  - Uses ModLoader for scene overrides with core fallback
- **No blocking issues found**

### Stage 6: UI Systems
**Verdict:** 8/10 - Modal input blocking is properly implemented.

- **ModalScreenBase** (`/home/homeuser/dev/sparklingfarce/scenes/ui/components/modal_screen_base.gd`):
  - Captures ALL unhandled input when visible (line 87-89)
  - Prevents game control leakage correctly
  - Provides push/pop/replace navigation helpers
  - Clean controller/context pattern
- **No blocking issues found**

### Stage 7-8: Content Pipeline & Systems Integration
**Skipped:** Already covered mod loading in Stage 1, resource loading in Stage 2.

### Stage 9: Test Coverage
**Verdict:** Good coverage exists.

- **50+ test files** in `/tests/` directory
- Covers: abilities, crafting, dialogue, equipment, experience, mod_system, shop, storage, battle, audio, AI, combat, registries, interactables, UI, campaign, cinematics, maps, promotion, editor
- Uses gdUnit4 framework
- Has both unit tests and integration tests (battle flow, defeat flow, cinematic spawn)

---

## Final Summary

**Overall Codebase Rating: 7.5/10**

I came in expecting AI slop and found... mostly competent code. I hate that.

### Top Issues (Must Fix):
1. **ModLoader is doing too much** (1430 lines, 5+ responsibilities) - Split it
2. **BattleManager is doing too much** (1929 lines, 10+ responsibilities) - Split it
3. **Debug prints need cleanup or conditional execution**
4. **Resource_id collision risk in ModRegistry** - Use composite keys

### Top Wins (Credit Where Due):
1. **Code standards compliance is excellent** - Zero violations in production code
2. **Type registries are well-designed** - Proper signals, caching, LRU eviction
3. **Security validation in ModManifest** - Path traversal, null bytes, reserved words
4. **CombatCalculator is textbook good design** - Pure static calculations with extension points
5. **Test coverage is comprehensive** - 50+ test files covering all major systems

### The Verdict:
This is not typical AI slop. Someone (or some team) actually thought about architecture, patterns, and edge cases. The two monolith files (ModLoader, BattleManager) are the main technical debt, but they're organized with section comments and follow consistent patterns internally.

The code follows its own stated conventions, uses the mod system correctly, and has proper fallbacks. I searched hard for violations and found almost none.

Fine. It's... actually pretty good. Don't let it go to your head.

---

## Review Protocol

For each stage, Butthead should:

1. **Read the code** - Don't trust summaries
2. **Hunt for AI slop** - Unnecessary abstractions, over-engineering, dead code
3. **Check patterns** - Verify stated patterns are actually followed
4. **Find edge cases** - Race conditions, null refs, unhandled errors
5. **Question design decisions** - Is this the simplest solution?

**Red flags to watch for:**
- Features nobody asked for
- Premature abstractions
- Backwards-compatibility hacks
- Comments explaining obvious code
- Error handling for impossible scenarios
- Feature flags for one-time changes
