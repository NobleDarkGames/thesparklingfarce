# Total Conversion Modding Platform Audit

**Date:** December 3, 2025
**Last Updated:** December 5, 2025
**Auditors:** Modro (Mod Architecture Specialist), Clauderina (UI/UX Specialist)
**Platform Version:** 0.2.6
**Overall Score:** 8.25/10 → **9.0/10** (after P0 completion)

---

## Status Update (December 5, 2025)

**All P0 Critical Items Have Been Completed!**

| P0 Item | Original Status | Current Status |
|---------|-----------------|----------------|
| Battle Editor Map Preview | Needed | ✅ **COMPLETE** - `battle_map_preview.gd` with full click-to-place |
| Visual Cinematic Editor | Needed | ✅ **COMPLETE** - Per Sparkling Editor Phase 3 |
| Terrain Data Editor | Needed | ✅ **COMPLETE** - Per Sparkling Editor expansion |
| Mod Starter Template | Needed | ✅ **COMPLETE** - `mods/_template/` with README and examples |

The audit below is preserved for historical reference. Scores and recommendations have been updated where applicable.

---

## Executive Summary

This audit evaluates The Sparkling Farce modding platform from the perspective of a modder attempting to create a **total conversion** mod. Two specialists walked through the complete modding journey:

- **Modro**: Evaluated architecture, extensibility, mod isolation, and total conversion feasibility
- **Clauderina**: Evaluated editor tools, workflow efficiency, and UX quality

### Key Findings

| Category | Score | Assessment |
|----------|-------|------------|
| Data-Driven Design | 9/10 | Nearly everything is data, minimal hardcoded values |
| Extension Points | 8/10 | Good registries, could use more hooks |
| Mod Isolation | 8/10 | Flag namespacing excellent, type namespacing partial |
| Editor Coverage | 8/10 | 73% of content types have full editor support |
| Documentation | 5/10 | Platform spec good, modding docs nonexistent |
| Total Conversion | 7/10 | Feasible with friction; critical gaps remain |

### Bottom Line

A determined modder **can** create a total conversion today, but they would need to:
- Write GDScript for triggers and custom AI
- Hand-edit terrain effects as `.tres` files
- Write cinematic JSON by hand
- Guess-and-check battle enemy positions
- Read engine source code for undocumented systems

Addressing the P0 items below would push the platform to **9+/10** moddability.

---

## Prioritized TODO List

### P0 - Critical (Blocks Total Conversions) - ✅ ALL COMPLETE

#### ~~TODO 1: Battle Editor Map Preview~~ ✅ COMPLETE
- **Status**: ✅ Implemented in `addons/sparkling_editor/ui/components/battle_map_preview.gd`
- **Features delivered**:
  - SubViewport rendering of map scene
  - Grid overlay toggle
  - Blue marker for player spawn position
  - Red markers for enemy positions with labels
  - Yellow markers for neutral units
  - **Full click-to-place functionality** with PlacementMode enum
  - `position_clicked` signal for editor integration
  - Zoom control and camera positioning
- **Lines of code**: 707

#### ~~TODO 2: Visual Cinematic Editor~~ ✅ COMPLETE
- **Status**: ✅ Implemented per Sparkling Editor Expansion Phase 3
- **Features delivered**:
  - 19 command types supported
  - Command ItemList with reordering
  - Command inspector panel for parameters
  - Type-specific parameter forms
  - JSON serialization

#### ~~TODO 3: Terrain Data Editor~~ ✅ COMPLETE
- **Status**: ✅ Implemented per Sparkling Editor Expansion
- **Features delivered**:
  - Full TerrainData resource editing
  - Movement costs per movement type
  - Defense/evasion bonuses
  - Damage per turn configuration
  - Impassable flags

#### ~~TODO 4: Mod Starter Template~~ ✅ COMPLETE
- **Status**: ✅ Implemented in `mods/_template/`
- **Features delivered**:
  - Comprehensive `mod.json` with inline `_comment_*` documentation
  - 165-line `README.md` with quick start guide
  - Example resources: character, class, item, ability, battle, terrain
  - Complete directory structure with `.gitkeep` files
  - Load priority guide, content creation instructions, override documentation

---

### P1 - High Priority (Major Friction)

