# The Sparkling Farce: A Modding Platform for Shining Force Fans

*A love letter to the tactical RPGs that shaped us*

---

Hey r/ShiningForce (and crossposting to r/JRPG, r/Godot, r/TacticalRPG),

We've been quietly building something for the past while, and we're finally ready to share it with the community that inspired it.

**The Sparkling Farce** is a Godot 4.5-based modding platform designed to let fans create their own Shining Force-style campaigns. It's not a remake. It's not trying to "fix" the classics. It's a toolkit for the community to build the SF content we've all been dreaming about for years.

---

## Why We're Building This

Like many of you, we grew up with Shining Force. The promotion fanfare is burned into our souls. We've argued about whether Domingo is overpowered (yes) and whether Gort is worth training (also yes, fight us). We've restarted SF1 because we missed that one chest in Chapter 2.

We've also watched the Fire Emblem community thrive with tools like FEBuilder while the SF community has been stuck with hex editors and dreams. We wanted to change that.

**Our philosophy is simple:** The platform provides infrastructure. The game is just a mod.

Everything - characters, items, battles, campaigns - lives in the `mods/` folder. The "base game" uses the exact same systems that your total conversion mod will use. There's no hardcoded content. If we can override it, you can override it.

---

## What's Actually Working Right Now

We believe in showing, not promising. Here's what's implemented and functional:

### Core Platform
- [x] **Full mod system** with priority-based loading (user mods can override base content)
- [x] **16 moddable resource types** (characters, classes, items, abilities, battles, campaigns, maps, terrain, and more)
- [x] **Type registries** - mods can add new weapon types, equipment slots, terrain types, and AI behaviors without touching code
- [x] **Dependency system** - mods can require other mods (for expansion packs, compatibility patches, etc.)
- [x] **Total conversion support** - high-priority mods can completely replace the base game

### Combat System
- [x] **SF2-authentic battle mechanics** - damage formulas, terrain bonuses, the works
- [x] **Double attack system** - class-based rates, just like SF2
- [x] **Counter system** - with the exact SF2 rates (3%/6%/12%/25% by class)
- [x] **Terrain defense and evasion bonuses** - positioning matters
- [x] **Session-based combat display** - one battle screen for the full exchange (attack, double, counter)

### Experience & Progression
- [x] **Level-difference XP tables** - that classic SF feeling where grinding weak enemies is pointless
- [x] **Formation XP bonuses** - reward tactical positioning by giving allies nearby a cut
- [x] **Catch-up mechanics** - underleveled characters get bonus XP to stay relevant
- [x] **Support XP** - healers and buffers earn XP too (with anti-spam protection)
- [x] **30+ configurable parameters** - mods can tune every aspect of progression

### Class & Promotion System
- [x] **SF2-style promotions** - level resets to 1, stats carry over
- [x] **Branching promotions via items** - want Knight + Pegasus Wing = Pegasus Knight? Supported. Mods can created unlimited branched
- [x] **Movement types** - walking, flying, floating (with terrain cost tables)
- [x] **Equipment restrictions** - by weapon type, armor type, class, whatever you configure

### Shop System
- [x] **Five shop types** - Weapon, Item, Church, Crafter, Special
- [x] **"Who equips this?" flow** - SF-style equipment purchasing
- [x] **Church services** - heal, revive (level-scaled cost), uncurse
- [x] **Sell from inventory or depot** - with price multipliers and deals
- [x] **Configurable Rare Resources** - Want mithril AND dragon scales AND fairy dust as special materials? Supported.

### Quality of Life
- [x] **Debug console** with mod-extensible commands (mods can register their own!)
- [x] **No chapter lockouts** - SF2's open world philosophy, not SF1's
- [x] **Battle Previews** - See hit chance, counter chance, and more all before you attack
- [x] **Multiple Item Purchasing** - With friendly item distribution to party - even straight to caravan!

### A Complete Professional-Grade No-Code Mod Editor
- [x] **Drag-and-drop Campaign Creator** - Node-style connections between campaign locations and events with flags and conditionals
- [x] **Graphical Cinematic Maker** - Chain together actions to make a cinematic.  Dialog line > move character > camera shake > fade out > done! Supports flags, conditionals, and multiple choices
- [X] **Built-in Save Slot Editor** - Give that hex editor a little break

