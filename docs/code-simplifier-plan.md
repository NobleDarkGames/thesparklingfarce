# Code Simplifier Agent Execution Plan

This document outlines a prioritized plan for running the code-simplifier agent through the codebase in manageable batches.

## Summary Statistics

| Area | Files | Total Lines | Largest File |
|------|-------|-------------|--------------|
| core/systems/ | ~30 | ~15,000 | input_manager.gd (2332) |
| core/components/ | 13 | ~4,500 | unit.gd (796) |
| core/resources/ | ~25 | ~6,500 | character_save_data.gd (554) |
| core/registries/ | 11 | ~2,700 | equipment_type_registry.gd (478) |
| core/mod_system/ | 3 | ~2,300 | mod_loader.gd (1326) |
| core/utils/ | 6 | ~395 | ui_colors.gd (110) |
| scenes/ui/ | ~50 | ~12,000 | combat_animation_scene.gd (1130) |
| addons/sparkling_editor/ | ~40 | ~20,000 | cinematic_editor.gd (2264) |

---

## Batch Execution Plan

### Phase 1: Core Infrastructure (High Priority)

These files are foundational and frequently touched. Simplifying them yields high leverage.

#### Batch 1.1: Largest System Files (Critical)
**Scope**: 4 files, ~7,000 lines
**Risk**: High - core gameplay systems
**Dependencies**: Review before Batch 1.2

| File | Lines | Recent Commits | Notes |
|------|-------|----------------|-------|
| `core/systems/input_manager.gd` | 2332 | 24 | Largest file in codebase |
| `core/systems/battle_manager.gd` | 2025 | 56 | Most frequently modified |
| `core/systems/ai/configurable_ai_brain.gd` | 1365 | 16 | Complex AI logic |
| `core/systems/cinematics_manager.gd` | 1190 | 37 | High dependency count (42 loads) |

**Simplification Focus**:
- Extract helper classes/functions
- Reduce method complexity
- Identify state machine patterns that could be extracted

---

#### Batch 1.2: Mod System
**Scope**: 3 files, ~2,300 lines
**Risk**: High - affects all resource loading
**Dependencies**: Review after Batch 1.1

| File | Lines | Recent Commits | Notes |
|------|-------|----------------|-------|
| `core/mod_system/mod_loader.gd` | 1326 | 41 | Central to platform |
| `core/mod_system/mod_registry.gd` | 567 | 11 | Resource registry |
| `core/mod_system/mod_manifest.gd` | 430 | 14 | Mod metadata parsing |

**Simplification Focus**:
- Reduce loader complexity
- Extract validation logic
- Consolidate error handling patterns

---

#### Batch 1.3: Secondary System Files
**Scope**: 6 files, ~4,700 lines
**Risk**: Medium
**Dependencies**: Can run parallel to Batch 1.2

| File | Lines | Recent Commits | Notes |
|------|-------|----------------|-------|
| `core/systems/debug_console.gd` | 1169 | 13 | Standalone utility |
| `core/templates/map_template.gd` | 968 | 21 | Map scene logic |
| `core/systems/caravan_controller.gd` | 962 | 13 | Exploration mode |
| `core/systems/shop_manager.gd` | 916 | 11 | Shop transactions |
| `core/systems/party_manager.gd` | 864 | 19 | Party state management |
| `core/systems/turn_manager.gd` | 711 | 18 | Battle turn logic |

**Simplification Focus**:
- Extract reusable patterns
- Reduce method lengths
- Identify duplicate logic across managers

---

### Phase 2: Components and Resources

#### Batch 2.1: Core Components
**Scope**: 7 files, ~3,500 lines
**Risk**: Medium - used throughout UI and systems
**Dependencies**: Review after Phase 1

| File | Lines | Recent Commits | Notes |
|------|-------|----------------|-------|
| `core/components/unit.gd` | 796 | 15 | Battle unit logic |
| `core/components/npc_node.gd` | 768 | 14 | NPC behavior |
| `core/components/unit_stats.gd` | 548 | 11 | Stats calculations |
| `core/components/caravan_follower.gd` | 480 | - | Movement following |
| `core/components/cinematic_actor.gd` | 462 | 14 | Cutscene actors |
| `core/components/interactable_node.gd` | 462 | - | Interaction handling |
| `core/components/exploration_ui_controller.gd` | 454 | - | UI coordination |

**Simplification Focus**:
- Reduce coupling between components
- Extract shared behavior to base classes
- Simplify signal connections

---

#### Batch 2.2: Resource Definitions
**Scope**: 8 files, ~3,300 lines
**Risk**: Low - mostly data structures
**Dependencies**: None

