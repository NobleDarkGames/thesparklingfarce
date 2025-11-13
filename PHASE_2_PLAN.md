# Phase 2 Plan - Additional Editors & Runtime Foundation

## Overview

Phase 2 builds upon the solid foundation from Phase 1 by completing the editor toolset and beginning runtime systems. This phase focuses on three additional editors (Ability, Dialogue, Battle) and laying groundwork for the tactical battle engine.

**Status**: In Progress
**Started**: November 13, 2024
**Phase 1 Completion**: November 12, 2024

---

## Recent Progress

### ✅ Editor Refactoring (November 13, 2024 - Morning)
- Created `base_resource_editor.gd` to eliminate code duplication
- Refactored all three existing editors to extend base class
- Reduced codebase by 352 lines (-24%)
- Fixed critical bug in save operation (bounds checking)
- Established template method pattern for future editors

**Benefits**:
- DRY principle applied to all editor code
- Future editors require only ~300 lines instead of ~500+
- Consistent behavior across all editors
- Centralized bug fixes and improvements

### ✅ Ability Editor (November 13, 2024 - Afternoon)
**Status: COMPLETE & TESTED**
- Implemented `ability_editor.gd` (286 lines)
- Created scene file and added to main panel
- Supports all AbilityData properties
- Comprehensive validation and reference checking
- Manual testing confirmed all functionality working

### ✅ Dialogue Editor (November 13, 2024 - Afternoon)
**Status: COMPLETE & TESTED**
- Implemented `dialogue_editor.gd` (547 lines)
- Dynamic line management (Add/Remove/Move Up/Down)
- Simple yes/no branching with choices
- Non-programmer friendly interface
- Manual testing confirmed basic functionality

**Bug Fixed During Development**:
- Auto-select newly created resources in base class
- Eliminated "No resource selected" warning on creation
- Improved UX by automatically loading new resources for editing

---

---

## Current Status (November 13, 2024)

### ✅ Completed Editors (5 of 6)
1. **Character Editor** - Refactored, tested ✅
2. **Class Editor** - Refactored, tested ✅
3. **Item Editor** - Refactored, tested ✅
4. **Ability Editor** - Complete, tested ✅
5. **Dialogue Editor** - Complete, tested ✅

### 🔴 Remaining Work

#### Battle Editor (NEXT - After Bug Fix)
**Status**: Not started
**Complexity**: Very High
**Estimated**: 450-500 lines

**Known Bug to Fix First**:
There is a bug that needs to be addressed before implementing the Battle Editor. The specific bug details should be documented here before proceeding.

**Battle Editor Approach**:
- Start simple: Form-based editing without visual grid
- Unit placement via list with x/y coordinates
- Defer visual grid editor to Phase 3
- Focus on making battle scenarios editable, not beautiful

---

## Phase 2 Goals

### Priority 1: Complete Editor Toolset

#### 1. Ability Editor ✅ COMPLETE
**Complexity**: Medium
**Estimated Lines**: ~280 (using base class)

Allows editing of `AbilityData` resources (skills, spells, attacks).

**Features**:
- Basic info: Name, description, icon
- Ability type selection (Attack, Heal, Support, Debuff, Special)
- Target type selection (Single Enemy, Single Ally, Self, All Enemies, All Allies, Area)
- Range configuration (min/max range)
- Area of effect settings
- Status effects with duration and chance
- Cost system (MP and/or HP cost)
- Animation and audio references

**UI Sections**:
1. Basic Information
2. Type & Targeting
3. Range & Area of Effect
4. Costs & Effects
5. Status Effects (dynamic list)
6. Visual & Audio

**Validation**:
- Name cannot be empty
- Max range >= min range
- Area of effect >= 0
- Cost values cannot be negative
- At least one valid target type

**Reference Checking**:
- Check ClassData learnable_abilities
- Check ItemData consumable_effect
- Check CharacterData (future: known_abilities)

---

#### 2. Dialogue Editor ⏳ PLANNED
**Complexity**: Medium-High
**Estimated Lines**: ~350 (using base class)

Allows editing of `DialogueData` resources (conversations, cutscenes).

