# Inventory & Equipment System Integration Plan

**Status**: Design Complete, Ready for Implementation
**Created**: 2025-12-05
**Contributors**: Commander Claudius, Mr. Nerdlinger, Lt. Clauderina, Chief O'Brien

---

## Executive Summary

This plan integrates our new `InventoryPanel` component into a complete inventory management system spanning exploration, Caravan depot, and battle contexts. The design honors Shining Force 2's UX patterns while providing modern quality-of-life improvements and full moddability.

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Slot Architecture** | Typed (WPN/RNG1/RNG2/ACC) + Inventory | Platform flexibility over SF2 purity |
| **Effective Capacity** | 8 slots (4 equip + 4 inventory) | Configurable per-mod; SF2 purists set inventory to 0 |
| **Depot Storage** | Unlimited, in SaveData | SF2-authentic, no artificial limits |
| **Battle Equip** | Free action (no turn cost) | SF-authentic tactical flexibility |
| **Item Transfer** | "Give to..." menu flow | Simpler than drag-drop, controller-friendly |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         EXPLORATION / OVERWORLD                          │
│  ┌───────────────┐    ┌────────────────────┐    ┌───────────────────┐   │
│  │  GameMenuBar  │───▶│ PartyEquipmentMenu │───▶│  InventoryPanel   │   │
│  │  [I] key      │    │ (multi-character)  │    │ (single char)     │   │
│  └───────────────┘    └─────────┬──────────┘    └───────────────────┘   │
│                                 │                                        │
│                                 ▼                                        │
│                       ┌────────────────────┐                            │
│                       │  CaravanDepotPanel │                            │
│                       │  (shared storage)  │                            │
│                       └─────────┬──────────┘                            │
└─────────────────────────────────│────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         PERSISTENCE LAYER                                │
│  ┌───────────────────┐    ┌─────────────────┐    ┌──────────────────┐   │
│  │ CharacterSaveData │    │  StorageManager │    │     SaveData     │   │
│  │ - equipped_items  │    │  (autoload)     │    │ - depot_items[]  │   │
│  │ - inventory[]     │    │                 │    │ - gold           │   │
│  └───────────────────┘    └─────────────────┘    └──────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            BATTLE CONTEXT                                │
│  ┌─────────────┐    ┌───────────────┐    ┌────────────────────────┐    │
│  │ ActionMenu  │───▶│ BattleItemMenu│───▶│  ItemTargetSelector    │    │
│  │ [Item]      │    │ Use/Give/Equip│    │  (adjacent allies)     │    │
│  └─────────────┘    └───────────────┘    └────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## SF Series Analysis Summary

### SF1 Genesis Pain Points (What We Fix)
- 4 unified slots for BOTH equipment and items (constant juggling)
- No "can equip" preview before transferring items
- Tedious character-by-character menu navigation
- No stat comparison when equipping

### SF1 GBA Improvements (What We Adopt)
- Equipment comparison arrows (ATK ↑/↓)
- "Can equip" indicators per character
- Faster menu navigation

### SF2 Caravan/Depot (Our Model)
- **Unlimited shared storage** - the killer QoL feature
- Accessible from overworld (Caravan icon visible)
- NOT accessible in towns or battles (planning required)
- Items don't stack by quantity in original (we improve this)

### What We Modernize
- Stat comparisons on hover (not just equip preview)
- Search/filter in depot
- Batch operations ("Send all consumables to depot")
- Party-wide inventory view

---

## Context Designs

### 1. Party Equipment Menu (Overworld/Town)

**Access**: Menu button or `I` key