#### TODO 5: Asset Preview System
- **Problem**: Cannot see portraits, icons, or sprites in editor
- **Impact**: Must run game to verify asset paths are correct
- **Solution**: Add preview panels to resource editors
- **Files to modify**:
  - `addons/sparkling_editor/ui/character_editor.gd` (portrait preview)
  - `addons/sparkling_editor/ui/item_editor.gd` (icon preview)
  - `addons/sparkling_editor/ui/base_resource_editor.gd` (preview infrastructure)
- **Implementation steps**:
  1. Add TextureRect preview panel to detail_panel
  2. Load texture when path field changes
  3. Handle missing/invalid paths gracefully
  4. Add thumbnail column to resource list (optional)
- **Effort**: 1-2 days

#### TODO 6: Batch Validation Tool
- **Problem**: No way to validate all mod content at once
- **Impact**: Must check resources individually; broken references discovered at runtime
- **Solution**: Add "Validate All" button and CLI tool
- **Files to modify**:
  - `addons/sparkling_editor/ui/main_panel.gd` (add button)
  - Create `addons/sparkling_editor/validation/batch_validator.gd`
- **Implementation steps**:
  1. Iterate all resources in active mod
  2. Call each resource's `validate()` method
  3. Check cross-references exist (character -> class, battle -> map, etc.)
  4. Display results in scrollable error panel
  5. (Optional) CLI: `godot --headless --script validate_mod.gd -- mod_id`
- **Effort**: 1-2 days

#### TODO 7: Modding Documentation
- **Problem**: Modders must read source code to understand systems
- **Impact**: High barrier to entry; only programmers can create mods
- **Solution**: Create modding guide documentation
- **Files to create**:
  - `docs/modding/getting-started.md`
  - `docs/modding/mod-json-reference.md`
  - `docs/modding/cinematic-commands.md`
  - `docs/modding/campaign-nodes.md`
  - `docs/modding/custom-triggers.md`
  - `docs/modding/custom-ai.md`
- **Content needed**:
  1. Getting Started: Copy template, edit mod.json, create first character
  2. mod.json Reference: Every field with type, default, and example
  3. Cinematic Commands: All commands with parameters and examples
  4. Campaign Nodes: Node types, transitions, flag conditions
  5. Custom Triggers: GDScript API, handler signature, examples
  6. Custom AI: AIBrain base class, decision methods, examples
- **Effort**: 2-3 days

#### TODO 8: Learnable Abilities UI in Class Editor
- **Problem**: `ClassData.learnable_abilities` dictionary has no editor UI
- **Impact**: Must manually edit `.tres` to set level-up abilities
- **Solution**: Add abilities-by-level editor widget
- **Files to modify**:
  - `addons/sparkling_editor/ui/class_editor.gd`
- **Implementation steps**:
  1. Add "Learnable Abilities" section with ItemList
  2. Each row: Level (SpinBox) + Ability (ResourcePicker)
  3. Add/Remove buttons
  4. Serialize to dictionary on save
- **Effort**: 0.5-1 day

---

### P2 - Medium Priority (Quality of Life)

#### TODO 9: Real-Time Field Validation
- **Problem**: Validation errors only shown after clicking Save
- **Impact**: Frustrating trial-and-error; must fix and retry
- **Solution**: Add inline validation indicators
- **Files to modify**:
  - `addons/sparkling_editor/ui/base_resource_editor.gd`
- **Implementation steps**:
  1. Add `_validate_field(field_name, value)` method
  2. Show yellow warning icon next to invalid fields
  3. Tooltip shows validation message
  4. Optionally disable Save button when errors present
- **Effort**: 1 day

#### TODO 10: Tooltip/Help Text Pass
- **Problem**: Many fields have no explanation
- **Impact**: Modders must guess field purpose
- **Solution**: Add tooltips to all editor fields
- **Files to modify**: All editor files in `addons/sparkling_editor/ui/`
- **Implementation steps**:
  1. Audit each editor for fields without tooltips
  2. Add `hint_tooltip` to all input controls
  3. Include: purpose, valid range, example value
- **Effort**: 1 day

#### TODO 11: Resource Templates
- **Problem**: Every new resource starts blank
- **Impact**: Repetitive data entry for similar content
- **Solution**: Add "New from Template" feature
- **Files to modify**:
  - `addons/sparkling_editor/ui/base_resource_editor.gd`
  - Create `addons/sparkling_editor/templates/` with preset JSON