| File | Lines | Notes |
|------|-------|-------|
| `core/resources/character_save_data.gd` | 554 | Save/load serialization |
| `core/resources/map_metadata.gd` | 517 | Map configuration |
| `core/resources/save_data.gd` | 476 | Game state persistence |
| `core/resources/cinematic_data.gd` | 399 | Cutscene definitions |
| `core/resources/combat_phase.gd` | 369 | Combat animation data |
| `core/resources/shop_data.gd` | 322 | Shop configuration |
| `core/resources/ai_behavior_data.gd` | 292 | AI config resources |
| `core/resources/interactable_data.gd` | 288 | Interactable config |

**Simplification Focus**:
- Consolidate validation methods
- Extract common serialization patterns
- Reduce getter/setter boilerplate

---

#### Batch 2.3: Registries
**Scope**: 5 files, ~1,600 lines
**Risk**: Low - lookup tables
**Dependencies**: None

| File | Lines | Notes |
|------|-------|-------|
| `core/registries/equipment_type_registry.gd` | 478 | Equipment slot logic |
| `core/registries/ai_brain_registry.gd` | 354 | AI brain factory |
| `core/registries/tileset_registry.gd` | 331 | Tileset management |
| `core/registries/status_effect_registry.gd` | 259 | Status effect lookup |
| `core/registries/ai_mode_registry.gd` | 245 | AI mode definitions |

**Simplification Focus**:
- Identify common registry patterns
- Extract base registry class if not present
- Reduce registration boilerplate

---

### Phase 3: UI Layer

#### Batch 3.1: Major UI Panels
**Scope**: 6 files, ~4,800 lines
**Risk**: Medium - user-facing
**Dependencies**: Review after Phase 2

| File | Lines | Recent Commits | Notes |
|------|-------|----------------|-------|
| `scenes/ui/combat_animation_scene.gd` | 1130 | 16 | Battle animations |
| `scenes/ui/inventory_panel.gd` | 935 | 9 | Inventory management |
| `scenes/ui/caravan_depot_panel.gd` | 871 | 8 | Depot interface |
| `scenes/ui/party_management_panel.gd` | 684 | 6 | Party roster |
| `scenes/ui/shared/character_detail_base.gd` | 683 | - | Character info base |
| `scenes/ui/battle_game_menu.gd` | 553 | - | Battle menu |

**Simplification Focus**:
- Extract common UI patterns
- Reduce signal callback complexity
- Consolidate item display logic

---

#### Batch 3.2: Shop System UI
**Scope**: 10 files, ~2,600 lines
**Risk**: Low-Medium
**Dependencies**: Can run parallel to Batch 3.1

| File | Lines | Notes |
|------|-------|-------|
| `scenes/ui/shops/screens/crafter_recipe_browser.gd` | 318 | Recipe browsing |
| `scenes/ui/shops/screens/church_char_select.gd` | 309 | Character selection |
| `scenes/ui/shops/screens/item_browser.gd` | 299 | Item browsing |
| `scenes/ui/shops/screens/church_save_confirm.gd` | 295 | Save confirmation |
| `scenes/ui/shops/screens/placement_mode.gd` | 281 | Item placement |
| `scenes/ui/shops/screens/church_promote_select.gd` | 281 | Promotion selection |
| `scenes/ui/shops/shop_controller.gd` | 249 | Shop state machine |
| `scenes/ui/shops/screens/sell_inventory.gd` | 217 | Sell interface |
| `scenes/ui/shops/screens/transaction_result.gd` | 213 | Transaction display |
| `scenes/ui/shops/shop_context.gd` | 211 | Shop state context |

**Simplification Focus**:
- Identify duplicate screen patterns
- Extract shared browse/select logic
- Consolidate transaction handling

---

#### Batch 3.3: Menu Systems
**Scope**: 8 files, ~3,200 lines
**Risk**: Low-Medium
**Dependencies**: None

| File | Lines | Notes |
|------|-------|-------|
| `scenes/ui/exploration_field_menu.gd` | 519 | Field menu |
| `scenes/ui/item_menu.gd` | 518 | Item actions |
| `scenes/ui/battle_map_overlay.gd` | 479 | Battle HUD |
| `scenes/ui/spell_menu.gd` | 476 | Spell selection |
| `scenes/ui/item_action_menu.gd` | 417 | Item use menu |
| `scenes/ui/caravan_main_menu.gd` | 405 | Caravan hub |
| `scenes/ui/action_menu.gd` | 387 | Unit actions |
| `scenes/ui/dialog_box.gd` | 365 | Dialog display |

**Simplification Focus**:
- Extract menu base class patterns
- Consolidate keyboard navigation logic
- Reduce state management complexity

---

### Phase 4: Editor Addon (Lower Priority)

Note: Recently cleaned up per git history. May have fewer opportunities.

#### Batch 4.1: Large Editor Files
**Scope**: 5 files, ~7,900 lines
**Risk**: Low - development tooling
**Dependencies**: None

