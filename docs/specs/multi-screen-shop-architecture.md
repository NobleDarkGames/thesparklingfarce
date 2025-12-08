# Multi-Screen Shop Architecture with Order Queue

**Version**: 2.0.0
**Status**: Technical Specification (Final)
**Authors**: Chief Engineer O'Brien, Lt. Clauderina
**Date**: 2025-12-07
**Approved By**: Captain Obvious

---

## Executive Summary

This specification defines a multi-screen shop system with an integrated order queue for bulk consumable purchases. The system uses a **pay-per-placement** model where gold is charged incrementally as each item is placed into inventory.

### Core Design Principles

> **Captain's Rule #1**: "Players can only queue what they can afford."
>
> Quantity validation happens at queue time. If a player tries to queue more than they can afford, the quantity resets to the maximum affordable amount.

> **Captain's Rule #2**: "Gold is charged per placement, not upfront."
>
> During placement mode, each click on a character deducts gold for ONE item. Clicking Caravan places ALL remaining items and charges for all of them.

> **Captain's Rule #3**: "Caravan storage is infinite."
>
> Players were emphatic about this. The Caravan can always accept all remaining items.

---

## 1. Screen Structure

### 1.1 Directory Layout

```
scenes/ui/shops/
├── shop_controller.gd         # Main controller, screen stack, context owner
├── shop_controller.tscn       # Controller scene with shared UI elements
├── screens/
│   ├── shop_greeting.gd       # Welcome/farewell screen
│   ├── shop_greeting.tscn
│   ├── action_select.gd       # Buy/Sell/Deals/Exit menu
│   ├── action_select.tscn
│   ├── item_browser.gd        # Item list with queue building for consumables
│   ├── item_browser.tscn
│   ├── placement_mode.gd      # Distribute queued items to characters (PAY-PER-PLACEMENT)
│   ├── placement_mode.tscn
│   ├── char_select.gd         # Single-item destination (equipment)
│   ├── char_select.tscn
│   ├── sell_char_select.gd    # Choose who's selling (sell mode)
│   ├── sell_char_select.tscn
│   ├── sell_inventory.gd      # Browse character inventory to queue items for sale
│   ├── sell_inventory.tscn
│   ├── sell_confirm.gd        # Confirm batch sale
│   ├── sell_confirm.tscn
│   ├── confirm_transaction.gd # "Buy X for Y gold?" confirmation (equipment)
│   ├── confirm_transaction.tscn
│   ├── transaction_result.gd  # Success/failure feedback
│   └── transaction_result.tscn
└── components/
    ├── item_button.gd         # Reusable item display button
    ├── item_button.tscn
    ├── character_slot.gd      # Character portrait with inventory preview
    ├── character_slot.tscn
    ├── queue_panel.gd         # Shows queued items with running total
    ├── queue_panel.tscn
    └── stat_comparison.gd     # Equipment stat diff display
    └── stat_comparison.tscn
```

### 1.2 Screen Hierarchy

```
ShopController (CanvasLayer)
├── SharedUI
│   ├── Header (shop name, REAL-TIME gold display)
│   ├── QueuePanel (visible during item_browser, placement_mode)
│   └── MessageFeedback
├── ScreenContainer (Control)
│   └── [Current Screen - swapped by controller]
└── InputBlocker (ColorRect, blocks input during transitions)
```

### 1.3 Screen Responsibilities

| Screen | Purpose | Transitions To |
|--------|---------|----------------|
| `shop_greeting` | Display shopkeeper greeting, brief pause | `action_select` |
| `action_select` | Main menu: Buy, Sell, Deals, Exit | `item_browser`, `sell_char_select`, Exit |
| `item_browser` | Browse items, add to queue (consumables) or select (equipment) | `char_select`, `placement_mode`, back to `action_select` |
| `char_select` | "Who equips this?" for equipment | `confirm_transaction`, back |
| `placement_mode` | Distribute queued consumables, **charge per placement** | `transaction_result`, cancel clears queue |
| `sell_char_select` | "Who's selling?" | `sell_inventory`, back |
| `sell_inventory` | Browse inventory, queue items to sell | `sell_confirm`, back |
| `sell_confirm` | Confirm batch sale, show total gold earned | `transaction_result`, back |
| `confirm_transaction` | Final confirmation for equipment purchase | `transaction_result`, back |
| `transaction_result` | Success/failure message | `item_browser` (continue), `action_select` (done) |

---

## 2. Queue Data Structure

### 2.1 QueuedItem Resource

