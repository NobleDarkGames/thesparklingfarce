# User Content Directory

Welcome to The Sparkling Farce content creation system! This directory is where you can add your own custom content and extensions to the game.

## Overview

The Sparkling Farce is designed as an extensible platform for creating tactical RPG content. You can create new characters, classes, items, abilities, and battles without writing any code.

## Getting Started

### 1. Enable the Sparkling Editor Plugin

1. Open the project in Godot
2. Go to `Project` → `Project Settings` → `Plugins`
3. Enable "Sparkling Editor"
4. You should see a new "Sparkling Editor" panel at the bottom of the editor

### 2. Creating Content

#### Quick Creation (Tools Menu)

Use the `Project` → `Tools` menu to quickly create new content:
- **Create New Character** - Creates a blank CharacterData resource
- **Create New Class** - Creates a blank ClassData resource
- **Create New Item** - Creates a blank ItemData resource
- **Create New Ability** - Creates a blank AbilityData resource

#### Using the Editor Panel

The Sparkling Editor panel provides tabbed interfaces for browsing and editing content:

**Characters Tab:**
- View all characters in `data/characters/`
- Edit character stats, growth rates, and equipment
- Assign classes to characters

**Classes Tab:**
- View all classes in `data/classes/`
- Define movement type and range
- Set equipment restrictions
- Configure class promotions

**Items Tab:**
- View all items in `data/items/`
- Create weapons with attack power and range
- Create armor with stat modifiers
- Create consumable items with effects

### 3. Using Templates

The `templates/` folder contains example resources you can use as starting points:

**Classes:**
- `warrior_class_template.tres` - Melee fighter with high defense
- `mage_class_template.tres` - Magic user with spell casting
- `archer_class_template.tres` - Ranged attacker

**Items:**
- `sword_item_template.tres` - Basic melee weapon
- (More coming in future phases)

**Abilities:**
- `healing_ability_template.tres` - Single-target healing spell
- `attack_ability_template.tres` - Powerful melee attack

**How to use templates:**
1. Navigate to the `templates/` folder in Godot's FileSystem
2. Right-click a template file
3. Select "Duplicate"
4. Move the duplicated file to the appropriate `data/` subfolder
5. Edit the resource in the Inspector or Editor panel

## Content Types

### CharacterData

Characters represent units that can be deployed in battle (both player units and enemies).

**Required Fields:**
- `character_name`: Display name
- `character_class`: The class this character belongs to (must create a ClassData first)

**Stats:**
- Base stats: HP, MP, Strength, Defense, Agility, Intelligence, Luck
- Growth rates: % chance to increase each stat on level up

**Appearance:**
- `portrait`: Character portrait image (for dialogue/menus)
- `battle_sprite`: Sprite used in battle scenes

**Configuration:**
- `starting_level`: Initial level
- `starting_equipment`: Array of ItemData for default equipment

### ClassData

Classes define what a character can do and how they move.

**Required Fields:**
- `class_name`: Display name

**Movement:**
- `movement_type`: Walking (ground), Flying (ignores obstacles), or Floating
- `movement_range`: How many tiles the unit can move per turn

**Equipment:**
- `equippable_weapon_types`: Array of weapon type strings (e.g., ["sword", "axe"])
- `equippable_armor_types`: Array of armor type strings (e.g., ["light", "heavy"])

**Abilities:**
- `learnable_abilities`: Dictionary mapping level → AbilityData

**Promotion:**
- `promotion_class`: The advanced class this promotes to
- `promotion_level`: Level required to promote

### ItemData

Items can be weapons, armor, consumables, or key items.

**Required Fields:**
- `item_name`: Display name
- `item_type`: Weapon, Armor, Consumable, or Key Item

**For Weapons:**
- `equipment_type`: "sword", "axe", "bow", etc.
- `attack_power`: Base damage
- `attack_range`: 1 for melee, higher for ranged
- `hit_rate`: % chance to hit
- `critical_rate`: % chance for critical hit

**For Armor:**
- `equipment_type`: "light", "heavy", "robe", etc.
- Stat modifiers: Bonuses to HP, Defense, etc.

**For Consumables:**
- `usable_in_battle`: Can be used during combat
- `usable_on_field`: Can be used outside combat
- `effect`: AbilityData that defines what the item does

