# Priest NPC Creation Process Log

**Goal:** Create a priest NPC in Mudford to test the church promotion system

**Date:** 2026-01-07

---

## Step 1: Create Church Shop

- Opened Shop Editor
- Created new shop with:
  - Shop Name: "Church"
  - Shop ID: "default_priest_shop" (or auto-generated)
  - Shop Type: Church
- Saved successfully

## Step 2: Create Priest NPC (Initial Attempt)

- Opened NPC Editor
- Created new NPC
- Selected "Priest" role in Quick Setup
- **Issue #1:** Shop dropdown showed filename (`demo_campaign_shop_1767812930`) instead of shop name ("Church")
- **Issue #2:** Error on save: "Quick Setup: Shop must be selected for this role"

---

## Platform Bugs Found & Fixed

### Bug 1: Shop Name Not Displayed in ResourcePicker

**File:** `addons/sparkling_editor/ui/components/resource_picker.gd`

**Problem:** `_get_display_name()` didn't check for `shop_name` property, falling back to filename.

**Fix:** Added `"shop_name"` to the `name_properties` array (line 354).

**Status:** FIXED - Shop now displays as "[demo_campaign] Church"

---

### Bug 2: ResourcePicker Selection Not Registered

**File:** `addons/sparkling_editor/ui/components/resource_picker.gd`

**Problem:** When `allow_none = false`, the dropdown visually showed the first item, but `_current_metadata` was empty, causing `has_selection()` to return false.

**Initial Fix Attempt:** Added auto-select logic in `refresh()` to select first item when `allow_none = false`.

**Why It Didn't Work:** The NPC editor's `_load_resource_data()` called `select_none()` after refresh, which unconditionally cleared `_current_metadata`.

**Root Cause (found by Lt. Barclay):** `select_none()` cleared internal state even when there was no "none" option to select.

**Final Fix:** Added guard in `select_none()` to early-return when `allow_none = false` (lines 604-609).

**Status:** FIXED - Verified working

---

### Bug 3: NPC Preview Panel - Wrong Sprite Property

**File:** `addons/sparkling_editor/ui/components/npc_preview_panel.gd`

**Problem:** Code tried to access `char_data.map_sprite` but CharacterData uses `sprite_frames`.

**Fix:** Changed to use `SpriteUtils.extract_texture_from_sprite_frames(char_data.sprite_frames)` (line 254-255).

**Status:** FIXED

---

### Bug 4: Intermittent "Invalid new child index: 5" (Low Priority)

**File:** `addons/sparkling_editor/ui/base_resource_editor.gd`

**Problem:** Intermittent error when positioning error panel in detail_panel. Likely timing issue during UI reconstruction.

**Status:** NOTED - Non-blocking, works on retry. Will investigate if it becomes frequent.

---

## Current Status

- [ ] Reload editor and verify priest NPC can be saved
- [ ] Place priest NPC on Mudford map
- [ ] Test church services (HEAL, REVIVE, UNCURSE)
- [ ] Test promotion system (requires promotable character)

---

## Staged Changes (Not Yet Committed)

Church promotion UI implementation:
- `scenes/ui/shops/shop_context.gd` - Added PROMOTION mode
- `core/systems/shop_manager.gd` - Added church_promote(), get_promotable_characters()
- `scenes/ui/shops/screens/church_action_select.gd/.tscn` - Added PROMOTE button
- `scenes/ui/shops/screens/church_char_select.gd` - PROMOTION handling
- `scenes/ui/shops/screens/church_promote_select.gd/.tscn` - NEW promotion path selection
- `scenes/ui/shops/screens/transaction_result.gd` - PROMOTION result handling
- `tests/unit/shop/test_shop_manager.gd` - 6 new promotion tests (all passing)

---

## Notes

- The base game doesn't include a default priest - mods must create their own church shops and priest NPCs
- Church shop type automatically provides HEAL, REVIVE, UNCURSE, and PROMOTE services
- Promotion requires: character at level 10+, has promotion paths defined in class data
