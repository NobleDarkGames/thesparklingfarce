# The Sparkling Farce

**A modding platform for Shining Force-style tactical RPGs**

[![Godot 4.5](https://img.shields.io/badge/Godot-4.5-blue?logo=godot-engine)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)]()

Create your own Shining Force campaigns with visual editors. No ROM hacking. No hex editing. No programming required.

---

## See It In Action

| Demo | Description |
|------|-------------|
| [PLACEHOLDER: Gameplay Demo](URL) | Overworld exploration, town navigation, battle with spells |
| [PLACEHOLDER: Editor Demo](URL) | Create a class, weapon, and character in 5 minutes |

---

## Quick Start

### Option A: Run from Source (Recommended for Modders)

```bash
git clone https://github.com/[PLACEHOLDER]/sparklingfarce.git
cd sparklingfarce
```

1. Open the project in [Godot 4.5](https://godotengine.org/download/)
2. Press **F5** to run

### Option B: Download Release

[PLACEHOLDER: Link to releases page with pre-built binaries]

---

## Your First Mod in 5 Minutes

The Sparkling Editor lets you create content without writing code. Here's how to make a playable character from scratch.

### Step 1: Open the Sparkling Editor

1. Open Godot and load the Sparkling Farce project
2. Look at the **bottom of the editor window** - find the **"Sparkling Editor"** tab (next to Output, Debugger, etc.)
3. Click it to expand the editor interface

### Step 2: Select Your Mod

1. At the top of the Sparkling Editor, find the **"Active Mod"** dropdown
2. Select **`_sandbox`** (the development playground)
3. Or click **"Create New Mod"** to make your own

### Step 3: Create a Weapon

1. Click the **"Items"** tab
2. Click **"New"** (top left)
3. Fill in:
   - **Item Name**: "Rusty Sword"
   - **Item Type**: Weapon
   - **Equipment Type**: sword
   - **Equipment Slot**: Weapon
   - **Attack Power**: 5
   - **Icon**: Browse to `mods/_sandbox/art/placeholder/items/sword.png`
4. Click **"Save Changes"**

### Step 4: Create a Class

1. Click the **"Classes"** tab
2. Click **"New"**
3. Fill in:
   - **Class Name**: "Squire"
   - **Movement Type**: Walking
   - **Movement Range**: 5
   - **Growth Rates**: Adjust HP/STR/DEF sliders to taste
   - Under **Equippable Weapon Types**: Check "sword"
4. Click **"Save Changes"**

### Step 5: Create a Character

1. Click the **"Characters"** tab
2. Click **"New"**
3. Fill in:
   - **Name**: "Sir Reginald"
   - **Class**: Select "Squire" (the class you just made)
   - **Starting Level**: 1
   - **Unit Category**: player
   - **Portrait**: Browse to `mods/_sandbox/art/placeholder/portraits/knight.png`
   - **Map Spritesheet**: Browse to `mods/_sandbox/art/placeholder/sprites/knight_spritesheet.png`
   - **Starting Weapon**: Select "Rusty Sword"
4. Click **"Save Changes"**

### Step 6: Add to Party

1. Click the **"Party Templates"** tab
2. Select an existing party or click **"New"**
3. Click **"+ Add Member"**
4. Select your character from the dropdown
5. Click **"Save Changes"**

### Step 7: Play!

1. Press **F5** (or click the Play button)
2. Start a new game
3. Your character appears in the party with their portrait, class, and weapon!

**Total time:** Under 5 minutes

### Placeholder Art Available

| Type | Location | Examples |
|------|----------|----------|
| Portraits | `mods/_sandbox/art/placeholder/portraits/` | hero, warrior, mage, knight, healer |
| Map Sprites | `mods/_sandbox/art/placeholder/sprites/` | `*_spritesheet.png` (64x128, 4 directions) |
| Item Icons | `mods/_sandbox/art/placeholder/items/` | sword, axe, staff, potion, herb |

### Editor Shortcuts

| Key | Action |
|-----|--------|
| Ctrl+S | Save current resource |
| Ctrl+N | Create new resource |
| Ctrl+D | Duplicate selected |
| Ctrl+F | Focus search filter |

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Character not in party | Ensure Unit Category is "player" and party template includes them |
| Can't equip weapon | Check class has weapon type in "Equippable Weapon Types" |
| Sprite not animating | Spritesheet must be exactly 64x128 pixels (2 frames × 4 directions) |
| Changes not saving | Click "Save Changes" button; check Output panel for errors |

---

## What's Working

The platform is in active development with these systems **implemented and functional**:

### Core Platform
- **Full mod system** - Priority-based loading, resource overrides, total conversion support
- **16 resource types** - Characters, classes, items, abilities, battles, campaigns, maps, terrain, shops, NPCs, and more
- **Type registries** - Add weapon types, equipment slots, terrain types via JSON (no code)
- **Dependency system** - Mods can require other mods

### Combat (SF2-Authentic)
- AGI-based turn order with SF2-accurate formulas
- Double attacks, counters (3%/6%/12%/25% class-based rates)
- Terrain defense and evasion bonuses
- Class-based magic with level-gated spell unlocks
- Session-based combat display (attack + double + counter in one screen)

### Progression
- Level-difference XP tables
- Catch-up mechanics for underleveled characters
- Support XP for healers (with anti-spam protection)
- SF2-style promotions with branching paths via items

### The Caravan (SF2's Soul)
- Mobile HQ follows your party on the overworld
- 12-slot active party with unlimited reserves
- Depot storage with Take/Store modes
- SF2-authentic UI patterns

### Cinematic & Dialog System
- Text interpolation: `{player_name}`, `{gold}`, `{char:id}`, `{flag:name}`
- Party management commands: recruit, remove, rejoin characters
- System messages with customization
- NPC conditional dialogs with AND/OR flag logic

### Editor Tooling (15+ Editors)
- Character, Class, Item, Ability editors
- Battle editor with enemy placement
- Campaign editor (visual node graph)
- Cinematic editor (19 command types)
- Dialogue editor with branching
- Shop, NPC, Terrain, Map editors
- Save file debug editor

[Full feature list in the announcement](docs/announcements/reddit-announcement-draft.md)

---

## What's Not Ready Yet

We believe in honest assessments:

| Feature | Status |
|---------|--------|
| Full demo campaign | Placeholder content exists; polished campaign in progress |
| Crafting system | Resource classes exist; UI/integration pending |

---

## Project Structure

```
sparklingfarce/
  core/                 # Platform code (never game content)
    mod_system/         # ModLoader, ModRegistry
    resources/          # Resource class definitions
    systems/            # Autoload singletons (BattleManager, etc.)
    components/         # Reusable node components

  mods/                 # ALL game content lives here
    _base_game/         # Official content (priority 0)
      data/             # Characters, classes, items, battles...
      ai_brains/        # AI behavior scripts
      tilesets/         # TileSet resources
    _sandbox/           # Your development mod (priority 100)

  scenes/               # UI scenes, exploration, tests
  addons/               # Sparkling Editor, gdUnit4
  tests/                # Automated tests
```

**Key principle:** The game is just a mod. Everything in `_base_game` uses the same systems your mod will use. Override any resource by creating one with the same ID at higher priority.

[Full architecture details](docs/specs/platform-specification.md)

---

## Creating a New Mod

### Using the Editor

1. Open the **Sparkling Editor** (bottom panel)
2. Click **"Create New Mod"** button
3. Fill in the wizard:
   - **Mod ID**: lowercase with underscores (e.g., `my_awesome_mod`)
   - **Display Name**: Human-readable name
   - **Author**: Your name
   - **Description**: Brief description
   - **Mod Type**: "Content Expansion" for adding new content
4. Click **"Create Mod"**
5. The new mod is automatically selected as active

### Manual Setup

1. Create `mods/your_mod_name/` directory
2. Create `mod.json`:
   ```json
   {
     "id": "your_mod_name",
     "name": "Your Mod Display Name",
     "version": "1.0.0",
     "author": "Your Name",
     "load_priority": 500,
     "dependencies": []
   }
   ```
3. Create `data/` subdirectory with resource type folders (characters/, items/, etc.)
4. Resources auto-discovered on game launch

### Load Priority Guide

| Range | Purpose |
|-------|---------|
| 0-99 | Official core content |
| 100-8999 | User mods, expansions |
| 9000-9999 | Total conversions |

Higher priority overrides same-ID resources from lower priority mods.

---

## Contributing

### Report Bugs
[Open an issue](https://github.com/[PLACEHOLDER]/sparklingfarce/issues) with:
- Steps to reproduce
- Expected vs actual behavior
- Godot version and OS

### Request Features
Check [existing issues](https://github.com/[PLACEHOLDER]/sparklingfarce/issues) first, then open a new one describing:
- The use case
- How it fits SF-style gameplay
- Any implementation thoughts

### Submit Code
1. Fork the repository
2. Create a feature branch
3. Follow code standards:
   - Strict typing required (`var x: int = 5`, not `var x := 5`)
   - Use `if "key" in dict:` not `dict.has("key")`
   - See [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
4. Run tests: `godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd`
5. Open a pull request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

This project stands on the shoulders of giants:

- **[Shining Force Central](https://shiningforcecentral.com/)** - The community that kept SF alive for decades
- **Shining Force Unleashed & Alternate** - ROM hacks that proved the demand for new SF content
- **Caravan stat tools** - Fan tools that inspired our editor approach
- **[Godot Engine](https://godotengine.org/)** - The open-source engine making this possible
- **The original Shining Force teams at Sonic!/Camelot** - For creating the games that shaped us

---

## Links

- [Platform Specification](docs/specs/platform-specification.md) - Technical architecture
- [Reddit Announcement](docs/announcements/reddit-announcement-draft.md) - Full feature overview
- [PLACEHOLDER: Discord/Community Link]
- [PLACEHOLDER: Wiki/Documentation Site]

---

*The platform provides infrastructure. The game is just a mod. What will you create?*