```gdscript
## scenes/ui/shops/resources/queued_item.gd
class_name QueuedItem
extends RefCounted

## The item being purchased
var item_id: String = ""

## Quantity of this item in the queue
var quantity: int = 0

## Unit price at time of queueing (captures deal pricing)
var unit_price: int = 0

## Whether this was queued from deals menu
var is_deal: bool = false

## Total cost for this queue entry
func get_total_cost() -> int:
    return unit_price * quantity


## Create a new queued item
static func create(p_item_id: String, p_quantity: int, p_unit_price: int, p_is_deal: bool = false) -> QueuedItem:
    var item: QueuedItem = QueuedItem.new()
    item.item_id = p_item_id
    item.quantity = p_quantity
    item.unit_price = p_unit_price
    item.is_deal = p_is_deal
    return item
```

### 2.2 OrderQueue Class

```gdscript
## scenes/ui/shops/order_queue.gd
class_name OrderQueue
extends RefCounted

## Signal emitted when queue contents change
signal queue_changed()

## Signal emitted when an item is added
signal item_added(item_id: String, quantity: int)

## Signal emitted when an item is removed (placement or manual removal)
signal item_removed(item_id: String, quantity: int)

## Internal storage: Dictionary[String, QueuedItem] keyed by item_id
var _items: Dictionary = {}

## Cached total cost (updated on modification)
var _cached_total: int = 0


## Add items to the queue
## Returns true if successfully added, false if would exceed budget
func add_item(item_id: String, quantity: int, unit_price: int, is_deal: bool, available_gold: int) -> bool:
    var additional_cost: int = unit_price * quantity

    # Captain's Rule: Cannot queue more than we can afford
    if _cached_total + additional_cost > available_gold:
        return false

    if item_id in _items:
        _items[item_id].quantity += quantity
    else:
        _items[item_id] = QueuedItem.create(item_id, quantity, unit_price, is_deal)

    _cached_total += additional_cost
    item_added.emit(item_id, quantity)
    queue_changed.emit()
    return true


## Remove ONE item from the queue (used during placement)
## Returns the QueuedItem info for the removed item, or null if not found
func remove_one(item_id: String) -> QueuedItem:
    if item_id not in _items:
        return null

    var queued: QueuedItem = _items[item_id]
    var unit_price: int = queued.unit_price

    queued.quantity -= 1
    _cached_total -= unit_price

    if queued.quantity <= 0:
        _items.erase(item_id)

    item_removed.emit(item_id, 1)
    queue_changed.emit()

    # Return info about what was removed
    return QueuedItem.create(item_id, 1, unit_price, queued.is_deal)


## Remove specific quantity from queue
func remove_item(item_id: String, quantity: int) -> int:
    if item_id not in _items:
        return 0

    var queued: QueuedItem = _items[item_id]
    var actual_removed: int = mini(quantity, queued.quantity)

    queued.quantity -= actual_removed
    _cached_total -= queued.unit_price * actual_removed

    if queued.quantity <= 0:
        _items.erase(item_id)

    item_removed.emit(item_id, actual_removed)
    queue_changed.emit()
    return actual_removed


## Get quantity of specific item in queue
func get_quantity(item_id: String) -> int:
    if item_id in _items:
        return _items[item_id].quantity
    return 0


## Get unit price for item (needed for per-placement charging)
func get_unit_price(item_id: String) -> int:
    if item_id in _items:
        return _items[item_id].unit_price
    return 0


## Get total cost of entire queue
func get_total_cost() -> int:
    return _cached_total


## Get total number of items (sum of all quantities)
func get_total_item_count() -> int:
    var total: int = 0
    for item: QueuedItem in _items.values():
        total += item.quantity
    return total


## Check if queue is empty
func is_empty() -> bool:
    return _items.is_empty()


## Clear the entire queue (used on cancel)
func clear() -> void:
    var had_items: bool = not _items.is_empty()
    _items.clear()
    _cached_total = 0
    if had_items:
        queue_changed.emit()


## Get all queued items as array (for iteration)
func get_all_items() -> Array[QueuedItem]:
    var result: Array[QueuedItem] = []
    for item: QueuedItem in _items.values():
        result.append(item)
    return result


## Get first item in queue (for placement mode display)
func get_first_item() -> QueuedItem:
    if _items.is_empty():
        return null
    return _items.values()[0]
```

### 2.3 Where Queue Lives

The `OrderQueue` instance lives in `ShopContext`, which is owned by `ShopController`. This ensures:

1. Queue persists across screen transitions within a shop session
2. Queue is automatically cleared when shop closes
3. All screens access the same queue via context reference

---

## 3. Flow Branching

### 3.1 Buy Flow: Equipment vs Consumables

The branching decision happens in `item_browser.gd` when an item is selected:

```gdscript
## item_browser.gd

func _on_item_confirmed(item_id: String, quantity: int) -> void:
    var item_data: ItemData = _get_item_data(item_id)
    if not item_data:
        return

    # DECISION POINT: Equipment vs Consumable
    if item_data.is_equippable():
        # Path A: Equipment - go directly to character selection
        _start_equipment_flow(item_id)
    else:
        # Path B: Consumables - add to queue
        _add_to_queue(item_id, quantity)
```

### 3.2 Visual Flow Diagrams

