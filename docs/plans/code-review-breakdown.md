# Code Review Breakdown Report

**Author**: Lt. Claudbrain
**Stardate**: 2025-12-03
**Mission**: Break codebase into manageable review chunks

---

## Executive Summary

The USS Torvalds codebase consists of **~160 GDScript files** totaling approximately **32,000 lines of code** (excluding gdUnit4 addon and test infrastructure). I've identified **17 logical review chunks** organized by subsystem and complexity.

### Codebase at a Glance

| Area | Files | LOC | Complexity |
|------|-------|-----|------------|
| Core Systems | 27 | 10,572 | High |
| Cinematic Commands | 14 | 507 | Low |
| Core Resources | 24 | 4,202 | Medium |
| Core Components | 7 | 2,251 | Medium-High |
| Core Registries | 7 | 911 | Low |
| Mod System | 3 | 1,253 | High |
| Scenes/UI | 15 | 3,574 | Medium |
| Map Exploration | 6 | 1,438 | Medium |
| Editor Plugin | 20 | 14,140 | High |
| Tests | 20 | 6,698 | Medium |
| Mods (GDScript) | 6 | ~200 | Low |

---

## Review Chunks

### Chunk 1: Battle System Core
**Priority**: Critical
**LOC**: ~1,740
**Dependencies**: GridManager, TurnManager, InputManager

| File | LOC | Notes |
|------|-----|-------|
| `core/systems/battle_manager.gd` | 1,084 | Battle orchestration, state machine |
| `core/systems/turn_manager.gd` | 351 | AGI-based turn order |
| `core/systems/combat_calculator.gd` | 305 | Damage/hit/crit formulas (static) |

**Review Focus**:
- State machine transitions
- Signal flow between components
- Battle phase management
- Correct formula implementation

---

### Chunk 2: Battle Input & Grid
**Priority**: Critical
**LOC**: ~2,508 (includes LARGEST FILE)
**Dependencies**: BattleManager, GridManager

| File | LOC | Notes |
|------|-----|-------|
| `core/systems/input_manager.gd` | 1,784 | Input state machine (LARGEST FILE) |
| `core/systems/grid_manager.gd` | 602 | A* pathfinding, tile occupancy |
| `core/resources/grid.gd` | 122 | Grid resource data |

**Review Focus**:
- Input state machine correctness
- State transitions (unit selection, movement, targeting)
- Pathfinding algorithm efficiency
- Edge case handling

---

### Chunk 3: Unit System
**Priority**: Critical
**LOC**: ~1,288
**Dependencies**: UnitStats, CharacterData, ClassData

| File | LOC | Notes |
|------|-----|-------|
| `core/components/unit.gd` | 598 | Battle unit node |
| `core/components/unit_stats.gd` | 451 | Runtime stat calculations |
| `core/resources/character_data.gd` | 116 | Character definition |
| `core/resources/class_data.gd` | 123 | Class definition |

**Review Focus**:
- Stat calculation correctness
- Equipment modifier application
- Level-up stat changes
- Unit lifecycle management

---

### Chunk 4: AI & Enemy Behavior
**Priority**: High
**LOC**: ~315
**Dependencies**: BattleManager, Unit

| File | LOC | Notes |
|------|-----|-------|
| `core/systems/ai_controller.gd` | 68 | AI execution coordinator |
| `core/resources/ai_brain.gd` | 167 | AI decision resource |
| `mods/_base_game/ai_brains/ai_aggressive.gd` | ~50 | Aggressive AI impl |
| `mods/_base_game/ai_brains/ai_stationary.gd` | ~30 | Stationary AI impl |

**Review Focus**:
- AI decision-making logic
- Target selection algorithms
- Action priority ordering
- Performance under many units

---

### Chunk 5: Mod System
**Priority**: Critical
**LOC**: ~1,253
**Dependencies**: All resource loading

| File | LOC | Notes |
|------|-----|-------|
| `core/mod_system/mod_loader.gd` | 753 | Discovery, loading, registry init |
| `core/mod_system/mod_registry.gd` | 270 | Resource storage & retrieval |
| `core/mod_system/mod_manifest.gd` | 230 | mod.json parsing |

