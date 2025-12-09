# Exploration Field Menu Implementation Plan

**Document Version:** 1.1
**Date:** 2025-12-08
**Status:** Planning (Crew Review Complete)

---

## Overview

This plan details the implementation of an **ExplorationFieldMenu** - a context menu that appears when the player presses the interaction button (`sf_confirm`) OR the cancel button (`sf_cancel`) while NOT facing an interactable object during map exploration. This is an authentic Shining Force 1/2 feature that provides quick access to party management functions without requiring proximity to the Caravan.

### SF1/SF2 Reference Behavior

In the original Shining Force games, pressing the confirm button in an empty area (or the cancel/B button) opens a compact field menu with options:
- **Item** - Access character inventories
- **Magic** - Cast field-usable spells (Egress, Detox only - NOT healing spells)
- **Search** - Examine the current tile/area
- **Member** - View party member stats (NOTE: SF2 called this "Member", not "Status")

This menu is distinct from the Caravan menu and is available at any time during exploration.

---

## Crew Review Summary (2025-12-08)

### Design Decisions Finalized

| Decision | Resolution | Rationale |
|----------|------------|-----------|
| **Menu Layout** | Vertical list (not radial) | Multi-input support (keyboard/mouse/gamepad), mod extensibility (>4 options), easier implementation |
| **"Status" Label** | Renamed to **"Member"** | SF2 authenticity - "Status" was Caravan menu, "Member" was field menu |
| **Menu Trigger** | `sf_confirm` AND `sf_cancel` | SF2 allowed both buttons to open field menu |
| **Magic Restrictions** | Egress + Detox ONLY | SF2 authentic - healing spells required items/Caravan/church |
| **Menu Open Animation** | Fast (0.08s) or instant | SF2's snappiness is part of its rhythm |
| **Cursor Movement** | **INSTANT** (no animation) | Critical for SF2 feel - no tweening delays |
| **Description Footer** | None | Keep compact for frequent access |

### SF2 Purist Acceptance Criteria (Mr. Nerdlinger)

The vertical menu is approved IF these requirements are met:

1. **Default to first option** - No extra navigation needed for common actions
2. **Instant cursor movement** - Press = move, NO animation delays
3. **Cursor wrapping** - Down from bottom → top, up from top → bottom
4. **Distinctive cursor sound** - SF2-style blip, not modern whoosh
5. **Keyboard shortcuts** - I/M/S/E for Item/Magic/Search/Member (optional but recommended)
6. **Very obvious selection highlight** - Yellow text + cursor indicator
7. **Consistent menu position** - Don't move between uses

### UI/UX Requirements (Lt. Clauderina)

1. **Edge-case positioning** - Menu must not clip off-screen or obscure hero
2. **Mouse support** - Hover highlight + click selection (match ItemActionMenu)
3. **CanvasLayer usage** - Layer 100 for screen-anchored positioning
4. **Complete visual specs** - All constants defined (margins, spacing, corner radius)
5. **Hide unavailable options** - Don't show greyed-out Magic if no one has field spells

---

## Requirements Summary

1. Menu appears when `sf_confirm` OR `sf_cancel` is pressed with no interaction target
2. Integrates with `ExplorationUIController` state machine
3. Follows established patterns from `ItemActionMenu` and `CaravanMainMenu`
4. Implements Modal UI Input Blocking pattern (see `docs/specs/platform-specification.md:669-721`)
5. SF-authentic menu options: **Item, Magic, Search, Member** (in that order)
6. Mod-extensible architecture for custom menu options (vertical list supports >4 options)
7. **Instant cursor movement** - no animation delays on navigation
8. **Smart edge positioning** - menu never clips off-screen
9. **Mouse support** - hover and click handling

---

## Architecture Design

### New Files to Create

| File | Purpose |
|------|---------|
| `scenes/ui/exploration_field_menu.gd` | Menu controller script |
| `scenes/ui/exploration_field_menu.tscn` | Menu scene |
| `scenes/ui/field_magic_menu.gd` | Magic selection sub-menu script |
| `scenes/ui/field_magic_menu.tscn` | Magic selection scene |