**Layout**:
```
┌─────────────────────────────────────────────────────────────────┐
│ PARTY EQUIPMENT                              [Depot] [X]        │
├─────────────────────────────────────────────────────────────────┤
│ [Max ▼] [Sarah] [Luke] [Ken] [Jaha] [Tao]   ← Character tabs   │
├─────────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────┐  ┌───────────────────────────┐ │
│ │   [InventoryPanel - Max]    │  │ Quick Actions:            │ │
│ │   Equipment: WPN RNG1 RNG2  │  │ [Give Item To...]         │ │
│ │   Inventory: □ □ □ □        │  │ [Store In Depot]          │ │
│ │   [Description Box]         │  │ [Compare Gear]            │ │
│ └─────────────────────────────┘  └───────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Key Features**:
- Embeds existing `InventoryPanel` component
- Tab-based character switching (keyboard: Tab, controller: LB/RB)
- "Give to..." opens character selector modal
- Stat comparison mode shows deltas vs equipped

### 2. Caravan Depot Panel

**Access**: From Party Menu or Caravan interaction on overworld

**Layout**:
```
┌─────────────────────────────────────────────────────────────────┐
│ CARAVAN DEPOT                    [Search...] [Filter: All ▼]   │
├─────────────────────────────────────────────────────────────────┤
│ ┌─────────────────┐     ┌─────────────────────────────────────┐│
│ │ [Character Inv] │ ◄─► │ Bronze Sword      x1    [Take]      ││
│ │ Max - 4 items   │     │ Power Ring        x2    [Take]      ││
│ │ WPN RNG1 RNG2   │     │ Healing Seed      x5    [Take]      ││
│ │ □ □ □ □         │     │ Medical Herb      x3    [Take]      ││
│ │                 │     │ ... (scrollable, 125 items)         ││
│ │ [Char ▼]        │     └─────────────────────────────────────┘│
│ └─────────────────┘                                            │
├─────────────────────────────────────────────────────────────────┤
│ [Store All Consumables] [Retrieve Healing Items] [Sort: Type]  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Features**:
- Unlimited storage (SF2-authentic)
- Items stack with quantity display
- Search by name, filter by type
- Batch operations for common transfers

### 3. Battle Item Menu

**Access**: Select "Item" from battle action menu

**Layout**:
```
┌───────────────────────────────┐
│ MAX - Items                   │
├───────────────────────────────┤
│ Current Equipment:            │
│ [Steel Sword] ATK+12 Range 1  │
├───────────────────────────────┤
│ Inventory:                    │
│ ► Healing Seed    [Use]       │  ← Consumes turn
│   Javelin         [Equip]     │  ← FREE action
│   Power Wine      [Use]       │
│   (empty)                     │
├───────────────────────────────┤
│ [Z] Action [X] Give [C] Back  │
└───────────────────────────────┘
```

**Turn Cost Rules** (SF-authentic):
- **Use consumable**: Ends turn
- **Equip weapon/ring**: FREE (tactical flexibility)
- **Give to adjacent ally**: FREE
- **Drop**: FREE

### 4. Shop Interface (Deferred)

Shop system design is complete but implementation deferred. Key features planned:
- Buy/sell with stat comparison vs party
- "Who can equip?" indicators
- Bulk purchase for consumables
- Sell price = 50% of buy price

---

## Implementation Phases

### Phase 1: Core Infrastructure (No UI)

**Files to Create/Modify**:

| File | Action | Description |
|------|--------|-------------|
| `core/resources/save_data.gd` | Modify | Add `depot_items: Array[String]` |
| `core/systems/storage_manager.gd` | Create | Depot operations API (autoload) |
| `core/systems/party_manager.gd` | Modify | Add `transfer_item_between_members()` |
| `project.godot` | Modify | Register StorageManager autoload |

**StorageManager API**:
```gdscript
signal depot_changed()
signal item_added_to_depot(item_id: String)
signal item_removed_from_depot(item_id: String)

func add_to_depot(item_id: String) -> bool
func remove_from_depot(item_id: String) -> bool
func get_depot_contents() -> Array[String]
func get_depot_contents_grouped() -> Dictionary  # by item type
func get_depot_count() -> int
```

### Phase 2: Exploration UI

**Files to Create**:

| File | Description |
|------|-------------|
| `scenes/ui/party_equipment_menu.gd` | Multi-character equipment screen |
| `scenes/ui/party_equipment_menu.tscn` | Scene file |
| `scenes/ui/caravan_depot_panel.gd` | Depot browsing/transfer UI |
| `scenes/ui/caravan_depot_panel.tscn` | Scene file |
| `scenes/ui/item_transfer_dialog.gd` | "Give to..." character selector |

**Reuse Strategy**:
- `PartyEquipmentMenu` embeds `InventoryPanel` instances
- `CaravanDepotPanel` embeds one `InventoryPanel` + custom depot grid
- All panels use `ItemSlot` component for consistency