**Review Focus**:
- Load order correctness
- Override mechanics
- Error handling on malformed mods
- Resource leak prevention
- Dependency resolution

---

### Chunk 6: Type Registries
**Priority**: Medium
**LOC**: ~911
**Dependencies**: ModLoader

| File | LOC | Notes |
|------|-----|-------|
| `core/registries/equipment_registry.gd` | 144 | Weapon/armor types |
| `core/registries/equipment_slot_registry.gd` | 126 | Equipment slots |
| `core/registries/terrain_registry.gd` | 107 | Terrain types |
| `core/registries/trigger_type_registry.gd` | 141 | Trigger types |
| `core/registries/unit_category_registry.gd` | 96 | Unit categories |
| `core/registries/environment_registry.gd` | 144 | Environment types |
| `core/registries/animation_offset_registry.gd` | 153 | Animation offsets |

**Review Focus**:
- Mod extensibility patterns
- Default value handling
- Type validation

---

### Chunk 7: Party & Progression
**Priority**: High
**LOC**: ~1,644
**Dependencies**: CharacterData, PartyData

| File | LOC | Notes |
|------|-----|-------|
| `core/systems/party_manager.gd` | 437 | Party composition |
| `core/systems/experience_manager.gd` | 426 | XP distribution, level-up |
| `core/systems/promotion_manager.gd` | 483 | Class promotion |
| `core/resources/party_data.gd` | 118 | Party definition |
| `core/resources/experience_config.gd` | 180 | XP curve config |

**Review Focus**:
- Hero always at position 0
- Party size limits
- XP curve correctness
- Promotion eligibility checks

---

### Chunk 8: Equipment & Inventory
**Priority**: High
**LOC**: ~690
**Dependencies**: ItemData, UnitStats

| File | LOC | Notes |
|------|-----|-------|
| `core/systems/equipment_manager.gd` | 431 | Equip/unequip logic |
| `core/systems/equipment_slot.gd` | 31 | Slot enum |
| `core/systems/inventory_config.gd` | 70 | Inventory limits |
| `core/resources/item_data.gd` | 158 | Item definition |

**Review Focus**:
- Slot validation
- Stat modifier stacking
- Class equipment restrictions
- Inventory overflow handling

---

### Chunk 9: Save System
**Priority**: Critical
**LOC**: ~1,722
**Dependencies**: All game state

| File | LOC | Notes |
|------|-----|-------|
| `core/systems/save_manager.gd` | 431 | Save/load operations |
| `core/systems/game_state.gd` | 305 | Story flags, namespacing |
| `core/resources/save_data.gd` | 319 | Save file structure |
| `core/resources/character_save_data.gd` | 462 | Per-character save |
| `core/resources/slot_metadata.gd` | 205 | Save slot info |

**Review Focus**:
- Data integrity
- Version compatibility
- Error recovery
- Flag namespacing correctness

---

### Chunk 10: Dialog & Cinematics
**Priority**: High
**LOC**: ~1,472
**Dependencies**: DialogueData, CinematicData

| File | LOC | Notes |
|------|-----|-------|
| `core/systems/dialog_manager.gd` | 264 | Dialog state machine |
| `core/systems/cinematics_manager.gd` | 463 | Cutscene orchestration |
| `core/systems/cinematic_loader.gd` | 278 | Cinematic JSON loading |
| `core/systems/cinematic_command_executor.gd` | 42 | Command dispatch base |
| `core/resources/dialogue_data.gd` | 155 | Dialog definition |
| `core/resources/cinematic_data.gd` | 270 | Cinematic definition |

**Review Focus**:
- Dialog branching logic
- Cinematic command sequencing
- Portrait/emotion handling
- Choice selection flow

---

### Chunk 11: Cinematic Commands
**Priority**: Medium
**LOC**: ~507
**Dependencies**: CinematicsManager

All files in `core/systems/cinematic_commands/`:

| File | LOC |
|------|-----|
| `dialog_executor.gd` | 96 |
| `move_entity_executor.gd` | 74 |
| `camera_follow_executor.gd` | 58 |
| `camera_move_executor.gd` | 40 |
| `despawn_entity_executor.gd` | 38 |
| `fade_screen_executor.gd` | 37 |
| `camera_shake_executor.gd` | 31 |
| `play_animation_executor.gd` | 26 |
| `set_variable_executor.gd` | 22 |
| `set_facing_executor.gd` | 19 |
| `play_music_executor.gd` | 19 |
| `play_sound_executor.gd` | 18 |
| `wait_executor.gd` | 15 |
| `spawn_entity_executor.gd` | 14 |

**Review Focus**:
- Command interface consistency
- Async completion handling
- Error cases

---

### Chunk 12: Campaign System
**Priority**: High
**LOC**: ~1,451
**Dependencies**: CampaignData, GameState

| File | LOC | Notes |
|------|-----|-------|
| `core/systems/campaign_manager.gd` | 689 | Campaign progression |
| `core/systems/campaign_loader.gd` | 345 | Campaign JSON loading |
| `core/resources/campaign_data.gd` | 193 | Campaign definition |
| `core/resources/campaign_node.gd` | 224 | Node in campaign graph |

**Review Focus**:
- Node transition logic
- Condition evaluation
- Save/restore campaign state
- Campaign graph traversal

---

### Chunk 13: Map & Scene Management
**Priority**: High
**LOC**: ~1,909
**Dependencies**: MapMetadata, SceneManager

| File | LOC | Notes |
|------|-----|-------|
| `core/systems/scene_manager.gd` | 260 | Scene transitions |
| `core/systems/map_metadata_loader.gd` | 293 | Map JSON loading |
| `core/systems/trigger_manager.gd` | 435 | Map trigger routing |
| `core/resources/map_metadata.gd` | 397 | Map definition |
| `core/resources/transition_context.gd` | 118 | Transition data |
| `core/components/map_trigger.gd` | 199 | Trigger node |
| `core/components/spawn_point.gd` | 207 | Spawn point node |

**Review Focus**:
- Trigger activation logic
- Scene transition smoothness
- Spawn point validation
- Map type handling

---

### Chunk 14: Battle UI
**Priority**: Medium
**LOC**: ~3,574
**Dependencies**: BattleManager, Unit

| File | LOC | Notes |
|------|-----|-------|
| `scenes/ui/item_menu.gd` | 562 | Item selection UI |
| `scenes/ui/combat_animation_scene.gd` | 447 | Combat animations |
| `scenes/ui/action_menu.gd` | 324 | Action selection |
| `scenes/ui/dialog_box.gd` | 321 | Dialog display |
| `scenes/ui/promotion_ceremony.gd` | 318 | Promotion UI |
| `scenes/ui/level_up_celebration.gd` | 239 | Level up UI |
| `scenes/ui/combat_results_panel.gd` | 228 | Combat results |
| `scenes/ui/turn_order_panel.gd` | 202 | Turn order display |
| `scenes/ui/choice_selector.gd` | 166 | Choice UI |
| `scenes/ui/active_unit_stats_panel.gd` | 170 | Unit stats display |
| `scenes/ui/victory_screen.gd` | 132 | Victory UI |
| `scenes/ui/combat_forecast_panel.gd` | 125 | Combat preview |
| `scenes/ui/grid_cursor.gd` | 124 | Grid cursor |
| `scenes/ui/defeat_screen.gd` | 123 | Defeat UI |
| `scenes/ui/terrain_info_panel.gd` | 93 | Terrain info |

**Review Focus**:
- Signal connections to managers
- Animation timing
- Input handling
- State synchronization

---

### Chunk 15: Map Exploration
**Priority**: Medium
**LOC**: ~1,438
**Dependencies**: PartyManager, MapMetadata

| File | LOC | Notes |
|------|-----|-------|
| `scenes/map_exploration/map_test_playable.gd` | 395 | Playable map scene |
| `scenes/map_exploration/hero_controller.gd` | 344 | Hero movement |
| `scenes/map_exploration/party_follower.gd` | 314 | Party following |
| `scenes/map_exploration/test_map_headless.gd` | 164 | Headless testing |
| `scenes/map_exploration/map_test.gd` | 148 | Map testing |
| `scenes/map_exploration/map_camera.gd` | 73 | Camera control |
| `core/components/cinematic_actor.gd` | 418 | Cinematic NPC |
| `core/components/tilemap_animation_helper.gd` | 193 | Tile animations |
| `core/components/animation_phase_offset.gd` | 185 | Animation sync |

