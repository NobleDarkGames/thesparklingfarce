# Sparkling Editor Comprehensive Review Plan

**Prepared by:** Claudbrain (Strategic Planning)
**For:** Agent Macklin (Execution)
**Date:** 2026-01-11

---

## Overview

This document provides a systematic review checklist for the Sparkling Editor, organized by tab/component. Each section lists files to review, key functionality, and specific items to verify.

**Total Editors:** 23 tabs across 4 categories
**Shared Components:** 10+ reusable UI components
**Existing Tests:** 6 test files covering core components

---

## General Review Standards (Apply to ALL Tabs)

### Code Quality Checklist
- [ ] Strict typing on all variables (e.g., `var x: float = 5.0` not `var x := 5.0`)
- [ ] Dictionary checks use `if "key" in dict:` not `if dict.has("key"):`
- [ ] No dead code or commented-out blocks
- [ ] Consistent signal connection cleanup in `_exit_tree()`
- [ ] Proper null checks before accessing resources/nodes

### UI/UX Checklist
- [ ] All form fields have tooltips explaining their purpose
- [ ] Help text present for complex sections
- [ ] Responsive layout (works on laptop screens, minimum 600px width)
- [ ] Dirty state tracking with `_mark_dirty()` calls on all editable fields
- [ ] `_is_loading` guard used to prevent false dirty state during load

### Data Flow Checklist
- [ ] Uses `ModLoader.registry.get_resource()` for resource access (not direct `load()`)
- [ ] ResourcePickers properly refresh via EditorEventBus
- [ ] `resource_dependencies` declared BEFORE `super._ready()` for auto-subscription
- [ ] `_on_dependencies_changed()` implemented if needed

### Validation Checklist
- [ ] `_validate_resource()` reads from UI state, NOT resource state
- [ ] Returns `{valid: bool, errors: Array[String], warnings: Array[String]}`
- [ ] All required fields validated
- [ ] Range validation for numeric fields
- [ ] Cross-reference validation where applicable

---

## Part 1: Infrastructure and Base Classes

### 1.1 Main Panel
**File:** `addons/sparkling_editor/ui/main_panel.gd`

Review Items:
- [ ] Mod selector persists selection across sessions
- [ ] Category bar correctly filters tabs by category
- [ ] "Refresh Mods" properly reloads all mods and refreshes all editors
- [ ] "Create New Mod" wizard validates mod ID format
- [ ] EditorEventBus signals properly emitted on mod changes
- [ ] Settings persistence to `user://sparkling_editor_settings.json`

### 1.2 Base Resource Editor
**File:** `addons/sparkling_editor/ui/base_resource_editor.gd`

Review Items:
- [ ] Keyboard shortcuts work (Ctrl+S save, Ctrl+N new, Ctrl+D duplicate, Delete)
- [ ] Search filter correctly filters resource list
- [ ] Unsaved changes dialog prompts before switching resources
- [ ] Cross-mod resource display shows `[mod_id] Resource Name` format
- [ ] "Copy to My Mod" and "Create Override" buttons work correctly
- [ ] Write protection for resources from other mods
- [ ] Undo/redo integration with EditorUndoRedoManager
- [ ] `_check_resource_references()` called before deletion

### 1.3 JSON Editor Base
**File:** `addons/sparkling_editor/ui/json_editor_base.gd`

Review Items:
- [ ] Proper JSON parsing and serialization
- [ ] Error handling for malformed JSON
- [ ] Mod directory detection for save paths

### 1.4 Editor Utilities
**File:** `addons/sparkling_editor/ui/editor_utils.gd`

Review Items:
- [ ] FormBuilder pattern creates consistent layouts
- [ ] `generate_id_from_name()` properly sanitizes identifiers
- [ ] Color constants match theme (help color, error color, etc.)
- [ ] Section creation with proper spacing

### 1.5 Editor Tab Registry
**File:** `addons/sparkling_editor/editor_tab_registry.gd`

Review Items:
- [ ] Built-in tabs registered with correct categories
- [ ] Mod tabs properly loaded from `editor_extensions` in mod.json
- [ ] Category sorting and priority ordering
- [ ] Instance tracking and refresh_all() functionality

### 1.6 Editor Event Bus
**File:** `addons/sparkling_editor/editor_event_bus.gd`

Review Items:
- [ ] All signals properly defined (resource_saved, resource_created, resource_deleted)
- [ ] mods_reloaded and active_mod_changed signals
- [ ] No circular signal loops