### Phase 3: Battle Integration

**Files to Create/Modify**:

| File | Action | Description |
|------|--------|-------------|
| `scenes/ui/battle_item_menu.gd` | Create | Use/Give/Equip submenu |
| `core/battle/input_manager.gd` | Modify | Add give-targeting state |
| `core/battle/battle_manager.gd` | Modify | Handle give/equip actions |

**Give-to-Adjacent Flow**:
1. Player selects item, chooses "Give"
2. Grid highlights adjacent allies with inventory space
3. Player selects target
4. Item transfers, menu closes, turn continues (FREE action)

### Phase 4: Polish & Testing

- Inventory-full error handling everywhere
- Missing mod item graceful degradation ("Unknown Item")
- Save migration testing (pre-depot saves)
- Sound effects for all operations
- Controller navigation testing

---

## Signal Flow

### Item Transfer Between Characters

```
PartyEquipmentMenu
    │
    ├─► User clicks "Give to..." on item
    │
    ▼
ItemTransferDialog.show_recipients(source_uid, item_id)
    │
    ├─► User selects recipient
    │
    ▼
PartyManager.transfer_item_between_members(from_uid, to_uid, item_id)
    │
    ├─► source.remove_item_from_inventory()
    ├─► target.add_item_to_inventory()
    │
    ▼
Signal: item_transferred(from_uid, to_uid, item_id)
    │
    ├─► Both InventoryPanels refresh
    └─► Dialog closes
```

### Depot Operations

```
CaravanDepotPanel
    │
    ├─► User clicks "Store" on character's item
    │
    ▼
CharacterSaveData.remove_item_from_inventory(item_id)
StorageManager.add_to_depot(item_id)
    │
    ├─► StorageManager.depot_changed signal
    │
    ▼
CaravanDepotPanel refreshes depot list
InventoryPanel refreshes character inventory
```

---

## Risk Areas

### High Risk

1. **Save Compatibility**: Adding `depot_items` must not break existing saves
   - Mitigation: Migration code in `deserialize_from_dict()`
   - Test: Load pre-depot save, verify depot starts empty

2. **Item Loss Prevention**: Operations must never silently lose items
   - Mitigation: All operations return success/failure
   - UI shows clear error messages

3. **Battle State Sync**: Equipment changes must update combat stats
   - Mitigation: `EquipmentManager.equip_item()` auto-refreshes unit cache

### Medium Risk

4. **Concurrent Panel Updates**: Multi-character view needs proper signal handling
   - Mitigation: Single source of truth (CharacterSaveData), subscribe to signals

5. **Mod Item Orphaning**: Items from removed mods become "Unknown"
   - Mitigation: Graceful degradation, items can be dropped/stored

---

## Moddability

| Feature | Mod Override |
|---------|--------------|
| Equipment Slots | `equipment_slot_layout` in mod.json |
| Inventory Size | `inventory_config.slots_per_character` |
| Depot Capacity | `caravan_config.capacity` (-1 = unlimited) |
| Battle Item Access | `caravan_config.accessible_in_battle` |

**SF2-Authentic Configuration**:
```json
{
  "inventory_config": {
    "slots_per_character": 0
  }
}
```
This gives 4 equipment-only slots, matching SF2's unified 4-slot feel.

---

## Visual Standards

All UI follows established patterns:
- **Font**: Monogram at pixel-perfect sizes (16px body, 24px headers)
- **Colors**: Dark panels (`COLOR_PANEL_BG`), subtle borders (`COLOR_PANEL_BORDER`)
- **Spacing**: 4px slot spacing, 6px section spacing, 6px panel padding
- **Slot Size**: 48x48 pixels with icon scaling

---

## Dependencies

```
Phase 1 ─────────┬─────────► Phase 2
                 │
                 └─────────► Phase 3 (can parallel with Phase 2)

Phase 2 ─────────┬─────────► Phase 4
Phase 3 ─────────┘
```

Phase 1 must complete before any UI work. Phases 2 and 3 can be developed in parallel.

---

## Next Steps

