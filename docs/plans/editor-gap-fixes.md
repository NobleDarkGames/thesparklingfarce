# Editor Gap Fixes Implementation Plan

**Created:** 2025-12-19
**Updated:** 2026-01-07
**Status:** Partially implemented, documentation updated for current state
**Reviewed by:** Lt. Claudbrain (planning), Commander Claudius (authenticity)

## Overview

The Sparkling Editor is missing UI for several existing resource properties, forcing modders to edit code/JSON directly. This plan addresses those gaps to enable full total conversion support through the editor.

**Key Finding:** All properties already exist in the data classes. We're exposing existing functionality, not adding features.

## Current Status Update (2026-01-07)

**✅ COMPLETED:**
- **Class Editor - Combat Rates** (lines 22-29 in ClassData) ✓ Implemented
- **NewGameConfig Editor - Story Flags** (lines 82-85 in NewGameConfigData) ✓ Already existed

**🔄 STILL NEEDED:**
- **Battle Editor - Item Rewards** (line 86 in BattleData) - Missing UI
- **Character Editor - Unique Abilities** (line 51 in CharacterData) - Missing UI

**🚫 REMOVED:**
- **Campaign Editor - Flag Management** - Campaign system removed 2026-01-06 (commit 4c4ebdb)

---

## Authenticity Assessment

| Fix | SF Authentic | Notes |
|-----|--------------|-------|
| Campaign flags | ✅ 100% | Core SF progression mechanic |
| Combat rates | ✅ 100% | SF2 had 3/6/12/25% per class |
| Item rewards | ✅ 100% | Every SF battle had drops |
| Unique abilities | ✅ 100% | Domingo, Yogurt, etc. |
| Battle music | ✅ 100% | Boss themes were iconic |
| Turn dialogues | ✅ 100% | Mid-battle events staple |
| Combat formula picker | ⚠️ Unclear | Not SF pattern - defer |

---

## Phase 1: Quick Wins

### 1. Class Editor - Combat Rates ✅ COMPLETED

**File:** `addons/sparkling_editor/ui/class_editor.gd`
**Resource:** `core/resources/class_data.gd` (lines 22-29)
**Complexity:** Low (~30-40 lines)

**Properties exposed:**
```gdscript
@export_range(0, 50) var counter_rate: int = 12
@export_range(0, 50) var double_attack_rate: int = 6
@export_range(0, 50) var crit_rate_bonus: int = 0
```

**Implementation (Completed 2026-01-07):**
- Added member variables for SpinBox controls
- Created `_add_combat_rates_section()` with FormBuilder pattern
- Added to `_create_detail_form()` after equipment section
- Updated `_load_resource_data()` and `_save_resource_data()`
- Added help text referencing SF2 authentic values (25=1/4, 12=1/8, 6=1/16, 3=1/32)

---

### 2. NewGameConfig Editor - Story Flag Management ✅ ALREADY EXISTS

**File:** `addons/sparkling_editor/ui/new_game_config_editor.gd`
**Resource:** `core/resources/new_game_config_data.gd` (lines 82-85)
**Complexity:** Medium (~150-200 lines)

**Properties exposed:**
```gdscript
@export var starting_story_flags: Dictionary = {}
```

**Implementation (Already existed as of 2025-12-20):**
- Member variables: `story_flags_container` (line 57), `story_flags_list` (line 58)
- `_add_story_flags_section()` function exists (line 595)
- `_load_resource_data()` and `_save_resource_data()` handle flags (lines 175-220)
- UI includes: LineEdit (key) + CheckBox (value) + Remove button
- "Add Story Flag" button functionality present

**Note:** Campaign system removed 2026-01-06. This replaces the planned campaign flag management.

---

### 3. Battle Editor - Item Rewards

**File:** `addons/sparkling_editor/ui/battle_editor.gd`
**Resource:** `core/resources/battle_data.gd` (line 86)
**Complexity:** Medium (~80-100 lines)

**Property to expose:**
```gdscript
@export var item_rewards: Array[ItemData] = []
```

**Current state:** Placeholder at lines 425-429 says "Coming soon"

**Implementation:**
1. Add member variables:
   ```gdscript
   var item_rewards_section: CollapseSection
   var item_rewards_container: VBoxContainer
   var item_rewards_list: Array[Dictionary] = []
   ```

2. Replace placeholder in `_add_rewards_section()`:
   - CollapseSection titled "Item Rewards"
   - VBoxContainer for item rows
   - "Add Item Reward" button

3. Add helper functions:
   - `_on_add_item_reward()`
   - `_add_item_reward_row(item: ItemData)` - ResourcePicker + Remove button
   - `_on_remove_item_reward(row)`
   - `_clear_item_rewards_ui()`

4. Update `_load_resource_data()` and `_save_resource_data()`

**Pattern to follow:** character_editor.gd inventory system (lines 1076-1228)

---

### 4. Character Editor - Unique Abilities

**File:** `addons/sparkling_editor/ui/character_editor.gd`
**Resource:** `core/resources/character_data.gd` (line 51)
**Complexity:** Medium (~100-130 lines)