**Path A: Equipment Purchase (Single Item)**
```
[Item Browser]
    │ Select sword, qty always 1
    ▼
[Char Select] "Who equips this?"
    │ Select Max
    ▼
[Confirm] "Buy Bronze Sword for 120G?"
    │ Confirm
    ▼
[Result] "Max equipped Bronze Sword!"
    │
    ▼
[Item Browser] (continue shopping)
```

**Path B: Consumable Bulk Purchase (Pay-Per-Placement)**
```
[Item Browser]
    │ Select Herb, set qty to 6
    │ Click "Add to Queue"
    │ Queue shows: 6x Herb = 60G
    │ Click "Proceed to Placement"
    ▼
[Placement Mode]                    Gold: 100G
    │ Click Hero
    │   → 1 Herb placed             Gold: 90G (charged 10G)
    │ Click Hero
    │   → 1 Herb placed             Gold: 80G (charged 10G)
    │ Click Warrior
    │   → 1 Herb placed             Gold: 70G (charged 10G)
    │ Click Caravan
    │   → 3 Herbs placed (ALL)      Gold: 40G (charged 30G)
    ▼
[Result] "Placed 6 items! Spent 60G"
    │
    ▼
[Item Browser] (continue shopping)
```

**Path B: Cancelled Mid-Placement**
```
[Placement Mode]                    Gold: 100G
    │ Click Hero
    │   → 1 Herb placed             Gold: 90G
    │ Click Hero
    │   → 1 Herb placed             Gold: 80G
    │ Click CANCEL
    │   → Confirmation dialog
    │   → Queue cleared (4 unplaced)
    │   → NO REFUND NEEDED (never charged)
    ▼
[Item Browser]                      Gold: 80G (kept what was placed)
```

### 3.3 Sell Flow (Same Queue Pattern)

**Path C: Selling Items**
```
[Action Select]
    │ Click "Sell"
    ▼
[Sell Char Select] "Who's selling?"
    │ Select Max
    ▼
[Sell Inventory]
    │ Browse Max's items
    │ Select Herb, qty 3 → Add to sell queue
    │ Select Old Sword → Add to sell queue
    │ Queue shows: 3x Herb + Old Sword = 45G earned
    │ Click "Confirm Sale"
    ▼
[Sell Confirm]
    │ "Sell 4 items for 45G?"
    │ Confirm
    ▼
[Result] "Sold 4 items! Earned 45G"
    │
    ▼
[Action Select] (continue or exit)
```

### 3.4 Flow Determination

| Item Type | Buy Flow | Sell Flow |
|-----------|----------|-----------|
| WEAPON | Equipment (Path A) | Batch (Path C) |
| ARMOR | Equipment (Path A) | Batch (Path C) |
| ACCESSORY | Equipment (Path A) | Batch (Path C) |
| CONSUMABLE | Queue + Placement (Path B) | Batch (Path C) |
| KEY_ITEM | Usually not sellable | Usually not sellable |

---

## 4. Gold Handling Strategy: Pay-Per-Placement

### 4.1 The Pay-Per-Placement Model

**Key Insight**: Gold is NOT charged when items are added to the queue. Gold is charged incrementally AS EACH ITEM IS PLACED during placement mode.

**Queue Building Phase**:
1. Player selects item and quantity
2. System validates: `queue_total + (quantity × price) <= current_gold`
3. If invalid, quantity resets to max affordable
4. If valid, item added to queue
5. **NO GOLD CHARGED YET**

**Placement Phase**:
1. Player clicks a character → ONE item placed → ONE item's gold charged
2. Player clicks Caravan → ALL remaining items placed → ALL remaining gold charged
3. Gold display updates in REAL-TIME after each placement

### 4.2 Example Walkthrough

```
Initial State:
  Gold: 100G
  Queue: 6x Healing Herb @ 10G each (60G total)

Player clicks Hero:
  Action: Place 1 Herb to Hero, charge 10G
  Result: Queue now 5x Herb, Gold now 90G

Player clicks Hero:
  Action: Place 1 Herb to Hero, charge 10G
  Result: Queue now 4x Herb, Gold now 80G

Player clicks Caravan:
  Action: Place ALL 4 Herbs to Caravan, charge 40G
  Result: Queue empty, Gold now 40G

Player clicks Cancel (alternate):
  Action: Clear remaining queue
  Result: Queue cleared, Gold stays at current value
  No refund needed - unplaced items were never charged!
```

### 4.3 Queue Validation

```gdscript
## In item_browser.gd - when player adjusts quantity spinner

func _on_quantity_changed(new_value: int) -> void:
    var item_price: int = _get_item_price(selected_item_id)
    var queue_cost: int = context.queue.get_total_cost()
    var current_gold: int = ShopManager.get_gold()
    var available: int = current_gold - queue_cost

    var max_affordable: int = available / item_price if item_price > 0 else 0

    # Cap quantity to max affordable
    if new_value > max_affordable:
        quantity_spinner.value = max_affordable
        _show_feedback("Can only afford %d" % max_affordable)
```

