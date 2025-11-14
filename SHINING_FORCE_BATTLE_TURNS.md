# Shining Force Battle Turn Structure Research

## Overview
This document details the exact turn flow for units in Shining Force battles, including movement, action menus, and turn completion.

## Complete Turn Sequence

### 1. Turn Start
- Unit's turn begins based on AGI-calculated turn order
- Unit's stats window appears
- Terrain effects display (if applicable)
- **Movement range highlights** - Ground flashes showing all walkable cells

### 2. Movement Phase
- Player uses D-pad to move unit within flashing area
- Unit cannot occupy spaces with other units
- **Movement is FREE and CANCELABLE** until action is selected
- Press **B button** to cancel movement and return unit to starting position
- Player can move, cancel, and re-move as many times as desired
- No turn cost for experimenting with movement

### 3. Action Menu Trigger
- Once positioned, press **A or C** to open action menu
- Menu appears with 4 options (see below)
- Menu intelligently highlights default option based on context:
  - If enemy in attack range → "Attack" highlighted
  - If enemy out of range → "Stay" highlighted

### 4. Action Menu Options

#### **Attack**
- Select target enemy within weapon/attack range
- Range shown with visual indicators
- Initiates battle calculation sequence
- **ENDS TURN immediately after resolution**

#### **Magic** (if unit is spellcaster)
- Opens list of learned spells
- Each spell shows MP cost, range, and valid targets
- Select spell, then select target(s)
- Some spells target single units, others target areas
- **ENDS TURN immediately after casting**

#### **Item**
- Opens character's item inventory
- Can use consumable items on self or adjacent allies
- Can transfer items between adjacent characters
- Can drop items (doesn't end turn in some versions)
- Can equip/unequip equipment during battle
- **ENDS TURN after using consumable item**
- **Equip/drop may NOT end turn** (version-dependent)

#### **Stay/Wait**
- Unit remains in current position
- No action taken
- **ENDS TURN immediately**

### 5. Turn End
- Any action from menu (Attack, Magic, Item, Stay) ends the unit's turn
- Exception: Some non-combat actions like viewing stats or equipping items may not end turn (version-dependent)
- Next unit in turn queue activates

## Special Rules & Notes

### Movement Rules
- Can cancel movement with B button before confirming action
- Once action menu option is selected, movement is locked
- Cannot move after opening action menu
- Movement + Action is the complete turn structure

### B Button Functions
During battle, B button serves dual purposes:
1. **Cancel Movement** - Returns unit to starting position to re-plan movement
2. **Open Info Menu** - Access Map, Member stats, Quit, Speed settings (doesn't end turn)

### Item System During Battle
- **Consumable items** disappear after use
- **Weapons with magic** are reusable (rings may crack/break)
- **Equipment** must be equipped during battle to gain benefits
- **Cursed items** cannot be removed without priest/Detox spell
- **Stat-boosting items** should be used after promotion for max effect

### Actions That DON'T End Turn
- Viewing character statistics
- Checking the map
- Reading message log
- Changing battle speed
- Canceling movement with B button
- Possibly equipping items (version-dependent)

### Menu Intelligence
The action menu attempts to predict player intent:
- Enemy in range → Attack option pre-selected
- No enemies nearby → Stay option pre-selected
- Reduces button presses for common actions

## Implementation Implications

### For The Sparkling Farce Platform

1. **Movement First, Action Second**
   - Display movement range when turn starts
   - Allow free movement exploration with cancel/redo
   - Only open action menu after position confirmed

2. **Action Menu System**
   - Radial or list-based menu with 4 core options
   - Context-aware highlighting based on situation
   - Clear visual feedback for what each option does

3. **Turn State Tracking**
   - `has_moved`: false → true when position confirmed
   - `has_acted`: false → true when action selected
   - Turn ends when `has_acted == true`

4. **Cancel/Redo Movement**
   - Store starting position when turn begins
   - Allow B button to reset to starting position
   - Clear any movement indicators and recalculate

5. **Item Menu Complexity**
   - Needs sub-menu for inventory
   - Target selection for healing items
   - Equipment management (equip/unequip)
   - Item transfer between adjacent allies
   - Drop item option

## Comparison to Current Implementation

### What We Have Now
- ❌ Click-to-move immediate movement
- ❌ Hotkey for attack (Space)
- ❌ Hotkey for end turn (Enter)
- ✅ Turn-based system with active unit
- ✅ Movement range calculation

### What We Need
- ✅ Movement range display on turn start
- ✅ Free movement exploration with cancel
- ✅ Action menu after position confirmed
- ✅ Attack, Magic, Item, Stay options
- ✅ Context-aware menu highlighting
- ✅ Proper turn ending only after action selected

## References
- Shining Force 1 Official Instructions Manual
- Shining Force 2 Official Instructions Manual
- RPG Classics Shrine: Shining Force How to Play
- Shining Force Central Ultimate Guides
