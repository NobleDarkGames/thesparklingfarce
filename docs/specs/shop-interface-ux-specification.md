# Shop Interface UX Specification

**Version**: 2.0
**Date**: 2025-12-07
**Status**: DESIGN PHASE
**Author**: Lt. Clauderina, UI/UX Specialist, USS Torvalds

---

## Executive Summary

The current shop interface suffers from critical usability failures that make the system nearly unusable with keyboard/gamepad and confusing with mouse input. This specification defines a complete redesign based on Shining Force's proven patterns, modern accessibility standards, and The Sparkling Farce's commitment to retro authenticity with quality-of-life improvements.

**Critical Issues Addressed**:
- Character selection buttons don't respond to clicks (signal connection issues)
- BUY button has identity crisis (mode switcher? action button? page indicator?)
- No keyboard/gamepad navigation support whatsoever
- Focus management completely absent
- Selection vs hover vs focus states undefined
- Buy/Sell mode switching unclear and non-functional

---

## Research Findings: What Shining Force Got Right (and Wrong)

### Original SF1/SF2 Shop Flow

Based on analysis of the Shining Force manual and gameplay documentation, the shop flow worked like this:

1. **Talk to shopkeeper** → Choose action (Buy/Sell/Deal/Repair)
2. **Browse item list** → Highlight item with D-pad, see price
3. **Confirm selection** → "Buy this item? Yes/No"
4. **Choose recipient** → Select character name from list
5. **Equip check** → If character can't equip, shopkeeper asks "buy anyway?"
6. **Transaction complete** → Return to item list for repeat purchases

**What worked well**:
- Linear, predictable flow with clear next steps
- D-pad navigation was fast and responsive
- Item list as the "hub" you return to after each purchase
- Immediate feedback on whether a character can use an item
- Separate Sell mode kept cognitive load low