| File | Lines | Notes |
|------|-------|-------|
| `addons/sparkling_editor/ui/cinematic_editor.gd` | 2264 | Cutscene editor |
| `addons/sparkling_editor/ui/base_resource_editor.gd` | 1783 | Editor base class |
| `addons/sparkling_editor/ui/character_editor.gd` | 1518 | Character editing |
| `addons/sparkling_editor/ui/battle_editor.gd` | 1320 | Battle configuration |
| `addons/sparkling_editor/ui/new_game_config_editor.gd` | 1130 | New game setup |

**Simplification Focus**:
- Push common logic to base_resource_editor
- Extract form-building patterns
- Reduce UI construction boilerplate

---

#### Batch 4.2: Secondary Editor Files
**Scope**: 8 files, ~5,700 lines
**Risk**: Low
**Dependencies**: Review after Batch 4.1

| File | Lines | Notes |
|------|-------|-------|
| `addons/sparkling_editor/ui/map_metadata_editor.gd` | 1093 | Map editor |
| `addons/sparkling_editor/ui/interactable_editor.gd` | 1059 | Interactable config |
| `addons/sparkling_editor/ui/mod_json_editor.gd` | 1038 | Mod metadata |
| `addons/sparkling_editor/ui/save_slot_editor.gd` | 978 | Save editing |
| `addons/sparkling_editor/ui/main_panel.gd` | 882 | Editor main panel |
| `addons/sparkling_editor/ui/npc_editor.gd` | 819 | NPC configuration |
| `addons/sparkling_editor/ui/crafting_recipe_editor.gd` | 798 | Recipe editor |
| `addons/sparkling_editor/ui/dialogue_editor.gd` | 792 | Dialogue trees |

---

### Phase 5: Tertiary Systems

#### Batch 5.1: Remaining Systems
**Scope**: 8 files, ~3,500 lines
**Risk**: Low
**Dependencies**: None

| File | Lines | Notes |
|------|-------|-------|
| `core/systems/grid_manager.gd` | 700 | Grid calculations |
| `core/systems/promotion_manager.gd` | 623 | Class promotions |
| `core/systems/save_manager.gd` | 597 | Save/load orchestration |
| `core/systems/audio_manager.gd` | 566 | Sound playback |
| `core/systems/experience_manager.gd` | 551 | XP/leveling |
| `core/systems/trigger_manager.gd` | 523 | Event triggers |
| `core/systems/game_state.gd` | 522 | Global state |
| `core/systems/combat_calculator.gd` | 473 | Damage formulas |

---

#### Batch 5.2: Caravan & Members UI
**Scope**: 12 files, ~2,400 lines
**Risk**: Low
**Dependencies**: None

Files from `scenes/ui/caravan/` and `scenes/ui/members/` directories.

---

## Execution Guidelines

### Before Each Batch

1. **Run tests**: `diagnostics` to establish baseline
2. **Check git status**: Ensure clean working tree
3. **Note dependencies**: Which other files import from batch targets

### During Review

Focus areas for code-simplifier:
- Methods over 50 lines
- Classes over 500 lines
- Duplicate code blocks
- Complex conditionals (nested if/match)
- Long parameter lists
- Dead code or commented-out blocks

### After Each Batch

1. **Run tests**: Verify no regressions
2. **Manual smoke test**: If UI changes
3. **Review diff**: Ensure changes are improvements
4. **Stage changes**: Do not commit without approval

---

## Recommended Execution Order

```
Week 1: Phase 1 (Core Infrastructure)
  - Batch 1.1 -> Batch 1.2 -> Batch 1.3

Week 2: Phase 2 (Components/Resources) + Phase 3.1
  - Batch 2.1 -> Batch 2.2 (parallel: Batch 2.3)
  - Batch 3.1

Week 3: Phase 3 (UI) remaining
  - Batch 3.2 -> Batch 3.3

Week 4: Phase 4-5 (Editor + Tertiary)
  - Batch 4.1 -> Batch 4.2
  - Batch 5.1 -> Batch 5.2
```

---

## Files to Skip

These are small, stable, or recently cleaned:
- `core/utils/*` - Small utility files (395 total lines)
- `core/systems/game_juice.gd` - Minimal, effect-only
- `core/systems/game_event_bus.gd` - Simple signal hub
- `scenes/ui/shops/screens/shop_screen_base.gd` - Small base class (54 lines)
- `scenes/ui/caravan/screens/caravan_screen_base.gd` - Small base class (77 lines)

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking changes | Run full test suite after each batch |
| Scope creep | Stick to simplification only, no new features |
| Lost context | Document architectural decisions in code comments |
| Merge conflicts | Complete batches before other development work |

---

## Success Metrics

- Reduced average file size by 10-20%
- Reduced cyclomatic complexity in flagged methods
- No increase in test failures
- Maintained or improved code coverage
