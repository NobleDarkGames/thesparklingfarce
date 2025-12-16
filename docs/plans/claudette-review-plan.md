# Lt. Claudette Comprehensive Code Review Plan

**Mission**: Systematic code review of the Sparkling Farce codebase
**Total Scope**: ~241 GDScript files, ~73,000 LOC
**Estimated Phases**: 8 phases, each reviewable in a single session

---

## Review Standards Checklist

Every phase must verify:

### Mandatory Code Standards
- [ ] Strict typing: `var x: float = 5.0` (NOT `var x := 5.0`)
- [ ] Dictionary checks: `if "key" in dict:` (NOT `if dict.has("key"):`)
- [ ] GDScript style guide compliance
- [ ] No game content in `core/` (platform code only)

### Architecture Standards
- [ ] Registry access pattern used for resources (NOT direct `load()`)
- [ ] Signals properly typed and documented
- [ ] No circular dependencies
- [ ] Appropriate use of singletons vs. static classes

### Quality Standards
- [ ] No dead code or unused variables
- [ ] Error handling for edge cases
- [ ] Comments for non-obvious logic only
- [ ] Consistent naming conventions

---

## Phase 1: Platform Infrastructure (Critical Foundation)

**Priority**: HIGHEST - All other code depends on this
**Files**: 15 files, ~2,600 LOC
**Focus**: Mod loading, registry patterns, core architecture

### Files to Review

```
core/mod_system/
├── mod_loader.gd          (1,368 LOC) ⚠️ HOTSPOT
├── mod_manifest.gd
└── mod_registry.gd
```

### Review Focus
1. **mod_loader.gd** - Critical path for all content loading
   - Mod discovery algorithm correctness
   - Priority resolution for overlapping resources
   - Error handling for malformed mods
   - Resource caching strategy

2. **mod_registry.gd** - Resource lookup patterns
   - Thread safety if applicable
   - Memory management
   - Duplicate ID handling

3. **mod_manifest.gd** - Manifest parsing
   - JSON schema validation
   - Default value handling
   - Version compatibility checks

### Command for Lt. Claudette
```
Review Phase 1: Platform Infrastructure

Focus on: core/mod_system/ (3 files)

Critical questions:
- Does mod_loader.gd correctly handle mod priority conflicts?
- Are all error paths properly handled?
- Is resource caching efficient and correct?
- Does the registry pattern support all documented resource types?

Apply all mandatory code standards from the review checklist.
```

---

## Phase 2: Type Registries (Content Registration)

**Priority**: HIGH - Defines how content plugs into platform
**Files**: 12 files, ~1,500 LOC
**Focus**: Registry pattern consistency, type safety

### Files to Review

```
core/registries/
├── ai_brain_registry.gd
├── ai_mode_registry.gd
├── ai_role_registry.gd
├── animation_offset_registry.gd
├── equipment_registry.gd
├── equipment_slot_registry.gd
├── equipment_type_registry.gd
├── status_effect_registry.gd
├── terrain_registry.gd
├── tileset_registry.gd
├── trigger_type_registry.gd
└── unit_category_registry.gd
```

### Review Focus
1. Consistent API across all registries
2. Proper error messages for missing keys
3. Thread safety considerations
4. No duplicate registration silently overwriting
5. Proper typing on all getter/setter methods

### Command for Lt. Claudette
```
Review Phase 2: Type Registries

Focus on: core/registries/ (12 files)

Critical questions:
- Do all registries follow consistent API patterns?
- Are registration conflicts handled appropriately?
- Are return types properly typed?
- Is error handling consistent across registries?

Apply all mandatory code standards from the review checklist.
```

---

## Phase 3: Core Resource Definitions (Data Layer)

**Priority**: HIGH - Defines all game data structures
**Files**: 32 files, ~6,800 LOC
**Focus**: Type safety, serialization, defaults

### Files to Review