1. **Review**: Captain approves this plan
2. **Phase 1**: Implement core infrastructure (1-2 sessions)
3. **Phase 2**: Build exploration UI (2-3 sessions)
4. **Phase 3**: Battle integration (1-2 sessions)
5. **Phase 4**: Polish and testing (1 session)

---

*"Honor SF's tactical scarcity, eliminate SF's tedious friction, enable modders' wildest dreams."*

---

## Implementation Progress (Updated 2025-12-05)

### Completed

**Phase 1: Core Infrastructure** ✅
- Added `depot_items` to SaveData (v2 migration)
- Created StorageManager autoload
- Added `transfer_item_between_members()` to PartyManager
- 35 unit tests passing

**Phase 2: UI Components** ✅
- PartyEquipmentMenu with character tabs, transfer mode, depot store
- CaravanDepotPanel with filtering, take item functionality
- Test scene at `res://scenes/ui/test_party_inventory.tscn`

### In Progress

**UI Scaling Fix** 🔄
- **Issue**: UI was too large for 640x360 viewport
- **Root Cause**: ItemSlot at 48x48 consumes too much of 640px width
- **Fix Applied**: Reduced ItemSlot from 48x48 → 32x32
  - Border: 2px → 1px
  - Icon inset: 4px → 2px
  - Font: KEPT at 16px (Monogram minimum)
- **Centering Fix**: Changed from `set_anchors_preset(PRESET_CENTER)` to `set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_KEEP_SIZE)`

### Key Technical Findings

**Viewport Configuration:**
- Base viewport: 640x360
- Window override: 1280x720 (2x upscale)
- Stretch mode: `viewport` (correct for pixel art)
- Content scale mode: 1 (CONTENT_SCALE_MODE_VIEWPORT)

**SF2-Authentic Sizing for 640x360:**
- Item slots: 32x32 (SF2 used ~28px at 320x224)
- Font: 16px minimum (Monogram pixel-perfect)
- Panel width: max ~240px (37% of viewport)

### Files Modified

- `core/resources/save_data.gd` - depot_items field
- `core/systems/storage_manager.gd` - new autoload
- `core/systems/party_manager.gd` - transfer signals/method
- `scenes/ui/party_equipment_menu.gd` - new menu
- `scenes/ui/caravan_depot_panel.gd` - new panel
- `scenes/ui/components/item_slot.gd` - 32x32 sizing
- `scenes/ui/test_party_inventory.gd` - test harness
- `tests/unit/storage/` - 35 tests

### Phase 2.5: Game Flow Integration ✅

**ExplorationUIController Architecture** (2025-12-05)

Created `ExplorationUIController` as a local scene component (not autoload) to manage exploration UI state:

```
ExplorationScene
    │
    ├── HeroController (has ui_controller reference)
    ├── ExplorationUIController
    │       ├── state_changed signal
    │       ├── menu_opened signal
    │       └── menu_closed signal
    └── UILayer (CanvasLayer)
            ├── PartyEquipmentMenu
            └── CaravanDepotPanel
```

**Key Decisions:**
- ExplorationUIController is scene-local (not autoload) - follows battle scene pattern
- CaravanDepotPanel is sibling of PartyEquipmentMenu (not child)
- HeroController checks `ui_controller.is_blocking_input()` before processing movement
- Input action `sf_inventory` mapped to "I" key for inventory hotkey
- Depot navigation: closing depot returns to inventory if that's where it was opened from

**Files Created:**
- `core/components/exploration_ui_controller.gd` - Menu state management

**Files Modified:**
- `project.godot` - Added `sf_inventory` input action
- `scenes/map_exploration/hero_controller.gd` - Added `ui_controller` ref and blocking checks
- `scenes/map_exploration/map_test_playable.gd` - Wired up ExplorationUIController

**UI Polish Applied:**
- DESCRIPTION_HEIGHT increased from 64 to 88 pixels (prevents stat clipping)
- ITEMS_PER_ROW reduced from 6 to 5 (prevents horizontal scroll in depot)

### Pending

- Phase 3: Battle item menu integration (new BattleItemMenu component)
- Visual testing of 32x32 slots with 16px font
- Stat comparison deltas for equipment hover (Clauderina recommendation)
- Inventory capacity indicator in character info (Clauderina recommendation)