**Review Focus**:
- Movement grid alignment
- Party follow pathfinding
- Collision handling
- Camera boundaries

---

### Chunk 16: Editor Plugin
**Priority**: Medium
**LOC**: ~14,140 (LARGEST SUBSYSTEM - split into sub-chunks)
**Dependencies**: ModLoader, all resource types

#### Sub-Chunk 16A: Editor Infrastructure
**LOC**: ~1,787

| File | LOC | Notes |
|------|-----|-------|
| `editor_plugin.gd` | 39 | Plugin entry |
| `editor_event_bus.gd` | 65 | Editor signals |
| `ui/main_panel.gd` | 448 | Main dock panel |
| `ui/base_resource_editor.gd` | 893 | Editor base class |
| `ui/json_editor_base.gd` | 341 | JSON editor base |

**Review Focus**: Plugin lifecycle, base class patterns, event coordination

#### Sub-Chunk 16B: Complex Resource Editors (NEW/HEAVILY UPDATED)
**LOC**: ~6,185

| File | LOC | Notes |
|------|-----|-------|
| `ui/map_metadata_editor.gd` | 1,516 | Map editor |
| `ui/battle_editor.gd` | 1,404 | Battle editor **(+263 recent)** |
| `ui/cinematic_editor.gd` | 1,230 | Cinematic editor **(+883 recent)** |
| `ui/party_editor.gd` | 1,174 | Party editor |
| `ui/campaign_editor.gd` | 1,149 | Campaign editor |
| `ui/components/battle_map_preview.gd` | 706 | Battle map preview **(NEW)** |

**Review Focus**: Complex state management, visual previews, GraphEdit usage

#### Sub-Chunk 16C: Standard Resource Editors
**LOC**: ~4,398

| File | LOC | Notes |
|------|-----|-------|
| `ui/mod_json_editor.gd` | 1,104 | mod.json editor |
| `ui/dialogue_editor.gd` | 793 | Dialogue editor |
| `ui/class_editor.gd` | 565 | Class editor **(+147 recent)** |
| `ui/ability_editor.gd` | 530 | Ability editor |
| `ui/terrain_editor.gd` | 526 | Terrain editor **(NEW)** |
| `ui/character_editor.gd` | 492 | Character editor |
| `ui/item_editor.gd` | 462 | Item editor |

**Review Focus**: Field validation, resource saving, consistency

#### Sub-Chunk 16D: Editor Components
**LOC**: ~703

| File | LOC | Notes |
|------|-----|-------|
| `ui/components/resource_picker.gd` | 454 | Resource selection |
| `ui/components/dialog_line_popup.gd` | 249 | Dialog line popup |

**Review Focus**: Reusable component patterns, cross-editor usage

---

### Chunk 17: Test Suite
**Priority**: Medium
**LOC**: ~6,698
**Dependencies**: All systems under test

**Test Infrastructure**:
| File | LOC |
|------|-----|
| `tests/test_runner_scene.gd` | 1,250 |
| `tests/test_runner.gd` | 528 |

**Unit Tests by Area**:
| Test File | LOC | Coverage |
|-----------|-----|----------|
| `unit/combat/test_combat_calculator.gd` | 545 | Combat formulas |
| `unit/promotion/test_promotion_manager.gd` | 431 | Promotions |
| `unit/crafting/test_crafting_recipe_data.gd` | 429 | Crafting |
| `unit/map/test_map_metadata_loader.gd` | 393 | Map loading |
| `unit/map/test_map_metadata.gd` | 346 | Map resources |
| `unit/crafting/test_material_spawn_data.gd` | 313 | Materials |
| `unit/map/test_spawn_point.gd` | 294 | Spawn points |
| `unit/crafting/test_crafter_data.gd` | 259 | Crafters |
| `unit/equipment/test_character_save_equipment.gd` | 251 | Save/load |
| `unit/equipment/test_unit_stats_equipment.gd` | 229 | Stat equip |
| `unit/crafting/test_rare_material_data.gd` | 210 | Rare mats |
| `unit/equipment/test_equipment_slot_registry.gd` | 190 | Equip slots |
| `unit/mod_system/test_namespaced_flags.gd` | 189 | Flag namespaces |
| `unit/equipment/test_item_data_equipment.gd` | 183 | Item equip |
| `unit/mod_system/test_tileset_resolution.gd` | 170 | Tileset loading |
| `unit/mod_system/test_trigger_type_registry.gd` | 153 | Trigger types |
| `unit/equipment/test_inventory_config.gd` | 103 | Inventory |

