# Tutorial 2: Your First Class and Character

> **Prerequisite:** Complete [Tutorial 1: Creating Your First Mod](01-creating-your-first-mod.md) first.

This tutorial walks you through creating a playable character. Characters require a **Class** to define their stat growth, abilities, and equipment options, so we create the Class first.

## Part 1: Creating a Class

### Open the Class Editor

1. In the Sparkling Editor, click **Content** in the category bar
2. Click the **Classes** tab

### Create a New Class

1. Click the **New** button above the class list
2. A new class named "New Class" appears

### Basic Information

- **Class Name**: Display name (e.g., "Warrior", "Mage")

### Movement

- **Movement Type**: How terrain affects this class

| Type | Move Cost | Defense Bonus | Terrain Effects |
|------|-----------|---------------|-----------------|
| Walking | Pays terrain costs | Yes | Affected (damage/heal) |
| Flying | Always 1 MP | No | Immune (above terrain) |
| Floating | Always 1 MP | Yes | Affected |
| Custom | Mod-defined | Mod-defined | Mod-defined |

Flying units sacrifice terrain defense and terrain effects (healing tiles, damage tiles) for consistent mobility. Floating is the best movement type - used by mages and healers in SF2.

- **Movement Range**: Tiles per turn (typical: 4-5 infantry, 6-7 cavalry)

### Equipment Restrictions

Check which weapon types this class can equip. A Warrior might use swords and axes; a Mage might use staves and tomes.

### Growth Rates

Growth rates determine how stats increase when leveling up. The system uses percentages from 0-200:

| Range | Effect |
|-------|--------|
| 0-99 | Percentage chance of +1 (e.g., 50 = 50% chance) |
| 100+ | Guaranteed +1, with remainder% chance of +2 (e.g., 150 = always +1, 50% for +2) |

Typical values:
- HP: 80-150 (higher for tanks)
- MP: 0-30 for melee, 60-80 for casters
- Combat stats: 40-100 depending on class role

### Save

Click **Save**. The class is now available for characters to use.

Skip the Promotion and Learnable Abilities sections for now. These are covered in later tutorials.

---

## Part 2: Creating a Character

### Open the Character Editor

1. Click the **Characters** tab (still under Content)

### Create a New Character

1. Click the **New** button above the character list
2. A new character named "New Character" appears

### Basic Information

- **Name**: Display name shown in menus and dialogue
- **Class**: Select the class you just created
- **Starting Level**: Level when this character joins (default: 1)
- **Biography**: Optional background story for status screens

The **Character UID** is auto-generated. Use this when referencing the character in cinematics or dialogue.

### Battle Configuration

- **Unit Category**: Determines behavior
  - Player: Controllable party member
  - Enemy: Hostile AI opponent
  - Neutral: Non-combatant NPC
- **Is Unique**: ON for named characters, OFF for generic templates (e.g., "Goblin")
- **Is Hero**: The main protagonist. If this character falls, battle is lost.
- **Starting Party**: Include in the party at game start
- **Unit Tags**: Type tags for weapon bonus targeting (e.g., "undead", "beast", "armored"). Weapons with matching `unit_tag_bonuses` deal extra damage to this character. Leave empty for generic units.

### Base Stats

Set starting statistics. These combine with class growth rates as the character levels up.

| Stat | Purpose |
|------|---------|
| HP | Damage before falling |
| MP | Resource for spells |
| Strength | Physical attack power |
| Defense | Physical damage reduction |
| Agility | Turn order and evasion |
| Intelligence | Magic power |
| Luck | Critical hits and rare drops |

Typical starting values for a balanced fighter: HP 20, MP 5, STR 6, DEF 5, AGI 5, INT 4, LUK 5.

### Appearance

Expand the **Appearance** section:

- **Portrait**: Image for menus and dialogue. Any size works; square images display best.
- **Map Spritesheet**: A 64x128 pixel image with this layout:

```
+-------+-------+
| down1 | down2 |  Row 0: Walking down
+-------+-------+
| left1 | left2 |  Row 1: Walking left
+-------+-------+
|right1 |right2 |  Row 2: Walking right
+-------+-------+
| up1   | up2   |  Row 3: Walking up
+-------+-------+
```

Each frame is 32x32 pixels. The editor validates your spritesheet and shows an animated preview.

### Save

Click **Save**. The editor validates your character. Player characters require a class to be assigned.

---

## What You Built

You now have:
- A **Class** that defines stat growth and equipment options
- A **Character** that uses that class

The character is ready for battle. To give them abilities, you'll need to add learnable abilities to the class or create unique abilities for the character.

Continue to [Tutorial 3: Items and Equipment](03-items-and-equipment.md) to gear up your character.