**Property to expose:**
```gdscript
@export var unique_abilities: Array[AbilityData] = []
```

**Implementation:**
1. Add member variables:
   ```gdscript
   var unique_abilities_section: CollapseSection
   var unique_abilities_container: VBoxContainer
   var unique_abilities_add_button: Button
   var _current_unique_abilities: Array[Dictionary] = []
   ```

2. Add `_add_unique_abilities_section()`:
   - CollapseSection (start collapsed)
   - Help text: "Character-specific abilities that bypass class restrictions"
   - VBoxContainer for ability rows
   - "Add Unique Ability" button

3. Add helper functions following class_editor learnable abilities pattern (lines 536-654):
   - `_on_add_unique_ability()`
   - `_add_unique_ability_row(ability: AbilityData)`
   - `_on_remove_unique_ability(row)`
   - `_load_unique_abilities()`, `_save_unique_abilities()`

4. Call from `_create_detail_form()` after battle configuration section

---

## Phase 2: Audio & Events

### 5. Battle Editor - Music Pickers

**File:** `addons/sparkling_editor/ui/battle_editor.gd`
**Resource:** `core/resources/battle_data.gd` (lines 79-81)
**Complexity:** Medium (~60-80 lines)

**Properties to expose:**
```gdscript
@export var background_music: AudioStream
@export var victory_music: AudioStream
@export var defeat_music: AudioStream
```

**Current state:** Placeholder at lines 387-391 says "Coming soon"

**Implementation:**
1. Add member variables for three audio path edits or pickers

2. Replace placeholder in `_add_audio_section()`:
   - Use file path LineEdit + Browse button pattern
   - Or ResourcePicker if AudioStream type is supported

3. Helper function `_create_audio_picker(label, field_name)`:
   - Row with Label, LineEdit (path), Browse button
   - FileDialog filtered to .ogg, .wav, .mp3

4. Update load/save to handle AudioStream paths

---

### 6. Battle Editor - Turn Dialogues

**File:** `addons/sparkling_editor/ui/battle_editor.gd`
**Resource:** `core/resources/battle_data.gd` (line 76)
**Complexity:** Medium (~90-110 lines)

**Property to expose:**
```gdscript
@export var turn_dialogues: Dictionary = {}  # {turn_number: DialogueData}
```

**Current state:** Placeholder at lines 372-375 says "Coming soon"

**Implementation:**
1. Add member variables:
   ```gdscript
   var turn_dialogues_section: CollapseSection
   var turn_dialogues_container: VBoxContainer
   var turn_dialogues_list: Array[Dictionary] = []
   ```

2. Replace placeholder:
   - CollapseSection titled "Turn Dialogues"
   - Help text: "Trigger dialogues at specific turns"
   - VBoxContainer for rows
   - "Add Turn Dialogue" button

3. Add helper functions:
   - `_on_add_turn_dialogue()`
   - `_add_turn_dialogue_row(turn: int, dialogue: DialogueData)`:
     - SpinBox (turn 1-99) + ResourcePicker (dialogue) + Remove button
   - `_on_remove_turn_dialogue(row)`
   - `_clear_turn_dialogues_ui()`

4. Load: iterate Dictionary keys, create rows
5. Save: collect from UI into new Dictionary

---

## Deferred: Combat Formula Picker

**Needs design decision:**
- SF games had ONE combat formula per game, not per-battle
- If global: belongs in Settings/NewGameConfig, not BattleEditor
- If per-battle override: requires adding property to BattleData first

**Action:** Clarify intent before implementation

---

## Implementation Notes

### Patterns to Follow
- **FormBuilder:** For simple labeled fields (class_editor)
- **CollapseSection:** For optional/advanced sections
- **ResourcePicker:** For cross-mod resource selection
- **Array[Dictionary]:** Track dynamic UI rows for save/load

### Testing Strategy
1. Each feature testable independently via editor
2. Create test data in _sandbox mod
3. Verify save/load round-trips correctly
4. Verify ResourcePickers show resources from all loaded mods

### Scope Discipline
- Do NOT add validation beyond what data classes enforce
- Do NOT build fancy drag-drop or graph UIs
- Do NOT add "while we're at it..." features
- Stick to exposing existing properties

---

## Summary

## Updated Implementation Summary

| Phase | Item | File | Status | Lines |
|-------|------|------|--------|-------|
| 1 | Combat rates | class_editor.gd | ✅ COMPLETED | 40 |
| 1 | Story flags | new_game_config_editor.gd | ✅ ALREADY EXISTS | N/A |
| 1 | Item rewards | battle_editor.gd | 🔄 NEEDED | 80-100 |
| 1 | Unique abilities | character_editor.gd | 🔄 NEEDED | 100-130 |
| 2 | Battle music | battle_editor.gd | 🔄 NEEDED | 60-80 |
| 2 | Turn dialogues | battle_editor.gd | 🔄 NEEDED | 90-110 |
| - | Combat formula | TBD | DEFERRED | - |

**Remaining work:** ~330-420 lines across 3 files (battle_editor.gd, character_editor.gd)

**NOTE:** Campaign system removed on 2026-01-06 (commit 4c4ebdb). Plan updated for current state.