---

## Part 2: Content Category Editors

### 2.1 Character Editor
**Files:**
- `addons/sparkling_editor/ui/character_editor.gd`
- `tests/unit/editor/test_character_editor_validation.gd`

Review Items:
- [ ] Name and ID with lock/unlock auto-generation
- [ ] Class picker (required for player category, warning for others)
- [ ] Category selection (player/enemy/neutral)
- [ ] Level range validation (1-99)
- [ ] Base stats section (HP, MP, STR, DEF, AGI, INT, LUK)
- [ ] Starting equipment array management
- [ ] Portrait picker integration
- [ ] Battle sprite picker integration
- [ ] Unit flags (is_in_starting_party, is_recruitable)
- [ ] Validation reads from UI state (per test_character_editor_validation.gd)

Edge Cases:
- [ ] Empty name validation
- [ ] Whitespace-only name validation
- [ ] Player without class fails
- [ ] Enemy without class passes with warning

### 2.2 Class Editor
**File:** `addons/sparkling_editor/ui/class_editor.gd`

Review Items:
- [ ] Display name field
- [ ] Movement type dropdown (Walking, Flying, Floating, Swimming, Custom)
- [ ] Movement range validation (1-20)
- [ ] Growth rates sliders (0-200% range with 5% steps)
- [ ] Equipment restrictions (weapon type checkboxes from registry)
- [ ] Combat rates (counter, double attack, crit bonus)
- [ ] Promotion section:
  - [ ] Promotion level (1-99)
  - [ ] Reset level on promotion checkbox
  - [ ] Consume promotion item checkbox
  - [ ] Promotion paths with ResourcePicker for target class and required item
- [ ] Learnable abilities section:
  - [ ] Level + AbilityData pairs
  - [ ] Duplicate level warning display
  - [ ] Proper save to class_abilities and ability_unlock_levels

Edge Cases:
- [ ] Empty promotion paths handled
- [ ] Multiple abilities at same level shows warning

### 2.3 Item Editor
**File:** `addons/sparkling_editor/ui/item_editor.gd`

Review Items:
- [ ] Item name and icon picker
- [ ] Item type dropdown (Weapon, Accessory, Consumable, Key Item)
- [ ] Conditional sections (weapon_section, consumable_section, curse_section)
- [ ] Stat modifiers (HP, MP, STR, DEF, AGI, INT, LUK)
- [ ] Weapon properties (attack power, range min/max, hit rate, crit rate)
- [ ] Range validation (min <= max with auto-adjustment)
- [ ] Consumable properties (usable_in_battle, usable_on_field, effect picker)
- [ ] Economy (buy price, sell price validation >= 0)
- [ ] Curse properties (is_cursed, uncurse_items)
- [ ] Equipment slot picker from registry
- [ ] Is crafting material checkbox

Edge Cases:
- [ ] Negative price validation
- [ ] Icon oversized warning (>64px)

### 2.4 Ability Editor
**File:** `addons/sparkling_editor/ui/ability_editor.gd`

Review Items:
- [ ] Name and ID with lock/unlock
- [ ] Ability type dropdown (Attack, Heal, Support, Debuff, etc.)
- [ ] Target type dropdown (Single Enemy, Single Ally, Self, All, Area)
- [ ] Range and AoE (min_range <= max_range validation)
- [ ] Cost section (MP cost, HP cost >= 0)
- [ ] Potency and accuracy (0-100% validation)
- [ ] Status effects picker (multi-select from registry)
- [ ] Effect chance validation (0-100%)
- [ ] Animation stub field

Edge Cases:
- [ ] Unknown status effects filtered out during load

### 2.5 NPC Editor
**File:** `addons/sparkling_editor/ui/npc_editor.gd`

Review Items:
- [ ] Name and ID with lock/unlock
- [ ] Portrait picker with preview
- [ ] Map spritesheet picker (64x128, 4 directions x 2 frames)
- [ ] Generated SpriteFrames saved to data/sprite_frames/
- [ ] Place on Map section:
  - [ ] Grid position spinboxes
  - [ ] Map selection popup
  - [ ] Auto-save before placement
- [ ] Advanced options (collapsible):
  - [ ] Primary and fallback cinematic pickers
  - [ ] Conditional cinematics with AND/OR flags
  - [ ] Behavior (face_player, facing_override)
