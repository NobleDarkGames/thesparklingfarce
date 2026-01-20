# Tutorial 3: Items and Equipment

> **Prerequisite:** Complete [Tutorial 2: Your First Character](02-your-first-character.md) first.

This tutorial covers creating weapons, accessories, and consumable items. The Sparkling Farce uses an SF2-authentic equipment system: characters equip one weapon plus rings/accessories. There is no traditional armor.

## Item Types Overview

| Type | Purpose | Equippable |
|------|---------|------------|
| Weapon | Attack power, range, hit/crit rates | Yes (weapon slot) |
| Accessory | Stat bonuses from rings and trinkets | Yes (ring_1, ring_2, accessory slots) |
| Consumable | One-use items that trigger abilities | No |
| Key Item | Quest objects, not usable or equippable | No |

## Creating a Weapon

### Open the Item Editor

1. In the Sparkling Editor, click **Content** in the category bar
2. Click the **Items** tab

### Create a New Item

1. Click the **New** button above the item list
2. A new item named "New Item" appears

### Basic Information

- **Item Name**: Display name (e.g., "Steel Sword")
- **Icon**: Browse to select a 32x32 pixel image
- **Item Type**: Select **Weapon**
- **Equipment Type**: Category for class restrictions. Standard types:
  - sword, axe, spear, bow, staff, knife

- **Equipment Slot**: Leave as **Weapon** (the default)
- **Description**: Flavor text shown when examining the item

### Weapon Properties

This section appears only for Weapon-type items.

| Field | Purpose | Typical Values |
|-------|---------|----------------|
| Attack Power | Base damage added to attacks | 5-15 early, 20-40 mid, 50+ late game |
| Min Attack Range | Closest distance weapon can hit | 1 for melee, 2+ creates a dead zone |
| Max Attack Range | Farthest distance weapon can hit | 1 for melee, 2-3 for bows |
| Hit Rate | Accuracy percentage | 90% standard, 70% for heavy weapons |
| Critical Rate | Double damage chance | 5% normal, 15%+ for killer weapons |

**Range Examples:**
- Sword: Min 1, Max 1 (melee only)
- Spear: Min 1, Max 2 (can poke diagonally)
- Bow: Min 2, Max 3 (cannot hit adjacent - the dead zone)

### Stat Modifiers

Weapons can grant bonus stats when equipped. All modifiers default to 0.

- **Strength**: Common for weapons (+1 to +5 typical)
- **Agility**: Some light weapons grant speed
- **Defense**: Rare; usually negative for glass cannon weapons

### Economy

- **Buy Price**: Cost in shops. Set to 0 for unbuyable items.
- **Sell Price**: Gold when sold. Typically 50% of buy price.

### Save

Click **Save**. The weapon is ready to equip on characters whose class allows that weapon type.

---

## Creating an Accessory

Accessories provide stat bonuses and occupy ring or accessory slots. SF2 used rings extensively.

### Setup

1. Create a new item
2. Set **Item Type** to **Accessory**
3. Set **Equipment Type** to `ring` (or `accessory` for non-ring trinkets)
4. Set **Equipment Slot** to **Ring 1**, **Ring 2**, or **Accessory**

Ring-type accessories can equip in either ring slot. The Equipment Slot field sets the default.

### Stat Modifiers

Accessories shine through stat bonuses:

| Accessory Concept | Suggested Modifiers |
|-------------------|---------------------|
| Power Ring | +3 Strength |
| Speed Ring | +3 Agility |
| Protect Ring | +3 Defense |
| Mage Ring | +3 Intelligence, +5 MP |
| Life Ring | +10 HP |

### Cursed Items

The Curse Properties section appears for weapons and accessories.

- **Is Cursed**: Check to prevent unequipping through normal means
- **Uncurse Items**: Comma-separated item IDs that can remove the curse

Cursed items are typically powerful but lock the equipment slot. Leave **Uncurse Items** empty if only church services can remove the curse.

---

## Creating a Consumable

Consumables trigger abilities when used. A Healing Herb uses a heal ability; an Attack Seed might grant a buff.

### Prerequisites

Create the ability first. See [Tutorial 4: Abilities and Magic](04-abilities-and-magic.md) for details. For now, you can use any existing ability.

### Setup

1. Create a new item
2. Set **Item Type** to **Consumable**
3. Configure usage context:
   - **Usable in Battle**: Can use during combat turns
   - **Usable on Field**: Can use from the menu outside battle

### Effect

The **Effect** picker shows all abilities from loaded mods. Select the ability that triggers when the item is used.

Example consumables:

| Item | Effect Ability | Battle | Field |
|------|----------------|--------|-------|
| Healing Herb | Heal (single ally) | Yes | Yes |
| Antidote | Cure Poison | Yes | Yes |
| Angel Wing | Egress (flee battle) | Yes | No |
| Power Potion | Strength buff | Yes | No |

### Crafting Materials

Check **Is Crafting Material** for items that combine at crafter NPCs (mithril, dragon scales). These items appear in crafting menus but cannot be used directly.

---

## Equipment and Classes

Characters can only equip weapons their class allows. When you created a class in Tutorial 2, you set **Equippable Weapon Types**.

### Verifying Compatibility

If a character cannot equip your weapon:

1. Open the **Classes** tab
2. Select the character's class
3. Check **Equippable Weapon Types** includes your weapon's **Equipment Type**

A Warrior class with `["sword", "axe"]` can equip swords and axes but not bows or staves.

### Adding New Weapon Types

The platform includes these weapon types by default: sword, axe, spear, bow, staff, knife.

To add custom types (e.g., "tome", "gun"), add them to a class's equippable types. The system registers new types automatically when first used.

---

## Giving Items to Characters

Characters can start with equipment:

1. Open the **Characters** tab
2. Select your character
3. Expand the **Starting Equipment** section
4. Each equipment slot (Weapon, Ring 1, Ring 2, Accessory) has a dropdown picker
5. Select items from the filtered dropdowns - only compatible items appear

The pickers automatically filter by slot compatibility. The weapon slot shows only weapons; ring slots show only ring-type accessories.

Starting equipment appears in the character's inventory when they join the party.

---

## What You Built

You now have:
- A **Weapon** with attack stats and range
- An **Accessory** with stat bonuses
- Optionally, a **Consumable** linked to an ability

These items integrate with the class system - only compatible classes can equip your weapons.

Continue to [Tutorial 4: Abilities and Magic](04-abilities-and-magic.md) to create the spells and skills that power your characters and consumables.