### 4.4 Display Strategy

**During Queue Building (Item Browser)**:
```
┌─────────────────────────┐
│ ORDER QUEUE             │
├─────────────────────────┤
│ 6x Healing Herb    60G  │
├─────────────────────────┤
│ TOTAL:             60G  │
│ GOLD:             100G  │
│ AFTER PURCHASE:    40G  │
└─────────────────────────┘
```

**During Placement Mode**:
```
┌─────────────────────────────────────────┐
│ PLACING: Healing Herb (4 remaining)     │
│ GOLD: 80G (-10G per placement)          │
├─────────────────────────────────────────┤
│ [HERO]      [WARRIOR]    [MAGE]         │
│ Place 1     Place 1      Place 1        │
│ -10G        -10G         -10G           │
├─────────────────────────────────────────┤
│ [STORE ALL IN CARAVAN]                  │
│ 4 items → -40G                          │
├─────────────────────────────────────────┤
│ [CANCEL ORDER]                          │
└─────────────────────────────────────────┘
```

---

## 5. State Management

### 5.1 ShopContext Class

```gdscript
## scenes/ui/shops/shop_context.gd
class_name ShopContext
extends RefCounted

## The ShopData resource for the current shop
var shop: ShopData = null

## Current shopping mode
enum Mode { BUY, SELL, DEALS }
var mode: Mode = Mode.BUY

## The order queue (for consumable bulk purchases OR batch selling)
var queue: OrderQueue = null

## Currently selected item (for equipment flow)
var selected_item_id: String = ""

## Quantity for current selection (equipment = 1, consumables use queue)
var selected_quantity: int = 1

## Selected destination for equipment ("caravan" or character_uid)
var selected_destination: String = ""

## In sell mode: whose inventory are we selling from?
var selling_from_uid: String = ""

## Reference to SaveData (for gold operations)
var save_data: SaveData = null

## Screen navigation history (for back button)
var screen_history: Array[String] = []

## Last transaction results (for result screen)
var last_result: Dictionary = {}


## Initialize context for a new shop session
func initialize(p_shop: ShopData, p_save_data: SaveData) -> void:
    shop = p_shop
    save_data = p_save_data
    mode = Mode.BUY
    queue = OrderQueue.new()
    selected_item_id = ""
    selected_quantity = 1
    selected_destination = ""
    selling_from_uid = ""
    screen_history.clear()
    last_result.clear()


## Clean up when closing shop
func cleanup() -> void:
    queue.clear()
    queue = null
    shop = null
    save_data = null
    screen_history.clear()
    last_result.clear()


## Check if we're in deals mode
func is_deals_mode() -> bool:
    return mode == Mode.DEALS


## Get current gold (real-time, reflects any charges)
func get_current_gold() -> int:
    return save_data.gold if save_data else 0


## Get gold available for NEW queue additions (gold - queue total)
func get_available_for_queue() -> int:
    var current_gold: int = get_current_gold()
    var queue_total: int = queue.get_total_cost() if queue else 0
    return current_gold - queue_total


## Push screen to history
func push_to_history(screen_name: String) -> void:
    screen_history.append(screen_name)


## Pop and return previous screen (or empty string if at root)
func pop_from_history() -> String:
    if screen_history.is_empty():
        return ""
    return screen_history.pop_back()
```

### 5.2 ShopController (Updated for Real-Time Gold)