```
core/resources/
├── character_data.gd
├── character_save_data.gd     (503 LOC)
├── class_data.gd
├── ability_data.gd
├── item_data.gd
├── combat_animation_data.gd
├── combat_formula_config.gd
├── combat_phase.gd
├── ai_behavior_data.gd
├── ai_brain.gd
├── map_metadata.gd            (535 LOC)
├── battle_data.gd
├── campaign_data.gd
├── campaign_node.gd
├── grid.gd
├── terrain_data.gd
├── equipment_data.gd (various)
├── status_effect_data.gd
├── experience_config.gd
├── shop_data.gd
├── crafting_recipe_data.gd
├── crafter_data.gd
├── rare_material_data.gd
├── material_spawn_data.gd
├── cinematic_data.gd
├── dialogue_data.gd
├── npc_data.gd
├── party_data.gd
├── transition_context.gd
└── new_game_config_data.gd
```

### Review Focus
1. All `@export` properties properly typed
2. Reasonable defaults for all fields
3. Serialization compatibility (save/load)
4. Documentation of field purposes
5. Validation logic where appropriate

### Command for Lt. Claudette
```
Review Phase 3: Core Resource Definitions

Focus on: core/resources/ (32 files)

Critical questions:
- Are all @export variables strictly typed?
- Do resources have sensible defaults?
- Is save/load serialization handled correctly?
- Are complex fields documented?

Apply all mandatory code standards from the review checklist.
```

---

## Phase 4A: Battle Systems (Combat Core)

**Priority**: CRITICAL - Core gameplay loop
**Files**: 8 files, ~5,500 LOC
**Focus**: Combat flow, turn management, damage calculations

### Files to Review

```
core/systems/
├── battle_manager.gd          (2,148 LOC) ⚠️ HOTSPOT
├── turn_manager.gd            (591 LOC)
├── grid_manager.gd            (675 LOC)
├── ai_controller.gd
└── ai/
    ├── configurable_ai_brain.gd (1,292 LOC) ⚠️ HOTSPOT
    └── ai_role_behavior.gd

core/utils/
└── combat_calculator.gd       (static utility)
```

### Review Focus
1. State machine correctness in battle_manager
2. Turn order algorithm (AGI-based)
3. A* pathfinding implementation
4. AI decision-making logic
5. Damage formula accuracy
6. Signal flow between systems

### Command for Lt. Claudette
```
Review Phase 4A: Battle Systems

Focus on: core/systems/battle_manager.gd, turn_manager.gd, grid_manager.gd,
         ai_controller.gd, core/systems/ai/ (2 files), core/utils/combat_calculator.gd

Critical questions:
- Is the battle state machine complete and correct?
- Does turn order calculation match SF2 mechanics?
- Is A* pathfinding efficient for grid sizes used?
- Are all AI decision paths properly handled?
- Are combat formulas mathematically sound?

Apply all mandatory code standards from the review checklist.
```

---

## Phase 4B: Input & Exploration Systems

**Priority**: HIGH - User interaction layer
**Files**: 6 files, ~3,500 LOC
**Focus**: State machines, input handling, player control

### Files to Review

```
core/systems/
├── input_manager.gd           (2,295 LOC) ⚠️ HOTSPOT - LARGEST FILE
└── input_manager_helpers.gd   (extracted utilities)

scenes/map_exploration/
├── hero_controller.gd         (544 LOC)
├── map_test_playable.gd       (463 LOC)
└── (other exploration files)
```

### Review Focus
1. Input state machine completeness
2. Edge cases in input handling
3. Keybinding system flexibility
4. Movement and collision logic
5. Mode transitions (explore vs. battle)

### Command for Lt. Claudette
```
Review Phase 4B: Input & Exploration Systems

Focus on: core/systems/input_manager.gd, input_manager_helpers.gd,
         scenes/map_exploration/ (all .gd files)

Critical questions:
- Is the input state machine handling all modes correctly?
- Are there any input edge cases that could cause soft locks?
- Is keybinding customization properly implemented?
- Is hero movement responsive and collision-correct?

Apply all mandatory code standards from the review checklist.
```