- [ ] Preview panel integration (NPCPreviewPanel component)

Edge Cases:
- [ ] Empty NPC ID validation
- [ ] NPC with no cinematics shows warning
- [ ] Conditional entry validation (must have both flags and cinematic)

### 2.6 Shop Editor
**File:** `addons/sparkling_editor/ui/shop_editor.gd`

Review Items:
- [ ] Name and ID with lock/unlock
- [ ] Shop type dropdown (Weapon, Item, Church, Crafter, Special)
- [ ] Conditional sections based on shop type
- [ ] Inventory management:
  - [ ] Item list with stock and price override
  - [ ] Add/remove items from registry
- [ ] Deals section with discount
- [ ] Economy multipliers (buy, sell, deals discount)
- [ ] Availability flags (required, forbidden)
- [ ] Features checkboxes (can sell, store to caravan, sell from caravan)
- [ ] Church section (heal cost, revive base/multiplier, uncurse cost)
- [ ] Crafter section with ResourcePicker
- [ ] `resource_dependencies = ["item", "npc", "crafter"]`

Edge Cases:
- [ ] Invalid item IDs in inventory validation
- [ ] Crafter shop without crafter selected fails

### 2.7 Crafter Editor
**File:** `addons/sparkling_editor/ui/crafter_editor.gd`

Review Items:
- [ ] Name and ID
- [ ] Crafter type dropdown with custom option
- [ ] Skill level (1-99)
- [ ] Specializations (comma-separated)
- [ ] Location section (map picker, grid position)
- [ ] NPC link (character picker)
- [ ] Availability flags
- [ ] Service fee modifier (0.1-5.0)
- [ ] Description field
- [ ] `resource_dependencies = ["character", "map"]`

Edge Cases:
- [ ] Empty crafter type validation
- [ ] Skill level < 1 validation
- [ ] Service fee <= 0 validation

### 2.8 Crafting Recipe Editor
**File:** `addons/sparkling_editor/ui/crafting_recipe_editor.gd`

Review Items:
- [ ] Recipe name and ID
- [ ] Result item picker
- [ ] Ingredients list (item + quantity)
- [ ] Required crafter type and skill level
- [ ] Gold cost
- [ ] Crafting time

### 2.9 Interactable Editor
**File:** `addons/sparkling_editor/ui/interactable_editor.gd`

Review Items:
- [ ] Interactable type and name
- [ ] Interaction cinematic picker
- [ ] Visual representation (sprite/icon)
- [ ] Position and map placement

---

## Part 3: Battles Category Editors

### 3.1 Battle Editor
**File:** `addons/sparkling_editor/ui/battle_editor.gd`

Review Items:
- [ ] Battle name and description
- [ ] Map scene selector
- [ ] Player spawn position
- [ ] Player party picker (ResourcePicker, optional override)
- [ ] Enemy forces section (collapsible):
  - [ ] Character picker + position + AI behavior
  - [ ] Add/remove enemies
- [ ] Neutral forces section
- [ ] Victory conditions dropdown with conditional fields:
  - [ ] Boss index, protect index, turn count, target position
- [ ] Defeat conditions dropdown with conditional fields
- [ ] Battle flow (pre-battle, victory, defeat dialogue pickers)
- [ ] Audio stubs
- [ ] Rewards (experience, gold, item list)
- [ ] `resource_dependencies = ["character", "party", "dialogue", "item", "ai_behavior"]`

### 3.2 Party Editor
**File:** `addons/sparkling_editor/ui/party_editor.gd`

Review Items:
- [ ] Party name and ID
- [ ] Member list with character pickers
- [ ] Add/remove members
- [ ] Starting positions

---

## Part 4: World Category Editors

### 4.1 Map Metadata Editor
**File:** `addons/sparkling_editor/ui/map_metadata_editor.gd`

Review Items:
- [ ] Map ID and display name
- [ ] Scene path reference
- [ ] Map type (world, battle, town, dungeon)
- [ ] Connections to other maps
- [ ] Tileset picker (uses TilesetRegistry)

### 4.2 Terrain Editor
**File:** `addons/sparkling_editor/ui/terrain_editor.gd`

Review Items:
- [ ] Terrain type definitions
- [ ] Movement costs by movement type
- [ ] Defense/evasion bonuses
- [ ] Visual representation

### 4.3 Dialogue Editor
**File:** `addons/sparkling_editor/ui/dialogue_editor.gd`