---

## Classic SF Complaints We've Addressed

We love these games, but we also know their rough edges. Here's what the platform handles differently:

| Classic Complaint | Our Approach |
|-------------------|--------------|
| **SF1's chapter lockouts** | Both linear and sandbox campaigns fully supported, or any combination |
| **4-item inventory limit** | Confugurable inventory size - Depot storage via mobile Caravan |
| **"Trap" characters falling behind** | Catch-up XP mechanics (configurable or disable-able) |
| **Grinding tedium vs. no-grind frustration** | Configurable: enable/disable anti-grinding, tune XP curves |
| **Save only at churches** | OPTIONAL Save anywhere (mods can enable/disable) |
| **Limited replayability** | Branching promotions, mod support, configurable difficulty |
| **Sparse character development** | Dialogue system + cinematic engine for deeper storytelling |

---

## Fire Emblem Features (ENTIRELY OPTIONAL)

We've heard the debates. "SF should stay SF, not become FE." We agree.

These features exist in the platform but are **off by default** or **require mod configuration**:

- **Support conversations** - infrastructure exists for relationship-building dialogue (off by default)
- **Adjutant system** - bench characters earning partial XP (disabled, skeleton only - planned for future)
- **Weapon durability** - NOT implemented, and we're not planning to unless heavily requested
- **Permadeath** - NOT implemented. This is a Shining Force platform. Your units retreat, they don't die.
- **Auras** - Passive area bonuses. We actually like this and (OPTIONAL, moddable!) support coming soon

The base game will feel like SF2. If you want FE-style mechanics, **you click a few buttons in the Sparkling Editor** and you've got a custom mod. This isn't a game, this is a toolkit.

---

## The Editor Tooling

This is where we're most proud. No hex editing. No ROM corruption. Visual tools in the Godot editor.

### 15+ Specialized Editors:
- **Character Editor** - stats, portraits, starting equipment
- **Class Editor** - growth rates, promotions, abilities, equipment restrictions
- **Item Editor** - equipment stats, consumables, key items
- **Ability Editor** - spells, skills, targeting patterns
- **Battle Editor** - enemy placement, victory/defeat conditions, terrain
- **Campaign Editor** - visual node graph for campaign flow
- **Dialogue Editor** - branching conversations with conditions
- **Cinematic Editor** - cutscenes with 15 command types (camera, movement, fade, sound)
- **Map Metadata Editor** - spawn points, Caravan visibility, connections
- **Shop Editor** - inventory, pricing, shop type configuration
- **Terrain Editor** - defense bonuses, movement costs by type
- **NPC Editor** - behavior triggers, dialogue links
- **Party Editor** - starting party configurations
- **Save Editor** - debug tool for save files
- **Mod JSON Editor** - edit mod manifests

All editors use live preview and integrate with Godot's inspector system.

---

## How We Compare to Existing Community Projects

We're not the first SF fan project. We know the graveyard well. Here's how we're different:

| Project Type | Limitations | Our Approach |
|--------------|-------------|--------------|
| **ROM Hacks** (Unleashed, Alternate) | Limited to modifying existing content. Hex editing. No new campaigns. | Full content creation. Visual editors. Unlimited campaigns. |
| **Fan Remakes** (various abandoned) | Scope creep. Art asset burden. Single-game focus. | Platform-first. Content is separate. Community can share assets. |
| **Stat Editors** (Caravan tools) | Tweak numbers only. Can't add content. Janky UX. | Full resource creation. 16 data types. Professional editor UI. |
| **Generic TRPG Engines** | Lose SF identity. Different combat feel. | SF2-authentic mechanics baked in. Feels like SF from frame one. |

**What we're NOT doing:**
- We're not promising to remake SF1 or SF2 (though mods could)
- We're not trying to replace the originals
- We're not making "SF but better" - we're making "SF but *yours*"

---

## What Modders Can Do

