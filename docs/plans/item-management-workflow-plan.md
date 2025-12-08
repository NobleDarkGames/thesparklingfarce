# Item Management Workflow Plan

**Status**: APPROVED FOR IMPLEMENTATION
**Priority**: HIGH (Phase 3.5)
**Estimated Effort**: 2 weeks
**Created**: 2025-12-07

---

## Overview

Add player-accessible item management workflows for equipping, using, giving, and dropping items. This completes the core RPG gameplay loop by exposing existing backend systems through proper UI.

---

## Captain's Decisions

| Question | Decision |
|----------|----------|
| Field healing targeting | **Party selection** - use existing bouncing cursor from attack mode |
| Undroppable items | **Item property** - add `can_be_dropped` flag to ItemData (not category-based) |
| Drop confirmation | **Per-item setting** - add `confirm_on_drop` property, defaults to `true` |
| Battle equipment changes | **Configurable** - game/mod setting to allow or block mid-battle equip |

---

## Current State Assessment

### Already Implemented ✓

| System | Location | Notes |
|--------|----------|-------|
| ItemData resource | `core/resources/item_data.gd` | Complete with types, slots, effects |
| CharacterSaveData.inventory | `core/resources/character_save_data.gd` | 4 slots, CRUD methods |
| EquipmentManager | `core/systems/equipment_manager.gd` | Equip/unequip, curse mechanics |
| PartyManager.transfer_item | `core/systems/party_manager.gd` | Give between characters |
| StorageManager | `core/systems/storage_manager.gd` | Caravan depot |
| ItemSlot component | `scenes/ui/components/item_slot.gd` | 32x32 reusable widget |
| InventoryPanel | `scenes/ui/inventory_panel.gd` | Single character equip view |
| PartyEquipmentMenu | `scenes/ui/party_equipment_menu.gd` | Multi-char + Give flow |
| Battle ItemMenu | `scenes/ui/item_menu.gd` | Shows 4 slots, USE only |
| Bouncing cursor | `core/systems/input_manager.gd` | Target selection UI |

### Missing ✗

| Feature | Priority |
|---------|----------|
| Use consumables on field (with party target selection) | HIGH |
| Drop/Discard items | HIGH |
| Item Action Menu (Use/Equip/Give/Drop/Info sub-menu) | HIGH |
| Item detail view panel | MEDIUM |
| Battle Equip/Give (configurable) | LOW (Phase 5) |

---

## SF2 Authenticity Guidelines

### Sacred Cows (Must Preserve)
- 4 inventory slots per character
- Consumables-only in battle by default
- No giving items mid-battle
- Caravan depot for shared storage