**Integration Tests**:
| File | LOC | Coverage |
|------|-----|----------|
| `integration/battle/test_battle_flow.gd` | 232 | Battle flow |

**Review Focus**:
- Test coverage gaps
- Test isolation
- Mock usage
- Edge case coverage

---

## Recommended Review Order

### Phase 1: Critical Foundation (Chunks 1-5, 9)
1. **Mod System** (Chunk 5) - Everything depends on this
2. **Battle System Core** (Chunk 1)
3. **Battle Input & Grid** (Chunk 2)
4. **Unit System** (Chunk 3)
5. **Save System** (Chunk 9)

### Phase 2: Game Systems (Chunks 6-8, 10-13)
6. **Party & Progression** (Chunk 7)
7. **Equipment & Inventory** (Chunk 8)
8. **Dialog & Cinematics** (Chunk 10)
9. **Campaign System** (Chunk 12)
10. **Map & Scene Management** (Chunk 13)
11. **Type Registries** (Chunk 6)
12. **Cinematic Commands** (Chunk 11)
13. **AI & Enemy Behavior** (Chunk 4)

### Phase 3: Presentation Layer (Chunks 14-15)
14. **Battle UI** (Chunk 14)
15. **Map Exploration** (Chunk 15)

### Phase 4: Tooling (Chunks 16-17)
16. **Editor Plugin** (Chunk 16A-D) - Recently expanded significantly
17. **Test Suite** (Chunk 17)

---

## Recent Changes (Last 5 Commits)

These files have been recently modified and may warrant priority review:

| File | Change | LOC Now |
|------|--------|---------|
| `cinematic_editor.gd` | +883 lines (visual editor) | 1,230 |
| `battle_map_preview.gd` | NEW (click-to-place) | 706 |
| `class_editor.gd` | +147 lines (learnable abilities) | 565 |
| `terrain_editor.gd` | NEW | 526 |
| `battle_editor.gd` | +277 lines (map preview) | 1,404 |
| `mods/_template/` | NEW (mod template) | N/A |

---

## High-Risk Files (Extra Scrutiny Recommended)

These files are either large, complex, or critical to system stability:

| File | LOC | Risk Factor |
|------|-----|-------------|
| `input_manager.gd` | 1,784 | Largest file, complex state machine |
| `map_metadata_editor.gd` | 1,516 | Complex editor, map handling |
| `battle_editor.gd` | 1,404 | Recently expanded, visual preview |
| `cinematic_editor.gd` | 1,230 | Recently tripled in size |
| `party_editor.gd` | 1,174 | Complex party management UI |
| `campaign_editor.gd` | 1,149 | GraphEdit-based node editor |
| `battle_manager.gd` | 1,084 | Battle orchestration |
| `mod_json_editor.gd` | 1,104 | Mod manifest editing |
| `mod_loader.gd` | 753 | All content loading |
| `battle_map_preview.gd` | 706 | New visual component |
| `campaign_manager.gd` | 689 | Campaign state |

---

## Coverage Gaps to Investigate

During review, pay attention to potential missing test coverage for:
- `input_manager.gd` - No direct tests visible
- `battle_manager.gd` - Only integration test
- `grid_manager.gd` - No tests in `tests/unit/grid/`
- `cinematics_manager.gd` - No tests visible
- `campaign_manager.gd` - No tests visible
- `party_manager.gd` - No tests visible
- **All editor files** - No editor tests visible

---

*"Logic is the beginning of wisdom, not the end." - Spock*

*Report complete. Ready to commence systematic review at your command, Captain.*
