# The Sparkling Farce - Pending Tasks

This document tracks all pending work items. Updated 2026-01-21.

---

## Editor Bugs (Priority: HIGH)

Critical bugs found in Sparkling Editor code review:

### Off-by-One Metadata Bugs
- [ ] `battle_editor.gd:633` - AI dropdown metadata at wrong index
- [ ] `battle_editor.gd:604` - Audio dropdown item ID off by one
- [ ] `character_editor.gd:731` - AI behavior dropdown metadata off by one

### Missing Dirty Tracking
- [ ] `class_editor.gd:261-269` - Equipment section never calls `_mark_dirty`
- [ ] `ability_editor.gd:435` - Status effect changes don't trigger dirty flag

### Memory Leaks
- [ ] `cinematic_editor.gd:1289-1299` - ConfirmationDialog never freed
- [ ] `caravan_editor.gd:443-444` - EditorFileDialog not freed

### Data Integrity
- [ ] `save_slot_editor.gd:942-968` - Creates orphaned/duplicate metadata entries

**Full report:** `docs/untracked/EDITOR_CODE_REVIEW.md`

---

## Release Blocking (Priority: CRITICAL)

2 items remaining before alpha release:

- [ ] Complete modder documentation Tutorial 4 (Abilities and Magic)
- [ ] Replace 23 [PLACEHOLDER] entries across community docs

---

## Editor Code Quality (Priority: MEDIUM)

From code review - consolidation opportunities:

### Duplication to Consolidate
- [ ] Place on Map sections (~100 lines duplicated in npc_editor.gd, interactable_editor.gd)
- [ ] CRAFTER_TYPES constant (duplicated in crafter_editor.gd, crafting_recipe_editor.gd)
- [ ] `_updating_ui` pattern (5 editors duplicate base class `_is_loading`)
- [ ] Texture loading helpers (same code in 3+ files)
- [ ] Registry fallback patterns (4 files have identical lookup code)

### Large Files to Split
- [ ] `cinematic_editor.gd` (2,231 lines) - Split into components
- [ ] `character_editor.gd` (1,428 lines) - Extract sections
- [ ] `base_resource_editor.gd` (1,817 lines) - Decompose setup method

---

## Deferred Features (Priority: BACKLOG)

- [ ] Dialog box auto-positioning (avoid portrait overlap)
- [ ] Mod field menu options (position parameter support)
- [ ] Spell animation system enhancements
- [ ] Additional cinematic commands
- [ ] Save slot management improvements
- [ ] Advanced AI behavior patterns

---

## Reference Documents

- `docs/untracked/PHASE_STATUS.md` - High-level project status
- `docs/untracked/EDITOR_CODE_REVIEW.md` - Full editor code review findings
- `docs/specs/platform-specification.md` - Technical specification