### Existing Files to Modify

| File | Modification |
|------|--------------|
| `core/templates/map_template.gd` | Call field menu when no interaction target |
| `core/components/exploration_ui_controller.gd` | Add `FIELD_MENU` state, add blocking check |
| `scenes/map_exploration/hero_controller.gd` | Add field menu blocking to fallback checks |
| `core/systems/debug_console.gd` | Add field menu to modal check |

---

## Detailed Design

### 1. ExplorationFieldMenu Component

**Location:** `scenes/ui/exploration_field_menu.gd`

**Class Structure:**
```gdscript
class_name ExplorationFieldMenu
extends Control

## ExplorationFieldMenu - SF-style field menu for exploration mode
##
## Appears when player presses confirm with no interaction target.
## Provides quick access to: Item, Magic, Search, Member
##
## Mod-extensible via FieldMenuExtensionRegistry (future Phase 2)

# =============================================================================
# SIGNALS
# =============================================================================

signal option_selected(option_id: String)
signal close_requested()
signal magic_requested()
signal item_requested()
signal search_requested()
signal member_requested()  # SF2 calls this "Member", not "Status"
signal custom_option_requested(option_id: String, data: Dictionary)

# =============================================================================
# ENUMS
# =============================================================================

enum MenuOption {
    ITEM,
    MAGIC,
    SEARCH,
    MEMBER  # SF2 terminology - "Status" is used in Caravan menu
}
```

**Key Properties:**
- `_selected_index: int` - Currently highlighted option
- `_is_active: bool` - Whether menu is showing and accepting input
- `_menu_options: Array[Dictionary]` - Dynamic options list (supports mod extension)
- `_hero_grid_position: Vector2i` - Position where menu was opened (for Search)

**Visual Design (SF-authentic with modern polish):**
- Compact vertical list positioned near hero (not centered)
- Semi-transparent dark background panel
- Monogram font at 16px
- Yellow highlight for selected option
- Cursor indicator (">") on selected item
- **NO description footer** - keep compact for frequent access
- **Smart edge positioning** - clamp to viewport, never clip off-screen
- **CanvasLayer (layer=100)** - screen-anchored, not world-anchored
- **Instant cursor movement** - no tween delays on navigation
- **Mouse hover support** - highlight on hover, click to select

**Menu Options Array Structure:**
```gdscript
var DEFAULT_OPTIONS: Array[Dictionary] = [
    {
        "id": "item",
        "label": "Item",
        "description": "View party inventory",
        "enabled": true,
        "is_custom": false,
        "action": MenuOption.ITEM
    },
    {
        "id": "magic",
        "label": "Magic",
        "description": "Cast field spells",
        "enabled": true,  # Dynamic: HIDE (not grey out) if no party member has field magic
        "is_custom": false,
        "action": MenuOption.MAGIC
    },
    {
        "id": "search",
        "label": "Search",
        "description": "Examine this area",
        "enabled": true,
        "is_custom": false,
        "action": MenuOption.SEARCH
    },
    {
        "id": "member",
        "label": "Member",  # SF2 terminology - NOT "Status"
        "description": "View party members",
        "enabled": true,
        "is_custom": false,
        "action": MenuOption.MEMBER
    }
]
```

### 2. ExplorationUIController Integration

**New State:**
```gdscript
enum UIState {
    EXPLORING,      ## Normal gameplay
    INVENTORY,      ## PartyEquipmentMenu open
    DEPOT,          ## CaravanDepotPanel open
    FIELD_MENU,     ## ExplorationFieldMenu open (NEW)
    FIELD_MAGIC,    ## Magic selection from field menu (NEW)
    DIALOG,         ## Dialog box active
    SHOP,           ## Shop interface
    PAUSED          ## Pause menu
}
```