```gdscript
## scenes/ui/shops/shop_controller.gd
extends CanvasLayer

signal shop_closed()

## Context shared across all screens
var context: ShopContext = null

## Currently active screen instance
var current_screen: Control = null

## Screen scene cache
var _screen_scenes: Dictionary = {
    "greeting": preload("res://scenes/ui/shops/screens/shop_greeting.tscn"),
    "action_select": preload("res://scenes/ui/shops/screens/action_select.tscn"),
    "item_browser": preload("res://scenes/ui/shops/screens/item_browser.tscn"),
    "char_select": preload("res://scenes/ui/shops/screens/char_select.tscn"),
    "placement_mode": preload("res://scenes/ui/shops/screens/placement_mode.tscn"),
    "sell_char_select": preload("res://scenes/ui/shops/screens/sell_char_select.tscn"),
    "sell_inventory": preload("res://scenes/ui/shops/screens/sell_inventory.tscn"),
    "sell_confirm": preload("res://scenes/ui/shops/screens/sell_confirm.tscn"),
    "confirm_transaction": preload("res://scenes/ui/shops/screens/confirm_transaction.tscn"),
    "transaction_result": preload("res://scenes/ui/shops/screens/transaction_result.tscn"),
}

@onready var screen_container: Control = %ScreenContainer
@onready var queue_panel: Control = %QueuePanel
@onready var gold_label: Label = %GoldLabel


func _ready() -> void:
    context = ShopContext.new()
    hide()


## Open shop with given ShopData
func open_shop(shop_data: ShopData, save_data: SaveData) -> void:
    context.initialize(shop_data, save_data)
    update_gold_display()
    _show_queue_panel(false)
    show()
    push_screen("greeting")


## Update gold display (call after any transaction)
func update_gold_display() -> void:
    var gold: int = context.get_current_gold()
    gold_label.text = "GOLD: %dG" % gold


## Close shop and clean up
func close_shop() -> void:
    context.cleanup()
    _clear_current_screen()
    hide()
    shop_closed.emit()


## Navigate to a new screen
func push_screen(screen_name: String) -> void:
    var old_screen_name: String = _get_current_screen_name()
    if not old_screen_name.is_empty():
        context.push_to_history(old_screen_name)
    _transition_to_screen(screen_name)


## Go back to previous screen
func pop_screen() -> void:
    var previous: String = context.pop_from_history()
    if previous.is_empty():
        close_shop()
    else:
        _transition_to_screen(previous)


## Replace current screen without adding to history
func replace_screen(screen_name: String) -> void:
    _transition_to_screen(screen_name)


func _transition_to_screen(screen_name: String) -> void:
    _clear_current_screen()

    if screen_name not in _screen_scenes:
        push_error("ShopController: Unknown screen '%s'" % screen_name)
        return

    var scene: PackedScene = _screen_scenes[screen_name]
    current_screen = scene.instantiate()
    current_screen.initialize(self, context)
    screen_container.add_child(current_screen)

    # Show/hide queue panel based on screen
    var show_queue: bool = screen_name in ["item_browser", "placement_mode", "sell_inventory"]
    _show_queue_panel(show_queue and not context.queue.is_empty())


func _clear_current_screen() -> void:
    if current_screen:
        current_screen.queue_free()
        current_screen = null


func _get_current_screen_name() -> String:
    if not current_screen:
        return ""
    return current_screen.scene_file_path.get_file().get_basename()


func _show_queue_panel(p_visible: bool) -> void:
    queue_panel.visible = p_visible
    if p_visible:
        queue_panel.refresh(context.queue, context.get_current_gold())
```

---

## 6. Placement Mode: Pay-Per-Placement Implementation

### 6.1 Core Placement Logic

