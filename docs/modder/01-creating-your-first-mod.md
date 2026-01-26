# Tutorial 1: Creating Your First Mod

> **Prerequisite:** Read [Tutorial 0: Understanding the Mod System](00-understanding-the-mod-system.md) first.

This tutorial walks you through creating a new mod using the Sparkling Editor. No coding required.

## Opening the Sparkling Editor

1. Open Godot with The Sparkling Farce project
2. Look at the bottom of the editor window for the **Sparkling Editor** tab (next to Output, Debugger, etc.)
3. Click the tab to open the editor

## Creating a New Mod

1. Click the **Create New Mod** button in the top-right corner of the Sparkling Editor

2. Fill in the wizard fields:

   - **Mod Name**: Your mod's display name. Example: `My First Mod`
   - **Mod ID**: Auto-fills from your name as a folder-safe version. You can change it if needed. Example: `my_first_mod`
   - **Author**: Your name
   - **Description**: A brief description of what your mod does

3. Choose a **Mod Type**:

   | Type | Use When... |
   |------|-------------|
   | **Content Mod** | Campaigns, patches, expansions - adds or modifies content alongside the base game |
   | **Total Conversion** | Building a completely new game that replaces everything |

   If unsure, pick **Content Mod**. You can change this later.

4. Click **Create Mod**

The editor creates your mod folder with all the directories you need and a `mod.json` configuration file.

## The Editor Interface

After creating your mod, take a moment to look around:

**Mod Selector** (top of editor): Shows your active mod. The dropdown lets you switch between mods. Your new mod should be selected.

**Category Bar** (below mod selector): Four buttons organize the editor tabs:

- **Content**: Characters, Classes, Abilities, Items, Status Effects
- **Battles**: Maps, Terrain, Battles, AI Behaviors
- **Story**: NPCs, Interactables, Cinematics, Campaigns, Shops, Crafters, Recipes
- **System**: Overview, Mod Settings, New Game Configs, Save Slots, Caravans, Experience

**Overview Tab**: Found under System, contains quick-start tips and explains what each tab does.

## What's Next?

Your mod is ready! Here's the recommended order for creating content:

1. **Classes** first (characters need a class)
2. **Abilities** that classes can learn
3. **Characters** assigned to those classes
4. **Items** for equipment and consumables
5. **Battles** using your characters as enemies
6. **Cinematics** for story sequences

Each editor tab has a **New** button to create resources, with **Save** and **Delete** typically in the inspector panels to the right.

Ready to create your first character? Continue to [Tutorial 2: Your First Character](02-your-first-character.md).
