# Multi-Agent Code Review Plan
## The Sparkling Farce - Core Platform Review

### Overview

This plan organizes a comprehensive code review of the core platform (~133 GDScript files, ~37,000 lines) using multiple specialized agents. Each agent focuses on a specific domain, ensuring thorough coverage with minimal overlap.

---

## Agent Assignments

### Agent 1: Mod System & Infrastructure
**Focus:** Foundation that all other systems depend on
**Priority:** CRITICAL - Review first

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/mod_system/mod_loader.gd` | ~1,100 | Mod discovery, load order, dependency resolution |
| `core/mod_system/mod_registry.gd` | ~570 | Resource lookup, override tracking, namespace isolation |
| `core/mod_system/mod_manifest.gd` | ~730 | JSON parsing, validation, error handling |

**Review Criteria:**
- [ ] Correct mod load ordering and priority handling
- [ ] Proper namespace isolation between mods
- [ ] Override conflict detection and resolution
- [ ] Error handling for malformed mod.json files
- [ ] Resource caching and memory management
- [ ] Strict typing compliance (no `:=`)
- [ ] Dictionary access patterns (`if "key" in dict:`)

---

### Agent 2: State & Event Systems
**Focus:** Central state management and event-driven architecture
**Priority:** CRITICAL - Core communication backbone

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/systems/game_state.gd` | ~520 | Flag management, campaign progress, save integration |
| `core/systems/game_event_bus.gd` | ~260 | Event emission, listener registration, cancellation |
| `core/systems/save_manager.gd` | Medium | Save/load persistence, data integrity |
| `core/systems/settings_manager.gd` | Small | User preferences persistence |
| `core/systems/storage_manager.gd` | Small | Persistent storage abstraction |

**Review Criteria:**
- [ ] Thread-safe state modifications
- [ ] Event listener lifecycle (memory leaks?)
- [ ] Save data versioning and migration
- [ ] Flag namespacing (`mod_id:flag_name` pattern)
- [ ] Undo/redo potential for state changes
- [ ] Event cancellation propagation

---

### Agent 3: Battle System Core
**Focus:** Tactical combat orchestration
**Priority:** HIGH - Core gameplay loop

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/systems/battle_manager.gd` | Large | Battle flow, unit spawning, victory conditions |
| `core/systems/turn_manager.gd` | Medium | Turn order, initiative, phase management |
| `core/systems/combat_calculator.gd` | ~200 | Damage formulas, accuracy, critical hits |
| `core/systems/grid_manager.gd` | Medium | Grid operations, pathfinding, terrain |
| `core/systems/combat_formula_base.gd` | Small | Formula interface/contract |
| `core/components/unit.gd` | Large | Unit behavior, actions, state machine |
| `core/components/unit_stats.gd` | Medium | Runtime stat calculations, modifiers |
| `core/components/grid_cursor.gd` | Medium | Cursor movement, selection |
| `core/components/spawn_point.gd` | Small | Spawn location validation |

**Review Criteria:**
- [ ] Battle state machine correctness
- [ ] Turn order edge cases (ties, speed changes mid-battle)
- [ ] Combat formula accuracy and balance hooks
- [ ] Grid pathfinding efficiency (A* correctness)
- [ ] Unit action validation (legal moves only)
- [ ] Status effect stacking rules
- [ ] Memory cleanup on battle end

---

### Agent 4: AI System
**Focus:** Enemy behavior and decision making
**Priority:** HIGH - Gameplay quality

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/systems/ai_controller.gd` | Medium | AI orchestration, decision timing |
| `core/systems/configurable_ai_brain.gd` | Medium | Data-driven AI behavior execution |
| `core/resources/ai_behavior_data.gd` | Small | AI behavior definitions |
| `core/resources/ai_brain.gd` | Small | AI brain base resource |
| `core/registries/ai_brain_registry.gd` | Small | Brain type registration |
| `core/registries/ai_mode_registry.gd` | Small | AI mode registration |