Review Items:
- [ ] Dialogue structure management
- [ ] Dialogue line management
- [ ] Speaker/portrait selection
- [ ] Branching options

### 4.4 Cinematic Editor
**File:** `addons/sparkling_editor/ui/cinematic_editor.gd`

Review Items:
- [ ] Extends JsonEditorBase
- [ ] Cinematic ID with lock/unlock auto-generation
- [ ] Name and description
- [ ] Settings (can_skip, disable_input)
- [ ] Actors panel:
  - [ ] Actor ID, entity type, entity picker
  - [ ] Position and facing
- [ ] Command list:
  - [ ] Add command dropdown (populated from CinematicsManager)
  - [ ] Move up/down/duplicate/delete
  - [ ] Quick Add Dialog button
- [ ] Command inspector (right panel):
  - [ ] Type-specific parameter widgets
  - [ ] Target actor dropdown
- [ ] EditorWidgetContext for widget system
- [ ] Unsaved changes dialog

---

## Part 5: Configuration Category Editors

### 5.1 New Game Config Editor
**File:** `addons/sparkling_editor/ui/new_game_config_editor.gd`

Review Items:
- [ ] Config ID and name
- [ ] is_default flag
- [ ] Starting campaign and location
- [ ] Starting gold
- [ ] Starting depot items
- [ ] Starting story flags
- [ ] Starting party ID
- [ ] Caravan unlocked

### 5.2 Experience Config Editor
**File:** `addons/sparkling_editor/ui/experience_config_editor.gd`

Review Items:
- [ ] Experience curve configuration
- [ ] Level cap
- [ ] XP formulas

### 5.3 AI Brain Editor
**File:** `addons/sparkling_editor/ui/ai_brain_editor.gd`

Review Items:
- [ ] AI behavior ID and name
- [ ] Priority rules
- [ ] Targeting preferences
- [ ] Movement patterns

### 5.4 Status Effect Editor
**File:** `addons/sparkling_editor/ui/status_effect_editor.gd`

Review Items:
- [ ] Effect ID and display name
- [ ] Effect type
- [ ] Duration and stacking
- [ ] Visual/audio indicators

### 5.5 Caravan Editor
**File:** `addons/sparkling_editor/ui/caravan_editor.gd`

Review Items:
- [ ] Caravan configuration
- [ ] Storage capacity
- [ ] Item management

### 5.6 Save Slot Editor
**File:** `addons/sparkling_editor/ui/save_slot_editor.gd`

Review Items:
- [ ] Save slot display
- [ ] Party member management
- [ ] Character data viewing

### 5.7 Mod JSON Editor
**File:** `addons/sparkling_editor/ui/mod_json_editor.gd`

Review Items:
- [ ] mod.json editing
- [ ] Validation of required fields
- [ ] Dependencies management
- [ ] Editor extensions configuration

---

## Part 6: Shared Components

### 6.1 ResourcePicker
**Files:**
- `addons/sparkling_editor/ui/components/resource_picker.gd`
- `tests/unit/editor/test_resource_picker.gd`
- `tests/unit/editor/test_resource_picker_widget.gd`

Review Items:
- [ ] Shows resources from ALL mods with `[mod_id] Resource Name` format
- [ ] `resource_type` property triggers refresh
- [ ] `allow_none` and `none_text` options
- [ ] `filter_function` callable support
- [ ] Auto-refresh via EditorEventBus connection
- [ ] `select_resource()`, `select_by_id()`, `select_none()` methods
- [ ] `get_selected_resource()` and `get_selected_resource_id()` methods
- [ ] Override info tracking
- [ ] Signal: `resource_selected(metadata: Dictionary)`

### 6.2 CollapseSection
**Files:**
- `addons/sparkling_editor/ui/components/collapse_section.gd`
- `tests/unit/editor/test_collapse_section.gd`

Review Items:
- [ ] Title and collapse toggle
- [ ] `start_collapsed` property
- [ ] Content visibility toggle
- [ ] Proper child management

### 6.3 Texture Pickers
**Files:**
- `addons/sparkling_editor/ui/components/texture_picker_base.gd`
- `addons/sparkling_editor/ui/components/portrait_picker.gd`
- `addons/sparkling_editor/ui/components/battle_sprite_picker.gd`
- `addons/sparkling_editor/ui/components/map_spritesheet_picker.gd`

