# Shining Force Equipment Management Analysis & Design Recommendations

**Mission Officer:** Commander Claudius (First Officer, SF Vision Guardian)
**Date:** December 5, 2025
**Status:** DESIGN ANALYSIS COMPLETE
**Purpose:** Guide platform inventory/equipment design based on SF series analysis

---

## Executive Summary

This document analyzes equipment management across Shining Force 1 (Genesis), SF1 Resurrection of the Dark Dragon (GBA), and Shining Force 2 (Genesis), identifying pain points and successful patterns. It provides design recommendations for The Sparkling Farce platform based on SF authenticity, modern UX expectations, and our "platform-first" mission.

**Key Findings:**
1. SF2's Caravan Depot was the series' greatest QoL improvement - unlimited mobile storage
2. The 4-slot inventory constraint created meaningful tactical decisions BUT caused player frustration
3. SF1 GBA's separation of equipment from inventory slots was a significant improvement
4. Modern tactical RPGs (Fire Emblem) have solved many problems SF left unaddressed
5. **Our platform has already implemented most best practices** (equipment + inventory separation, configurable slots, typed equipment slots)

---

## Part 1: Shining Force Series Analysis

### 1.1 Shining Force 1 (Genesis) - The Original Implementation

#### Inventory System
- **4 item slots per character** - weapons, armor, consumables all share this pool
- **No centralized storage** - each character manages their own inventory independently
- **No headquarters storage** - HQ only provided party swapping, not item management
- **Item drops require empty slots** - killing enemies with full inventory loses loot to the "Deals" shop

#### Pain Points (from fan feedback and research)

