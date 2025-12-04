# Mod Template for The Sparkling Farce

Welcome, modder! This template provides a starting point for creating your own mod.

## Quick Start

1. **Copy this folder** to create your own mod:
   ```
   mods/_template/  -->  mods/my_awesome_mod/
   ```

2. **Edit `mod.json`** to configure your mod:
   - Change `id` to a unique identifier (lowercase, underscores OK)
   - Change `name` to your mod's display name
   - Update `author`, `description`, and `version`
   - Set `load_priority` (500 is a good default for content mods)

3. **Create your content** using the example resources as templates:
   - Classes in `data/classes/`
   - Characters in `data/characters/`
   - Items in `data/items/`
   - Abilities in `data/abilities/`
   - Battles in `data/battles/`
   - Terrain in `data/terrain/`

4. **Use the Sparkling Editor** (in Godot) to create and edit resources visually.

## Directory Structure

```
my_mod/
  mod.json              # Required: Mod configuration
  README.md             # Optional: Your mod's documentation

  data/                 # Game content (auto-discovered)
    characters/         # CharacterData .tres files
    classes/            # ClassData .tres files
    items/              # ItemData .tres files
    abilities/          # AbilityData .tres files
    battles/            # BattleData .tres files
    parties/            # PartyData .tres files
    terrain/            # TerrainData .tres files
    dialogues/          # DialogueData .tres files
    cinematics/         # CinematicData .json files
    campaigns/          # CampaignData .json files
    maps/               # MapMetadata .json files

  assets/               # Art and audio
    sprites/            # Battle sprites (16x16 or 32x32)
    portraits/          # Character portraits (64x64 or 96x96)
    icons/              # Item/ability icons

  scenes/               # Custom scenes (UI, maps, etc.)
  triggers/             # Custom trigger scripts (*_trigger.gd)
  tilesets/             # TileSet .tres files
```

## Load Priority Guide

| Priority Range | Use Case |
|----------------|----------|
| 0-99 | Official content only (don't use) |
| 100-499 | Add-on content that others might override |
| 500 | Default for most mods |
| 501-8999 | Content that should override lower mods |
| 9000-9999 | Total conversions (complete game replacements) |

## Creating Content

### Classes
Classes define character roles (Warrior, Mage, Healer, etc.):
- Set movement range and type (walking, floating, flying)
- Define stat growth rates (0-100%)
- List equippable weapon and armor types
- Configure promotion paths (optional)

See: `data/classes/example_warrior.tres`

### Characters
Characters are the actual units in your game:
- Assign a class (required!)
- Set base stats for level 1
- Configure as hero, party member, enemy, or NPC
- Add portrait and battle sprite (optional)

See: `data/characters/example_knight.tres`

### Items
Items can be equipment or consumables:
- Weapons: Add attack power, set weapon type
- Armor: Add defense, set armor type
- Consumables: Reference an ability for the effect
- Key Items: Quest items with no direct use

See: `data/items/example_sword.tres`

### Abilities
Abilities are spells and skills:
- Set type (attack, heal, support, debuff)
- Configure targeting (single, area, all)
- Define range, cost, and power
- Add status effects (optional)

See: `data/abilities/example_heal.tres`

### Terrain
Terrain affects movement and combat:
- Set movement costs per movement type
- Add defense and evasion bonuses
- Configure damage/healing per turn
- Mark impassable terrain

See: `data/terrain/example_forest.tres`

### Battles
Battles are complete combat scenarios:
- Reference a map scene
- Place enemies with positions and AI
- Set victory/defeat conditions
- Add dialogue and rewards

See: `data/battles/example_battle.tres`

## Overriding Base Game Content

To replace a base game resource:
1. Create a file with the **exact same filename** in your mod
2. Set your mod's `load_priority` higher than the base game (0)
3. The game will use your version instead

Example: To override the hero character:
- Base game has: `mods/_base_game/data/characters/max.tres`
- Your mod creates: `mods/my_mod/data/characters/max.tres`
- With priority 500, your version is used

## Custom Types

Extend the game's type systems in `mod.json`:

```json
{
  "custom_weapon_types": ["laser", "plasma"],
  "custom_armor_types": ["force_field"],
  "custom_trigger_types": ["puzzle"]
}
```

Then use these types in your equipment and trigger configurations.

## Tips for Modders

1. **Start small**: Create one character and one battle first
2. **Use the editor**: The Sparkling Editor makes content creation much easier
3. **Test often**: Run the game to verify your content works
4. **Check the console**: Error messages appear in Godot's Output panel
5. **Reference examples**: Look at `_base_game` for working examples

## Getting Help

- Check the example resources in this template
- Look at the `_base_game` mod for reference
- Review the platform specification: `docs/specs/platform-specification.md`
- The `.tres` files include inline comments explaining each field

Happy modding!