**New Methods:**
```gdscript
## Reference to field menu (set via setup())
var exploration_field_menu: ExplorationFieldMenu = null

## Open the exploration field menu
## @param hero_position: Grid position where menu was opened (for Search)
func open_field_menu(hero_position: Vector2i) -> void:
    if current_state != UIState.EXPLORING:
        return

    if not exploration_field_menu:
        push_warning("ExplorationUIController: No ExplorationFieldMenu assigned")
        return

    _set_state(UIState.FIELD_MENU)
    exploration_field_menu.show_menu(hero_position)
    AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)

## Open the field magic sub-menu
func open_field_magic() -> void:
    # Transition from FIELD_MENU to FIELD_MAGIC
    _previous_state = current_state
    _set_state(UIState.FIELD_MAGIC)
```

**Updated `is_blocking_input()`:**
```gdscript
func is_blocking_input() -> bool:
    if DebugConsole and DebugConsole.is_open:
        return true
    if ShopManager and ShopManager.is_shop_open():
        return true
    if DialogManager and DialogManager.is_dialog_active():
        return true
    # Block during field menu states
    if current_state in [UIState.FIELD_MENU, UIState.FIELD_MAGIC]:
        return true
    return current_state != UIState.EXPLORING
```

### 3. MapTemplate Hook Point

**Modified `_on_hero_interaction()`:**

```gdscript
## Called when hero presses the interaction button.
## Handles NPC interactions, or opens field menu if no target found.
func _on_hero_interaction(interaction_pos: Vector2i) -> void:
    _debug_print("MapTemplate: Interaction at tile %s" % interaction_pos)

    # Check for NPCs at interaction position
    var npc: Node = _find_npc_at_position(interaction_pos)
    if npc:
        _debug_print("MapTemplate: Found NPC at interaction position: %s" % npc.name)
        if npc.has_method("interact"):
            npc.interact(hero)
            return

    # Check for other interactables (signs, chests, etc.)
    var interactable: Node = _find_interactable_at_position(interaction_pos)
    if interactable:
        if interactable.has_method("interact"):
            interactable.interact(hero)
            return

    # No interaction target found - open field menu
    # This is SF-authentic behavior: confirm in empty space = field menu
    if exploration_ui and exploration_ui.has_method("open_field_menu"):
        exploration_ui.open_field_menu(hero.grid_position)
```

**New: B-Button (Cancel) Trigger in HeroController:**

SF2 also allowed opening the field menu via the cancel button. Add to `hero_controller.gd`:

```gdscript
func _input(event: InputEvent) -> void:
    # ... existing movement blocking checks ...

    # Interaction key (confirm) - existing behavior
    if event.is_action_pressed("sf_confirm"):
        _try_interact()
        return

    # Cancel key opens field menu directly (SF2 authentic)
    # Only when in exploration mode with no UI active
    if event.is_action_pressed("sf_cancel"):
        if ui_controller and not ui_controller.is_blocking_input():
            # Open field menu at hero's current position
            if ui_controller.has_method("open_field_menu"):
                ui_controller.open_field_menu(grid_position)
```

### 4. FieldMagicMenu Sub-Menu

**Purpose:** Allows selection of a party member, then selection of a field-usable ability.

**CRITICAL SF2 AUTHENTICITY NOTE:**
In Shining Force 2, only **Egress** and **Detox** worked in the field menu. Healing spells (Heal, Aura, etc.) were NOT available in the field - you had to use healing items, the Caravan, or visit a church. This was intentional game design that forced resource management.

**Two-Step Selection:**
1. **Caster Selection** - Show party members who have field-usable abilities (Egress, Detox)
2. **Spell Selection** - Show that character's field-usable abilities

**Field-Usable Ability Detection (SF2 Authentic):**
```gdscript
## Check if an ability can be used on the field
## SF2 AUTHENTIC: Only Egress and Detox work in the field!
## Healing spells require items, Caravan, or church.
func is_field_usable(ability: AbilityData) -> bool:
    # Check explicit field_usable flag on AbilityData
    # Default abilities with this flag: Egress, Detox
    if "usable_on_field" in ability and ability.usable_on_field:
        return true

    # Fallback: check for known field-usable ability IDs
    var field_usable_ids: Array[String] = ["egress", "detox"]
    return ability.id in field_usable_ids
```