> "The inventory is a complete pain in the ass, with each character only having four item slots. Doesn't really make a difference with the secondary characters, but every time I open a chest the main character has to have an open inventory slot, so I spend a lot of time dicking around with item distribution."
> — [GameFAQs User, 2010](https://gamefaqs.gamespot.com/boards/563340-shining-force/50029594)

**Major Issues:**
1. **Constant inventory juggling** - Opening chests and picking up loot required pre-emptive slot management
2. **Hero tax** - The protagonist had to maintain free slots for story/treasure items
3. **No overflow solution** - Lost items went to shops at markup prices
4. **Tedious item transfers** - Moving items between characters required multiple menu dives
5. **Equipment vs consumables** - Equipped gear occupied inventory slots, forcing hard choices

**What Worked:**
- The 4-slot limit created **meaningful scarcity** - you had to plan loadouts carefully
- Character specialization emerged naturally - healers carried herbs, fighters carried weapons
- Trade-offs felt tactical - "Do I carry a backup weapon or more healing items?"

#### Equipment Management
- **Class-restricted equipment** - Not every character could use every weapon
- **Equipment occupied inventory slots** - No separation between "equipped" and "carrying"
- **Rings provided build customization** - Power Ring, Speed Ring, Protect Ring were iconic
- **No durability system** - Items didn't degrade (good!)

#### Battle vs Overworld Inventory Access
- **Battle**: Full inventory access via "Item" command - equip, use, give, drop
- **Overworld**: Same menu structure in towns and headquarters
- **No difference in functionality** - consistent interface across all contexts

---

### 1.2 Shining Force 1: Resurrection of the Dark Dragon (GBA) - The Improved Remake

The GBA remake addressed several pain points while preserving SF's tactical core:

#### Key Improvements

> "Each character now has four item slots in addition to the usual four equipment slots, so you don't need to juggle their inventory quite as much."
> — [Hands-On Review, Sega-16](https://www.sega-16.com/2005/02/hands-on-shining-force-ressurection-of-dark-dragon-gba/)

> "With the Item Box (and the fact that equipped weapons and accessories no longer take up Item space), you never have to worry about filling up your item capacity."
> — [GameFAQs User, GBA Guide](https://gamefaqs.gamespot.com/gba/918893-shining-force-resurrection-of-the-dark-dragon/faqs)

**Equipment/Inventory Separation:**
- **4 dedicated equipment slots** - weapon, shield, accessory, etc. (implementation details unclear)
- **4 additional inventory slots** - for consumables, backup gear, quest items
- **8 effective slots total** - doubled capacity without losing the "constrained loadout" feel

**Experience System Fix:**
- SF1 Genesis reset XP to 0 on level-up (frustrating!)
- GBA remake carries XP over like SF2 (massive improvement)

**Character Balance:**
- Previously weak characters (healers, supports) made more viable
- No more über-powerful units steamrolling battles - better balance

**Clear Bonuses:**
- Completing maps in few turns grants gold or special weapons
- Encouraged efficient tactics and replayability

**What This Means:**
The GBA remake proved that **doubling inventory capacity through separation** (equipment vs items) dramatically improved UX without sacrificing tactical depth. Players still made meaningful loadout choices, but without the tedious inventory micromanagement.

---

### 1.3 Shining Force 2 (Genesis) - The Caravan Revolution

SF2's signature innovation was the **mobile Caravan headquarters** that addressed SF1's storage problems:

#### The Caravan System

> "The Caravan acts like the headquarters in Shining Force 1, except that it's with you at all times. Plus, it has some handy new features. In addition to choosing party members, you can also deposit items into storage so they don't waste inventory space."
> — [SF2 Guide, RPGClassics](http://shrines.rpgclassics.com/genesis/sforce2/walkthrough/walk06.shtml)

> "It has unlimited storage space for things, which can be stored and taken out at will, which makes it great for stashing things like Mithril chunks, the Sky Orb, the Achilles Sword and the Dry Stone."
> — [Caravan Wiki, Shining Force Fandom](https://shining.fandom.com/wiki/Caravan)

**Core Features:**
1. **Unlimited storage capacity** - no more throwing away items due to full inventory
2. **Always accessible** - travels with your party on the overworld (not in towns/dungeons)
3. **Party swapping on-the-go** - no need to return to HQ to change members
4. **Depot menu**: Look (examine items), Derive (retrieve items), Store (deposit items)
5. **Cross-river travel** - provided overworld mobility beyond just storage

**Famous Exploit:**
- Putting cracked items into Caravan storage and retrieving them repaired them for free
- Shows that storage was a simple "bank" with no durability tracking

#### What SF2 Kept From SF1
- **4 inventory slots per character** - still the constraint
- **Equipment occupies inventory** - no separation (unlike GBA remake)
- **Class-restricted equipment** - weapons/armor tied to class types
- **Rings system** - Power, Protect, Speed rings returned

#### Pain Points That Remained
- **Still juggling 4 slots** - even with Caravan access, per-character inventory was tight
- **Caravan access limited** - couldn't access in towns, dungeons, or battles
- **Menu diving** - transferring items between characters and Caravan was tedious
- **No quick-sort or filters** - large inventories became unwieldy to navigate

**Impact:**
The Caravan was universally praised as a massive QoL improvement. It solved the "lost loot" problem and gave players breathing room for quest items, promotional items, and gear experimentation. However, it didn't eliminate all inventory friction.

---

### 1.4 Fire Emblem's Convoy System - Comparison Point

Fire Emblem (the other major tactical RPG series) took a different approach:

#### Convoy Mechanics

> "The supply convoy is a gameplay service allowing the storage of spare weapons and items. Owing to the limited inventory space possessed by individual units, use of the supply convoy lets units withdraw and deposit items as they need them throughout the course of the game."
> — [Fire Emblem Wiki](https://fireemblemwiki.org/wiki/Supply_convoy)

**Key Differences from SF:**
1. **Convoy tied to a unit** - usually the lord character (Corrin, Eirika, etc.)
2. **In-battle access** - units adjacent to convoy holder can swap items mid-combat
3. **Pre-battle preparations** - full convoy access before each battle
4. **Capacity limits** - 100-500 items depending on game (SF2 Caravan = unlimited)
5. **No mid-exploration access** - convoy only accessible in specific contexts

**Shops During Battle:**
FE allows shopping and NPC interactions during battle maps, whereas SF segregates these to towns/HQ.

> "With Fire Emblem, you have to visit shops and talk to people while you're in the middle of a battle. This was disorienting for me after being used to Shining Force where these aspects are segregated."
> — [GameFAQs Comparison Thread](https://gamefaqs.gamespot.com/boards/563341-shining-force-ii/55151457)

**What We Can Learn:**
- **Context-aware inventory access** - FE provides convoy access when it makes sense (pre-battle, adjacent to holder)
- **Capacity as a balancing lever** - different games use different limits based on design goals
- **Unit proximity for transfers** - adjacent units can trade items (SF requires menu navigation)

---

## Part 2: Pain Point Analysis

### 2.1 The 4-Slot Inventory Constraint

**The Good:**
- Forces **meaningful loadout decisions** - can't carry everything
- Creates **character specialization** - fighters carry weapons, healers carry items
- Encourages **party diversity** - need different unit types to cover all needs
- Rewards **tactical planning** - thinking ahead about what you'll need in battle

**The Bad:**
- **Tedious micromanagement** - constant item shuffling between characters
- **Chest-opening friction** - protagonist must maintain empty slots for story items
- **Loot loss anxiety** - killing item-dropping enemies with full inventory wastes rewards
- **Promotes hoarding** - players keep inventory sparse "just in case"

**The Verdict:**
The 4-slot limit is **iconic to SF's identity** but needs modern quality-of-life improvements to feel good. The GBA remake's solution (4 equipment + 4 inventory = 8 total) hit the sweet spot.

---

### 2.2 Equipment vs Inventory Confusion

**The Problem:**
In SF1/SF2, equipped gear occupies inventory slots. This means:
- A character with a weapon, shield, and ring equipped only has 1 free slot
- Swapping equipment requires inventory space management
- Players can't tell at a glance what's equipped vs carried

**The GBA Solution:**
Separate equipment from inventory - equipped items don't consume inventory space.

**Modern Convention:**
Nearly all modern RPGs separate these concepts:
- **Equipment slots** - what you're wearing/wielding right now
- **Inventory** - what you're carrying as spares/consumables

**Impact on Our Platform:**
We've already implemented this separation (equipment + inventory arrays in CharacterSaveData). This is the right call.

---

### 2.3 Item Transfer Tedium

**The Problem:**
Transferring items between characters in SF requires:
1. Open menu → Select character A
2. Item submenu → Select item
3. Give command → Select target character B
4. Confirm transfer

For cross-party item redistribution, this becomes exhausting.

**What SF2 Caravan Added:**
A centralized depot, but still menu-driven:
1. Walk to Caravan on map
2. Open Caravan menu → Depot
3. Store items from character
4. Switch to different character
5. Derive (retrieve) items to character

**Modern Improvements We Could Add:**
- Drag-and-drop item transfers in UI (mouse/touch friendly)
- Multi-select for batch transfers
- Auto-sort by item type
- "Transfer to Caravan" button from character inventory (no map navigation)

---

### 2.4 No Visual Inventory State

**The Problem:**
SF games use text-based menus with no visual item representation. Players must:
- Remember what items look like based on names alone
- Read descriptions to understand effects
- Navigate nested menus to compare equipment stats

**Modern Expectations:**
- **Icon-based slots** - visual representation of items (we've implemented this!)
- **Drag-and-drop** - intuitive item manipulation
- **Stat comparisons** - show changes when hovering over equipment
- **Quick filters** - "Show only weapons", "Show only consumables"

---

## Part 3: Context-Specific Inventory Access

### 3.1 In-Battle Inventory

**SF Series Behavior:**
- Full item access via "Item" command during any character's turn
- Can equip/unequip weapons (doesn't consume turn!)
- Can use consumables on self or adjacent allies
- Can give items to adjacent allies
- Can drop items (permanent loss)

**Platform Recommendation:**
✅ **Support full SF-style battle inventory access**
- Equipping weapons mid-battle is tactically important (ranged vs melee swaps)
- Using consumables is core healing/buff mechanic
- Giving items enables clutch plays (pass Healing Seed to injured ally)
- Make equip action free (doesn't consume turn) like SF2

**Implementation Notes:**
- Battle inventory UI should be streamlined (our InventoryPanel component is a good base)
- Show item effects/stats clearly (SF's text descriptions were minimal)
- Highlight usable items based on current context (can't use healing items at full HP)

---

### 3.2 Overworld Inventory

**SF Series Behavior:**
- Access via main menu (same as battle, but no adjacency requirements)
- Can equip/unequip freely
- Can use consumables on any party member
- **SF2**: Can access Caravan Depot when standing on Caravan tile on overworld

**Platform Recommendation:**
✅ **Provide full inventory access on overworld**
- Allow equipment swaps to prepare for upcoming battles
- Allow consumable use for field healing (if enabled per item)
- Provide Caravan access from menu (no tile-standing requirement - QoL improvement)

**UX Enhancement:**
Add a **party-wide inventory view** on overworld:
- See all characters' inventories simultaneously
- Drag items between characters
- Quick "Optimize Equipment" button per character (auto-equip best gear)

---

### 3.3 Town/HQ Inventory

**SF Series Behavior:**
- Same as overworld - full menu access
- **SF1**: HQ provides party swapping (no storage)
- **SF2**: Caravan not accessible in towns (must exit to overworld)

**Platform Recommendation:**
✅ **Allow inventory management in all non-combat contexts**
- Towns should provide shop interaction (buy/sell items)
- HQ/Caravan should provide storage access
- Party swapping should allow inventory transfers with benched characters

**Shop Integration:**
Shops need to display:
1. Character's current equipment + stats
2. Shop inventory with prices
3. Stat comparison when hovering over shop items (ATK +5 → +8)
4. Clear buy/sell/repair options

---

### 3.4 Caravan/Depot Storage

**SF Series Behavior:**
- **SF1**: No centralized storage (major pain point)
- **SF2**: Caravan with unlimited storage, accessible on overworld only

**Platform Recommendation:**
✅ **Implement SF2-style Caravan with modern improvements**

**Core Design:**
- **Unlimited storage capacity** - no artificial limits (SF2 authentic)
- **Always accessible from menu** - don't require map tile interaction (QoL)
- **Organize by item type** - weapons, rings, consumables, key items tabs
- **Search/filter** - especially important for large inventories
- **Batch transfer** - "Store All Consumables", "Retrieve All Herbs"

**When to Block Caravan Access:**
- During battle (tactical limitation)
- In dungeons/caves (if dungeon design forbids retreat)
- Certain story moments (if forced to proceed with current loadout)

---

## Part 4: Design Recommendations for The Sparkling Farce Platform

### 4.1 Current Implementation Status (December 2025)

Our platform has **already implemented** most best practices:

✅ **Equipment + Inventory Separation** (CharacterSaveData):
- `equipped_items: Array[Dictionary]` - 4 typed slots (weapon, ring_1, ring_2, accessory)
- `inventory: Array[String]` - 4 item IDs for consumables/spares
- Total: 8 effective slots per character (SF1 GBA model)

✅ **Data-Driven Equipment Slots** (EquipmentSlotRegistry):
- Mods can define custom slot layouts via mod.json
- Default SF-style: weapon, ring_1, ring_2, accessory
- Total conversion could use: helmet, body_armor, main_hand, off_hand

✅ **Configurable Inventory Size** (InventoryConfig):
- `slots_per_character` configurable per mod (default: 4)
- Supports SF2-authentic constraint or expanded inventories

✅ **Cursed Item System**:
- `is_cursed` flag prevents unequipping
- `uncurse_items` array defines removal methods
- Church services and consumable items both supported

✅ **Modern UI** (InventoryPanel component):
- Icon-based item slots (48x48 with visual states)
- Hover descriptions with stat breakdowns
- Equip/unequip flow with slot validation
- Visual feedback for cursed items (red border, blocked unequip)
- Fixed-height description box (no layout shifts)
- Pixel-perfect Monogram font sizing (16px intervals)

✅ **Class Equipment Restrictions**:
- `ClassData.equippable_weapon_types` enforces restrictions
- Auto-unequip on promotion if new class can't use equipped weapon
- Overflow handling (move to Caravan if inventory full)

**Status:** Phases 4.2.1-4.2.6 complete. The foundation is solid.

---

### 4.2 Recommended Future Enhancements

#### 4.2.7: Caravan Storage System (Next Major Feature)

Implement SF2-style Caravan with modern UX:

**Core Features:**
1. **StorageManager** singleton (autoload)
   - `depot_items: Array[String]` - unlimited capacity
   - `add_to_depot(item_id: String)` - store item
   - `remove_from_depot(item_id: String) -> bool` - retrieve item
   - `get_depot_contents() -> Dictionary` - items grouped by type

2. **CaravanPanel UI** (similar to InventoryPanel)
   - Left side: Current character's inventory
   - Right side: Caravan depot (scrollable, organized by type)
   - Drag-and-drop or click-to-transfer
   - Search bar and filter dropdowns (weapons, rings, consumables, etc.)
   - Batch operations: "Store All", "Retrieve All [Type]"

3. **Accessibility Rules**:
   - Available from overworld menu (always)
   - Available from town menu (always)
   - **Not** available during battles
   - **Not** available in dungeons (configurable per-map)

**Moddability:**
- Mods can set `caravan_enabled: false` to disable storage entirely
- Mods can set `depot_capacity: 100` to limit storage (default: unlimited)
- Mods can register custom storage NPCs (e.g., bank tellers in towns)

---

#### 4.2.8: Party-Wide Inventory View

Allow players to see and manage all active party members' inventories simultaneously:

**UI Layout:**
```
+-----------------------------------------------------------+
| [Character 1] [Character 2] [Character 3] [Character 4]  |
| [Equip][Inv]  [Equip][Inv]  [Equip][Inv]  [Equip][Inv]  |
+-----------------------------------------------------------+
| [Character 5] [Character 6] [Character 7] [Character 8]  |
| [Equip][Inv]  [Equip][Inv]  [Equip][Inv]  [Equip][Inv]  |
+-----------------------------------------------------------+
| [Item Description Panel]                                  |
| [Quick Actions: Optimize All | Store Extras | Sort Items] |
+-----------------------------------------------------------+
```

**Features:**
- Drag items between characters directly
- Visual indicators for cursed items, empty slots, unusable gear
- "Optimize" button auto-equips best gear per character
- "Store Extras" moves all non-essential items to Caravan
- Available on overworld and in towns (not during battles)

---

#### 4.2.9: Shop System Integration

Shops need special inventory handling:

**UI Requirements:**
1. **Three-Panel Layout**:
   - Left: Shop inventory (items for sale with prices)
   - Center: Character equipment/stats
   - Right: Character inventory

2. **Buy Flow**:
   - Click shop item → shows stat comparison
   - Confirm purchase → item added to character inventory
   - If inventory full → prompt to store in Caravan or cancel

3. **Sell Flow**:
   - Drag item from character inventory to "Sell" area
   - Shows sell price (typically 50% of buy price)
   - Confirm → item removed, gold added

4. **Repair Flow** (if durability is ever added):
   - Shows cracked items with repair costs
   - Confirm → gold spent, item repaired

**Moddability:**
- Mods define shop inventories via `ShopData` resources
- Shops can be NPC-based (talk to merchant) or tile-based (stand on shop tile)
- Dynamic pricing (discounts based on story flags)

---

#### 4.2.10: In-Battle Item Transfers

Modernize SF's "Give" command with visual clarity:

**Current SF Behavior:**
- Select "Give" → select item → select adjacent ally → item transferred

**Enhanced Flow:**
1. Select unit with item to give
2. Click "Give Item" command
3. **Highlight valid targets** (adjacent allies with inventory space)
4. Click target ally
5. Show target's inventory → select slot to place item (or auto-place)
6. Confirm transfer

**Tactical Implications:**
- Passing Healing Seeds to injured units who've already acted
- Equipping a bow to a ranged unit who's in position
- Distributing consumables before boss battles

---

### 4.3 Key UX Principles (Platform Design Philosophy)

#### Principle 1: Honor SF's Tactical Scarcity
**The 4-slot inventory constraint is iconic.** Don't bloat it to 20 slots by default.

**However:**
- Allow mods to configure inventory size (our InventoryConfig supports this)
- Provide the Caravan as an "overflow relief valve" (like SF2)
- Separate equipment from inventory (like GBA remake) to reduce tedium without losing constraint

#### Principle 2: Reduce Menu Diving
**SF's nested menus were a product of 16-bit limitations.** We can do better.

**Apply modern UX:**
- Icon-based item slots with hover descriptions (✅ implemented)
- Drag-and-drop item transfers (future enhancement)
- Batch operations ("Store All Herbs", "Optimize Equipment")
- Context-sensitive menus (hide unusable options)

#### Principle 3: Visual Feedback is Critical
**Text-only menus don't cut it anymore.**

**Show, don't tell:**
- Item icons with visual states (empty, filled, cursed, selected) (✅ implemented)
- Stat comparisons when hovering over equipment (show "+3 ATK" change)
- Highlight valid targets/slots during interactions (✅ implemented for equip flow)
- Color-code item types (weapons = red, consumables = green, rings = blue)

#### Principle 4: Accessibility Contexts Matter
**Not all inventory access is created equal.**

**Context-Aware Design:**
- **Battle**: Limited to Item command, adjacency restrictions, turn economy matters
- **Overworld**: Full access, can reorganize freely, Caravan accessible
- **Town**: Full access, shop integration, NPC services (uncurse, repair)
- **Dungeon**: Depends on map config - some may block Caravan for challenge

#### Principle 5: Moddability is Non-Negotiable
**Every constraint must be configurable.**

**Data-Driven Design:**
- Equipment slot layouts defined in mod.json (✅ implemented)
- Inventory size per mod (✅ implemented)
- Caravan capacity per mod (future)
- Item type extensibility (weapon_types, armor_types in mod.json) (✅ implemented)
- Custom uncurse methods via AbilityData (✅ supported)

---

## Part 5: Comparative Matrix

| Feature | SF1 Genesis | SF1 GBA | SF2 Genesis | Fire Emblem | Our Platform |
|---------|-------------|---------|-------------|-------------|--------------|
| **Inventory Slots** | 4 total | 4 equipment + 4 inventory | 4 total | 5-8 (varies) | 4 equip + 4 inv (configurable) |
| **Centralized Storage** | ❌ None | ✅ Item Box | ✅ Caravan (unlimited) | ✅ Convoy (100-500) | ✅ Planned (unlimited) |
| **Equipment/Inventory Separation** | ❌ Shared | ✅ Separate | ❌ Shared | ✅ Separate | ✅ Separate |
| **In-Battle Equip Swaps** | ✅ Yes (free action) | ✅ Yes | ✅ Yes (free action) | ✅ Yes | ✅ Yes (planned) |
| **Cursed Items** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ Rare | ✅ Yes (implemented) |
| **Class Equipment Restrictions** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes (implemented) |
| **Item Icons** | ❌ Text-only | ⚠️ Small icons | ❌ Text-only | ✅ Full icons | ✅ Full icons (48x48) |
| **Drag-and-Drop Items** | ❌ No | ❌ No | ❌ No | ❌ No | ⚠️ Planned |
| **Stat Comparison UI** | ❌ No | ⚠️ Basic | ❌ No | ✅ Yes | ⚠️ Planned |
| **Party-Wide Inventory View** | ❌ No | ❌ No | ❌ No | ❌ No | ⚠️ Planned |
| **Moddable Slot Layouts** | ❌ Hardcoded | ❌ Hardcoded | ❌ Hardcoded | ❌ Hardcoded | ✅ Yes (mod.json) |
| **Configurable Inventory Size** | ❌ Fixed | ❌ Fixed | ❌ Fixed | ❌ Fixed | ✅ Yes (mod.json) |

**Legend:**
- ✅ = Fully supported
- ⚠️ = Partially implemented or planned
- ❌ = Not supported

---

## Part 6: Implementation Roadmap

### Phase 1: Foundation (✅ COMPLETE - December 2025)
- ✅ Equipment/inventory separation in CharacterSaveData
- ✅ EquipmentSlotRegistry for mod-defined slot layouts
- ✅ InventoryConfig for configurable inventory size
- ✅ EquipmentManager with signals and validation
- ✅ UnitStats equipment caching
- ✅ CombatCalculator weapon integration
- ✅ InventoryPanel UI component
- ✅ ItemSlot component with visual states
- ✅ Cursed item handling

### Phase 2: Caravan Storage (Next Priority)
- [ ] Create StorageManager singleton
- [ ] Add Caravan depot data to SaveManager
- [ ] Implement CaravanPanel UI
- [ ] Add menu integration (accessible from overworld/town)
- [ ] Implement batch transfer operations
- [ ] Add search/filter for large inventories
- [ ] Test with 100+ items in depot

### Phase 3: Party-Wide Management
- [ ] Create PartyInventoryPanel UI
- [ ] Implement drag-and-drop item transfers
- [ ] Add "Optimize Equipment" auto-equip logic
- [ ] Add "Store Extras" batch Caravan transfer
- [ ] Integrate with overworld menu

### Phase 4: Shop System
- [ ] Create ShopData resource type
- [ ] Implement ShopPanel UI (three-panel layout)
- [ ] Add stat comparison overlays
- [ ] Integrate with NPC dialog system
- [ ] Test buy/sell/inventory-full flows

### Phase 5: In-Battle Inventory
- [ ] Create BattleInventoryPanel (streamlined variant)
- [ ] Integrate with TurnManager (Item command)
- [ ] Implement adjacency checks for Give command
- [ ] Add visual target highlighting
- [ ] Test equip swaps (free action) vs item use (consumes turn)

### Phase 6: Polish & QoL
- [ ] Add keyboard shortcuts for common actions
- [ ] Implement item sorting options (type, name, value)
- [ ] Add tooltips for all buttons
- [ ] Create tutorial popups for first-time users
- [ ] Add accessibility options (colorblind mode, text scaling)

---

## Part 7: Modding Scenarios

### Scenario 1: SF2-Authentic Experience
A mod wants to recreate SF2's exact inventory model:

```json
{
  "mod_id": "sf2_authentic",
  "name": "Shining Force 2 Classic Mode",
  "inventory_config": {
    "slots_per_character": 4,
    "allow_duplicates": true
  },
  "equipment_slot_layout": [
    {"id": "weapon", "display_name": "Weapon", "accepts_types": ["weapon"]},
    {"id": "ring_1", "display_name": "Ring 1", "accepts_types": ["ring"]},
    {"id": "ring_2", "display_name": "Ring 2", "accepts_types": ["ring"]},
    {"id": "accessory", "display_name": "Accessory", "accepts_types": ["accessory"]}
  ],
  "caravan_config": {
    "enabled": true,
    "capacity": -1,
    "accessible_in_dungeons": false
  }
}
```

**Result:** 4 equipment slots + 4 inventory slots = 8 total (GBA-style separation), with SF2's unlimited Caravan.

---

### Scenario 2: Fire Emblem-Style Convoy
A mod wants FE-style convoy mechanics:

```json
{
  "mod_id": "convoy_tactics",
  "name": "Convoy Tactics RPG",
  "inventory_config": {
    "slots_per_character": 5,
    "allow_duplicates": true
  },
  "caravan_config": {
    "enabled": true,
    "capacity": 200,
    "accessible_in_battle": true,
    "requires_adjacent_unit": "hero"
  }
}
```

**Custom Logic (mod script):**
- Connect to BattleManager signals
- Check unit adjacency to hero before allowing Caravan access
- Limit convoy capacity to 200 items

---

### Scenario 3: Diablo-Style Loot System
A mod wants unlimited inventory with weight limits:

```json
{
  "mod_id": "loot_frenzy",
  "name": "Loot Frenzy ARPG Mod",
  "inventory_config": {
    "slots_per_character": 50,
    "allow_duplicates": true,
    "weight_limit_enabled": true,
    "max_weight_per_character": 100
  },
  "equipment_slot_layout": [
    {"id": "helmet", "display_name": "Helmet", "accepts_types": ["helmet"]},
    {"id": "chest", "display_name": "Chest Armor", "accepts_types": ["armor"]},
    {"id": "weapon_main", "display_name": "Main Hand", "accepts_types": ["weapon"]},
    {"id": "weapon_off", "display_name": "Off Hand", "accepts_types": ["weapon", "shield"]},
    {"id": "ring_1", "display_name": "Ring 1", "accepts_types": ["ring"]},
    {"id": "ring_2", "display_name": "Ring 2", "accepts_types": ["ring"]},
    {"id": "amulet", "display_name": "Amulet", "accepts_types": ["amulet"]}
  ],
  "caravan_config": {
    "enabled": true,
    "capacity": -1,
    "accessible_in_battle": false
  }
}
```

**Custom Logic (mod script):**
- Add `weight` property to ItemData
- Connect to EquipmentManager.pre_equip signal
- Block equip if total weight exceeds limit

---

### Scenario 4: Minimalist JRPG
A mod wants simple shared party inventory:

```json
{
  "mod_id": "party_pool",
  "name": "Shared Inventory JRPG",
  "inventory_config": {
    "slots_per_character": 0,
    "shared_party_inventory": true,
    "shared_inventory_size": 99
  },
  "caravan_config": {
    "enabled": false
  }
}
```

**Custom Logic (mod script):**
- Bypass per-character inventory
- Store all items in PartyManager.shared_inventory
- Any character can use any item in battle

---

## Part 8: Conclusion & Recommendations

### What We're Doing Right
✅ **Separated equipment from inventory** - eliminated SF's biggest friction point
✅ **Configurable slot layouts** - mods can use 4 slots or 20 slots or custom types
✅ **Data-driven restrictions** - class equipment limits flow through modding system
✅ **Modern UI** - icon-based slots with visual feedback (cursed items, hover descriptions)
✅ **Cursed item system** - faithful to SF with multiple uncurse methods

### What We Should Prioritize Next
1. **Caravan Storage System** - This was SF2's killer feature, and fans expect it
2. **Shop Integration** - Can't have an RPG without buying/selling gear
3. **In-Battle Item Command** - Core tactical mechanic for healing and equipment swaps
4. **Party-Wide Inventory View** - Modern QoL that eliminates menu diving

### What We Should Avoid
❌ **Durability/Repair Systems** - Captain already rejected this (good call - tedious busywork)
❌ **Hardcoding Slot Types** - We've made them data-driven, don't break that
❌ **Blocking Caravan Access Unnecessarily** - SF2 limited it to overworld; we can be more generous
❌ **Ignoring Drag-and-Drop** - Modern players expect mouse/touch-friendly UIs

### Design Philosophy Summary
**"Honor SF's tactical scarcity, eliminate SF's tedious friction, enable modders' wildest dreams."**

- Keep the **4-slot inventory constraint** as the default (configurable)
- Provide the **Caravan safety net** (unlimited storage, easily accessible)
- Separate **equipment from inventory** (8 effective slots, less juggling)
- Make **item transfers intuitive** (drag-and-drop, batch operations)
- Support **total conversion mods** (custom slot layouts, inventory models)

**Final Verdict:**
Our platform is on the right track. The foundation (Phases 4.2.1-4.2.6) is solid and honors SF's design while modernizing UX. The next priorities (Caravan, shops, battle items) will complete the vision and make this a best-in-class tactical RPG platform.

**Make it so, Number One.**

---

## Sources

### Shining Force 1 (Genesis)
- [New to game; Question about item management - GameFAQs](https://gamefaqs.gamespot.com/boards/563340-shining-force/50029594)
- [Shining Force - How to Play - RPGClassics](https://shrines.rpgclassics.com/genesis/shiningforce/howtoplay.shtml)
- [Is there an easy way to store and manage items? - GameFAQs](https://gamefaqs.gamespot.com/boards/954264-sonics-ultimate-genesis-collection/48332942)

### Shining Force 1: Resurrection of the Dark Dragon (GBA)
- [Hands-On: Shining Force: Resurrection of Dark Dragon (GBA) - Sega-16](https://www.sega-16.com/2005/02/hands-on-shining-force-ressurection-of-dark-dragon-gba/)
- [Shining Force: Resurrection of the Dark Dragon FAQs - GameFAQs](https://gamefaqs.gamespot.com/gba/918893-shining-force-resurrection-of-the-dark-dragon/faqs)

### Shining Force 2 (Genesis)
- [The Ultimate Shining Force 2 Guide: Instructions Manual](https://sf2.shiningforcecentral.com/guide/instructions-manual/)
- [Taros & The Caravan - RPGClassics](http://shrines.rpgclassics.com/genesis/sforce2/walkthrough/walk06.shtml)
- [Caravan | Shining Wiki | Fandom](https://shining.fandom.com/wiki/Caravan)
- [Shining Force II - Guide and Walkthrough - GameFAQs](https://gamefaqs.gamespot.com/genesis/563341-shining-force-ii/faqs/25815)

### Fire Emblem Comparison
- [Supply convoy - Fire Emblem Wiki](https://fireemblemwiki.org/wiki/Supply_convoy)
- [Supply Convoy | Fire Emblem Wiki | Fandom](https://fireemblem.fandom.com/wiki/Supply_Convoy)
- [How do the Shining Force games compare to Fire Emblem? - GameFAQs](https://gamefaqs.gamespot.com/boards/563341-shining-force-ii/55151457)

---

**Live long and design quality systems.**
*Commander Claudius, First Officer - USS Torvalds*