Review Items:
- [ ] File browser with proper filters (.png, .webp, .jpg)
- [ ] Preview display at appropriate size
- [ ] Path validation (ResourceLoader.exists)
- [ ] Default path to active mod assets
- [ ] Clear button functionality
- [ ] Oversized texture warnings

### 6.4 NPC Preview Panel
**File:** `addons/sparkling_editor/ui/components/npc_preview_panel.gd`

Review Items:
- [ ] `bind_sources()` for reactive preview
- [ ] Portrait and sprite display
- [ ] Animation preview

### 6.5 Map Placement Helper
**File:** `addons/sparkling_editor/ui/components/map_placement_helper.gd`

Review Items:
- [ ] `get_available_maps()` static method
- [ ] `place_npc_on_map()` functionality
- [ ] Scene modification handling
- [ ] `is_scene_open()` detection

### 6.6 Dialog Components
**Files:**
- `addons/sparkling_editor/ui/components/dialog_line_popup.gd`
- `addons/sparkling_editor/ui/components/quick_dialog_generator.gd`

Review Items:
- [ ] Dialog line creation workflow
- [ ] Character/speaker selection
- [ ] Text input with proper escaping

### 6.7 Cinematic Command Definitions
**File:** `addons/sparkling_editor/ui/components/cinematic_command_defs.gd`

Review Items:
- [ ] Command type definitions
- [ ] Parameter schemas
- [ ] Display names and icons

### 6.8 Editor Widget Context
**File:** `addons/sparkling_editor/ui/components/widgets/editor_widget_context.gd`

Review Items:
- [ ] `populate_from_registry()` queries fresh data
- [ ] Character, NPC, shop, map, etc. lists populated correctly
- [ ] Used by cinematic editor widgets

---

## Part 7: Cross-Cutting Concerns

### 7.1 Signal Cleanup
- [ ] Every editor with EditorEventBus connections has proper `_exit_tree()` cleanup
- [ ] ResourcePickers disconnect on tree exit
- [ ] No memory leaks from orphaned signal connections

### 7.2 Mod Workflow
- [ ] Resources from other mods are read-only (save button disabled or shows warning)
- [ ] "Copy to My Mod" creates new resource with new ID
- [ ] "Create Override" preserves ID for priority-based replacement
- [ ] Active mod properly detected and used for save paths

### 7.3 Empty State Handling
- [ ] Empty resource lists show appropriate message
- [ ] New resources have sensible defaults
- [ ] No crashes on null current_resource

### 7.4 Consistency Checks
- [ ] All editors use FormBuilder pattern for consistent layout
- [ ] All editors have the same button order (Save, Delete, mod workflow)
- [ ] All numeric spinboxes have appropriate min/max values
- [ ] All text fields have max_length where appropriate

---

## Execution Notes for Macklin

1. **Work through tabs systematically** - Complete one editor fully before moving to the next
2. **Run existing tests first** - Before modifying code, run `diagnostics` to ensure tests pass
3. **Document findings** - Note any issues found for each checklist item
4. **Prioritize validation issues** - These are most likely to cause data loss
5. **Check git status periodically** - Track which files have been modified
6. **Start with infrastructure** - Review Part 1 first as it affects all other editors

---

## Priority Order

**High Priority (Review First):**
1. `base_resource_editor.gd` - Fixes here propagate to all editors
2. `resource_picker.gd` - Used by ~15 editors
3. `character_editor.gd` - Most complex, has validation tests as reference

**Medium Priority:**
4. Other Content editors (class, item, ability, npc, shop)
5. Battle editor
6. Cinematic editor

**Lower Priority:**
7. Configuration editors
8. Utility editors (save_slot, mod_json)

---

## Test Coverage Reference

| Component | Test File | Coverage |
|-----------|-----------|----------|
| EditorEventBus | `test_editor_event_bus.gd` | Signals, notifications |
| EditorTabRegistry | `test_editor_tab_registry.gd` | Registration, categories |
| EditorUtils | `test_sparkling_editor_utils.gd` | FormBuilder, ID generation |
| CharacterEditor | `test_character_editor_validation.gd` | UI state validation |
| ResourcePicker | `test_resource_picker.gd` | Selection, refresh |
| ResourcePickerWidget | `test_resource_picker_widget.gd` | Widget integration |
| CollapseSection | `test_collapse_section.gd` | Collapse behavior |