### Acceptable Modernizations
- Stat preview on hover (SF2 didn't have this)
- Explicit equipment slots vs SF2's "weapon equipped from inventory"
- Party-wide target selection for field consumables
- Configurable battle equip rules

### Items to Add
- DROP command with confirmation
- `can_be_dropped` flag on ItemData
- `confirm_on_drop` flag on ItemData

---

## Technical Design

### New ItemData Properties

```gdscript
# Add to core/resources/item_data.gd

## Whether this item can be dropped/discarded by the player
## Set to false for plot-critical or special items
@export var can_be_dropped: bool = true

## Whether to show confirmation dialog when dropping
## Defaults to true for safety; set false for common consumables if desired
@export var confirm_on_drop: bool = true
```

### New Game Settings

```gdscript
# Add to game config or mod.json

## Whether characters can equip items during battle
## true = SF2-modernized (allow equip mid-battle)
## false = SF2-authentic (no equip mid-battle, consumables only)
"allow_battle_equip": false  # Default to authentic
```

### ItemActionMenu Component

**Purpose**: Context-sensitive sub-menu when an item is selected

**Location**: `scenes/ui/item_action_menu.gd` + `.tscn`

**Behavior**:
```
┌─────────────────────┐
│  [Icon] Item Name   │
├─────────────────────┤
│  > Use              │  ← Available actions filtered by:
│    Equip            │     - Item type (consumable vs equipment)
│    Give             │     - Context (battle vs exploration)
│    Drop             │     - Item flags (can_be_dropped)
│    Info             │     - Game settings (allow_battle_equip)
└─────────────────────┘
```

**Action Availability Matrix**:

| Action | Exploration | Battle (Default) | Battle (Equip Enabled) |
|--------|-------------|------------------|------------------------|
| Use | If `usable_on_field` | If `usable_in_battle` | If `usable_in_battle` |
| Equip | If equippable | NO | If equippable |
| Give | Always | NO | NO |
| Drop | If `can_be_dropped` | If `can_be_dropped` | If `can_be_dropped` |
| Info | Always | Always | Always |

### Field Consumable Use Flow

```
1. Player opens inventory (Press I)
2. Selects consumable item
3. ItemActionMenu appears → selects "Use"
4. Target selection mode activates:
   - Bouncing cursor appears (reuse from attack targeting)
   - Shows valid targets (party members)
   - Player selects target with cursor
5. Effect applied, item consumed
6. Return to inventory view
```

**Integration with existing cursor**:
- Reuse `InputManager`'s target selection cursor
- Filter to show only party members (not enemies)
- Snap-to-target navigation already implemented

### Confirmation Dialog Component

**Purpose**: Reusable yes/no prompt for destructive actions

**Location**: `scenes/ui/confirmation_dialog.gd` + `.tscn`

**Usage**:
```gdscript
# When dropping an item with confirm_on_drop = true
confirmation_dialog.show_confirmation(
    "Drop Item?",
    "Are you sure you want to discard %s?" % item.item_name,
    _on_drop_confirmed,
    _on_drop_cancelled
)
```

---

## UI/UX Specifications

### Visual Style (Match Existing Patterns)

```gdscript
# Colors (from ActionMenu/ItemMenu)
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)  # Yellow
const PANEL_COLOR: Color = Color(0.1, 0.1, 0.15, 0.95)
const BORDER_COLOR: Color = Color(0.8, 0.8, 0.9, 1.0)

# Font
const FONT: Font = preload("res://assets/fonts/monogram.ttf")
const FONT_SIZE: int = 16
```

### Navigation

- **Keyboard**: Arrow keys to navigate, Enter to confirm, Escape to cancel
- **Mouse**: Click to select, hover for highlight
- **Audio**: cursor_move, menu_confirm, menu_cancel, menu_error sounds

### Modal Input Blocking

Follow platform spec pattern - add to `ExplorationUIController.is_blocking_input()`:
```gdscript
if _item_action_menu_visible:
    return true
```

---

## Implementation Phases

### Phase 1: Foundation (3-4 days)

**Tasks**:
1. Add `can_be_dropped` and `confirm_on_drop` to ItemData
2. Create `ItemActionMenu` component with action filtering
3. Create `ConfirmationDialog` component
4. Add game setting for `allow_battle_equip`

**Files**:
- MODIFY: `core/resources/item_data.gd`
- CREATE: `scenes/ui/item_action_menu.gd`
- CREATE: `scenes/ui/item_action_menu.tscn`
- CREATE: `scenes/ui/confirmation_dialog.gd`
- CREATE: `scenes/ui/confirmation_dialog.tscn`

**Testing**:
- Unit tests for action availability logic
- Headless validation

### Phase 2: Exploration Integration (3-4 days)

**Tasks**:
1. Hook ItemActionMenu into InventoryPanel
2. Implement "Use" action with party target selection
   - Reuse bouncing cursor from InputManager
   - Filter to party members only
3. Implement "Drop" action with confirmation flow
4. Implement "Info" action (detail panel or enhanced tooltip)
5. Update ExplorationUIController for modal blocking

**Files**:
- MODIFY: `scenes/ui/inventory_panel.gd`
- MODIFY: `core/components/exploration_ui_controller.gd`
- POSSIBLY CREATE: `scenes/ui/item_detail_panel.gd` (or enhance existing tooltip)

**Testing**:
- Manual: Use healing herb on party member
- Manual: Drop item with confirmation
- Manual: Verify modal blocking prevents movement

### Phase 3: Polish & Edge Cases (2-3 days)

**Tasks**:
1. Handle inventory full scenarios
2. Add sound effects for all new actions
3. Cursed item blocking (can't drop cursed equipped items)
4. Error messages for invalid operations
5. Update existing item resources with new flags where needed

**Testing**:
- Manual: Full workflow testing
- Integration tests with save/load

### Phase 4: Battle Integration (DEFER - Phase 5+)

**Tasks** (when ready):
1. Integrate ItemActionMenu into battle ItemMenu
2. Respect `allow_battle_equip` setting
3. Handle turn consumption for item actions

---

## File Summary

### New Files

| File | Purpose |
|------|---------|
| `scenes/ui/item_action_menu.gd` | Context-aware item action sub-menu |
| `scenes/ui/item_action_menu.tscn` | Scene for ItemActionMenu |
| `scenes/ui/confirmation_dialog.gd` | Reusable yes/no confirmation |
| `scenes/ui/confirmation_dialog.tscn` | Scene for ConfirmationDialog |

### Modified Files

| File | Changes |
|------|---------|
| `core/resources/item_data.gd` | Add `can_be_dropped`, `confirm_on_drop` |
| `scenes/ui/inventory_panel.gd` | Integrate ItemActionMenu |
| `core/components/exploration_ui_controller.gd` | Modal blocking check |
| Game config / mod.json schema | Add `allow_battle_equip` setting |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Target cursor reuse complexity | Medium | Cursor already supports filtering; test early |
| Modal input leaking | High | Follow documented blocking pattern strictly |
| Inventory full edge cases | Low | CharacterSaveData already validates |
| Save compatibility | Low | New ItemData fields have defaults |

---

## Success Criteria

1. Player can use healing items on any party member from inventory
2. Player can drop items with appropriate confirmation
3. Bouncing cursor works for party target selection
4. Modal UI properly blocks hero movement
5. All existing tests still pass
6. New functionality works with save/load

---

## References

- Platform Specification: `docs/specs/platform-specification.md`
- Modal UI Pattern: Platform spec section "Modal UI Input Blocking"
- Existing UI patterns: `scenes/ui/action_menu.gd`, `scenes/ui/item_menu.gd`
- SF2 mechanics analysis: Mr. Nerdlinger's report (2025-12-07)