---

## Phase 5: Party & Progression Systems

**Priority**: HIGH - Character management
**Files**: 10 files, ~3,500 LOC
**Focus**: Party logic, equipment, leveling, shops

### Files to Review

```
core/systems/
├── party_manager.gd           (732 LOC)
├── equipment_manager.gd
├── experience_manager.gd      (545 LOC)
├── promotion_manager.gd       (531 LOC)
├── shop_manager.gd            (771 LOC)
├── shop_controller.gd
├── storage_manager.gd
└── inventory_manager.gd
```

### Review Focus
1. Party composition rules
2. Equipment slot validation
3. XP distribution algorithms
4. Level-up stat calculations
5. Shop transaction integrity
6. Item duplication prevention

### Command for Lt. Claudette
```
Review Phase 5: Party & Progression Systems

Focus on: core/systems/party_manager.gd, equipment_manager.gd,
         experience_manager.gd, promotion_manager.gd, shop_manager.gd,
         shop_controller.gd, storage_manager.gd, inventory_manager.gd

Critical questions:
- Can party composition rules be circumvented?
- Is equipment validation complete (cursed items, class restrictions)?
- Is XP distribution fair and correct?
- Are shop transactions atomic (no item duplication)?
- Is inventory capacity enforced everywhere?

Apply all mandatory code standards from the review checklist.
```

---

## Phase 6: Narrative & Campaign Systems

**Priority**: MEDIUM - Content delivery
**Files**: 8 files, ~2,800 LOC
**Focus**: Dialogue, cinematics, campaign progression

### Files to Review

```
core/systems/
├── dialog_manager.gd
├── cinematics_manager.gd      (583 LOC)
├── campaign_manager.gd        (727 LOC)
├── trigger_manager.gd
├── game_state.gd
├── caravan_controller.gd      (919 LOC)
└── cinematic_commands/        (15 files, ~1,500 LOC)
    ├── base_command.gd
    ├── wait_command.gd
    ├── dialog_command.gd
    └── (etc.)
```

### Review Focus
1. Dialogue state machine
2. Cinematic command execution
3. Campaign branching logic
4. Save/restore of narrative state
5. Trigger fire conditions
6. Caravan lifecycle management

### Command for Lt. Claudette
```
Review Phase 6: Narrative & Campaign Systems

Focus on: core/systems/dialog_manager.gd, cinematics_manager.gd,
         campaign_manager.gd, trigger_manager.gd, game_state.gd,
         caravan_controller.gd, core/systems/cinematic_commands/ (all files)

Critical questions:
- Is dialogue state properly saved/restored?
- Can cinematics be interrupted safely?
- Is campaign progression tracked correctly?
- Are triggers firing at correct times and only once when intended?
- Is caravan state consistent across scene transitions?

Apply all mandatory code standards from the review checklist.
```

---

## Phase 7: UI Systems (Part 1 - Major Panels)

**Priority**: HIGH - User-facing quality
**Files**: 15 files, ~6,000 LOC
**Focus**: Major menu panels, combat UI

### Files to Review

```
scenes/ui/
├── combat_animation_scene.gd  (957 LOC)
├── inventory_panel.gd         (930 LOC)
├── caravan_depot_panel.gd     (872 LOC)
├── party_management_panel.gd  (624 LOC)
├── party_equipment_menu.gd    (579 LOC)
├── item_menu.gd               (516 LOC)
├── exploration_field_menu.gd  (513 LOC)
├── spell_menu.gd              (476 LOC)
├── item_action_menu.gd        (408 LOC)
├── caravan_main_menu.gd       (404 LOC)
└── members/screens/
    └── member_detail.gd       (705 LOC)
```