**AbilityData Enhancement (Phase 2):**
Add `usable_on_field: bool = false` property to AbilityData resource. Default to false (SF2 authentic). Set true only for:
- **Egress** - Teleport party to last visited town
- **Detox** - Cure poison/curse status

**Optional Accessibility Config:**
For players who want modern convenience, add to `NewGameConfigData`:
```gdscript
## Allow healing spells in field menu (non-SF2-authentic, easier gameplay)
@export var allow_field_healing: bool = false
```

If `allow_field_healing` is true, HEAL and SUPPORT types become field-usable. This lets accessibility-focused mods enable it while preserving SF2 authenticity by default.

**Note:** Full magic implementation is Phase 2. Phase 1 shows "No field magic available" placeholder if no party member has Egress/Detox.

### 5. Search Functionality

**Purpose:** Examines the current tile for hidden items or provides a description.

**Implementation Approach:**
```gdscript
## Handle Search action from field menu
func _on_search_requested() -> void:
    var hero_pos: Vector2i = _hero_grid_position

    # Check for hidden items at this position
    var hidden_item: String = _check_hidden_item(hero_pos)
    if not hidden_item.is_empty():
        _show_search_result("Found: %s!" % hidden_item)
        _give_item_to_party(hidden_item)
        return

    # Check for tile description
    var description: String = _get_tile_description(hero_pos)
    if not description.is_empty():
        _show_search_result(description)
        return

    # Default message
    _show_search_result("Nothing unusual here.")
```

**Hidden Item System (Future Enhancement):**
- Hidden items stored in MapMetadata or separate resource
- One-time collection tracked via GameState flags
- Example: `GameState.set_flag("searched_town1_tile_5_3")`

### 6. Member Menu Implementation

**SF2 Terminology:** This is called "Member" in SF2's field menu, not "Status". The Caravan menu uses "Status".

**Options:**
1. **Reuse PartyEquipmentMenu** in a view-only mode
2. **Create dedicated MemberInfoPanel** (compact stat display with page navigation)

**SF2 Reference - Member Info Pages:**
In SF2, selecting a party member from the Member menu showed multiple info pages you could cycle through with left/right:
- Page 1: Portrait, level, HP/MP, class, XP to next level
- Page 2: Combat stats (ATT/DEF/AGI/MOV)
- Page 3: Equipment slots (view-only)
- Page 4: Spell list with MP costs

**Recommended Approach for Phase 1:** Open `PartyEquipmentMenu` and let the user browse. This provides all the information, just not in the exact SF2 page layout.

**Phase 2 Enhancement:** Create a dedicated `MemberInfoPanel` with left/right page navigation for authentic SF2 feel.

---

## Signal Flow Diagram

```
[HeroController]
    |
    | sf_confirm (no target) OR sf_cancel
    v
[MapTemplate._on_hero_interaction()] OR [HeroController._input()]
    |
    | (no target found / cancel pressed)
    v
[ExplorationUIController.open_field_menu(grid_pos)]
    |
    | _set_state(FIELD_MENU)
    v
[ExplorationFieldMenu.show_menu()]
    |
    +---> option_selected("item") ---> open_inventory()
    |
    +---> option_selected("magic") ---> [FieldMagicMenu]
    |         |                         (only if party has Egress/Detox)
    |         +---> caster_selected(character)
    |         |
    |         +---> spell_selected(ability, caster)
    |         |
    |         +---> spell_cast ---> [Immediate Cast - no target for Egress/Detox]
    |
    +---> option_selected("search") ---> _execute_search()
    |
    +---> option_selected("member") ---> open_member_view()
    |
    +---> close_requested() ---> close_all_menus()
```

---

## Mod Extensibility Design (Simplified)