```gdscript
## scenes/ui/shops/screens/placement_mode.gd
extends ShopScreenBase

signal item_placed(item_id: String, target_uid: String, cost: int)
signal placement_complete(total_placed: int, total_spent: int)
signal placement_cancelled(placed_count: int, cancelled_count: int)

@onready var current_item_label: Label = %CurrentItemLabel
@onready var remaining_label: Label = %RemainingLabel
@onready var gold_label: Label = %GoldLabel
@onready var cost_per_label: Label = %CostPerLabel
@onready var character_grid: GridContainer = %CharacterGrid
@onready var caravan_button: Button = %CaravanButton
@onready var cancel_button: Button = %CancelButton

## Tracks how many items placed and gold spent this session
var _placed_count: int = 0
var _total_spent: int = 0


func _on_initialized() -> void:
    _placed_count = 0
    _total_spent = 0

    _setup_character_buttons()
    _setup_caravan_button()
    _update_display()

    cancel_button.pressed.connect(_on_cancel_pressed)


func _setup_character_buttons() -> void:
    for child in character_grid.get_children():
        child.queue_free()

    for character: CharacterData in PartyManager.party_members:
        var btn: Button = _create_character_button(character)
        character_grid.add_child(btn)


func _create_character_button(character: CharacterData) -> Button:
    var btn: Button = Button.new()
    var slots_used: int = character.inventory.size()
    var slots_max: int = character.max_inventory_size

    btn.text = "%s (%d/%d)\nPlace 1" % [character.character_name, slots_used, slots_max]
    btn.custom_minimum_size = Vector2(100, 60)

    # Disable if inventory full
    if slots_used >= slots_max:
        btn.disabled = true
        btn.text = "%s\nFULL" % character.character_name

    btn.pressed.connect(func() -> void: _on_character_clicked(character.character_uid))
    return btn


func _setup_caravan_button() -> void:
    _update_caravan_button()
    caravan_button.pressed.connect(_on_caravan_clicked)


func _update_caravan_button() -> void:
    var remaining: int = context.queue.get_total_item_count()
    var total_cost: int = context.queue.get_total_cost()

    if remaining == 0:
        caravan_button.disabled = true
        caravan_button.text = "CARAVAN\n(empty)"
    elif remaining == 1:
        caravan_button.text = "STORE IN CARAVAN\n1 item → -%dG" % context.queue.get_unit_price(context.queue.get_first_item().item_id)
    else:
        caravan_button.text = "STORE ALL IN CARAVAN\n%d items → -%dG" % [remaining, total_cost]


func _update_display() -> void:
    var first_item: QueuedItem = context.queue.get_first_item()

    if not first_item:
        # Queue empty - placement complete
        _finish_placement()
        return

    var item_data: ItemData = ModLoader.registry.get_resource("item", first_item.item_id)
    var item_name: String = item_data.item_name if item_data else first_item.item_id
    var remaining: int = context.queue.get_total_item_count()

    current_item_label.text = item_name
    remaining_label.text = "%d remaining" % remaining
    gold_label.text = "GOLD: %dG" % context.get_current_gold()
    cost_per_label.text = "-%dG per placement" % first_item.unit_price

    _update_caravan_button()
    _refresh_character_buttons()
    controller.update_gold_display()


func _refresh_character_buttons() -> void:
    var idx: int = 0
    for character: CharacterData in PartyManager.party_members:
        if idx < character_grid.get_child_count():
            var btn: Button = character_grid.get_child(idx)
            var slots_used: int = character.inventory.size()
            var slots_max: int = character.max_inventory_size

            if slots_used >= slots_max:
                btn.disabled = true
                btn.text = "%s\nFULL" % character.character_name
            else:
                btn.disabled = false
                btn.text = "%s (%d/%d)\nPlace 1" % [character.character_name, slots_used, slots_max]
        idx += 1


func _on_character_clicked(character_uid: String) -> void:
    var first_item: QueuedItem = context.queue.get_first_item()
    if not first_item:
        return

    # Execute single purchase via ShopManager
    var result: Dictionary = ShopManager.buy_item(
        first_item.item_id,
        1,
        character_uid
    )

    if result.success:
        # Remove from queue (already charged by ShopManager)
        context.queue.remove_one(first_item.item_id)

        _placed_count += 1
        _total_spent += first_item.unit_price

        item_placed.emit(first_item.item_id, character_uid, first_item.unit_price)

        _update_display()
    else:
        _show_error("Could not place item: %s" % result.error)


func _on_caravan_clicked() -> void:
    # Place ALL remaining items to Caravan
    var items_to_place: Array[QueuedItem] = context.queue.get_all_items().duplicate()

    for queued: QueuedItem in items_to_place:
        for i: int in range(queued.quantity):
            var result: Dictionary = ShopManager.buy_item(
                queued.item_id,
                1,
                "caravan"
            )

            if result.success:
                _placed_count += 1
                _total_spent += queued.unit_price
                item_placed.emit(queued.item_id, "caravan", queued.unit_price)

    # Clear queue (all items placed)
    context.queue.clear()

    _update_display()  # Will trigger _finish_placement since queue is empty


func _on_cancel_pressed() -> void:
    var remaining: int = context.queue.get_total_item_count()

    if remaining > 0:
        # Show confirmation
        var dialog: ConfirmationDialog = ConfirmationDialog.new()
        dialog.dialog_text = "Cancel placement?\n\n%d items placed (%dG spent)\n%d items will return to shop" % [
            _placed_count, _total_spent, remaining
        ]
        dialog.confirmed.connect(func() -> void:
            _do_cancel()
            dialog.queue_free()
        )
        dialog.canceled.connect(func() -> void: dialog.queue_free())
        add_child(dialog)
        dialog.popup_centered()
    else:
        _finish_placement()


func _do_cancel() -> void:
    var cancelled_count: int = context.queue.get_total_item_count()
    context.queue.clear()

    placement_cancelled.emit(_placed_count, cancelled_count)

    # Store result for display
    context.last_result = {
        "type": "placement_cancelled",
        "placed_count": _placed_count,
        "cancelled_count": cancelled_count,
        "total_spent": _total_spent
    }

    replace_with("transaction_result")


func _finish_placement() -> void:
    placement_complete.emit(_placed_count, _total_spent)

    context.last_result = {
        "type": "placement_complete",
        "placed_count": _placed_count,
        "total_spent": _total_spent
    }

    replace_with("transaction_result")


func _show_error(message: String) -> void:
    # Brief error feedback
    var label: Label = Label.new()
    label.text = message
    label.add_theme_color_override("font_color", Color.RED)
    add_child(label)

    var tween: Tween = create_tween()
    tween.tween_property(label, "modulate:a", 0.0, 1.5)
    tween.tween_callback(label.queue_free)
```

---

## 7. Caravan: Infinite Storage (When Available)

### 7.1 Design Decisions

Per player feedback, Caravan storage is **infinite**. This eliminates capacity edge cases.

**However**, the Caravan is NOT always available:
- In SF2, players don't get the Caravan until mid-game
- The Caravan may not be accessible in certain maps/dungeons
- Mods may have different Caravan unlock conditions

### 7.2 Caravan Availability Check