- **Implementation steps**:
  1. Add template dropdown next to "New" button
  2. Templates: Warrior Character, Mage Character, Melee Weapon, Heal Ability, etc.
  3. Load template values into new resource
  4. Allow mods to register custom templates
- **Effort**: 2-3 days

#### TODO 12: mod.json Schema Validation
- **Problem**: Malformed mod.json fails silently or with cryptic errors
- **Impact**: Hard to debug mod loading issues
- **Solution**: Add JSON schema validation
- **Files to modify**:
  - `core/mod_system/mod_loader.gd`
  - Create `core/mod_system/mod_schema.json`
- **Implementation steps**:
  1. Define JSON Schema for mod.json
  2. Validate on mod load
  3. Log detailed errors for schema violations
  4. (Optional) Distribute schema for IDE autocomplete
- **Effort**: 1 day

---

### P3 - Low Priority (Polish)

#### TODO 13: Editor Font Compliance
- **Problem**: Editor uses Godot default fonts, not Monogram
- **Impact**: Visual inconsistency with game UI
- **Solution**: Apply Monogram font theme to editor
- **Files to create**:
  - `addons/sparkling_editor/editor_theme.tres`
- **Effort**: 2-3 hours

#### TODO 14: Additional Keyboard Shortcuts
- **Problem**: Only Ctrl+S and Ctrl+N implemented
- **Impact**: Power users want more shortcuts
- **Solution**: Add common shortcuts
- **Shortcuts to add**:
  - Ctrl+D: Duplicate selected resource
  - Ctrl+Shift+S: Save all
  - Delete: Delete selected resource (with confirmation)
  - F2: Rename selected resource
- **Effort**: 0.5 days

#### TODO 15: Custom Type Collision Warning
- **Problem**: Two mods defining same type name could conflict
- **Impact**: Unpredictable behavior; hard to debug
- **Solution**: Warn on type name collision
- **Files to modify**:
  - `core/registries/equipment_registry.gd`
  - Other registry files
- **Implementation steps**:
  1. Check if type already registered by different mod
  2. Log warning with both mod IDs
  3. (Optional) Auto-prefix with mod ID
- **Effort**: 0.5 days

---

### P4 - Future (Complex Features)

#### TODO 16: Visual Trigger Editor
- **Problem**: Custom triggers require GDScript knowledge
- **Impact**: Non-programmers cannot create map interactions
- **Solution**: Node-based visual scripting for triggers
- **Scope**: Major feature; requires design work
- **Effort**: 5-7 days

#### TODO 17: AI Behavior Tree Editor
- **Problem**: Custom AI requires GDScript knowledge
- **Impact**: Non-programmers cannot create enemy behaviors
- **Solution**: Visual behavior tree designer
- **Scope**: Major feature; requires design work
- **Effort**: 7-10 days

---

## Content Type Coverage Matrix

| Resource Type | Editor | Format | Status | Gap |
|--------------|--------|--------|--------|-----|
| Characters | character_editor.gd | .tres | Complete | Portrait preview |
| Classes | class_editor.gd | .tres | Complete | Learnable abilities UI |
| Items | item_editor.gd | .tres | Complete | Icon preview |
| Abilities | ability_editor.gd | .tres | Complete | - |
| Parties | party_editor.gd | .tres | Complete | - |
| Battles | battle_editor.gd | .tres | Functional | **Map preview (P0)** |
| Maps | map_metadata_editor.gd | .json | Complete | Spawn point preview |
| Campaigns | campaign_editor.gd | .json | Complete | Flag badges |
| Cinematics | cinematic_editor.gd | .json | Browser only | **Visual editor (P0)** |
| Dialogues | dialogue_editor.gd | .tres | Deprecated | Use Cinematics |
| Terrain | None | .tres | **No editor** | **Create editor (P0)** |
| Triggers | None | .gd | Code only | Visual editor (P4) |
| AI Brains | None | .gd | Code only | Behavior trees (P4) |
| Mod Settings | mod_json_editor.gd | .json | Complete | - |

**Current coverage:** 11/15 (73%)
**Target coverage:** 13/15 (87%) after P0 items

---

## Documentation Gaps

These systems are undocumented and require reading source code:

| Topic | Source Files | Priority |
|-------|--------------|----------|
| Cinematic commands | `core/systems/cinematic_manager.gd` | P1 |
| Campaign node types | `core/resources/campaign_data.gd` | P1 |
| Scene ID registry | `core/mod_system/mod_loader.gd` | P1 |
| AI Brain API | `core/resources/ai_brain.gd` | P1 |
| Trigger handler API | `core/systems/trigger_manager.gd` | P1 |
| mod.json schema | `core/mod_system/mod_manifest.gd` | P2 |
| Save data structure | `core/systems/save_manager.gd` | P3 |

---

## Architectural Strengths (What to Preserve)

These systems are well-implemented and should be used as patterns:

1. **Cross-mod ResourcePicker** (`resource_picker.gd`)
   - Shows resources from all mods with source attribution
   - Handles override detection and visualization
   - Pattern for all cross-reference UI

2. **Mod Isolation Workflows** (`base_resource_editor.gd`)
   - "Copy to My Mod" creates namespaced duplicate
   - "Create Override" creates same-ID override
   - Write protection for other mods' resources

3. **Type Registries** (`core/registries/`)
   - Mods extend weapon types, equipment slots, triggers
   - Consistent pattern across all registries
   - Source tracking per type

4. **Dynamic Tab Registration** (`main_panel.gd`)
   - Mods provide custom editors via mod.json
   - Enables platform extensibility
   - No hardcoded editor list

5. **EditorEventBus** (`editor_event_bus.gd`)
   - Decoupled cross-editor communication
   - Auto-refresh on dependency changes
   - Async-safe signal handling

---

## Effort Summary

| Priority | Items | Total Effort | Status |
|----------|-------|--------------|--------|
| P0 (Critical) | 4 | 8-10.5 days | ✅ **COMPLETE** |
| P1 (High) | 4 | 5-8 days | Pending |
| P2 (Medium) | 4 | 5-6 days | Pending |
| P3 (Low) | 3 | 1.5 days | Pending |
| P4 (Future) | 2 | 12-17 days | Pending |

**Critical path to 9+/10 moddability:** ✅ P0 items complete - **Score achieved: 9.0/10**

**Next priority:** Equipment System (Phase 4.2) - enables weapons, rings, cursed items

---

## Appendix: Files Reviewed

### Core Mod System
- `core/mod_system/mod_loader.gd`
- `core/mod_system/mod_registry.gd`
- `core/mod_system/mod_manifest.gd`

### Resources
- `core/resources/character_data.gd`
- `core/resources/class_data.gd`
- `core/resources/item_data.gd`
- `core/resources/ability_data.gd`
- `core/resources/battle_data.gd`
- `core/resources/dialogue_data.gd`
- `core/resources/cinematic_data.gd`
- `core/resources/campaign_data.gd`
- `core/resources/map_metadata.gd`
- `core/resources/party_data.gd`
- `core/resources/terrain_data.gd`
- `core/resources/ai_brain.gd`

### Registries
- `core/registries/equipment_registry.gd`
- `core/registries/equipment_slot_registry.gd`
- `core/registries/trigger_type_registry.gd`

### Editor
- `addons/sparkling_editor/plugin.cfg`
- `addons/sparkling_editor/editor_plugin.gd`
- `addons/sparkling_editor/ui/main_panel.gd`
- `addons/sparkling_editor/ui/base_resource_editor.gd`
- `addons/sparkling_editor/ui/json_editor_base.gd`
- `addons/sparkling_editor/ui/character_editor.gd`
- `addons/sparkling_editor/ui/class_editor.gd`
- `addons/sparkling_editor/ui/item_editor.gd`
- `addons/sparkling_editor/ui/ability_editor.gd`
- `addons/sparkling_editor/ui/party_editor.gd`
- `addons/sparkling_editor/ui/battle_editor.gd`
- `addons/sparkling_editor/ui/map_metadata_editor.gd`
- `addons/sparkling_editor/ui/campaign_editor.gd`
- `addons/sparkling_editor/ui/cinematic_editor.gd`
- `addons/sparkling_editor/ui/mod_json_editor.gd`
- `addons/sparkling_editor/ui/components/resource_picker.gd`
- `addons/sparkling_editor/ui/components/dialog_line_popup.gd`

### Mod Examples
- `mods/_base_game/mod.json`
- `mods/_sandbox/mod.json`

---

*Report compiled by Modro & Clauderina, USS Torvalds crew*