**Philosophy:** Follow the existing mod.json pattern. No registry, no callbacks, just data.

### How Mods Add Field Menu Options

Mods declare options in `mod.json`:

```json
{
  "field_menu_options": {
    "bestiary": {
      "label": "Bestiary",
      "scene_path": "scenes/ui/bestiary_panel.tscn",
      "position": "end"
    },
    "quest_log": {
      "label": "Quests",
      "scene_path": "scenes/ui/quest_log.tscn",
      "position": "after_search"
    }
  }
}
```

### Position Options
- `"start"` - Before Item
- `"end"` - After Member (DEFAULT)
- `"after_item"`, `"after_magic"`, `"after_search"`, `"after_member"`

### Total Conversion Support

To replace all base options:
```json
{
  "field_menu_options": {
    "_replace_all": true,
    "scan": {
      "label": "Scan",
      "scene_path": "scenes/ui/scanner.tscn"
    }
  }
}
```

### What Happens When Selected

Custom options open their declared scene. The scene is responsible for:
- Displaying its UI
- Handling its own input
- Closing itself when done (emit signal or call `queue_free()`)

**No callback support** - If you need complex logic, put it in your scene's `_ready()`.

### Why No Registry?

Per Modro's review: 99% of use cases are "add option that opens scene." A full registry with runtime registration, callbacks, and priority ordering is overkill for a 4-8 item menu. The mod.json approach is:
- Simpler for mod authors (just declare what you need)
- Consistent with other mod extensions (ai_brains, tilesets, scenes)
- ~70 lines vs ~200+ lines of code

---

## Implementation Phases

### Phase 1: Core Field Menu (MVP)

**Scope:**
1. Create `ExplorationFieldMenu` with basic UI (vertical list, instant cursor movement)
2. Integrate with `ExplorationUIController` (new FIELD_MENU state)
3. Hook into `MapTemplate._on_hero_interaction()` for sf_confirm trigger
4. Hook into `HeroController._input()` for sf_cancel trigger (B-button)
5. Implement Item action (opens existing PartyEquipmentMenu)
6. Implement Member action (opens PartyEquipmentMenu for now)
7. Implement Search action (basic "Nothing unusual here" message)
8. Magic option: HIDE if no party member has Egress/Detox, show placeholder otherwise
9. Apply Modal UI Input Blocking pattern
10. Smart edge positioning (menu never clips off-screen)
11. Mouse hover + click support

**Deliverables:**
- `/home/user/dev/sparklingfarce/scenes/ui/exploration_field_menu.gd`
- `/home/user/dev/sparklingfarce/scenes/ui/exploration_field_menu.tscn`
- Modified `/home/user/dev/sparklingfarce/core/components/exploration_ui_controller.gd`
- Modified `/home/user/dev/sparklingfarce/core/templates/map_template.gd`
- Modified `/home/user/dev/sparklingfarce/scenes/map_exploration/hero_controller.gd`
- Modified `/home/user/dev/sparklingfarce/core/systems/debug_console.gd`

### Phase 2: Field Magic System (Egress/Detox Only)

**Scope:**
1. Create `FieldMagicMenu` with caster/spell selection
2. Add `usable_on_field: bool` property to `AbilityData` (default false)
3. Set `usable_on_field = true` only for Egress and Detox
4. Implement Egress (teleport to last visited town hub)
5. Implement Detox (cure poison/curse status)
6. MP cost checking and consumption
7. Optional: Add `allow_field_healing` to NewGameConfigData for accessibility

**Deliverables:**
- `/home/user/dev/sparklingfarce/scenes/ui/field_magic_menu.gd`
- `/home/user/dev/sparklingfarce/scenes/ui/field_magic_menu.tscn`
- Modified `/home/user/dev/sparklingfarce/core/resources/ability_data.gd` (new `usable_on_field` property)

### Phase 3: Search System & Hidden Items

