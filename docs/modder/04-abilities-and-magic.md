# Tutorial 4: Abilities and Magic

> **Prerequisite:** Complete [Tutorial 3: Items and Equipment](03-items-and-equipment.md) first.

This tutorial covers creating abilities (spells and skills) for your characters. Abilities are the core of tactical combat, handling everything from attack magic to healing to status effects.

## What Are Abilities?

Abilities represent any active skill a unit can use in battle:

- **Attack spells** (Blaze, Bolt, Freeze)
- **Healing magic** (Heal, Aura)
- **Buffs and debuffs** (Attack Up, Slow)
- **Status effects** (Sleep, Poison, Muddle)
- **Special skills** (Counter, Summon)

Characters learn abilities through their **class**. A Mage class might grant Blaze at level 1, Blaze 2 at level 8, and Blaze 3 at level 16. Consumable items can also trigger abilities when used.

## Ability Types

The platform supports nine ability types:

| Type | Purpose | Example |
|------|---------|---------|
| Attack | Deals damage | Blaze, Bolt |
| Heal | Restores HP | Heal, Aura |
| Support | Buffs allies | Attack Up, Boost |
| Debuff | Weakens enemies | Slow, Dispel |
| Status | Applies status effects | Sleep, Muddle |
| Summon | Summons units or effects | Phoenix, Dao |
| Counter | Reactive abilities | Counterattack |
| Special | Unique effects | Egress |
| Custom | Mod-defined types | (your creation) |

The type affects AI behavior and UI presentation. An AI healer prioritizes Heal-type abilities on wounded allies; Attack-type abilities target enemies.

## Creating an Ability

### Open the Ability Editor

1. In the Sparkling Editor, click **Content** in the category bar
2. Click the **Abilities** tab

### Create a New Ability

1. Click the **New** button above the ability list
2. A new ability named "New Ability" appears

### Basic Information

- **Ability Name**: Display name shown in battle menus (e.g., "Blaze", "Heal")
- **Ability ID**: Auto-generated from the name. Used in scripts and class ability assignments.
- **Description**: Tooltip text explaining what the ability does

### Type and Targeting

- **Ability Type**: Select from the types above. Affects AI priority and UI grouping.
- **Target Type**: Who can be targeted

| Target Type | Effect |
|-------------|--------|
| Single Enemy | Select one enemy |
| Single Ally | Select one ally |
| Self | Caster only |
| All Enemies | Hits every enemy |
| All Allies | Affects entire party |
| Area | Splash around a point (uses Area of Effect) |

### Range and Area of Effect

- **Min Range**: Closest tile the ability can target
  - 0 = self only
  - 1 = adjacent tiles
  - 2+ = ranged (creates a "dead zone" if min > 1)

- **Max Range**: Farthest tile the ability can target
  - Typical melee: 1-2
  - Typical ranged magic: 3-5

- **Area of Effect**: Radius around the target point
  - 0 = single target
  - 1 = 3x3 area (target + adjacent)
  - 2 = 5x5 area

**Range Examples:**

| Ability | Min | Max | AoE | Effect |
|---------|-----|-----|-----|--------|
| Heal | 0 | 3 | 0 | Heals one ally within 3 tiles |
| Blaze | 1 | 4 | 0 | Damages one enemy 1-4 tiles away |
| Blaze 2 | 1 | 4 | 1 | Damages enemies in 3x3 area |
| Aura | 0 | 0 | 1 | Heals allies in 3x3 around caster |

---

## Cost and Potency

### Cost

- **MP Cost**: Magic points consumed on use. Typical values:
  - 2-5 MP: Basic spells
  - 10-20 MP: Powerful mid-game spells
  - 30+ MP: Ultimate abilities

- **HP Cost**: Health sacrificed to use the ability. Rare; used for dark magic or desperation attacks. Usually 0.

### Potency

- **Potency**: Base effect strength. For damage/healing abilities, this multiplies with caster stats.
  - 10-30: Basic spells
  - 40-60: Mid-tier
  - 80+: Powerful late-game

