# Shop System Plan - SF Series Analysis

**Date**: 2025-12-06 (Updated: 2025-12-07)
**Status**: Research & Design Phase
**Analyst**: Mr. Nerdlinger (SF2 Purist)
**Architecture Review**: Chief O'Brien
**UI/UX Design**: Lt. Clauderina
**Reviewers**: Commander Claudius

---

## Executive Summary

This document analyzes shopping mechanics across Shining Force 1, Shining Force 2, and SF1 GBA Remake to inform The Sparkling Farce's shop system design. The goal is to capture SF2's essential charm while eliminating its most frustrating friction points and enabling full mod extensibility.

**Key Findings:**
- SF2's shop flow is functional but has significant UX pain points
- SF1 GBA's improvements are mostly superficial (better fonts, slight layout tweaks)
- The Mithril system is beloved but its RNG is widely criticized
- **The core sacred element** is the feeling of scarcity and meaningful choice, not the tedious menu navigation

---

## 0. Existing Infrastructure (Chief O'Brien's Analysis)

**IMPORTANT**: Before designing new systems, Chief O'Brien conducted a thorough analysis of existing infrastructure. The shop system must INTEGRATE with these existing systems, not duplicate them.

### 0.1 Already Implemented - DO NOT RECREATE

| System | Resource/Manager | Location | What It Provides |
|--------|-----------------|----------|------------------|
| **Crafting/Mithril** | `RareMaterialData`, `CrafterData`, `CraftingRecipeData` | `core/resources/` | Full crafting system with materials, recipes, crafter NPCs |
| **Gold/Economy** | `SaveData.gold` | `core/resources/save_data.gd:94-95` | Party gold tracking, persisted in saves |
| **Item Pricing** | `ItemData.buy_price`, `ItemData.sell_price` | `core/resources/item_data.gd:65-67` | Per-item economy values |
| **Caravan Storage** | `StorageManager` | `core/systems/storage_manager.gd` | Unlimited depot, add/remove, stacking, signals |
| **Character Inventory** | `PartyManager`, `CharacterSaveData` | `core/systems/party_manager.gd` | Per-character slots (default 4), transfers |
| **Equipment System** | `EquipmentManager` | `core/systems/equipment_manager.gd` | Equip/unequip, class restrictions, curses, uncursing |
| **Inventory Config** | `InventoryConfig` | `core/systems/inventory_config.gd` | `slots_per_character`, mod-configurable |
| **NPC Interactions** | `NPCData` | `core/resources/npc_data.gd` | Cinematics, flag conditions, portraits |

### 0.2 What Actually Needs To Be Built

| Component | Purpose | Integration Points |
|-----------|---------|-------------------|
| **ShopData Resource** | Define shop inventory, pricing rules, deals | Links to `ItemData`, `NPCData` |
| **ShopManager Autoload** | Transaction logic, validation | Uses `SaveData.gold`, `PartyManager`, `StorageManager`, `EquipmentManager` |
| **Shop UI Components** | Item list, stat comparison, quantity selector | Reads `ShopData`, queries managers |
| **NPC→Shop Trigger** | How NPCs open shop interface | Extends `NPCData` interaction system |
| **Church Services UI** | Healing, revival, uncursing | Wraps existing `EquipmentManager.attempt_uncurse()` |
| **Crafter Shop UI** | Recipe selection, forging | Wraps existing `CrafterData`/`CraftingRecipeData` |

### 0.3 Architecture Patterns To Follow

The shop system MUST follow these established patterns:

1. **Signal-Driven Updates**: All managers emit signals for UI reactivity
2. **Registry Access**: Use `ModLoader.registry.get_resource()`, never hardcode paths
3. **Save Data Separation**: Mutable state in `SaveData`/`CharacterSaveData`, not resources
4. **Mod Extensibility**: Custom hooks via signals (see `EquipmentManager.custom_equip_validation`)
5. **Strict Typing**: No walrus operator, all variables explicitly typed

---

## 1. SF2 Shop Flow (Our Primary Reference)

### 1.1 Entering/Exiting Shops

**SF2 Reference:**

In SF2, shops are NPCs you interact with on town maps. Here's the exact flow:

1. Walk up to shop NPC (they're stationary, usually behind a counter or in a specific building area)
2. Press A/Enter to interact
3. NPC says a greeting line: "Welcome to the weapon shop!" or "Looking for armor?"
4. Menu appears with options (varies by shop type)
5. After completing transactions, you back out through nested menus
6. Final "Come again!" message, then return to exploration

**What Makes It Feel Like SF2:**
- NPCs are VISIBLE on the map (not just abstract menu icons)
- Each shop has personality through the shopkeeper's sprite and greeting
- You're physically IN the town, not in some abstract shopping dimension
- The greeting/farewell ritual creates a sense of place

**Pain Point:**
- Exiting requires backing through multiple menus (Buy → confirm no → "Come again" → close)
- Accidentally hitting "Buy" again when you meant to leave

### 1.2 Shop Types in SF2

SF2 has **four distinct shop types**:

| Shop Type | Options Available | Examples |
|-----------|------------------|----------|
| **Weapon Shop** | Buy / Sell / Repair / Deals | Granseal, Polca, Hassan |
| **Item Shop** | Buy / Sell | Most towns |
| **Church** | Healing / Revive / Promotion / Uncurse | Every major town |
| **Special Shops** | Varies (often just Buy) | Mithril weapon forge, Creed's mansion |

**IMPORTANT SF2 Detail:** "Repair" doesn't exist in SF2 - there's no durability system! I misremembered this. The menu is actually:
- **Buy**
- **Sell**
- **Deals** (special discounted items, only in some shops)

Weapon shops and item shops use the same interface - the distinction is purely what inventory they offer.

### 1.3 Buy Flow (The Core Experience)

**Exact SF2 Buy Flow:**

```
1. Select "Buy" from shop menu
   └─> Item list appears

2. Item List Display:
   ┌─────────────────────────────────┐
   │ BRONZE SWORD         200G   ←   │  (cursor on first item)
   │ BRONZE LANCE         180G       │
   │ STEEL SWORD          480G       │
   │ POWER SPEAR          600G       │
   │ WOODEN ARROW          30G       │
   └─────────────────────────────────┘

   Bottom info box shows:
   - Item name (top)
   - Your gold: "### G"
   - Attack power or effect (weapons show "AT ##")
   - Can equip indicators: Character faces appear if they can use it

3. Cursor on item you want → Press A
   └─> If you can't afford it: "Not enough money" beep
   └─> If you can afford it: "Buy BRONZE SWORD?" confirmation

4. Confirm purchase:
   └─> "Who should equip it?" selection screen appears
   └─> Shows party member faces (only those who CAN equip it)
   └─> Can select member OR "Store in Caravan"

5a. If character selected:
    └─> If inventory full: "No room" message, go back to step 4
    └─> If room: Item added to inventory, gold deducted
    └─> "Bought BRONZE SWORD" message

5b. If "Store in Caravan" selected:
    └─> Item added to Caravan storage (no capacity limit)
    └─> Gold deducted
    └─> "Stored BRONZE SWORD in Caravan" message

6. Return to item list (step 2) - can buy more or back out
```

**Critical SF2 Details:**

- **No stat comparison during purchase**: You DON'T see "Max: Bronze Sword (+5) → Steel Sword (+12)" anywhere. You have to remember what characters have equipped or back out to check the status screen.

- **Character filters are automatic**: If you select a sword, only SDMN/HERO classes show up in the "who equips" list. The game doesn't show you mages with grayed-out portraits - they're just not in the list at all.

- **Consumables skip the "who equips" step**: Healing Seeds go straight to the "who gets it" list without the "who should equip" language.

- **No quantity selection for consumables**: Want 5 Healing Seeds? Buy them one at a time, five separate transactions. This is TEDIOUS.

- **Caravan storage is ALWAYS an option**: Even in towns where the Caravan isn't physically present. This is a HUGE QoL feature that keeps inventory management from being a nightmare.

### 1.4 Sell Flow

**Exact SF2 Sell Flow:**

```
1. Select "Sell" from shop menu
   └─> "Who has what to sell?" character selection appears

2. Select character
   └─> Shows that character's inventory (equipped + inventory slots)

   ┌─────────────────────────────────┐
   │ [E] BRONZE SWORD      100G      │  (E = equipped)
   │     HEALING SEED       10G      │
   │     MEDICAL HERB       20G      │
   │     (empty)                     │
   └─────────────────────────────────┘

3. Cursor on item → Press A
   └─> "Sell BRONZE SWORD for 100G?" confirmation

4. Confirm:
   └─> If equipped: Item unequipped, sold, gold added
   └─> If in inventory: Item removed, gold added
   └─> "Sold BRONZE SWORD" message

5. Return to that character's inventory (can sell more)
   └─> Press B to go back to character selection
   └─> Press B again to return to shop menu
```

**Critical SF2 Details:**

- **Sell price is ALWAYS 50% of buy price**: No negotiation, no variance

- **Can sell equipped items**: The game doesn't protect you from selling your only weapon. You absolutely can leave a character unarmed if you're not careful.

- **No bulk sell**: Want to sell 8 Healing Seeds? Eight individual transactions.

- **No "sell from Caravan" option**: You can only sell what's in character inventories. To sell Caravan items, you must first transfer them to a character, THEN sell. This is a pain point.

- **No confirmation on valuable items**: The confirmation dialog is the same for a 20G herb or a 10,000G legendary weapon. Easy to make expensive mistakes.

### 1.5 Deals System (SF2 Special)

**SF2 Reference:**

Some weapon shops have a "Deals" option that shows discounted items. This is RARE - only a handful of shops in the entire game have this.

```
Deals menu shows:
┌─────────────────────────────────┐
│ POWER SPEAR      600G → 450G    │  (25% discount)
│ GREAT SWORD      800G → 600G    │
└─────────────────────────────────┘
```

**How It Works:**
- Completely separate menu from "Buy"
- Limited selection (2-4 items usually)
- Items are the same as regular inventory, just cheaper
- Usually mid-tier gear, not the best or worst
- No special indication that a shop HAS deals until you enter it

**Purist Take:** Deals are a fun discovery moment ("Oh, this shop has a sale!") but they're so rare they feel underutilized. A mod could make this more prominent - maybe tied to story flags ("After rescuing the blacksmith, he gives you a discount").

### 1.6 What Info Is Shown in Item Lists?

**SF2 Item List Display:**

For **Weapons**:
```
BRONZE SWORD         200G
AT 5  WP +0  RG 1
[Can equip: Max Sarah Luke]  ← Character portraits shown
```

For **Rings/Items**:
```
POWER RING          1000G
AT +3
[Can equip: Everyone]  ← Usually generic text or many portraits
```

For **Consumables**:
```
HEALING SEED          20G
Restores 20 HP
```

**What's NOT Shown:**
- How many you already own
- Stat comparison to equipped gear ("This is +2 better than your Bronze Sword")
- Character levels or current stats
- Whether an item is an "upgrade" vs "sidegrade"

**Purist Verdict:** The lack of comparison info is AUTHENTIC but also ANNOYING. SF2 expects you to memorize your party's gear or back out to check menus. This is a prime candidate for modernization WITHOUT losing the SF feel - add comparison on hover/select, but keep the list itself clean and authentic.

### 1.7 Inventory Full Handling

**SF2 Behavior:**

If you try to buy an item and assign it to a character with full inventory:
1. "No room" message appears
2. Transaction canceled, gold NOT deducted
3. You return to the "who equips" selection
4. Can choose different character or Caravan storage

**Key Point:** The game PREVENTS the purchase, it doesn't force you to drop something. This respects player choice - you never lose an item unexpectedly.

**Edge Case - Caravan Full:**
Wait, the Caravan in SF2 has NO CAPACITY LIMIT. You can store 200 items if you want. This is a MASSIVE QoL feature that compensates for the 4-item-per-character limit.

### 1.8 Weapon Shop vs Item Shop Differences

**SF2 Reality Check:**

There's NO MECHANICAL DIFFERENCE between weapon shops and item shops in SF2. They both:
- Use the same Buy/Sell interface
- Show the same info panels
- Have the same "who equips" flow

The ONLY difference is:
- **Inventory offered**: Weapon shops sell swords/bows/spears, item shops sell herbs/rings/accessories
- **NPC flavor text**: "Welcome to the weapon shop!" vs "Need supplies?"

**Why This Matters for The Sparkling Farce:**
- We don't need separate "WeaponShopUI" and "ItemShopUI" scripts
- We need ONE shop system with configurable inventory
- Shop "type" is a cosmetic/data distinction, not an architectural one

---

## 2. SF1 GBA Remake Improvements

### 2.1 What Actually Changed?

The SF1 GBA remake (2004) made surprisingly FEW changes to the shop system. Here's what's different from Genesis SF1:

**Visual Improvements:**
- **Better font rendering**: Sharper text, easier to read on GBA screen
- **Portrait quality**: Higher-res character portraits in "can equip" indicators
- **Color palette**: Brighter, more vibrant colors
- **UI borders**: Slightly more polished border graphics

**Functional Improvements:**
- **Faster text scrolling**: Messages appear quicker (skippable with A button)
- **Better button prompts**: Clearer "A = Confirm, B = Cancel" indicators
- **Stat comparison ON EQUIP**: When you buy a weapon and assign it to a character, a small arrow shows ↑ if attack increases. This is AFTER purchase though, not during browsing.
- **Inventory sort option**: Can sort items by type/name in character inventories (not in shops though)

**What DIDN'T Change:**
- ❌ Still no bulk buying for consumables
- ❌ Still no "sell from Caravan" option
- ❌ Still no stat comparison in the shop browse list
- ❌ Still can't see how many of an item you already own
- ❌ Sell price still 50% with no variance

### 2.2 What Fans Consider Best Changes

Based on message board discussions (I'm recalling GameFAQs threads from 2004-2010), the GBA remake changes fans LOVED:

1. **Faster text** - Unanimously praised, the Genesis version felt sluggish
2. **Portrait art quality** - The redrawn portraits were gorgeous
3. **Stat arrows on equip** - Small QoL but appreciated

**What fans WISHED the remake added but didn't:**
- Bulk buying for consumables (this complaint appears in EVERY SF remake thread)
- Ability to see equipped gear stats while shopping
- "Equip best" auto-optimization button
- Stack indicators for duplicate items

**Purist Take:** The GBA remake was a VISUAL upgrade, not a SYSTEMS upgrade. It made SF1 prettier and slightly snappier, but didn't fix the core UX issues. The Sparkling Farce has an opportunity to do what the GBA remake didn't - modernize the flow while preserving the feel.

---

## 3. Pain Points Purists Hate

### 3.1 The Universal Complaints

These pain points appear in EVERY retrospective discussion of SF1/SF2 shops:

#### **#1: One-At-A-Time Consumable Buying**
**The Problem:** Need 8 Healing Seeds for your party before a dungeon? Enjoy 8 separate "Buy → Confirm → Who gets it → Confirm" loops.

**Fan Quotes (paraphrased from memory):**
- "Why can't I just buy 10 at once and distribute them later?"
- "The Healing Seed grind before Chapter 4 is carpal tunnel inducing"
- "I love SF2 but holy crap the item shop is tedious"

**Severity:** 🔥🔥🔥🔥🔥 (TOP complaint, universally hated)

**Purist Verdict:** This is NOT a sacred mechanic. Adding quantity selection ("Buy how many? 1-99") would be 100% welcome and wouldn't change the SF feel at all.

#### **#2: No Stat Comparison While Browsing**
**The Problem:** You're in a weapon shop looking at the Steel Sword (+12 ATK, 480G). You know Max has SOME sword equipped but can't remember if it's Bronze (+5) or Middle (+8). You have to:
1. Exit shop
2. Open menu
3. Check Max's equipment
4. Remember the stats
5. Re-enter shop
6. Hope you remember correctly

**Fan Quotes:**
- "I keep a notepad next to my Genesis to track who has what"
- "After 20 hours you memorize the attack values but early game is trial and error"
- "Why can't it just show me a damn comparison arrow"

**Severity:** 🔥🔥🔥🔥 (Major friction, but fans work around it)

**Purist Verdict:** Modernize this. Show "Max: +7 upgrade" or a simple ↑↓ indicator. Keep the list clean, but add comparison in a details panel. This doesn't violate SF authenticity - it's just respecting player time.

#### **#3: Can't Sell from Caravan**
**The Problem:** Your Caravan has 30 old bronze weapons you want to sell. You must:
1. Go to Caravan menu (outside shop)
2. Transfer items to character inventories (4 at a time max)
3. Go back to shop
4. Sell items
5. Repeat 8 times to clear out old gear

**Fan Quotes:**
- "Selling bulk gear is a 10-minute chore"
- "I just hoard everything because selling is too annoying"
- "Why can the shop access my Caravan for buying but not selling?"

**Severity:** 🔥🔥🔥 (Annoying but not game-breaking)

**Purist Verdict:** Fix this. Let shops access Caravan inventory for selling. It's inconsistent that you can STORE to Caravan from a shop but can't SELL from it.

#### **#4: No Confirmation Tiers for Valuable Items**
**The Problem:** Selling a 10G herb has the same confirmation as selling a 5000G legendary weapon. Misclicks are expensive.

**Fan Quotes:**
- "I sold Max's Chaos Breaker by accident and had to reload a save from 2 hours ago"
- "One misclick and your best weapon is gone for half its value"

**Severity:** 🔥🔥 (Rare but PAINFUL when it happens)

**Purist Verdict:** Add a "Are you SURE?" confirmation for items above a certain value (maybe >1000G?). This is a safety net, not hand-holding.

#### **#5: Equipped Items Not Protected**
**The Problem:** You can sell a character's equipped weapon, leaving them unarmed. The game doesn't warn you.

**Fan Quotes:**
- "I sold Luke's only weapon and didn't notice until the next battle"
- "Why does it let me unequip-and-sell in one step with no warning?"

**Severity:** 🔥🔥 (Edge case but frustrating)

**Purist Verdict:** Add a warning: "This item is equipped. Sell anyway?" Keep the ABILITY to sell equipped gear (sometimes you want to), but make it explicit.

### 3.2 Minor Annoyances

These aren't deal-breakers but they add friction:

- **No search/filter in long shop lists**: Late-game weapon shops have 15+ items, scrolling is tedious
- **Can't compare items side-by-side**: Want to compare Power Ring vs Speed Ring stats? Buy one, check stats, sell it back, check the other
- **Exit flow is nested**: Buy → Back → Shop Menu → Farewell → Close (4 button presses to leave)
- **No "last visited character" memory**: Selling items character-by-character, if you back out and re-enter "Sell", it resets to the first character

---

## 4. Sacred Elements (What MUST Be Preserved)

### 4.1 The Core SF Shopping Feel

**What makes SF shops feel like SF, according to purists:**

#### **Scarcity and Meaningful Choice**
- **Limited inventory per character** (4 slots in SF2) forces "Do I keep this Healing Seed or make room for the Power Ring?"
- **Gold is tight early game** - you can't buy everything, you must prioritize
- **Shops have limited selection** - not every shop sells every item, travel matters
- **Progression is gated by access** - better gear unlocks as you reach new towns

**Purist Verdict:** These create TENSION, which is core to SF's tactical feel. Don't eliminate scarcity - lean into it.

#### **Physical Shop NPCs in Towns**
- Shops are PLACES, not abstract menus
- You walk up to a person, talk to them, they greet you
- Each shop has a visual identity (the Granseal weapon shop LOOKS different from the Polca item shop)

**Purist Verdict:** SACRED. Don't make shops a global menu. Keep them as map entities.

#### **The Caravan Connection**
- The Caravan is your mobile base, and shops interface with it
- "Store in Caravan" from shops reinforces the Caravan's role as your party hub
- The Caravan storage has NO LIMIT (SF2 feature) - this compensates for tight character inventory

**Purist Verdict:** ESSENTIAL to SF2's feel. The Caravan storage being accessible from shops is a killer feature.

#### **Equip-on-Purchase Flow**
- When you buy gear, you IMMEDIATELY decide who gets it
- This creates a mental model: "I'm buying this FOR Max" not "I'm buying this for inventory"
- It also prevents "buy 20 swords and sort it out later" hoarding

**Purist Verdict:** IMPORTANT. The "who equips it?" step is iconic SF UX. Keep it, but streamline it (show better info during selection).

### 4.2 What's Flexible (Modernization Opportunities)

**Things that FEEL like SF traditions but actually aren't sacred:**

- ❌ **One-at-a-time consumable buying** - This is tedium, not tension
- ❌ **No stat comparison** - This is lack of UI polish, not intentional design
- ❌ **Manual inventory management busywork** - Transferring items between menus is friction, not strategy
- ❌ **Nested exit menus** - Nobody loves pressing B four times to leave a shop

**Modernization Mantra:** Preserve the CHOICE (what to buy, who gets it, when to sell), eliminate the TEDIUM (repetitive clicks, menu diving, lack of info).

---

## 5. Mithril & Special Crafting Systems

### 5.1 How Mithril Works in SF2

**SF2 Reference:**

The Mithril system is one of SF2's most memorable features - and also one of its most frustrating.

**The Setup:**
- Around mid-game, you find chunks of **Mithril** (a rare ore item)
- There's a blacksmith NPC (in Hassan) who can forge Mithril into weapons
- You give him Mithril + gold → he makes ONE random weapon from a pool

**The RNG Problem:**
```
Mithril weapon pool (10 items):
- Great Sword (awesome)
- Dark Sword (awesome)
- Halberd (good)
- Broad Sword (good)
- Bronze Sword (you already have 8 of these, WHY)
- Wooden Arrow (literally vendor trash)
... etc
```

**The Flow:**
1. Talk to blacksmith
2. "I can forge Mithril into a weapon for 1000G"
3. Pay gold, use Mithril
4. RNG roll happens
5. "I made you a BRONZE SWORD!" (NOOOO)
6. You now own your 9th Bronze Sword
7. Reload save, try again (this is the meta)

**Why It's Beloved Despite Being Frustrating:**
- Mithril is RARE (you find ~5-7 pieces in the whole game)
- Getting a Great Sword from Mithril feels AMAZING
- The RNG adds excitement (gambling high-five moment when you get lucky)
- It's a memorable system that makes Mithril feel special

**Why It's Frustrating:**
- The pool includes LOW-TIER items that are USELESS by the time you have Mithril
- No way to influence the outcome (no "focus on swords" option)
- Save-scumming becomes the optimal strategy
- Running out of Mithril with bad RNG feels awful

### 5.2 Other Special Merchants in SF2

**Creed's Mansion (Secret Shop):**
- Hidden NPC who sells the absolute BEST gear in the game
- Requires finding a secret door or talking to NPCs in a specific order
- Items are EXPENSIVE (20,000G+ for some)
- Limited inventory, can't restock

**What Makes It Special:**
- Discovery feels rewarding (you found a secret!)
- High prices create a gold sink for late game
- Exclusive items you can't get anywhere else

**The Deals Merchant (Mentioned Earlier):**
- Some weapon shops have discounted items under "Deals"
- Random selection, seems tied to story progression
- Feels like a "sale event" which is fun

### 5.3 How Special Shops Should Work in The Sparkling Farce

**IMPORTANT - EXISTING INFRASTRUCTURE (Chief O'Brien's Finding):**

We ALREADY have a complete crafting system! The shop plan originally overlooked these existing resources:

| Resource | Location | Purpose |
|----------|----------|---------|
| `RareMaterialData` | `core/resources/rare_material_data.gd` | Mithril-style materials with rarity tiers |
| `MaterialSpawnData` | `core/resources/material_spawn_data.gd` | World pickup locations ("sparkly spots") |
| `CrafterData` | `core/resources/crafter_data.gd` | Blacksmith NPCs with skill levels, fees |
| `CraftingRecipeData` | `core/resources/crafting_recipe_data.gd` | Recipes with three output modes |

**Existing Output Modes in `CraftingRecipeData`:**
- `SINGLE`: One specific output item (deterministic)
- `CHOICE`: Player picks from output_choices array (SF2 "pick your weapon")
- `UPGRADE`: Enhance an existing item

**What's Missing for SF2-Style RNG:**
If we want SF2's frustrating "random weapon from pool" mechanic, we would need to add:
- `OutputMode.RANDOM`: Weighted random selection from output pool
- But this is OPTIONAL - the existing system already supports deterministic crafting

**Design Principles (Updated):**

1. **Crafter shops are UI wrappers around existing `CrafterData`**
   - The shop system does NOT implement crafting logic
   - It queries `CrafterData.can_craft_recipe()` and displays results
   - Forge confirmation triggers existing crafting system

2. **Secret shops use existing flag system**
   - `CrafterData.required_flags` already supports story gating
   - `NPCData.conditional_cinematics` can gate shop access

3. **Mods extend the existing system**
   - Add new `RareMaterialData` resources for custom materials
   - Add new `CraftingRecipeData` for custom recipes
   - Add new `CrafterData` for custom blacksmiths
   - NO new crafting code needed

**Example: Creating a Mithril Forge (Using Existing System):**

`mods/_base_game/data/crafters/hassan_blacksmith.tres`:
```gdscript
[resource]
crafter_id = "hassan_blacksmith"
crafter_name = "Master Blacksmith"
crafter_type = "blacksmith"
skill_level = 3
service_fee_modifier = 1.0
available_recipes = ["mithril_sword", "mithril_axe", "mithril_spear"]
required_flags = ["reached_hassan"]
```

`mods/_base_game/data/recipes/mithril_sword.tres`:
```gdscript
[resource]
recipe_id = "mithril_sword"
recipe_name = "Mithril Sword"
output_mode = 1  # CHOICE - player picks from options
required_materials = [{"material_id": "mithril", "quantity": 1}]
gold_cost = 1000
output_choices = ["great_sword", "dark_sword", "broad_sword"]
```

**Purist Verdict:** The existing crafting system supports SF-authentic gameplay. For "classic frustrating Mithril RNG", add `OutputMode.RANDOM` as an enhancement - but the base system is already more player-friendly than SF2 while still supporting meaningful choice.

---

## 6. Recommendations for The Sparkling Farce

### 6.1 Core Architecture (Integrated with Existing Systems)

**ShopData Resource** (`core/resources/shop_data.gd`) - NEW:
```gdscript
class_name ShopData
extends Resource

enum ShopType { WEAPON, ITEM, CHURCH, CRAFTER, SPECIAL }

@export var shop_id: String = ""
@export var shop_name: String = ""
@export var shop_type: ShopType = ShopType.ITEM

@export_group("Presentation")
@export var greeting_text: String = "Welcome!"
@export var farewell_text: String = "Come again!"
@export var npc_id: String = ""  # Links to existing NPCData for portrait

@export_group("Inventory")
## Array of {item_id: String, stock: int (-1 = infinite), price_override: int (-1 = use ItemData default)}
@export var inventory: Array[Dictionary] = []
## Item IDs for "Deals" section (discounted items)
@export var deals_inventory: Array[String] = []

@export_group("Economy")
## Applied to ItemData.buy_price (use existing item pricing)
@export var buy_multiplier: float = 1.0
## Applied to ItemData.sell_price (default 50% already in ItemData)
@export var sell_multiplier: float = 1.0
@export var deals_discount: float = 0.75

@export_group("Availability")
@export var required_flags: Array[String] = []  # Uses existing GameState flag system
@export var forbidden_flags: Array[String] = []

@export_group("Features")
@export var can_sell: bool = true
@export var can_store_to_caravan: bool = true   # Uses existing StorageManager
@export var can_sell_from_caravan: bool = true  # Fix SF2 pain point
```

**ShopManager System** (`core/systems/shop_manager.gd`) - NEW:
```gdscript
# Integrates with EXISTING systems - does NOT recreate them
extends Node

signal transaction_completed(transaction: Dictionary)
signal purchase_failed(reason: String)
signal sale_failed(reason: String)
signal shop_opened(shop_data: ShopData)
signal shop_closed()

# Integration points (existing autoloads):
# - SaveData.gold (economy)
# - PartyManager (character inventory)
# - StorageManager (Caravan depot)
# - EquipmentManager (equip validation, class restrictions)
# - ModLoader.registry (item lookup)

func buy_item(shop: ShopData, item_id: String, quantity: int, target: String) -> Dictionary:
    # target: character_uid or "caravan"
    # Uses: SaveData.gold, PartyManager.add_item_to_member() or StorageManager.add_item()
    pass

func sell_item(item_id: String, source: String, quantity: int) -> Dictionary:
    # source: character_uid or "caravan"
    # Uses: SaveData.gold, PartyManager.remove_item_from_member() or StorageManager.remove_item()
    pass

func get_effective_buy_price(shop: ShopData, item_id: String) -> int:
    # Uses: ModLoader.registry.get_resource("item", item_id).buy_price * shop.buy_multiplier
    pass

func can_character_equip(character_uid: String, item_id: String) -> bool:
    # Uses: EquipmentManager's existing class restriction logic
    pass
```

**ShopUI Component** (`scenes/ui/shop_interface.gd`) - NEW:
- Single reusable UI for all shop types
- Adapts to ShopData.shop_type (shows/hides options)
- Stat comparisons via existing `EquipmentManager.get_equipped_weapon()` etc.
- "Can equip" indicators via existing class restriction checks
- Supports bulk buying for consumables

**Church Services** - Uses EXISTING `EquipmentManager`:
```gdscript
# Uncursing already implemented:
EquipmentManager.attempt_uncurse(character_save_data, slot, "church")

# Healing/Revival: Use existing AbilityData effects or create simple service functions
```

**Crafter Shop** - Uses EXISTING crafting system:
```gdscript
# Already have:
# - CrafterData: Blacksmith NPCs with skill levels, fees
# - CraftingRecipeData: Recipes with OutputMode.SINGLE, CHOICE, UPGRADE
# - RareMaterialData: Mithril-style materials

# Shop UI just wraps these existing resources
```

### 6.2 UX Improvements Over SF2

| SF2 Pain Point | Sparkling Farce Solution | Feels Like SF? |
|----------------|-------------------------|----------------|
| One-at-a-time consumables | Quantity selector for stackable items | ✅ Yes (faster, not different) |
| No stat comparison | Hover shows comparison to party's gear | ✅ Yes (info, not automation) |
| Can't sell from Caravan | "Sell from Caravan" option in sell menu | ✅ Yes (fixes inconsistency) |
| No confirmation tiers | "Are you sure?" for items >1000G | ✅ Yes (safety net) |
| Equipped item selling | "This is equipped, sell anyway?" warning | ✅ Yes (informed choice) |
| Nested exit menus | Single "Exit Shop" button always visible | ✅ Yes (less tedium) |
| No search in long lists | Filter/search bar for 10+ item shops | ✅ Yes (QoL for late game) |

### 6.3 Sacred Elements to Preserve

**MUST HAVE (Non-negotiable for SF feel):**
- ✅ Physical shop NPCs on maps (not global menu)
- ✅ "Who equips this?" immediate assignment flow
- ✅ Caravan storage accessible from shops
- ✅ Limited character inventory slots (configurable per mod)
- ✅ Shops have limited, curated inventory (not "every item in game")
- ✅ Greeting/farewell flavor text from NPC

**SHOULD HAVE (Strongly recommended):**
- ✅ Sell price = 50% buy price (default, mods can change)
- ✅ Gold scarcity balanced for meaningful choices
- ✅ Town-specific shop inventories (travel matters)
- ✅ "Deals" system for discounted items

**NICE TO HAVE (Mod-friendly features):**
- ✅ Support for crafting/RNG shops (Mithril-style)
- ✅ Secret shop mechanics via flag gating
- ✅ Custom shop types beyond weapon/item/church

### 6.4 Moddability Hooks (Following Existing Patterns)

**Pattern Reference**: See `EquipmentManager.custom_equip_validation` for the established hook pattern.

**ShopData Resource** (placed in `mods/*/data/shops/`):
```gdscript
# Mods create .tres files, auto-discovered by ModLoader
[resource]
shop_id = "custom_shop"
shop_type = 4  # ShopType.SPECIAL
shop_name = "Mysterious Merchant"
inventory = [
    {"item_id": "healing_seed", "stock": -1, "price_override": -1},
    {"item_id": "rare_ring", "stock": 1, "price_override": 5000}
]
required_flags = ["quest_complete"]
buy_multiplier = 0.9  # 10% discount
```

**Custom Transaction Hooks** (signal-based, matches existing patterns):
```gdscript
# In ShopManager:
signal custom_transaction_validation(shop: ShopData, item_id: String, quantity: int, result: Dictionary)

# Mods connect to this signal to add custom validation:
func _ready() -> void:
    ShopManager.custom_transaction_validation.connect(_on_transaction_validate)

func _on_transaction_validate(shop: ShopData, item_id: String, quantity: int, result: Dictionary) -> void:
    # Mods can set result["allowed"] = false and result["reason"] = "Custom message"
    if item_id == "max_only_sword" and PartyManager.get_selected_character().character_id != "max":
        result["allowed"] = false
        result["reason"] = "Only Max can purchase this weapon."
```

**What Mods Can Already Do (via existing systems):**
- **Story-gated items**: Use `ShopData.required_flags` (existing flag system)
- **Custom pricing**: Use `ShopData.buy_multiplier` or per-item `price_override`
- **Stock limits**: Use `stock: int` in inventory entries
- **Special materials**: Use existing `RareMaterialData` + `CraftingRecipeData`
- **Character restrictions**: Use existing class restriction system via `EquipmentManager`

**What Would Require Custom Scripts:**
- Barter systems (trade items instead of gold)
- Reputation-based dynamic pricing
- Time-based sales (if time system is implemented)
- Auction/bidding mechanics

---

## 7. Implementation Phases (Revised - Integration Focus)

### Phase 1: Core Data & Manager (Integration Layer)
1. Create `ShopData` resource in `core/resources/`
2. Add `"shop"` to `ModLoader.RESOURCE_TYPE_DIRS` for auto-discovery
3. Create `ShopManager` autoload that integrates with:
   - `SaveData.gold` for currency
   - `PartyManager` for character inventory
   - `StorageManager` for Caravan depot
   - `EquipmentManager` for equip validation
4. Unit tests for transaction logic (buy/sell/validation)

### Phase 2: Basic UI
1. Create `ShopInterface` scene (three-column layout per Clauderina's design)
2. Implement item list with existing `ItemData` display
3. Add buy/sell confirmation dialogs
4. Integrate "who equips" character selection (reuse character selection UI if exists)
5. Connect to ShopManager signals

### Phase 3: SF2-Authentic QoL Features
1. "Store in Caravan" option (wire to existing `StorageManager.add_item()`)
2. "Sell from Caravan" option (wire to existing `StorageManager.remove_item()`)
3. Stat comparison panel (query existing `EquipmentManager`)
4. "Can equip" indicators (use existing class restriction logic)
5. Quantity selection for consumables (bulk buy)
6. NPC greeting/farewell integration
7. **"Quick Equip" preview** - Try gear before purchase (Captain approved)
8. **"Equip Best" button** - Auto-optimize equipment (Captain approved)

### Phase 4: Polish & Edge Cases
1. Equipped item sell warnings
2. High-value item confirmations (>1000G)
3. Search/filter for shops with 10+ items
4. Keyboard/controller navigation
5. Sound effects: `coin_spend.ogg`, `coin_earn.ogg`, `error.ogg`
6. **Deals indicator on merchant NPCs** - Visual cue when shop has active deals (Captain approved)

### Phase 5: Special Shop Types (Wrappers Around Existing Systems)
1. **Deals system**: Discount multiplier on select items
2. **Church UI**: Wraps existing `EquipmentManager.attempt_uncurse()`
   - Add healing/revival as service functions or consumable effects
3. **Crafter UI**: Wraps existing `CrafterData`/`CraftingRecipeData`
   - NO new crafting logic - just UI for existing system
   - Recipe selection, material display, forge confirmation

### Phase 6: Mod Extensibility
1. `ShopManager.custom_transaction_hook` signal (matches EquipmentManager pattern)
2. Shop type registry for mod-defined shop types
3. UI theme overrides
4. Shop editor plugin for Sparkling Editor
5. Documentation for modders

### What We're NOT Building (Already Exists)
- ❌ New currency/gold system (use `SaveData.gold`)
- ❌ New inventory system (use `PartyManager`/`CharacterSaveData`)
- ❌ New storage system (use `StorageManager`)
- ❌ New crafting system (use `CrafterData`/`CraftingRecipeData`)
- ❌ New item pricing fields (use `ItemData.buy_price`/`sell_price`)
- ❌ New curse/uncurse logic (use `EquipmentManager`)

---

## 8. Design Decisions (Captain's Rulings)

### Answered by Infrastructure Analysis:

1. ~~**Inventory scarcity model**~~: ANSWERED - We use `InventoryConfig.slots_per_character` (default 4), configurable per-mod. Equipment is separate from inventory.

2. ~~**Caravan capacity**~~: ANSWERED - `StorageManager` currently has unlimited capacity (SF2-authentic). Configurable limit could be added to `InventoryConfig` if needed.

3. ~~**Mithril RNG**~~: ANSWERED - Existing `CraftingRecipeData` uses deterministic `OutputMode.CHOICE` (player picks). SF2-style RNG would require adding `OutputMode.RANDOM` with weights.

### Captain's Decisions (2025-12-07):

1. **Auto-equip option**: ✅ **YES** - Add "Equip Best" button. QoL feature that many will love; others can ignore it. Not SF-authentic but player-friendly.

2. **Shop stock depletion**: ✅ **NO (for now)** - Keep infinite stock for simplicity. No SF canon for limiting. Wait for modder feedback before adding complexity. The `stock: int` field remains available for mods that want scarcity.

3. **Deals discovery**: ✅ **YES** - Add visual indicator on merchant NPCs who have active deals. Captain's reasoning: "I'd get excited seeing it and think 'Oohh! Let's see what he's got!' as opposed to annoyed by having to manually check every time."

4. **Quick-equip in shop**: ✅ **YES** - Allow "try before you buy" preview. Great QoL addition that shows stat changes before committing gold.

---

## 9. Purist's Final Verdict

**What The Sparkling Farce MUST Capture:**
- The feeling of scarcity and meaningful choice
- Physical shops as part of town exploration
- The "who equips this?" ritual that makes gear personal
- Caravan as the party's shared resource hub

**What Can Be Modernized:**
- Bulk buying for consumables (PLEASE)
- Stat comparison info (showing data ≠ removing choice)
- Sell-from-Caravan option (fixes an inconsistency)
- Faster navigation, fewer nested menus

**The Sacred Cow Test:**
> "If I boot up The Sparkling Farce, walk into a weapon shop, and buy a Bronze Sword, will it FEEL like I'm playing Shining Force?"

**Answer:** YES, if:
- I walked up to a visible NPC shopkeeper on the map
- I saw a clean item list with "BRONZE SWORD  200G  AT 5"
- I confirmed purchase and got "Who should equip it?" with character faces
- I could choose "Store in Caravan" as an option
- The menu was snappier than SF2 but not so modern it feels like Skyrim

**Answer:** NO, if:
- Shops are a global "fast travel shopping menu"
- Items auto-equip without asking me
- The UI has smooth gradients, hover tooltips everywhere, and looks like a 2024 AAA game
- I can buy unlimited items with no gold or inventory constraints

---

## 10. Next Steps (Revised)

1. **Captain reviews this document** and answers remaining questions (Section 8)
2. **Create ShopData resource** in `core/resources/shop_data.gd`
3. **Register shop type** in `ModLoader.RESOURCE_TYPE_DIRS`
4. **Create ShopManager autoload** integrating with existing managers:
   - `SaveData.gold`
   - `PartyManager`
   - `StorageManager`
   - `EquipmentManager`
5. **Create shop UI** following Clauderina's three-column design
6. **Wire Caravan integration** (already exists, just connect to UI)
7. **Add crafter shop UI** wrapping existing `CrafterData`/`CraftingRecipeData`
8. **Add church UI** wrapping existing `EquipmentManager.attempt_uncurse()`
9. **Manual testing** via SNS sessions
10. **Documentation** for modders

### Files To Create (New)
```
core/resources/shop_data.gd
core/systems/shop_manager.gd
scenes/ui/shops/shop_interface.tscn
scenes/ui/shops/shop_interface.gd
scenes/ui/shops/components/shop_item_button.tscn
scenes/ui/shops/components/stat_comparison_panel.tscn
```

### Files To Modify (Existing)
```
core/mod_system/mod_loader.gd  # Add "shop" to RESOURCE_TYPE_DIRS
project.godot                   # Add ShopManager autoload
```

### Files NOT Needed (Already Exist)
```
❌ Currency/gold system (SaveData.gold)
❌ Inventory management (PartyManager, CharacterSaveData)
❌ Storage system (StorageManager)
❌ Crafting system (CrafterData, CraftingRecipeData, RareMaterialData)
❌ Equipment logic (EquipmentManager)
❌ Item pricing (ItemData.buy_price, sell_price)
```

---

*"Keep the scarcity, kill the tedium, and for the love of Mitula LET ME BUY MORE THAN ONE HEALING SEED AT A TIME."*
— Mr. Nerdlinger, SF2 Purist

*"Right then, before you run a new plasma conduit, check if there's already one in the Jefferies tube."*
— Chief O'Brien, on infrastructure reuse

---

**End of Document**