**Scope:**
1. Design hidden item data structure (in MapMetadata or separate)
2. Implement tile description system (terrain flavor text)
3. Search result dialog/display (use DialogManager for consistency)
4. One-time collection tracked via GameState flags
5. Editor support for placing hidden items

### Phase 4: Mod Extension Support (Simplified)

**Scope:**
1. Add `field_menu_options: Dictionary` to ModManifest
2. Parse `field_menu_options` from mod.json during mod loading
3. Append mod options to menu in mod load order (no priority system needed)
4. Scene-based only (no callbacks - put logic in your scene)

**NO FieldMenuExtensionRegistry** - Just iterate ModLoader.loaded_mods like other extensions.

**mod.json format:**
```json
{
  "field_menu_options": {
    "bestiary": {
      "label": "Bestiary",
      "scene_path": "scenes/ui/bestiary.tscn",
      "position": "end"
    }
  }
}
```

**Position options:** `"start"`, `"end"` (default), `"after_item"`, `"after_magic"`, `"after_search"`, `"after_member"`

**Total conversion support:** Add `"_replace_all": true` to hide base options.

**Implementation (~70 lines total):**
```gdscript
# In ModManifest - add property
@export var field_menu_options: Dictionary = {}

# In ExplorationFieldMenu - build options list
func _build_menu_options() -> Array[Dictionary]:
    var options: Array[Dictionary] = DEFAULT_OPTIONS.duplicate()

    for mod: ModManifest in ModLoader.get_loaded_mods():
        if "_replace_all" in mod.field_menu_options and mod.field_menu_options["_replace_all"]:
            options.clear()

        for option_id: String in mod.field_menu_options.keys():
            if option_id.begins_with("_"):
                continue  # Skip meta keys like _replace_all
            var opt_data: Dictionary = mod.field_menu_options[option_id]
            var new_option: Dictionary = {
                "id": option_id,
                "label": opt_data.get("label", option_id.capitalize()),
                "scene_path": mod.mod_directory.path_join(opt_data.get("scene_path", "")),
                "is_custom": true,
                "mod_id": mod.mod_id
            }
            _insert_option_at_position(options, new_option, opt_data.get("position", "end"))

    return options
```

### Phase 5: Dedicated Member Info Panel (Optional)

**Scope:**
1. Create `MemberInfoPanel` with SF2-style page navigation
2. Page 1: Portrait, level, HP/MP, class, XP to next level
3. Page 2: Combat stats (ATT/DEF/AGI/MOV)
4. Page 3: Equipment slots (view-only)
5. Page 4: Spell list with MP costs
6. Left/right navigation between pages (SF2 authentic)

---

## Testing Strategy

### Unit Tests

| Test | File | Purpose |
|------|------|---------|
| `test_field_menu_options` | `tests/unit/ui/test_exploration_field_menu.gd` | Verify option list generation |
| `test_field_menu_state_transitions` | `tests/unit/ui/test_exploration_ui_controller.gd` | State machine transitions |
| `test_field_magic_availability` | `tests/unit/ui/test_field_magic_menu.gd` | Magic option enabling logic |

### Integration Tests

| Test | Purpose |
|------|---------|
| Field menu opens on empty confirm | Verify hook in MapTemplate |
| Field menu blocks hero movement | Modal input blocking |
| Item option opens inventory | Action routing |
| Cancel returns to exploration | State cleanup |

### Manual Test Checklist

- [ ] Press confirm facing empty tile - field menu appears
- [ ] Press cancel (B button) during exploration - field menu appears
- [ ] Press confirm facing NPC - NPC interaction (no field menu)
- [ ] Navigate options with arrows - **INSTANT cursor movement** (no delay)
- [ ] Cursor wraps: down from Member → Item, up from Item → Member
- [ ] Select Item - PartyEquipmentMenu opens
- [ ] Select Member - PartyEquipmentMenu opens (Phase 1)
- [ ] Select Search - "Nothing unusual here" message appears
- [ ] Cancel from Item - returns to field menu
- [ ] Cancel from field menu - returns to exploration
- [ ] Hero cannot move while field menu is open
- [ ] Debug console cannot open while field menu is open
- [ ] Field menu cannot open while dialog is active
- [ ] Mouse hover highlights options
- [ ] Mouse click selects option
- [ ] Menu doesn't clip when hero is near screen edge
- [ ] Audio: cursor movement makes blip sound
- [ ] Audio: selection makes confirm sound