### Review Focus
1. UI state machine correctness
2. Input handling in menus
3. Data binding to game state
4. Animation and transition flow
5. Accessibility considerations
6. Memory management (freeing panels)

### Command for Lt. Claudette
```
Review Phase 7: UI Systems (Major Panels)

Focus on: scenes/ui/ - The 11 largest panel files listed above

Critical questions:
- Are UI state machines handling all transitions?
- Is input consumed correctly (no pass-through)?
- Are panels properly freed when closed?
- Is data binding reactive to state changes?
- Are there any potential UI soft locks?

Apply all mandatory code standards from the review checklist.
```

---

## Phase 8: UI Systems (Part 2 - Components & Supporting)

**Priority**: MEDIUM - Supporting UI code
**Files**: ~45 files, ~10,000 LOC
**Focus**: Reusable components, dialogs, shops

### Files to Review

```
scenes/ui/
├── shops/                     (shop-related UI)
├── components/                (reusable widgets)
├── dialogs/                   (dialog boxes)
├── equipment/                 (equipment UI)
├── status/                    (status displays)
└── (remaining UI files)
```

### Review Focus
1. Component reusability
2. Signal connections
3. Theme compliance
4. Edge case handling
5. Performance (no unnecessary updates)

### Command for Lt. Claudette
```
Review Phase 8: UI Systems (Components & Supporting)

Focus on: scenes/ui/ - All remaining .gd files not covered in Phase 7

Critical questions:
- Are components properly reusable?
- Are signals properly disconnected on free?
- Is theming consistent?
- Are edge cases (empty lists, null data) handled?

Apply all mandatory code standards from the review checklist.
```

---

## Supplementary Phases (Optional)

### Phase S1: Editor Addon

**Files**: 37 files in `addons/sparkling_editor/`
**Focus**: Editor tools, inspector plugins

### Phase S2: Test Suite Quality

**Files**: 47 test files in `tests/`
**Focus**: Test coverage, test quality, mock patterns

### Phase S3: Components & Templates

**Files**: `core/components/` (10 files), `core/templates/` (1 file)
**Focus**: Reusable game object components

---

## Execution Guide

### For Each Phase

1. **Invoke Lt. Claudette** with the phase command
2. **Capture findings** in a structured report
3. **Triage issues** by severity:
   - 🔴 Critical: Bugs, security issues, data corruption risks
   - 🟠 Major: Code standard violations, architectural issues
   - 🟡 Minor: Style issues, optimization opportunities
   - 🔵 Suggestion: Improvements, refactoring ideas
4. **Create issues** or fix immediately based on severity

### Invocation Template

```
/claudette Phase X: [Phase Name]

Files to review: [list from phase]

Standards checklist:
- Strict typing required
- Dictionary checks use "in" operator
- Registry access pattern (not direct load)
- No dead code
- Proper error handling

Focus areas: [from phase review focus]

Report findings in format:
- File:Line - Severity - Issue description
```

---

## Summary

| Phase | Area | Files | LOC | Priority |
|-------|------|-------|-----|----------|
| 1 | Platform Infrastructure | 3 | 2,600 | CRITICAL |
| 2 | Type Registries | 12 | 1,500 | HIGH |
| 3 | Resource Definitions | 32 | 6,800 | HIGH |
| 4A | Battle Systems | 8 | 5,500 | CRITICAL |
| 4B | Input & Exploration | 6 | 3,500 | HIGH |
| 5 | Party & Progression | 8 | 3,500 | HIGH |
| 6 | Narrative & Campaign | 8+ | 2,800 | MEDIUM |
| 7 | UI (Major Panels) | 11 | 6,000 | HIGH |
| 8 | UI (Components) | ~45 | 10,000 | MEDIUM |

**Total**: ~133 core files, ~42,200 LOC in main phases
**Supplementary**: 84 files (editor, tests, components)