**Review Criteria:**
- [ ] AI decision quality (no obviously bad moves)
- [ ] Performance under many units
- [ ] Configurability for different difficulty levels
- [ ] Determinism with seeded RNG
- [ ] Fallback behavior when preferred action impossible
- [ ] Mod extensibility for custom AI behaviors

---

### Agent 5: Cinematic System
**Focus:** Scripted sequences and dialogue
**Priority:** HIGH - Storytelling infrastructure

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/systems/cinematics_manager.gd` | Large | Cinematic orchestration, command queue |
| `core/systems/cinematic_loader.gd` | Medium | JSON cinematic parsing |
| `core/systems/dialog_manager.gd` | Medium | Dialogue display, choices |
| `core/systems/cinematic_commands/*.gd` | ~2,500 | 26 command executors |
| `core/systems/cinematic_spawners/*.gd` | ~400 | 4 entity spawners |
| `core/components/cinematic_actor.gd` | Medium | Actor control interface |
| `core/resources/cinematic_data.gd` | Small | Cinematic data structure |
| `core/resources/dialogue_data.gd` | Small | Dialogue data structure |

**Review Criteria:**
- [ ] Command executor error handling
- [ ] Async command sequencing (await chains)
- [ ] Entity cleanup after cinematics
- [ ] Interruption handling (player skip)
- [ ] Variable interpolation in dialogue
- [ ] Choice branching correctness
- [ ] Save/load during cinematics

---

### Agent 6: Party & Progression Systems
**Focus:** Character management and growth
**Priority:** MEDIUM - Core RPG systems

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/systems/party_manager.gd` | Medium | Party composition, active members |
| `core/systems/equipment_manager.gd` | Medium | Equipment slots, stat bonuses |
| `core/systems/experience_manager.gd` | Medium | XP distribution, level ups |
| `core/systems/promotion_manager.gd` | Small | Class promotion logic |
| `core/systems/shop_manager.gd` | Medium | Buy/sell transactions |
| `core/systems/crafting_manager.gd` | Medium | Recipe validation, creation |
| `core/systems/inventory_config.gd` | Small | Inventory limits |
| `core/systems/equipment_slot.gd` | Small | Slot definitions |
| `core/resources/character_data.gd` | Medium | Character stats, appearance |
| `core/resources/class_data.gd` | Medium | Class definitions |
| `core/resources/item_data.gd` | Medium | Item properties |
| `core/resources/party_data.gd` | Small | Party composition data |

**Review Criteria:**
- [ ] Equipment stat calculation correctness
- [ ] Level-up stat growth formulas
- [ ] Promotion prerequisite validation
- [ ] Inventory overflow handling
- [ ] Shop price calculation (buy vs sell)
- [ ] Crafting ingredient consumption atomicity
- [ ] Character data integrity on save/load

---

### Agent 7: Resource Definitions
**Focus:** Data structure correctness
**Priority:** MEDIUM - Foundation for content

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/resources/ability_data.gd` | Medium | Ability definitions |
| `core/resources/battle_data.gd` | Medium | Battle configurations |
| `core/resources/terrain_data.gd` | Small | Terrain properties |
| `core/resources/map_metadata.gd` | Small | Map configuration |
| `core/resources/npc_data.gd` | Small | NPC definitions |
| `core/resources/shop_data.gd` | Small | Shop inventory |
| `core/resources/status_effect_data.gd` | Small | Status effects |
| `core/resources/combat_animation_data.gd` | Small | Combat animations |
| `core/resources/combat_phase.gd` | Small | Combat phases |
| `core/resources/combat_formula_config.gd` | Small | Formula configs |
| `core/resources/crafting_recipe_data.gd` | Small | Recipes |
| `core/resources/crafter_data.gd` | Small | Crafter NPCs |
| `core/resources/interactable_data.gd` | Small | Interactables |
| `core/resources/transition_context.gd` | Small | Scene transitions |
| `core/resources/slot_metadata.gd` | Small | Slot info |
| `core/resources/grid.gd` | Small | Grid structure |

**Review Criteria:**
- [ ] Required vs optional field handling
- [ ] Default value appropriateness
- [ ] Validation in setters where needed
- [ ] Export hints for editor usability
- [ ] Documentation completeness
- [ ] Serialization correctness

---

### Agent 8: Registry System
**Focus:** Type registration and lookup
**Priority:** MEDIUM - Mod extensibility

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/registries/equipment_registry.gd` | Medium | Equipment type registration |
| `core/registries/equipment_slot_registry.gd` | Small | Slot registration |
| `core/registries/equipment_type_registry.gd` | Small | Type mappings |
| `core/registries/unit_category_registry.gd` | Small | Unit factions |
| `core/registries/terrain_registry.gd` | Small | Terrain types |
| `core/registries/trigger_type_registry.gd` | Small | Trigger types |
| `core/registries/tileset_registry.gd` | Small | TileSets |
| `core/registries/animation_offset_registry.gd` | Small | Animation offsets |
| `core/registries/status_effect_registry.gd` | Small | Status effects |

**Review Criteria:**
- [ ] Registration idempotency
- [ ] Lookup failure handling
- [ ] Mod override support
- [ ] Type safety in registrations
- [ ] Clear error messages for missing entries
- [ ] Documentation of registration contract

---

### Agent 9: Scene & UI Systems
**Focus:** Scene management and exploration
**Priority:** MEDIUM - Player experience

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/systems/scene_manager.gd` | Medium | Scene transitions |
| `core/systems/exploration_ui_manager.gd` | Medium | Exploration UI |
| `core/systems/camera_controller.gd` | Medium | Camera behavior |
| `core/systems/trigger_manager.gd` | Medium | Map triggers |
| `core/systems/map_metadata_loader.gd` | Small | Map JSON loading |
| `core/systems/caravan_controller.gd` | Medium | Mobile HQ |
| `core/components/map_trigger.gd` | Small | Trigger behavior |
| `core/components/npc_node.gd` | Small | NPC scenes |
| `core/components/interactable_node.gd` | Small | Interactables |
| `core/components/caravan_follower.gd` | Small | Following behavior |
| `core/components/exploration_ui_controller.gd` | Medium | UI logic |
| `core/templates/map_template.gd` | ~910 | Map scene template |

**Review Criteria:**
- [ ] Scene transition cleanup (memory leaks)
- [ ] Camera bounds and smoothing
- [ ] Trigger activation conditions
- [ ] NPC interaction flow
- [ ] UI state management
- [ ] Caravan following edge cases

---

### Agent 10: Audio & Presentation
**Focus:** Audio and visual feedback
**Priority:** LOW - Polish layer

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/systems/audio_manager.gd` | Medium | Music/SFX playback |
| `core/systems/game_juice.gd` | Small | Screen shake, effects |
| `core/components/animation_phase_offset.gd` | Small | Animation timing |
| `core/components/tilemap_animation_helper.gd` | Small | Tilemap animations |

**Review Criteria:**
- [ ] Audio resource management (streaming vs preload)
- [ ] Music crossfading
- [ ] Sound effect pooling
- [ ] Screen shake intensity curves
- [ ] Animation synchronization

---

### Agent 11: Input & Localization
**Focus:** Player input and text systems
**Priority:** LOW - Support systems

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/systems/input_manager.gd` | Medium | Input handling |
| `core/systems/input_manager_helpers.gd` | Small | Input utilities |
| `core/systems/localization_manager.gd` | Small | Translation |
| `core/systems/text_interpolator.gd` | Small | Dynamic text |

**Review Criteria:**
- [ ] Input buffering for responsiveness
- [ ] Controller support
- [ ] Rebinding persistence
- [ ] Translation key coverage
- [ ] Variable interpolation edge cases

---

### Agent 12: Utilities & Tools
**Focus:** Helper code and editor tools
**Priority:** LOW - Development support

| File | Lines | Key Review Points |
|------|-------|-------------------|
| `core/utils/dict_utils.gd` | Small | Dictionary helpers |
| `core/utils/unit_utils.gd` | Small | Unit utilities |
| `core/utils/sprite_utils.gd` | Small | Sprite helpers |
| `core/utils/ui_colors.gd` | Small | Color constants |
| `core/utils/facing_utils.gd` | Small | Direction utilities |
| `core/tools/tileset_auto_generator.gd` | Medium | TileSet generation |
| `core/tools/generate_map_sprite_frames.gd` | Small | Sprite generation |
| `core/tools/generate_all_map_sprites.gd` | Small | Batch generation |
| `core/systems/debug_console.gd` | Medium | Dev console |
| `core/systems/random_manager.gd` | Small | RNG management |

**Review Criteria:**
- [ ] Utility function correctness
- [ ] Edge case handling
- [ ] Tool idempotency
- [ ] Debug console security (no prod exploits)
- [ ] RNG determinism for replays

---

## Review Execution Order

```
Phase 1 (Foundation) - Run in Parallel:
  Agent 1: Mod System & Infrastructure
  Agent 2: State & Event Systems

Phase 2 (Core Gameplay) - Run in Parallel:
  Agent 3: Battle System Core
  Agent 4: AI System
  Agent 5: Cinematic System

Phase 3 (Game Systems) - Run in Parallel:
  Agent 6: Party & Progression Systems
  Agent 7: Resource Definitions
  Agent 8: Registry System

Phase 4 (UI & Polish) - Run in Parallel:
  Agent 9: Scene & UI Systems
  Agent 10: Audio & Presentation
  Agent 11: Input & Localization
  Agent 12: Utilities & Tools
```

---

## Universal Review Checklist

Every agent must verify these standards (from AGENTS.md):

### Code Style
- [ ] **Strict typing**: `var x: float = 5.0` NOT `var x := 5.0`
- [ ] **Dictionary checks**: `if "key" in dict:` NOT `if dict.has("key"):`
- [ ] **Naming**: PascalCase classes, snake_case functions/vars, UPPER_SNAKE constants
- [ ] **Private members**: Underscore prefix `_internal_state`
- [ ] **Return types**: All functions have explicit return types

### Architecture
- [ ] **No game content in core/**: Only platform code
- [ ] **Registry access**: Use `ModLoader.registry.get_resource()` not direct loads
- [ ] **Mod safety**: Namespaced flags, resource validation, fallbacks
- [ ] **Event-driven**: Use GameEventBus for cross-system communication

### Error Handling
- [ ] **Guard clauses**: Early returns for invalid conditions
- [ ] **Null safety**: Check before access
- [ ] **Assert usage**: Developer-time validation only
- [ ] **Graceful degradation**: Fallbacks for missing resources

### Documentation
- [ ] **Class headers**: Purpose, integration notes
- [ ] **Public functions**: Parameters, returns, usage documented
- [ ] **Complex algorithms**: Inline comments

---

## Output Format

Each agent should produce a report with:

1. **Summary**: Overall health assessment (Good/Needs Work/Critical Issues)
2. **Issues Found**: List with severity (Critical/High/Medium/Low)
3. **Code Violations**: Specific lines violating standards
4. **Recommendations**: Suggested improvements
5. **Technical Debt**: Areas needing future attention

---

## Estimated Review Time

| Phase | Agents | Est. Time | Files |
|-------|--------|-----------|-------|
| Phase 1 | 2 | 30 min | 8 files |
| Phase 2 | 3 | 60 min | 45 files |
| Phase 3 | 3 | 45 min | 38 files |
| Phase 4 | 4 | 45 min | 22 files |
| **Total** | **12** | **~3 hours** | **133 files** |

---

## How to Execute

To run this review with Claudette:

```
For each phase, launch agents in parallel:

Phase 1:
/review-agent mod-system
/review-agent state-events

Phase 2:
/review-agent battle-core
/review-agent ai-system
/review-agent cinematics

... etc
```

Or run all at once for maximum parallelism if resources allow.