- **Accuracy**: Base hit chance percentage.
  - 100%: Most spells (always hits)
  - 80-90%: Unreliable debuffs
  - 70%: Risky but powerful effects

---

## Status Effects

Abilities can apply status effects on hit.

### Adding Status Effects

1. In the **Status Effects** section, click **Select Effects...**
2. Check one or more effects from the dropdown
3. Selected effects display next to the button

The dropdown shows all status effects registered by loaded mods. Create custom effects in the **Status Effects** tab under Content.

### Effect Chance

- **Effect Chance**: Probability that the status applies when the ability hits
  - 100%: Guaranteed (e.g., dedicated sleep spell)
  - 30-50%: Unreliable side effect (e.g., attack with chance to poison)

**Example Configurations:**

| Ability | Effects | Chance | Purpose |
|---------|---------|--------|---------|
| Sleep | sleep | 100% | Dedicated sleep spell |
| Poison Strike | poison | 50% | Attack with poison chance |
| Blizzard | freeze | 30% | Damage with freeze side effect |
| Boost | str_up, agi_up | 100% | Multi-buff support spell |

---

## Assigning Abilities to Classes

Characters learn abilities through their class, not individually. This mirrors the Shining Force system where a Mage learns Blaze spells and a Priest learns Heal spells.

### Add Abilities to a Class

1. Open the **Classes** tab
2. Select the class you want to edit
3. Scroll to **Learnable Abilities**
4. Click **Add Ability**
5. Set the **Level** at which the ability unlocks
6. Select the **Ability** from the picker

### Example: Mage Class Setup

| Level | Ability |
|-------|---------|
| 1 | Blaze |
| 8 | Blaze 2 |
| 16 | Blaze 3 |
| 24 | Blaze 4 |

Characters of this class gain access to each spell when they reach the specified level. A level 10 Mage has Blaze and Blaze 2 available.

### Spell Tiers

Shining Force traditionally uses numbered spell tiers (Blaze 1-4, Heal 1-4). Create each tier as a separate ability with increasing potency, range, area, and MP cost.

**Progression Example:**

| Spell | Potency | Range | AoE | MP |
|-------|---------|-------|-----|-----|
| Blaze | 10 | 1-3 | 0 | 2 |
| Blaze 2 | 18 | 1-4 | 1 | 5 |
| Blaze 3 | 28 | 1-5 | 1 | 10 |
| Blaze 4 | 40 | 1-6 | 2 | 20 |

---

## Assigning Abilities to Items

Consumable items trigger abilities when used. The Healing Herb uses a heal ability; a Power Potion might trigger a strength buff.

### Create a Consumable with an Ability Effect

1. Create the ability first (e.g., "Herb Heal" - Heal type, single ally, potency 15)
2. Open the **Items** tab
3. Create or edit a consumable item
4. Set **Item Type** to **Consumable**
5. Check **Usable in Battle** and/or **Usable on Field**
6. In the **Effect** picker, select your ability

When the player uses the item, the linked ability activates. The item is consumed after use.

### Example Consumables

| Item | Effect Ability | Battle | Field |
|------|----------------|--------|-------|
| Healing Herb | Herb Heal (restores 15 HP) | Yes | Yes |
| Medical Herb | Cure Poison (removes poison) | Yes | Yes |
| Power Wine | Boost STR (applies str_up) | Yes | No |
| Angel Wing | Egress (ends battle) | Yes | No |

---

## Animation and Audio (Stub)

The **Animation & Audio** section exists for future spell visual effects:

- **Animation Name**: Key referencing a spell animation (not yet implemented)

These fields are placeholders. The spell animation system is planned for a future phase.

---

## What You Built

You now understand how to:

- Create abilities with damage, healing, range, and area effects
- Configure MP costs and accuracy
- Apply status effects through abilities
- Assign abilities to classes at specific levels
- Link abilities to consumable items

Abilities form the foundation of tactical combat. Combined with classes and items, they give your characters unique identities and playstyles.

The next step is creating battles where your characters and abilities are put to the test. Status effects are covered in the Status Effects tab under Content - create custom buffs, debuffs, and conditions to expand your ability options.