---

## Risk Assessment

### Low Risk
- Basic menu UI implementation (well-established patterns)
- Integration with ExplorationUIController (clear extension point)
- Item/Status routing to existing menus

### Medium Risk
- Magic sub-menu complexity (caster + spell + target selection)
- AbilityData modifications may require migration
- Search system requires new data structures

### Mitigation
- Phase 1 focuses on low-risk items only
- Magic shows placeholder in Phase 1
- Search returns default message in Phase 1

---

## Dependencies

### Required Before Implementation
- None - all prerequisites exist

### Blocking Other Features
- None identified

### Related Future Work
- Party management improvements
- Egress spell implementation (teleport to hub)
- Hidden item/treasure system

---

## Open Questions

1. **Search Result Display:** Should search results use the dialog system or a custom popup?
   - **Recommendation:** Use DialogManager for consistency with NPC interactions

2. **Magic Target Selection:** For multi-target or area spells, how do we select targets?
   - **Recommendation:** Phase 2 can implement a simple party member selector overlay

3. **Member View Scope:** Should Member show all party members or just active roster?
   - **Recommendation:** Show active party (like SF2), with option to view reserves

4. **Menu Position:** Should menu appear at screen center or near the hero?
   - **Recommendation:** Near hero (SF-authentic), offset to not obscure hero sprite

---

## Appendix A: Visual Reference

**SF2 Field Menu Appearance (adapted to vertical list):**
```
┌─────────┐
│ > Item  │
│   Magic │
│   Search│
│   Member│
└─────────┘
```
Note: SF2 used radial layout, but vertical list approved for multi-input support and mod extensibility.

**Complete Visual Specifications:**
```gdscript
## VISUAL SPECIFICATIONS (Complete)
const PANEL_MIN_SIZE: Vector2 = Vector2(100, 80)
const PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const PANEL_BORDER: Color = Color(0.5, 0.5, 0.6, 1.0)
const PANEL_BORDER_WIDTH: int = 2
const PANEL_CORNER_RADIUS: int = 4  # Match CaravanMainMenu

# Padding/margins to match ItemActionMenu
const CONTENT_MARGIN_TOP: int = 8
const CONTENT_MARGIN_BOTTOM: int = 8
const CONTENT_MARGIN_LEFT: int = 8
const CONTENT_MARGIN_RIGHT: int = 8
const OPTION_SEPARATION: int = 2  # Vertical spacing between options

# Text colors (consistent with existing menus)
const TEXT_NORMAL: Color = Color(0.85, 0.85, 0.85)
const TEXT_SELECTED: Color = Color(1.0, 0.95, 0.4)  # Yellow highlight
const TEXT_DISABLED: Color = Color(0.4, 0.4, 0.4)

# Cursor
const CURSOR_CHAR: String = ">"
const CURSOR_SPACING: int = 8  # Space between cursor and text

# Font (MANDATORY)
const FONT: Font = preload("res://assets/fonts/monogram.ttf")
const FONT_SIZE: int = 16

# Menu Open Animation (SF2-authentic: fast or instant)
const MENU_OPEN_DURATION: float = 0.08  # seconds (or 0.0 for instant)
const MENU_CLOSE_DURATION: float = 0.05  # seconds (faster close)

# Cursor Movement: INSTANT (no animation - SF2 purist requirement)
const CURSOR_MOVE_DURATION: float = 0.0
```