Things you **literally cannot do** with ROM hacking that The Sparkling Farce is **designed for**:

- Create entirely new campaigns with original characters, battles, and story
- Add new weapon types, equipment slots, and class categories via Sparkling Editor or JSON
- Design branching class trees with special promotion items
- Build custom XP curves and progression systems
- Create total conversion mods that completely replace the base game
- Share mod packs that depend on other mods (expansion pack ecosystem)
- Register custom debug console commands for testing
- Use 15 cinematic commands to create cutscenes **without code**
- Configure AI behaviors without programming

All in a cross-platform engine that exports to Windows, Linux, Mac, and potentially more.

---

## Current State & Near-Term Roadmap

**Honest assessment of where we are:**

### Solid & Working:
- Mod system (production-ready)
- Combat mechanics (SF2-authentic)
- Editor tooling (15+ editors)
- Experience/progression system
- Shop system with all SF features
- Save/load system
- Debug infrastructure

### Partially Implemented:
- Crafting system (resource classes exist, UI/logic pending)
- Some terrain effects (damage-per-turn works, status effects pending)
- Adjutant system (config exists, processing pending)

### Not Yet Started:
- Magic system (Phase 4)
- AI behavior variety (currently: aggressive and stationary only)
- Full base game content (we have placeholders - content is mod work, not platform work)

### Near-Term Focus:
1. Stabilizing the battle flow
2. Adding AI behavior variety
3. Polishing the editor experience
4. Building out the base game content as proof of concept

---

## The "Game is a Mod" Architecture

For the technically curious:

```
core/                          # Platform code ONLY
  systems/                     # BattleManager, ShopManager, etc.
  resources/                   # Resource class definitions
  registries/                  # Type extension system
  mod_system/                  # ModLoader, ModRegistry

mods/                          # ALL game content
  _base_game/                  # Official content (priority 0)
    data/characters/           # CharacterData .tres files
    data/items/                # ItemData .tres files
    data/battles/              # BattleData configs
    ...
  _sandbox/                    # Dev/testing (priority 100)
  your_mod/                    # Your content (priority 100-8999)
  total_conversion/            # Override everything (priority 9000+)
```

Higher priority mods override lower priority resources with matching IDs. Want to rebalance Max? Create a `max.tres` in your mod with priority 5000 (or edit Mod Settings in the Sparkling Editor!). Your version wins.

---

## Who This Is For

- **SF fans** who've wanted to create their own campaigns
- **Modders** frustrated by ROM hacking limitations
- **Game designers** who want SF-authentic tactical combat without building from scratch
- **Content creators** who want visual tools, not hex editors
- **Nostalgia enjoyers** who want the SF feel with modern QoL

---

## Who This Is NOT For

- People expecting a finished game right now (it's a platform; content takes time)
- Those wanting SF "fixed" into something else (we preserve the feel, not reinvent it)
- Fire Emblem fans wanting FE mechanics (use SRPG Studio or FEBuilder instead)

---

## Get Involved

We're building this for the community, and we'd love your input:

- **What features matter most to you?**
- **What would your dream SF mod add?**
- **What editor tools would help you create content?**

The platform is in active development. We're showing working code because we've seen too many fan projects announce grand visions and disappear. We'd rather show a functional foundation and grow from there.

---

## Technical Details

- **Engine:** Godot 4.5
- **Language:** GDScript (strict typing throughout)
- **Test Coverage:** 36 test files, gdUnit4 framework
- **Platform:** Primarily Linux development, cross-platform export planned

---

*We're huge SF fans building the modding platform we wish existed. Not trying to replace the classics - trying to give the community tools to celebrate and expand them.*

*Shining Force taught us that tactical RPGs could be warm, accessible, and full of personality. We're not reinventing that. We're building a platform that captures what made SF magical and lets you run with it.*

---

**tl;dr:** Open-source Godot platform for creating Shining Force-style tactical RPG campaigns THAT ALREADY WORKS. Full mod support. Visual editors. SF2-authentic mechanics. No ROM hacking required. Not vaporware - here's what actually works. Come help us build the tools the SF community deserves.

---

*May your Force always shine.*