```gdscript
## In StorageManager or GameState:

## Check if player has access to Caravan storage
func is_caravan_available() -> bool:
    # Check game progression flag
    if not GameState.has_flag("caravan_unlocked"):
        return false

    # Check if current map allows Caravan access
    if MapManager.current_map and not MapManager.current_map.allows_caravan:
        return false

    return true

## Caravan has no capacity limit (when available)
func can_store_in_caravan(item_id: String, quantity: int) -> bool:
    if not is_caravan_available():
        return false
    return true  # Infinite storage

func get_caravan_space_remaining() -> int:
    if not is_caravan_available():
        return 0
    return 999999  # Effectively infinite
```

### 7.3 Placement Mode: Caravan Button Visibility

```gdscript
## In placement_mode.gd

func _setup_caravan_button() -> void:
    # Only show Caravan button if Caravan is available
    if StorageManager.is_caravan_available():
        caravan_button.visible = true
        _update_caravan_button()
        caravan_button.pressed.connect(_on_caravan_clicked)
    else:
        caravan_button.visible = false
```

### 7.4 UI Display

**When Caravan IS available:**
```
┌─────────────────────────────────────────┐
│ [HERO]      [WARRIOR]    [MAGE]         │
├─────────────────────────────────────────┤
│ [STORE ALL IN CARAVAN]                  │
│ 6 items → -60G                          │
├─────────────────────────────────────────┤
│ [CANCEL ORDER]                          │
└─────────────────────────────────────────┘
```

**When Caravan is NOT available:**
```
┌─────────────────────────────────────────┐
│ [HERO]      [WARRIOR]    [MAGE]         │
├─────────────────────────────────────────┤
│ [CANCEL ORDER]                          │
└─────────────────────────────────────────┘
```

No Caravan button shown - players must distribute to party members only.

### 7.5 Edge Case: All Party Inventories Full, No Caravan

If during placement:
- All party member inventories are full
- Caravan is not available
- Items remain in queue

**Behavior:**
1. All character buttons become disabled (show "FULL")
2. Message displayed: "No room! Sell or drop items to make space."
3. Cancel button remains active
4. Player must cancel to return to shop (unplaced items returned to stock)

---

## 8. Sell Flow

### 8.1 Sell Queue Model

Selling uses the same queue pattern in reverse:
1. Player selects character who's selling
2. Player browses that character's inventory
3. Player queues items to sell (with quantities)
4. Player confirms batch sale
5. Gold is awarded, items removed from inventory

### 8.2 Key Differences from Buy Queue

| Aspect | Buy Queue | Sell Queue |
|--------|-----------|------------|
| Gold flow | Decreases on placement | Increases on confirm |
| Validation | Can afford queue total | Character has items |
| Placement | One-at-a-time to targets | Batch confirm |
| Caravan | "Dump all" option | Can sell from Caravan too |

### 8.3 Sell Confirmation Screen

```gdscript
## scenes/ui/shops/screens/sell_confirm.gd
extends ShopScreenBase

@onready var items_list: VBoxContainer = %ItemsList
@onready var total_label: Label = %TotalLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton


func _on_initialized() -> void:
    _populate_items_list()
    _update_total()

    confirm_button.pressed.connect(_on_confirm)
    cancel_button.pressed.connect(_on_cancel)


func _populate_items_list() -> void:
    for child in items_list.get_children():
        child.queue_free()

    for queued: QueuedItem in context.queue.get_all_items():
        var item_data: ItemData = ModLoader.registry.get_resource("item", queued.item_id)
        var label: Label = Label.new()
        label.text = "%dx %s → +%dG" % [
            queued.quantity,
            item_data.item_name if item_data else queued.item_id,
            queued.get_total_cost()
        ]
        items_list.add_child(label)


func _update_total() -> void:
    total_label.text = "TOTAL: +%dG" % context.queue.get_total_cost()


func _on_confirm() -> void:
    var total_earned: int = 0
    var items_sold: int = 0

    for queued: QueuedItem in context.queue.get_all_items():
        for i: int in range(queued.quantity):
            var result: Dictionary = ShopManager.sell_item(
                queued.item_id,
                context.selling_from_uid
            )

            if result.success:
                total_earned += queued.unit_price
                items_sold += 1

    context.queue.clear()

    context.last_result = {
        "type": "sell_complete",
        "items_sold": items_sold,
        "total_earned": total_earned
    }

    replace_with("transaction_result")


func _on_cancel() -> void:
    context.queue.clear()
    go_back()
```

---

## 9. Mod Extensibility

### 9.1 Extension Points

| Hook | Signal/Method | Purpose |
|------|---------------|---------|
| Queue validation | `OrderQueue.queue_validation_requested` | Custom item restrictions |
| Transaction validation | `ShopManager.custom_transaction_validation` | Per-item purchase checks |
| Screen override | `mod.json` scenes registration | Replace entire screens |
| UI extension | `shop_*_ready` hooks | Add widgets to existing UI |
| Price modification | Override `ShopData` in higher-priority mod | Adjust economy |