**What frustrated players**:
- **No bulk buying**: Buying 10 healing herbs meant 10 separate transactions ([forums discussion](https://forums.shiningforcecentral.com/viewtopic.php?t=21512))
- **No stat comparison**: Had to remember current weapon stats or exit shop to check
- **Inventory juggling**: Only 4 item slots meant constant manual transfers ([RPGFan review](https://www.rpgfan.com/review/shining-force-resurrection-of-the-dark-dragon-3/))

### SF1 GBA Remake Improvements

The GBA remake added:
- **4 extra item slots** (8 total) to reduce inventory shuffling ([GameFAQs discussion](https://gamefaqs.gamespot.com/boards/220-rpgs-role-playing-games/73062169))
- **Turn order display** for battle planning (not shop-related but shows QoL philosophy)
- **Non-grid overworld movement** for faster travel

**What was NOT improved**:
- Shop flow remained largely unchanged
- No bulk buying added (still a common complaint in remake discussions)
- No stat comparison UI

### Fan Complaints from Recrafted/Mod Projects

From [Shining Force Central forums](https://forums.shiningforcecentral.com/viewtopic.php?t=48317) and [Shining Force 2 - Recrafted review](https://thehande.wordpress.com/2020/08/09/shining-force-2-review/):
- "Glitchiness in the shop menu" in remakes
- UI resolution inconsistencies and pixel misalignment
- "Shopkeeper will not allow me to access any particular options" (button response failures)
- Anti-aliasing on small menu text reduced readability

**Sound familiar?** These are the EXACT issues we're experiencing. Button response failures and unclear action states plague even professional SF remakes.

---

## Design Principles for The Sparkling Farce Shop

### 1. **Input Method Parity**
Mouse, keyboard, and gamepad must have equal first-class support. No "this only works well with mouse" compromises.

### 2. **Clear Visual Feedback**
Every interactive element must have distinct visual states:
- **Normal**: Default appearance
- **Hover**: Mouse is over element (mouse-only)
- **Focus**: Element is selected for keyboard/gamepad input
- **Selected/Active**: Element represents current user choice
- **Disabled**: Element cannot be interacted with

### 3. **Predictable Navigation Flow**
Users should always know:
- Where they are in the flow
- What their current selection is
- What action will happen if they press confirm
- How to go back or cancel

### 4. **Monogram Font Sacred Law**
100% of shop UI text uses Monogram font. Zero exceptions. Font size scaling for readability:
- Headers: 24px
- Body text: 16px
- Small labels: 14px (if needed)

### 5. **SF2 Authenticity with Modern QoL**
Preserve the feel of SF2 shops while fixing what frustrated players:
- Keep three-column layout aesthetic
- Add bulk buying for consumables
- Add stat comparison for equipment
- Add Caravan storage option
- Keep single-button exit (no multi-step escape)

---

## The New Shop Flow: User Journey

### Mode A: Buying Equipment

```
[Shop Opens]
  ↓
[Item List has focus] ← User sees items, first item auto-selected
  ↓ (select different item)
[Details panel updates] ← Shows stats, price, "Can Equip" indicators
  ↓
[Character buttons auto-disable] ← Grey out characters who can't equip
  ↓ (click character OR navigate with keyboard and press confirm)
[Character highlights BLUE] ← Visual confirmation of selection
[BUY button enables and shows price] ← "BUY FOR 150G"
  ↓ (click BUY OR press confirm on BUY button)
[Purchase executes]
  ↓
[Character highlight clears, ready for next purchase]
[Item list maintains focus] ← User can immediately buy another item
```

### Mode B: Buying Consumables

```
[Shop Opens]
  ↓
[Item List has focus]
  ↓ (select healing herb)
[Details panel shows description]
[Quantity selector appears] ← SpinBox shows "1" by default
  ↓ (adjust quantity if desired)
[Price updates] ← "BUY: 30G" becomes "BUY: 90G" (3x quantity)
  ↓ (select character OR Caravan)
[Destination highlights]
[BUY button shows total] ← "BUY FOR 90G"
  ↓ (confirm)
[3 herbs added to character/Caravan inventory]
```

### Mode C: Selling Items

```
[User clicks SELL button]
  ↓
[Mode switches to SELL]
[Item list clears]
[Right column changes to "WHOSE INVENTORY?"]
  ↓ (select character)
[Item list populates with character's inventory]
[Character selection panel hides]
  ↓ (select item to sell)
[Details show "SELL FOR: 112G"]
[SELL button enables] ← "SELL FOR 112G"
  ↓ (confirm)
[Item sold, gold updated]
[Item list refreshes for that character]
```

### Mode D: Special Deals

```
[User clicks DEALS button]
  ↓
[Item list shows deal items with strikethrough pricing]
  "BRONZE SWORD    [s]200G[/s] 150G"
  ↓
[Flow identical to Mode A/B]
[BUY button uses deal price]
```

---

## Critical UX Fixes Required

### Issue 1: Button Click Response Failures

**Current Problem**: Character buttons have `.pressed.connect()` calls but clicks don't fire.

**Root Cause Analysis**:
```gdscript
# Line 411-414 in shop_interface.gd
button.pressed.connect(func() -> void:
    print("[SHOP] Button pressed for: %s" % char_name)
    _on_destination_selected(uid, button)
)
```

This code is CORRECT. The problem is likely:
1. **Focus stealing**: Another control is grabbing input before button receives it
2. **Z-index issues**: Button is visually present but not receiving mouse events
3. **Disabled state**: Button might be getting disabled before click registers
4. **Panel blocking**: PanelContainer might be consuming input events

**Solution**:
- Set `mouse_filter = MOUSE_FILTER_PASS` on all PanelContainers that contain interactive elements
- Verify button `disabled` state is properly managed
- Add `focus_mode = FocusMode.FOCUS_ALL` to all interactive buttons
- Test with `print()` in button's `_gui_input()` override to verify event reception

### Issue 2: BUY Button Identity Crisis

**Current Problem**: Button labeled "BUY" sometimes acts as action confirmation, sometimes is disabled, sometimes shows price, text changes dynamically but purpose is unclear.

**Solution**: BUY button has ONE job - execute purchase when prerequisites met:
- **Disabled state**: Item not selected OR destination not selected OR can't afford
- **Enabled state**: All prerequisites met
- **Text when disabled**: "BUY" (grey)
- **Text when enabled**: "BUY FOR {price}G" (white/gold)
- **On click**: Execute `_execute_purchase()`, no mode changes

### Issue 3: Zero Keyboard/Gamepad Support

**Current Problem**: No focus neighbors defined, no `_gui_input()` handlers, no gamepad action mapping.

**Solution**: Implement complete focus flow (see Navigation Architecture section).

### Issue 4: Mode Switching Confusion

**Current Problem**: BUY/SELL/DEALS buttons at bottom, but BUY also executes purchases? Users don't know if bottom buttons are tabs or actions.

**Solution**:
- Bottom buttons are MODE SELECTORS (like tabs)
- BUY button executes purchase (but ONLY appears/enables in Buy/Deals modes)
- Add visual distinction: mode buttons use different style than action button
- Rename for clarity:
  - "BUY MODE" / "SELL MODE" / "DEALS MODE" (too verbose?)
  - OR: Keep "BUY" / "SELL" / "DEALS" but add pressed state styling to show active mode
  - Add small indicator above active mode button ("< ACTIVE >")

**Recommended Approach**: Keep button labels short but add visual active state:
```
[  BUY  ]  [ SELL ]  [ DEALS ]  [  EXIT  ]
   ^^^^
  (highlighted border or different color when active)
```

---

## Node Hierarchy Redesign

### Current Structure Issues
- Character buttons dynamically created but parented to GridContainer without focus setup
- Item buttons dynamically created without navigation configuration
- No focus neighbor relationships defined
- PanelContainers might be blocking input

### Proposed Structure

```
ShopInterface (CanvasLayer)
└── ShopPanel (Control) - main visibility container
    └── Border (ColorRect)
        └── InnerPanel (ColorRect)
    └── MainMargin (MarginContainer)
        └── MainVBox (VBoxContainer)
            ├── HeaderSection (VBoxContainer)
            │   ├── ShopTitleLabel (Label)
            │   ├── GreetingLabel (Label)
            │   └── GoldLabel (Label)
            │
            ├── ThreeColumnContainer (HBoxContainer) [MODIFIED]
            │   ├── LeftColumn (VBoxContainer)
            │   │   ├── LeftColumnHeader (Label)
            │   │   └── ItemListScroll (ScrollContainer)
            │   │       ├── [mouse_filter = PASS] ← FIX
            │   │       └── ItemListContainer (VBoxContainer)
            │   │           └── [Dynamic Item Buttons]
            │   │               ├── focus_mode = ALL
            │   │               ├── focus_neighbor_top/bottom set dynamically
            │   │               └── focus_neighbor_right → first character button
            │   │
            │   ├── CenterColumn (VBoxContainer)
            │   │   ├── DetailsPanel (PanelContainer)
            │   │   │   ├── [mouse_filter = PASS] ← FIX
            │   │   │   └── ... (stats display, no focusable elements)
            │   │   └── QuantityPanel (PanelContainer) [MODIFIED]
            │   │       ├── [Only visible for consumables]
            │   │       └── QuantitySpinBox
            │   │           ├── focus_mode = ALL
            │   │           ├── focus_neighbor_left → current item button
            │   │           └── focus_neighbor_right → first character button
            │   │
            │   └── RightColumn (VBoxContainer)
            │       ├── RightColumnHeader (Label)
            │       └── CharacterPanel (PanelContainer)
            │           ├── [mouse_filter = PASS] ← FIX
            │           └── CharacterMargin (MarginContainer)
            │               └── CharacterVBox (VBoxContainer)
            │                   ├── CharacterGrid (GridContainer)
            │                   │   └── [Dynamic Character Buttons]
            │                   │       ├── focus_mode = ALL
            │                   │       ├── focus_neighbors set dynamically (2-column grid)
            │                   │       ├── focus_neighbor_left → current item button
            │                   │       └── focus_neighbor_down → Caravan OR mode buttons
            │                   └── CaravanButton
            │                       ├── focus_mode = ALL
            │                       └── focus_neighbor_down → BUY button
            │
            └── ButtonSection (HBoxContainer) [MODIFIED]
                ├── BuyButton (conditional visibility)
                │   ├── Only visible in "buy" or "deals" mode
                │   ├── focus_neighbor_up → Caravan button
                │   └── focus_neighbor_right → BuyModeButton
                ├── BuyModeButton [RENAMED from BuyButton]
                │   ├── Text: "BUY"
                │   ├── Toggleable visual style for active mode
                │   └── Always visible
                ├── SellModeButton [RENAMED]
                ├── DealsModeButton [RENAMED]
                └── ExitButton
```

### Key Structural Changes

1. **PanelContainer Input Fix**: Add `mouse_filter = MOUSE_FILTER_PASS` to all PanelContainers
2. **Focus Configuration**: Every button gets `focus_mode = FocusMode.FOCUS_ALL`
3. **Dynamic Focus Neighbors**: Item and character buttons set neighbors on creation
4. **Separate Action vs Mode Buttons**:
   - "BuyButton" (action) only visible when purchase can be executed
   - "BuyModeButton" (mode selector) always visible, shows active state
5. **ScrollContainer Focus**: May need custom input handling to scroll with keyboard

---

## Navigation Architecture

### Focus Flow Maps

#### Horizontal Navigation (Left/Right)

```
[Item List] ←→ [Quantity Selector] ←→ [Character Grid]
                (if consumable)
```

#### Vertical Navigation (Up/Down)

**Left Column (Items)**:
```
[Item 1] ↕ [Item 2] ↕ [Item 3] ↕ ... ↕ [Last Item]
```

**Right Column (Characters in 2-column grid)**:
```
[Char1] ←→ [Char2]
   ↕        ↕
[Char3] ←→ [Char4]
   ↕        ↕
[Caravan Button (spans columns)]
```

**Bottom Row (Mode/Action Buttons)**:
```
[BUY Action] ←→ [BUY Mode] ←→ [SELL] ←→ [DEALS] ←→ [EXIT]
(conditional)
```

#### Cross-Section Navigation

- **From Item List** → Press Right → Focus first character button
- **From Character Grid** → Press Left → Focus current item button
- **From Character Grid** → Press Down (on bottom row) → Focus first mode button
- **From Mode Buttons** → Press Up → Focus Caravan button (or last character)
- **From Quantity Selector** → Press Left → Focus current item button
- **From Quantity Selector** → Press Right → Focus first character button

### Focus Visual Feedback

Since we're using Godot's built-in focus system, leverage Theme resources:

**In `ui_theme.tres`** (add these):
```gdscript
Button/colors/font_color = Color(1, 1, 1, 1)           # Normal: white
Button/colors/font_hover_color = Color(1, 0.9, 0.5, 1) # Hover: gold tint
Button/colors/font_focus_color = Color(0.5, 0.8, 1, 1) # Focus: light blue
Button/colors/font_pressed_color = Color(0.8, 0.8, 0.8, 1) # Pressed: grey
Button/colors/font_disabled_color = Color(0.4, 0.4, 0.4, 1) # Disabled: dark grey

# For "selected" state (custom), use StyleBoxFlat overrides:
Button/styles/focus = [StyleBoxFlat with blue border]
```

**Selection State** (different from focus):
- **Use case**: Character/destination selected for purchase target
- **Implementation**: Add custom style override in code:
```gdscript
const STYLE_SELECTED: StyleBoxFlat = preload("res://assets/themes/button_selected_style.tres")
button.add_theme_stylebox_override("normal", STYLE_SELECTED)
```

**Summary of States**:
- **Normal**: White text, no border
- **Hover** (mouse-only): Gold text
- **Focus** (keyboard/gamepad): Blue border, light blue text
- **Selected** (purchase target): Blue background fill, white text
- **Disabled**: Dark grey text, no interaction

---

## Input Handling Implementation

### Required `_gui_input()` Overrides

#### For Item List ScrollContainer

Need custom scrolling when navigating with keyboard:

```gdscript
# In shop_interface.gd
func _setup_item_list_navigation() -> void:
    item_list_scroll.gui_input.connect(_on_item_list_scroll_input)

func _on_item_list_scroll_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_down"):
        # Focus next item button
        var current_idx: int = _get_focused_item_index()
        if current_idx < item_buttons.size() - 1:
            item_buttons[current_idx + 1].grab_focus()
            _scroll_to_focused_item()
            get_viewport().set_input_as_handled()

    elif event.is_action_pressed("ui_up"):
        var current_idx: int = _get_focused_item_index()
        if current_idx > 0:
            item_buttons[current_idx - 1].grab_focus()
            _scroll_to_focused_item()
            get_viewport().set_input_as_handled()

func _scroll_to_focused_item() -> void:
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused and focused in item_buttons:
        item_list_scroll.ensure_control_visible(focused)
```

#### Global Shop Navigation

Handle confirm/cancel at shop level:

```gdscript
func _input(event: InputEvent) -> void:
    if not visible or not shop_panel.visible:
        return

    # Cancel = close shop
    if event.is_action_pressed("ui_cancel"):
        _on_exit_pressed()
        get_viewport().set_input_as_handled()

    # Accept on focused element (let buttons handle their own accept)
    # No override needed - Godot's focus system handles this
```

### Gamepad Action Mapping

Ensure project input map includes:
- `ui_accept` (A button / Enter)
- `ui_cancel` (B button / Escape)
- `ui_up/down/left/right` (D-pad / Arrow keys)
- `ui_page_up/page_down` (L/R triggers for quick scroll)

---

## Mode Management Redesign

### Current Problems
- `current_mode` state exists but mode buttons don't reflect it
- BUY button sometimes switches modes, sometimes executes purchase
- No visual indication of current mode

### New Mode System

#### Mode State Variable
```gdscript
enum ShopMode {
    BUY,
    SELL,
    DEALS
}
var current_mode: ShopMode = ShopMode.BUY
```

#### Mode Button Styling

Create a theme variation for "active mode" buttons:

```gdscript
# When mode changes:
func _set_active_mode(mode: ShopMode) -> void:
    current_mode = mode

    # Update button styles
    buy_mode_button.remove_theme_stylebox_override("normal")
    sell_mode_button.remove_theme_stylebox_override("normal")
    deals_mode_button.remove_theme_stylebox_override("normal")

    match mode:
        ShopMode.BUY:
            buy_mode_button.add_theme_stylebox_override("normal", active_mode_style)
            _switch_to_buy_mode()
        ShopMode.SELL:
            sell_mode_button.add_theme_stylebox_override("normal", active_mode_style)
            _switch_to_sell_mode()
        ShopMode.DEALS:
            deals_mode_button.add_theme_stylebox_override("normal", active_mode_style)
            _switch_to_deals_mode()
```

#### Buy Action Button Visibility

```gdscript
func _update_buy_action_button() -> void:
    # Only show buy action button in buy/deals modes
    buy_action_button.visible = (current_mode == ShopMode.BUY or current_mode == ShopMode.DEALS)

    # Enable only when prerequisites met
    var can_buy: bool = (
        not selected_item_id.is_empty() and
        not selected_destination.is_empty() and
        ShopManager.can_afford(selected_item_id, selected_quantity, current_mode == ShopMode.DEALS)
    )

    buy_action_button.disabled = not can_buy

    if can_buy:
        var price: int = _get_total_price()
        buy_action_button.text = "BUY FOR %dG" % price
    else:
        buy_action_button.text = "BUY"
```

---

## Stat Comparison Panel Design

### When to Show
- Only for equipment items (weapons, armor, accessories)
- Only when a character is selected as destination
- Hidden for consumables and when no destination selected

### Information Architecture

```
╔══════════════════════════════════════════╗
║ BRONZE SWORD                             ║
║ AT  5      RG  1                         ║
║ BUY: 200G                                ║
║                                          ║
║ ┌────────────────────────────────────┐   ║
║ │ MAX'S CURRENT: WOODEN SWORD        │   ║
║ │ AT  3      RG  1                   │   ║
║ │                                    │   ║
║ │ CHANGE:  AT +2                     │   ║
║ └────────────────────────────────────┘   ║
╚══════════════════════════════════════════╝
```

### Implementation

```gdscript
func _update_stat_comparison(character_uid: String) -> void:
    stat_comparison_container.visible = false

    # Only for equipment
    var item: ItemData = _get_item_data(selected_item_id)
    if not item or not item.is_equippable():
        return

    # Get character's current equipment in same slot
    var character: CharacterData = _get_character_by_uid(character_uid)
    var current_item: ItemData = character.get_equipped_item_in_slot(item.equipment_slot)

    if not current_item:
        # Character has nothing equipped in this slot
        stat_comparison_label.text = "CURRENTLY UNARMED"
        stat_comparison_container.visible = true
        return

    # Build comparison text
    var comparison: String = "%s'S CURRENT: %s\n" % [character.character_name.to_upper(), current_item.item_name.to_upper()]
    comparison += "%s\n\n" % _format_item_stats(current_item)

    # Calculate differences
    var att_diff: int = item.attack_power - current_item.attack_power
    var def_diff: int = item.defense_modifier - current_item.defense_modifier

    comparison += "CHANGE:  "
    if att_diff != 0:
        comparison += "AT %+d  " % att_diff
    if def_diff != 0:
        comparison += "DF %+d" % def_diff

    stat_comparison_label.text = comparison
    stat_comparison_container.visible = true
```

### Visual Styling
- Green text for positive changes (+2)
- Red text for negative changes (-1)
- White text for neutral/equipment name

---

## Sell Mode Specific Flow

### Two-Step Process

**Step 1: Select Character (Whose Inventory?)**
```
Right column header changes to "WHOSE INVENTORY?"
Character grid shows all party members
Left column (item list) is empty with message "← SELECT CHARACTER"
```

**Step 2: Select Item to Sell**
```
User clicks character → Item list populates with that character's sellable items
Character panel HIDES (or dims) - no longer needed
Item selection works same as buy mode
SELL button (action) appears at bottom, shows "SELL FOR {price}G" when item selected
```

### Implementation Changes

```gdscript
func _switch_to_sell_mode() -> void:
    current_mode = ShopMode.SELL
    _clear_item_list()
    _clear_destination_selection()

    # Right column becomes character selector
    right_column_header.text = "WHOSE INVENTORY?"
    _populate_character_grid()
    character_panel.show()

    # Left column shows instruction
    var instruction_label: Label = Label.new()
    instruction_label.text = "← SELECT CHARACTER"
    instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    item_list_container.add_child(instruction_label)

    # Update button states
    buy_action_button.visible = false
    sell_action_button.visible = true
    sell_action_button.disabled = true
    sell_action_button.text = "SELL"

func _on_character_selected_for_selling(character_uid: String) -> void:
    # Populate item list with this character's inventory
    var character: CharacterData = _get_character_by_uid(character_uid)
    var sellable_items: Array[String] = character.get_sellable_item_ids()

    _populate_item_list(sellable_items, false)

    # Hide character panel (selection complete)
    character_panel.hide()

    # Update header
    right_column_header.text = "%s'S INVENTORY" % character.character_name.to_upper()

    # Store for sell transaction
    selling_from_character = character_uid
```

---

## Accessibility Considerations

### Color Contrast
All text must maintain 4.5:1 contrast ratio against backgrounds:
- White text on dark blue/black backgrounds ✓
- Dark grey disabled text still readable (test with contrast checker)
- Red "can't afford" text vs blue background (verify contrast)

### Font Scaling
Monogram at 16px is minimum for body text. Headers at 24px. If players report readability issues, consider:
- Adding a "Large Text" option that scales all UI by 1.5x
- Supporting custom theme overrides

### Screen Reader Support (Future)
Godot 4.x has limited screen reader support, but we can prepare:
- All buttons have descriptive text (not just icons)
- Focus order is logical top-to-bottom, left-to-right
- State changes announced via label text updates

### Keyboard-Only Players
Must be able to:
- Navigate entire shop with Tab/Arrow keys
- Execute all actions with Enter/Escape
- Never get "trapped" in a focus loop

---

## Performance Considerations

### Dynamic Button Creation
Currently recreating all character/item buttons on mode switch. This is acceptable for small party sizes (<20 characters) but consider:

- **Object pooling** if party sizes grow beyond 30 characters
- **Reuse buttons** and update text/state instead of queue_free() and recreate
- **Measure frame time** when populating item list with 100+ items

### ScrollContainer Optimization
- Use `clip_contents = true` to avoid rendering offscreen items
- Consider VirtualizedListContainer for item lists >50 items (custom implementation)

---

## Testing Checklist

### Mouse Input Tests
- [ ] Click item in list → Details update
- [ ] Click character → Character highlights blue
- [ ] Click BUY action button → Purchase executes
- [ ] Click mode buttons → Mode changes, visual feedback updates
- [ ] Click EXIT → Shop closes with farewell message

### Keyboard Input Tests
- [ ] Arrow keys navigate item list
- [ ] Right arrow from item → Focus moves to character grid
- [ ] Arrow keys navigate character grid (2-column)
- [ ] Down arrow from characters → Focus moves to mode buttons
- [ ] Enter on character → Character highlights blue
- [ ] Enter on BUY action → Purchase executes
- [ ] Escape → Shop closes

### Gamepad Input Tests
- [ ] D-pad navigation works identical to keyboard arrows
- [ ] A button = Enter (confirm selection)
- [ ] B button = Escape (close shop)
- [ ] L/R triggers scroll item list quickly (page up/down)

### State Management Tests
- [ ] BUY mode: Item list shows shop inventory
- [ ] DEALS mode: Item list shows deal items with strikethrough
- [ ] SELL mode: Right column asks "Whose Inventory?"
- [ ] SELL mode: After character selection, item list populates
- [ ] Disabled character buttons (can't equip) are greyed and unclickable
- [ ] BUY action button only appears in BUY/DEALS modes
- [ ] SELL action button only appears in SELL mode

### Edge Cases
- [ ] Empty shop inventory → Shows "NO ITEMS AVAILABLE"
- [ ] Character has no sellable items → Shows "INVENTORY EMPTY"
- [ ] Can't afford item → Price shows red, BUY disabled
- [ ] Character inventory full → Warning before purchase?
- [ ] Buying last item in stock → Item disappears from list
- [ ] Selling item that triggers Deal → Deal appears in DEALS mode

### Visual Verification
- [ ] All text uses Monogram font
- [ ] Font sizes: Headers 24px, body 16px
- [ ] Focus border visible on all buttons
- [ ] Hover state visible (gold tint)
- [ ] Selection state distinct from focus (blue background)
- [ ] Disabled state clearly greyed
- [ ] Active mode button highlighted
- [ ] Stat comparison shows green/red for +/-
- [ ] UI fits 1280x720 minimum resolution
- [ ] No pixel misalignment or anti-aliasing artifacts

---

## Implementation Roadmap

### Phase 1: Foundation Fixes (Critical)
1. Fix PanelContainer input blocking (mouse_filter = PASS)
2. Add focus_mode = ALL to all buttons
3. Separate BUY action from BUY mode button
4. Test character button click response

### Phase 2: Navigation System
1. Implement focus neighbor setup for item buttons
2. Implement focus neighbor setup for character grid
3. Add ScrollContainer keyboard navigation
4. Add global input handling for cancel/confirm
5. Test full keyboard navigation flow

### Phase 3: Visual Feedback
1. Create button style variations in theme
2. Implement selection state styling
3. Add active mode indicator
4. Verify Monogram font usage 100%
5. Add hover states

### Phase 4: Sell Mode Redesign
1. Implement two-step sell flow
2. Add "Whose Inventory?" character selection
3. Populate character inventory as item list
4. Add SELL action button
5. Test sell transaction

### Phase 5: Quality of Life
1. Implement stat comparison panel
2. Add bulk buying quantity selector focus
3. Add "can equip" indicators for characters
4. Add "can afford" red price highlighting
5. Test edge cases

### Phase 6: Polish
1. Add sound effects for selection/purchase
2. Add visual transitions between modes
3. Add purchase success animation
4. Optimize performance for large inventories
5. Final accessibility audit

---

## Open Questions for Captain Obvious

1. **Mode Button Naming**: Should we keep "BUY/SELL/DEALS" or be more explicit with "BUY MODE/SELL MODE/DEALS MODE"?

2. **Buy Action Button Placement**: Currently at bottom-left. Should it be more prominent? Center of bottom row?

3. **Character Grid Columns**: Currently 2 columns. Should this be configurable based on party size? (3 columns for 9+ members?)

4. **Caravan Button Position**: Currently below character grid. Should it be integrated into the grid or kept separate?

5. **Quantity Selector Focus**: Should quantity spinbox auto-grab focus when buying consumables, or require explicit navigation?

6. **Stat Comparison for Accessories**: Accessories don't have AT/DF stats - what comparison info do we show? (Stat modifiers only?)

7. **Sell Mode Character Panel**: After selecting character, should panel hide completely or just dim/disable?

8. **Keyboard Shortcuts**: Should we add Alt+B/S/D shortcuts for quick mode switching?

9. **Purchase Confirmation**: Should equipment purchases require "Are you sure?" or trust the two-click selection process?

10. **Sound Design**: What SFX should play for:
    - Item selection (cursor move beep)
    - Character selection (select beep)
    - Purchase success (ka-ching)
    - Purchase failure (error buzz)
    - Mode change (subtle swoosh?)

---

## References

### Research Sources
- [Shining Force 2 - Recrafted - UX Discussion](https://forums.shiningforcecentral.com/viewtopic.php?t=48317)
- [Shining Force 1 GBA vs Genesis Comparison](https://gamefaqs.gamespot.com/boards/220-rpgs-role-playing-games/73062169)
- [Shining Force: Resurrection of the Dark Dragon (GBA Remake)](https://shining.fandom.com/wiki/Shining_Force:_Resurrection_of_the_Dark_Dragon)
- [Shining Force Manual - Shop Flow](https://sf1.shiningforcecentral.com/guide/instructions-manual/)
- [Shining Force 2 Manual - Shop Instructions](https://sf2.shiningforcecentral.com/guide/instructions-manual/)
- [Shining Force - How to Play Guide](https://shrines.rpgclassics.com/genesis/shiningforce/howtoplay.shtml)

### Internal Documents
- `/home/user/dev/sparklingfarce/scenes/ui/shops/shop_interface.gd`
- `/home/user/dev/sparklingfarce/scenes/ui/shops/shop_interface.tscn`
- `/home/user/dev/sparklingfarce/docs/plans/shop-ux-refactor-status.md`
- `/home/user/dev/sparklingfarce/assets/themes/ui_theme.tres`

---

## Appendix A: Code Snippets

### Dynamic Focus Neighbor Setup

```gdscript
func _populate_character_grid() -> void:
    # Clear existing
    for button: Button in character_buttons:
        button.queue_free()
    character_buttons.clear()

    # Create buttons
    for character: CharacterData in PartyManager.party_members:
        var button: Button = _create_character_button(character)
        button.focus_mode = Control.FOCUS_ALL
        character_grid.add_child(button)
        character_buttons.append(button)

        var uid: String = character.character_uid
        button.pressed.connect(_on_destination_selected.bind(uid, button))

    # Set up focus neighbors (2-column grid)
    var cols: int = character_grid.columns
    for i: int in range(character_buttons.size()):
        var button: Button = character_buttons[i]

        # Vertical neighbors
        if i >= cols:  # Not in first row
            button.focus_neighbor_top = button.get_path_to(character_buttons[i - cols])
        if i < character_buttons.size() - cols:  # Not in last row
            button.focus_neighbor_bottom = button.get_path_to(character_buttons[i + cols])

        # Horizontal neighbors
        if i % cols > 0:  # Not in first column
            button.focus_neighbor_left = button.get_path_to(character_buttons[i - 1])
        else:  # First column - link to item list
            if item_buttons.size() > 0:
                button.focus_neighbor_left = button.get_path_to(item_buttons[0])

        if i % cols < cols - 1 and i < character_buttons.size() - 1:  # Not in last column
            button.focus_neighbor_right = button.get_path_to(character_buttons[i + 1])

    # Bottom row connects to Caravan
    if character_buttons.size() > 0 and caravan_button.visible:
        var last_row_start: int = (character_buttons.size() / cols) * cols
        for i: int in range(last_row_start, character_buttons.size()):
            character_buttons[i].focus_neighbor_bottom = character_buttons[i].get_path_to(caravan_button)

        caravan_button.focus_neighbor_top = caravan_button.get_path_to(character_buttons[last_row_start])
```

### Theme Style Creation (StyleBoxFlat)

```gdscript
# In preload or _ready()
var active_mode_style: StyleBoxFlat = StyleBoxFlat.new()
active_mode_style.bg_color = Color(0.2, 0.4, 0.6, 1.0)  # Blue background
active_mode_style.border_width_bottom = 2
active_mode_style.border_color = Color(0.5, 0.8, 1.0, 1.0)  # Light blue border

var selected_destination_style: StyleBoxFlat = StyleBoxFlat.new()
selected_destination_style.bg_color = Color(0.3, 0.5, 0.8, 1.0)  # Brighter blue
selected_destination_style.border_width_all = 1
selected_destination_style.border_color = Color(0.8, 0.9, 1.0, 1.0)
```

---

## Appendix B: Godot Focus System Reference

### Focus Modes
- `FOCUS_NONE`: Cannot receive focus
- `FOCUS_CLICK`: Can receive focus via mouse click only
- `FOCUS_ALL`: Can receive focus via keyboard/gamepad and mouse

### Focus Neighbor Properties
- `focus_neighbor_left/right/top/bottom`: NodePath to neighbor control
- `focus_next/previous`: NodePath for Tab/Shift+Tab navigation

### Focus Methods
- `grab_focus()`: Force this control to take focus
- `release_focus()`: Release focus back to nothing
- `get_viewport().gui_get_focus_owner()`: Get currently focused control

### Focus Signals
- `focus_entered`: Emitted when control gains focus
- `focus_exited`: Emitted when control loses focus

### Common Pitfalls
- **Focus neighbors must be set AFTER nodes are in scene tree** (use `_ready()` or after `add_child()`)
- **NodePaths are relative to the node setting them** (use `get_path_to(other_node)`)
- **ScrollContainer doesn't auto-scroll to focused child** (must manually call `ensure_control_visible()`)
- **PanelContainer/Panel can block input if mouse_filter = STOP** (set to PASS for children to receive clicks)

---

**End of Specification**

*"May your buttons respond swiftly and your focus flow logically. Engage."*
— Lt. Clauderina, USS Torvalds, Stardate 2025.12.07
