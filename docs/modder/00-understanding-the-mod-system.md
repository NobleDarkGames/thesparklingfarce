# Tutorial 0: Understanding the Mod System

Before creating content, it helps to understand how mods work in The Sparkling Farce. This page explains the concepts; the next tutorial covers hands-on creation.

## What Is a Mod?

A mod is a folder inside `mods/` containing:

- **mod.json** - A manifest file declaring the mod's identity and settings
- **data/** - Subfolders of game resources (characters, items, abilities, etc.)
- **assets/** - Images, sprites, portraits, and other media

That's it. The platform discovers mods automatically by scanning for `mod.json` files.

## How Mods Load

When the game starts:

1. ModLoader scans `mods/` for folders containing `mod.json`
2. Each manifest is parsed and validated
3. Mods are sorted by **load priority** (lowest first)
4. Resources from each mod register with the central registry

Lower-priority mods load first. Higher-priority mods load later and can **override** resources with the same ID.

## Load Priority Tiers

Priority determines load order and override behavior. The valid range is 0-9999.

| Range | Purpose | Example |
|-------|---------|---------|
| 0 | Platform defaults | `_starter_kit` (declares -1, clamped to 0) |
| 1-99 | Reserved for official content | Future base game content |
| 100-8999 | User mods and campaigns | `demo_campaign` uses 100 |
| 9000-9999 | Total conversions | Mods that replace everything |

**Priority Rules:**

- Lower numbers load first, higher numbers load later
- When two mods define the same resource ID, the higher-priority mod wins
- Equal priorities resolve alphabetically by mod ID (with a warning)

Most mods should use priority **100-8999**. Only use 9000+ if building a total conversion that intentionally replaces all base content.

## The _starter_kit Mod

The `_starter_kit` mod (priority 0) provides platform defaults:

- Basic terrain types (grass, forest, water, road, etc.)
- Default AI behaviors for enemies
- Fallback assets for missing content

Your mod doesn't need to define terrain or AI behaviors unless you want to customize them. The starter kit ensures the game always has working defaults.

## Adding vs. Overriding Content

### Adding New Content

Create a resource with a unique ID. The platform registers it alongside existing content.

```
mods/your_mod/data/characters/elena.tres
```

This character becomes available through the registry without affecting other characters.

### Overriding Existing Content

Create a resource with the **same ID** as an existing resource. Your higher-priority version replaces the original.

```
# If demo_campaign has: data/characters/max.tres
# And your mod (priority 200) has: data/characters/max.tres
# Your version wins because 200 > 100
```

This allows patches, balance tweaks, and translations without editing the original mod.

## Resource Types

The platform auto-discovers these resource types from `data/` subfolders:

| Folder | Contains |
|--------|----------|
| characters/ | Playable and enemy units |
| classes/ | Character classes with stats and abilities |
| abilities/ | Spells and skills |
| items/ | Equipment and consumables |
| battles/ | Battle configurations and enemy placement |
| cinematics/ | Story sequences and cutscenes |
| npcs/ | Non-player characters for maps |
| shops/ | Shop inventories and services |
| terrain/ | Battle tile properties |
| status_effects/ | Buffs and debuffs |

Each folder maps to a resource type. Place your `.tres` files in the appropriate folder and they register automatically.

*NOTE* Each mod directory contains `_README.txt` files explaining what goes in each folder. If you're starting from scratch, copy the `_starter_kit` mod as a template.

## Accessing Resources at Runtime

The platform provides a central registry. Modders should (ideally) never need to edit code, but if necessary, you should always use it instead of direct file paths:

```gdscript
# Correct - respects mod overrides
var char = ModLoader.registry.get_resource("character", "max")

# Wrong - bypasses the mod system
var char = load("res://mods/demo_campaign/data/characters/max.tres")
```

Direct `load()` calls break when another mod overrides the resource. The registry always returns the correct (highest-priority) version.

## The mod.json File

A minimal manifest looks like this:

```json
{
    "id": "my_mod",
    "name": "My Awesome Mod",
    "version": "1.0.0",
    "author": "Your Name",
    "description": "A brief description",
    "load_priority": 100
}
```

Required fields:
- **id** - Unique identifier (letters, numbers, underscores, hyphens)
- **name** - Human-readable display name

Optional but recommended:
- **version** - Semantic version string
- **author** - Creator credit
- **description** - What the mod does
- **load_priority** - Where in the load order (default: 0)

The `id` becomes your folder name and how other mods reference yours. If you later change one, you must change both.

## Dependencies (minimally tested as yet)

Mods can declare dependencies on other mods:

```json
{
    "id": "my_expansion",
    "name": "My Expansion Pack",
    "load_priority": 150,
    "dependencies": ["base_campaign"]
}
```

The loader ensures dependencies load first. If a dependency is missing, your mod fails to load with an error message.

## Summary

- Mods are folders with `mod.json` and a `data/` directory
- Lower priority loads first; higher priority can override
- Use priority 100 for normal mods, 9000+ for total conversions
- `_starter_kit` provides defaults you can override or ignore
- Always access resources through `ModLoader.registry`, not direct paths

Ready to create your first mod? Continue to [Tutorial 1: Creating Your First Mod](01-creating-your-first-mod.md).