**Economy:**
- `buy_price`: Cost to purchase
- `sell_price`: Value when sold

### AbilityData

Abilities are skills, spells, or special attacks used in battle.

**Required Fields:**
- `ability_name`: Display name
- `ability_type`: Attack, Heal, Support, Debuff, or Special

**Targeting:**
- `target_type`: Who can be targeted (Single Enemy, Single Ally, Area, etc.)
- `min_range` / `max_range`: Distance requirements
- `area_of_effect`: Radius for splash effects (0 = single target)

**Cost:**
- `mp_cost`: Mana cost
- `hp_cost`: Health cost (for special abilities)

**Power:**
- `power`: Base effectiveness (damage or healing)
- `accuracy`: % chance to succeed

**Status Effects:**
- `status_effects`: Array of effect names (e.g., ["poison", "attack_up"])
- `effect_duration`: How many turns effects last
- `effect_chance`: % chance to apply effects

## File Organization

```
sparklingfarce/
├── data/                    # Your created content goes here
│   ├── characters/         # CharacterData resources (.tres files)
│   ├── classes/           # ClassData resources
│   ├── items/             # ItemData resources
│   ├── abilities/         # AbilityData resources
│   ├── battles/           # BattleData resources (Phase 2+)
│   └── dialogues/         # DialogueData resources (Phase 2+)
├── templates/              # Example resources to duplicate
├── user_content/           # This directory - for documentation and mods
└── assets/                 # Images, sounds, music
    ├── sprites/           # Character and unit sprites
    ├── portraits/         # Character portraits
    ├── icons/             # Item/ability icons
    ├── music/             # Background music
    └── sfx/               # Sound effects
```

## Best Practices

### Naming Conventions

- **Files**: Use snake_case (e.g., `iron_sword.tres`, `fire_mage_class.tres`)
- **Resource names**: Use Title Case (e.g., "Iron Sword", "Fire Mage")
- **Equipment types**: Use lowercase (e.g., "sword", "light armor")

### Stat Balance Guidelines

**Character Base Stats (Level 1):**
- HP: 10-20
- MP: 0-10
- Other stats: 3-8

**Growth Rates:**
- Average: 40-60%
- Low: 10-30%
- High: 70-90%

**Weapons:**
- Weak: 5-10 power
- Average: 10-20 power
- Strong: 20-30+ power

**Items (Economy):**
- Early game: 50-500 gold
- Mid game: 500-2000 gold
- Late game: 2000+ gold
- Sell price typically 50% of buy price

### Class Design Tips

1. **Start with archetypes**: Warrior, Mage, Archer, Cleric, Knight
2. **Balance movement**: Lower movement for heavy armor, higher for light
3. **Restrict equipment thoughtfully**: Each class should have 2-4 weapon types
4. **Plan promotions**: Base class at level 1, promotes around level 10

### Character Creation Workflow

1. Create Classes first (characters require a class)
2. Create Abilities that the classes can learn
3. Create Items (weapons/armor) for the classes
4. Create Characters and assign them classes
5. Equip characters with appropriate starting items

## Advanced: Custom Scripts

For advanced users who want to extend functionality with code:

1. Create a new folder: `user_content/scripts/`
2. Add custom GDScript files
3. Reference them in your resources (e.g., custom victory conditions for battles)

**Note**: This requires programming knowledge. Most content can be created without code!

## Troubleshooting

### "Character validation failed"
- Make sure you've assigned a valid ClassData to the character
- Ensure character_name is not empty
- Check that starting_level is at least 1

### "Cannot equip item"
- Verify the item's equipment_type matches one in the class's equippable lists
- Check spelling and capitalization

### "Editor panel not showing"
- Ensure the plugin is enabled in Project Settings → Plugins
- Try closing and reopening Godot
- Check the console for error messages

## Getting Help

For more information:
- Check `PHASE_1_PLAN.md` for technical details
- Check `RESEARCH_OUTLINE.md` for design philosophy
- Check the official Godot documentation for Resource usage

## Future Phases

Phase 1 includes Characters, Classes, Items, and Abilities. Future phases will add:
- Battle Editor (Phase 2)
- Dialogue Editor (Phase 2)
- Map/Grid Editor (Phase 2)
- Runtime battle system (Phase 3+)

Stay tuned!