**Features**:
- Line-by-line dialogue creation
- Multiple speakers with portraits
- Emotion/expression selection
- Branching choice system
- Auto-advance toggle
- Audio integration (BGM, text sounds)

**UI Sections**:
1. Basic Information (title, description)
2. Dialogue Lines (scrollable list)
   - Add/Remove/Reorder lines
   - Edit speaker, text, portrait, emotion
   - Set auto-advance delay
3. Choice Branches
   - Add choice points
   - Link to other dialogue resources
4. Audio Settings
   - Background music selection
   - Text scroll sound

**Challenges**:
- Dynamic line list (add/remove/reorder)
- Linking dialogue choices to other DialogueData resources
- Preview system (optional, Phase 3)

**Reference Checking**:
- Check BattleData (pre_battle_dialogue, victory_dialogue, defeat_dialogue)
- Check BattleData turn_dialogues

---

#### 3. Battle Editor ✅ COMPLETE
**Complexity**: High (reduced with better separation of concerns)
**Estimated Lines**: ~400-450 (using base class)

Allows editing of `BattleData` resources (tactical battle scenarios).

**Design Philosophy - Separation of Concerns**:
- **BattleData**: Scenario configuration (enemies, conditions, rewards, dialogue)
- **Map Scene**: Spatial data (grid size, spawn points, terrain)
- Maps are reusable; battles configure WHO fights and HOW to win

**Features**:
- Map scene selection
- Enemy/Neutral unit configuration with per-unit AI
- Victory/Defeat condition builder
- Dialogue integration
- Environmental settings (weather, time of day)
- Reward configuration

**UI Sections**:
1. Basic Information (name, description)
2. Map Selection (PackedScene reference)
3. Enemy Forces **← Dynamic List**
   - CharacterData dropdown per enemy
   - Position (x, y) input per enemy
   - AI behavior dropdown per enemy (aggressive, defensive, patrol, stationary, support)
   - Add/Remove buttons
4. Neutral/NPC Forces **← Dynamic List**
   - CharacterData dropdown per neutral
   - Position (x, y) input per neutral
   - AI behavior dropdown per neutral
   - Add/Remove buttons
5. Victory Conditions
   - Condition type dropdown
   - Conditional fields (boss index, turn count, position, protect index)
6. Defeat Conditions
   - Condition type dropdown
   - Conditional fields (turn limit, unit dies index)
7. Battle Flow & Dialogue
   - Pre-battle, victory, defeat dialogues
   - Turn dialogues (Phase 3 placeholder)
8. Environment (weather, time of day)
9. Audio (Phase 3 placeholders)
10. Rewards (XP, gold, items - item list in Phase 3)

**Data Structure**:
- Uses `Array[Dictionary]` for enemies/neutrals (consistent with DialogueData pattern)
- Each dictionary: `{character: CharacterData, position: Vector2i, ai_behavior: String}`
- Per-unit AI behaviors instead of global settings

**Approach**:
- Form-based editing (no visual grid in Phase 2)
- Dynamic list management (similar to dialogue_editor)
- Phase 3: Visual grid editor with drag-and-drop
- Phase 3: Map scene visual preview
- Phase 3: Turn-based dialogue triggers

**Reference Checking**:
- Cannot check (battles are top-level scenarios)

---

### Priority 2: Testing & Polish

After each editor is implemented:
1. Manual testing in Godot
2. Create test resources for each type
3. Verify save/load/delete operations
4. Test reference checking
5. Verify validation messages

---

### Priority 3: Runtime Systems (Deferred to Phase 3)

These were originally planned for Phase 2 but will be moved to Phase 3 to focus on completing the editor toolset first.

**Core Systems**:
- GridManager (TileMapLayer, pathfinding)
- TurnManager (turn order, phase management)
- BattleManager (combat orchestration)
- InputManager (player controls)

**Components**:
- Unit (Node2D base)
- MovementComponent
- CombatComponent
- InventoryComponent
- AnimationComponent

---

## Implementation Order