**Positioning Logic (Edge-Safe):**
```gdscript
func _calculate_menu_position(hero_screen_pos: Vector2) -> Vector2:
    var menu_offset: Vector2 = Vector2(40, 20)  # Right and slightly down from hero
    var desired_pos: Vector2 = hero_screen_pos + menu_offset

    var viewport_rect: Rect2 = get_viewport_rect()
    var menu_size: Vector2 = _panel.get_combined_minimum_size()
    var edge_padding: float = 8.0

    # Clamp to viewport bounds
    desired_pos.x = clampf(desired_pos.x, edge_padding, viewport_rect.size.x - menu_size.x - edge_padding)
    desired_pos.y = clampf(desired_pos.y, edge_padding, viewport_rect.size.y - menu_size.y - edge_padding)

    return desired_pos
```

---

## Appendix B: Code Snippets

### Modal UI Blocking - How Field Menu Participates

The platform uses the Modal UI Input Blocking pattern (see `docs/specs/platform-specification.md:669-721`).

**The field menu automatically participates** because it uses `ExplorationUIController` states. When `current_state == FIELD_MENU`, the existing check `current_state != UIState.EXPLORING` returns `true`, blocking input.

**No additional manager required** - the field menu doesn't need its own `is_field_menu_open()` method because:
1. It's part of `ExplorationUIController`, not a separate autoload
2. The state machine already tracks `FIELD_MENU` state
3. `is_blocking_input()` checks `current_state != UIState.EXPLORING`

**`exploration_ui_controller.gd` - `is_blocking_input()` (existing pattern):**
```gdscript
func is_blocking_input() -> bool:
    if DebugConsole and DebugConsole.is_open:
        return true
    if ShopManager and ShopManager.is_shop_open():
        return true
    if DialogManager and DialogManager.is_dialog_active():
        return true
    # FIELD_MENU and FIELD_MAGIC states automatically block via this check:
    return current_state != UIState.EXPLORING
```

**`hero_controller.gd` - `_is_modal_ui_active()` (fallback only):**
```gdscript
func _is_modal_ui_active() -> bool:
    if DebugConsole and DebugConsole.is_open:
        return true
    if ShopManager and ShopManager.is_shop_open():
        return true
    if DialogManager and DialogManager.is_dialog_active():
        return true
    if CinematicsManager and CinematicsManager.is_cinematic_active():
        return true
    # Note: Field menu blocking handled via ui_controller.is_blocking_input()
    # This is fallback only when ui_controller isn't set
    return false
```

**`debug_console.gd` - `_is_other_modal_active()`:**
```gdscript
func _is_other_modal_active() -> bool:
    if ShopManager and ShopManager.is_shop_open():
        return true
    if DialogManager and DialogManager.is_dialog_active():
        return true
    # ExplorationUIController handles field menu state
    # No direct check needed here as field menu uses UIController
    return false
```

---

## Conclusion

This implementation plan provides a phased approach to adding SF-authentic field menu functionality. Phase 1 delivers immediate value with minimal risk, while subsequent phases add magic casting (Egress/Detox only), search functionality, and mod extensibility.

**Key Design Decisions (Crew Review Complete):**
- Vertical list layout (not radial) for multi-input support and mod extensibility
- "Member" terminology (SF2 authentic, not "Status")
- Dual trigger: `sf_confirm` on empty space OR `sf_cancel` (B button)
- Magic restricted to Egress/Detox only (SF2 authentic resource management)
- **Instant cursor movement** (no animation delays - SF2 purist requirement)
- Fast menu open (0.08s) with instant cursor response
- Smart edge positioning (never clips off-screen)
- Mouse hover/click support for PC users

The design follows established patterns in the codebase (`ItemActionMenu`, `CaravanMainMenu`) and integrates cleanly with the `ExplorationUIController` state machine.

Live long and prosper, Captain. Ready to implement on your command.

---

**Document History:**
- v1.0 (2025-12-08): Initial plan
- v1.1 (2025-12-08): Updated with crew review decisions (Clauderina UI/UX, Nerdlinger SF2 purist)
- v1.2 (2025-12-08): Simplified Phase 4 per Modro's review (removed FieldMenuExtensionRegistry, use mod.json parsing)