### 9.2 Custom Queue Validation Example

```gdscript
## Mod can limit purchases per visit
func _validate_queue_item(item_id: String, quantity: int, result: Dictionary) -> void:
    if item_id == "super_potion":
        var current: int = _get_current_queue_quantity("super_potion")
        if current + quantity > 5:
            result.allowed = false
            result.reason = "Maximum 5 Super Potions per visit!"
```

---

## 10. Implementation Checklist

### Phase 1: Core Infrastructure
- [ ] Create `ShopContext` class
- [ ] Create `OrderQueue` class with `remove_one()` method
- [ ] Create `QueuedItem` class
- [ ] Create `ShopScreenBase` class
- [ ] Create `ShopController` scene and script

### Phase 2: Buy Flow Screens
- [ ] Implement `shop_greeting` screen
- [ ] Implement `action_select` screen
- [ ] Implement `item_browser` screen with queue building
- [ ] Implement `char_select` screen (equipment)
- [ ] Implement `placement_mode` screen with pay-per-placement
- [ ] Implement `confirm_transaction` screen (equipment)
- [ ] Implement `transaction_result` screen

### Phase 3: Sell Flow Screens
- [ ] Implement `sell_char_select` screen
- [ ] Implement `sell_inventory` screen with sell queue
- [ ] Implement `sell_confirm` screen

### Phase 4: Components
- [ ] Create `queue_panel` component
- [ ] Create `item_button` component
- [ ] Create `character_slot` component with capacity display
- [ ] Create `stat_comparison` component

### Phase 5: Integration
- [ ] Connect `ShopManager.shop_opened` to `ShopController`
- [ ] Wire up all screen transitions
- [ ] Implement cancel confirmation dialog
- [ ] Test equipment flow (Path A)
- [ ] Test consumable pay-per-placement flow (Path B)
- [ ] Test sell batch flow (Path C)

### Phase 6: Polish
- [ ] Add transition animations
- [ ] Add sound effects hooks
- [ ] Add keyboard/gamepad navigation
- [ ] Real-time gold display updates
- [ ] Write unit tests for `OrderQueue`
- [ ] Write integration tests for full flows

---

## Appendix A: State Diagram

```
                    ┌─────────────┐
                    │   CLOSED    │
                    └──────┬──────┘
                           │ open_shop()
                           ▼
                    ┌─────────────┐
                    │  GREETING   │
                    └──────┬──────┘
                           │ auto-advance
                           ▼
                    ┌─────────────┐
              ┌────►│ACTION_SELECT│◄────────────────┐
              │     └──────┬──────┘                 │
              │            │                        │
         back │    ┌───────┼───────┐                │ done
              │    ▼       ▼       ▼                │
        ┌─────┴─────┐ ┌────────┐ ┌──────────────┐   │
        │ITEM_BROWSE│ │  SELL  │ │    DEALS     │   │
        └─────┬─────┘ │CHAR_SEL│ │(same as buy) │   │
              │       └───┬────┘ └──────────────┘   │
     ┌────────┴────────┐  │                         │
     │                 │  ▼                         │
     ▼ equipment       ▼ consumable  ┌──────────┐   │
┌────────────┐   ┌────────────┐      │SELL_INV  │   │
│CHAR_SELECT │   │ PLACEMENT  │      └────┬─────┘   │
└─────┬──────┘   │    MODE    │           │         │
      │          │ (pay-per-  │           ▼         │
      │          │  placement)│      ┌──────────┐   │
      ▼          └─────┬──────┘      │SELL_CONF │   │
┌────────────┐         │             └────┬─────┘   │
│  CONFIRM   │         │                  │         │
└─────┬──────┘         │                  │         │
      │                │                  │         │
      └────────┬───────┴──────────────────┘         │
               ▼                                    │
        ┌────────────┐                              │
        │   RESULT   │──────────────────────────────┘
        └────────────┘
```

---

## Appendix B: Pay-Per-Placement Summary

```
┌─────────────────────────────────────────────────────────────┐
│                   PAY-PER-PLACEMENT MODEL                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  QUEUE BUILDING:                                            │
│  • Validate quantity against available gold                 │
│  • Add to queue → NO CHARGE                                 │
│  • Display: "AFTER PURCHASE: XXG"                           │
│                                                             │
│  PLACEMENT MODE:                                            │
│  • Click Character → Place 1 → Charge 1 → Update gold      │
│  • Click Caravan → Place ALL → Charge ALL → Update gold    │
│  • Gold display updates in REAL-TIME                        │
│                                                             │
│  CANCEL:                                                    │
│  • Placed items STAY (gold already spent)                   │
│  • Unplaced items CLEARED (never charged = no refund)       │
│                                                             │
│  CARAVAN:                                                   │
│  • Infinite storage (player-demanded)                       │
│  • Always available as "dump remaining" option              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

*End of specification. Make it so, Captain.*