### Step 1: Ability Editor ⏳ NEXT
- Simplest of the three remaining editors
- Good practice with base class pattern
- No complex UI requirements
- Clear validation rules

### Step 2: Dialogue Editor
- Moderate complexity
- Introduces dynamic list management
- Prepares for battle editor complexity
- Useful for testing dialogue integration

### Step 3: Battle Editor 🔴 LAST
- Most complex editor
- Requires lessons learned from first two
- May defer visual features to Phase 3
- Start simple, iterate in future phases

---

## Success Criteria

Phase 2 will be considered complete when:

✅ All six resource types have functional editors
✅ All editors use the base class pattern
✅ All editors support create/save/delete operations
✅ All editors have proper validation
✅ Reference checking prevents orphaned resources
✅ Template resources exist for all types
✅ User documentation updated
✅ All editors manually tested and verified

---

## Architecture Notes

### Base Class Pattern
All editors extend `base_resource_editor.gd` and implement:

```gdscript
# Required overrides:
func _create_detail_form() -> void
func _load_resource_data() -> void
func _save_resource_data() -> void
func _validate_resource() -> Dictionary
func _check_resource_references(resource: Resource) -> Array[String]
func _create_new_resource() -> Resource
func _get_resource_display_name(resource: Resource) -> String

# Base class provides:
# - List management and refresh
# - Create/Save/Delete operations
# - Reference checking before deletion
# - UI setup (split panel, buttons)
# - Error handling and validation
```

### Code Reuse Stats (After Refactoring)
- **Phase 1 (before refactoring)**: 1,468 lines across 3 editors
- **Phase 1 (after refactoring)**: 1,116 lines across 3 editors + 254 line base class = 1,370 total
- **Savings**: -98 lines (-6.7%) for 3 editors
- **Future editors**: Each new editor saves ~150-200 lines of boilerplate
- **Phase 2 projection**: 3 new editors × 150 lines saved = ~450 lines saved

### Estimated Phase 2 Code Volume
- Ability Editor: ~280 lines
- Dialogue Editor: ~350 lines
- Battle Editor: ~450 lines
- **Total new code**: ~1,080 lines
- **Would have been without base class**: ~1,530 lines
- **Savings**: ~450 lines (-29%)

---

## Risks & Mitigation

### Risk 1: Battle Editor Complexity
**Risk**: Visual grid editor may be too complex for Phase 2
**Mitigation**: Start with simple form-based editing, defer visual features to Phase 3

### Risk 2: Dialogue Editor Line Management
**Risk**: Dynamic add/remove/reorder UI may be challenging
**Mitigation**: Use simple list with up/down buttons, defer advanced features

### Risk 3: Scope Creep
**Risk**: Trying to build perfect editors delays progress
**Mitigation**: Focus on MVP (minimum viable product) for each editor, iterate later

---

## Timeline Estimate

Based on Phase 1 completion rate:

- **Ability Editor**: 1-2 hours (straightforward)
- **Dialogue Editor**: 2-3 hours (dynamic lists)
- **Battle Editor**: 3-5 hours (complex UI)
- **Testing & Templates**: 1-2 hours
- **Documentation Update**: 1 hour

**Total Estimate**: 8-13 hours of development time

---

## Next Steps

1. ✅ Create PHASE_2_PLAN.md (this document)
2. ✅ Update PHASE_1_COMPLETE.md with refactoring
3. ⏳ Implement Ability Editor
4. Test Ability Editor, create templates
5. Implement Dialogue Editor
6. Test Dialogue Editor, create templates
7. Implement Battle Editor (simplified version)
8. Test Battle Editor, create templates
9. Update user documentation
10. Mark Phase 2 complete, plan Phase 3

---

## Future Phases

### Phase 3: Runtime Systems
- GridManager with TileMapLayer
- A* pathfinding (AStarGrid2D)
- TurnManager and BattleManager
- Component-based unit system
- Basic battle scene implementation
- Visual battle editor enhancements

### Phase 4: Polish & Content
- Animation system
- Audio system
- Save/load system
- Menu system
- Additional content creation tools

---

**Last Updated**: November 13, 2024
**Next Review**: After Ability Editor completion
