# The Sparkling Farce: A Modding Platform for Shining Force Fans

*A love letter to the tactical RPGs that shaped us*

---

Hey r/ShiningForce (and crossposting to r/JRPG, r/Godot, r/TacticalRPG),

We've been quietly building something for the past while, and we're finally ready to share it with the community that inspired it.

**The Sparkling Farce** is a Godot 4.5-based modding platform designed to let fans create their own Shining Force-style campaigns. It's not a remake. It's not trying to "fix" the classics. It's a toolkit for the community to build the SF content we've all been dreaming about for years.

Oh, and it's fully free and open source.

Let's chat, shall we?

---

## Why We're Building This

Like many of you, we grew up with Shining Force. The promotion fanfare is burned into our souls. We've argued about whether Domingo is overpowered (yes) and whether Gort is worth training (also yes, fight us). We've restarted SF1 because we missed that one chest in Chapter 2, and cheered out loud when Slade made the second-attack that saved the battle.

We've also watched the Fire Emblem community thrive with tools like FEBuilder while the SF community has been stuck with hex editors and dreams. We wanted to change that.

**Our philosophy is simple:** The platform provides infrastructure. We'll be releasing with something of a game, but the game is just a mod. Read that again. **The game is just a mod.**

Everything - characters, items, battles, campaigns - lives in the `mods/` folder. The "base game" uses the exact same systems that your total conversion mod will use. There's no hardcoded content. If we can override it, you can override it. And if we can't, then we redesign until we CAN. 

---

## What's Actually Working Right Now

We believe in showing, not promising. Here's what's **implemented and functional**:

### Core Platform
- [x] **Full mod system** with priority-based loading (user mods can override base content)
- [x] **16 moddable resource types** (characters, classes, items, abilities, battles, campaigns, maps, terrain, and more)
- [x] **Type registries** - mods can add new weapon types, equipment slots, terrain types, and AI behaviors without touching code
- [x] **Dependency system** - mods can require other mods (for expansion packs, compatibility patches, etc.)
- [x] **Total conversion support** - high-priority mods can completely replace the base game

### Combat System
- [x] **SF2-authentic battle mechanics** - 100% accurate AGI-based turn orders, SF-style damage formulas, terrain bonuses, the works
- [x] **Double/second attack system** - class-based rates, just like SF2
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
- [x] **SF2-style promotions WITHOUT the complex meta** - level resets to 1, stats carry over, but promoted growth rates always beat base class
- [x] **Branching promotions via items** - want Knight + Pegasus Wing = Pegasus Knight? Supported. Mods can create unlimited branches
- [x] **Movement types** - walking, flying, floating, etc (with terrain cost tables)
- [x] **Equipment restrictions** - by weapon type, class, whatever you configure

### Shop System
- [x] **Five shop types** - Weapon, Item, Church, Crafter, Special
- [x] **Moddable. Caravan. NPCs.** - I'll let that one simmer
- [x] **"Who equips this?" flow** - SF-style equipment purchasing **with quantities**.  Buy 10 healing herbs at once, pass them out to multiple party members at once.
- [x] **Church services** - heal, revive (level-scaled cost), uncurse
- [x] **Sell from inventory or depot** - with price multipliers and deals
- [x] **Configurable Rare Resources** - Want mithril AND dragon scales AND fairy dust as special materials? Supported.

### Quality of Life
- [x] **Debug console** with mod-extensible commands (mods can register their own!)
- [x] **No chapter lockouts** - SF2's open world philosophy, not SF1's (unless you want it. Check out the campaign editor!)
- [x] **Battle Previews** - See hit chance, counter chance, and more all before you attack
- [x] **Multiple Item Purchasing** - With friendly item distribution to party - even straight to caravan!

### A Complete Professional-Grade No-Code Mod Editor
- [x] **Drag-and-drop Campaign Creator** - Node-style connections between campaign locations and events with flags and conditionals
- [x] **Graphical Cinematic Maker** - Chain together actions to make a cinematic.  Dialog line > move character > camera shake > fade out > done! Supports flags, conditionals, and multiple choices
- [X] **Built-in Save Slot Editor** - Give that hex editor a little break

---

## The SF2 Details That Matter

These are the things that separate "tactical RPG" from "feels like Shining Force":

### The Mobile Caravan (SF2's Soul)
The Caravan was SF2's defining feature - your mobile HQ that follows you across the overworld. We've implemented it with:
- **Breadcrumb trail following** - the wagon walks the exact path your party walked, creating that classic trailing effect
- **12-slot active party grid** with reserves - swap characters anytime you're at the Caravan
- **Hero locked to slot 0** - your protagonist can never be benched, just like Bowie
- **Unlimited depot storage** - never throw away that weird item you might need later
- **Overworld-only visibility** - Caravan disappears in towns (that's what churches are for)

### Combat That FEELS Right
- **Damage at impact** - numbers appear when the hit lands, not after the animation. HP bars drain in real-time.
- **Session-based battles** - one fade-in, full exchange (attack, double, counter), one fade-out. No jarring transitions.
- **XP pooling for double attacks** - one XP award for the total damage, not two separate popups
- **The "Who equips this?" shop flow** - buy a Steel Sword, see only characters who can wield it

### The Healer Problem: SOLVED
Every SF veteran knows the pain: your fighters hit level 20 while Sarah is stuck at level 12 because healing gives garbage XP. We fixed this:
- **Support catch-up XP** - underleveled healers get bonus XP when supporting higher-level allies
- **Formation XP** - strong positioning earns XP
- **Meaningful healing XP** - big heals on wounded tanks earn good experience
- **Anti-spam protection** - no more casting Aura on full-health parties for free levels

---

## Classic SF Complaints We've Addressed

We love these games, but we also know their rough edges. Here's what the platform handles differently:

| Classic Complaint | Our Approach |
|-------------------|--------------|
| **SF1's chapter lockouts** | Both linear and sandbox campaigns fully supported, or any combination |
| **4-item inventory limit** | Configurable inventory size - Depot storage via mobile Caravan |
| **"Trap" characters falling behind** | Catch-up XP mechanics (configurable or disable-able) |
| **Grinding tedium vs. no-grind frustration** | Configurable: enable/disable anti-grinding, tune XP curves |
| **Save only at churches** | OPTIONAL Save anywhere (mods can enable/disable) |
| **Limited replayability** | Branching promotions, mod support, configurable difficulty |
| **Sparse character development** | Dialogue system + cinematic engine for deeper storytelling |

---

## Optional Modern Features (Off By Default)

We've heard the debates. "SF should stay SF." We agree completely.

These features exist in the platform but are **off by default** or **require mod configuration**:

- **Extended character dialogue system** - infrastructure exists for deeper character interactions and relationship-building conversations (off by default)
- **Adjutant system** - bench characters earning partial XP (disabled, skeleton only - planned for future)
- **Weapon durability** - NOT implemented, and we're not planning to unless heavily requested

**What we will NEVER change:**

- **No permadeath. Period.** This is a Shining Force platform. Your units retreat, they don't die. The retreat system is sacred - lose the battle, lose half your gold, keep your XP, wake up at HQ, and march right back in. That's the SF way, and it's non-negotiable in the base game.

The base game will feel like SF2. If you want different mechanics, **you click a few buttons in the Sparkling Editor** and you've got a custom mod. This isn't a game, this is a toolkit.

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

## Building on the Community's Foundation

We're not the first SF fan project, and we're standing on the shoulders of giants. Projects like **Shining Force Unleashed**, **Shining Force Alternate**, and the various **Caravan** stat tools have kept this community alive for decades. Their creators figured out how to bend these old ROMs to their will with hex editors and determination. That work inspired us.

What we're adding to the ecosystem:

| Existing Approach | What We're Building |
|-------------------|---------------------|
| **ROM Hacks** (Unleashed, Alternate, etc.) | These projects prove the demand exists. We're creating a path from "modify existing" to "create from scratch" - entirely new campaigns without ROM limitations. |
| **Stat Editors** (Caravan tools) | Great for tweaking what exists. We extend this to full content creation - 16 resource types, visual editors, no hex required. |
| **Fan Remakes** (various attempts) | Many stalled on scope/assets. Our platform-first approach means content is separate - the community can share assets and build incrementally. |
| **Generic TRPG Engines** | Powerful but lose the SF identity. We bake SF2-authentic mechanics in from frame one - it feels like Shining Force immediately. |

**What we're NOT doing:**
- We're not promising to remake SF1 or SF2 (though if we do our job, mods could)
- We're not trying to replace the originals or existing projects
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
- Demo campaign to show off working features

### Not Yet Started:
- Magic system (Phase 4)
- AI behavior variety (currently: aggressive and stationary only)
- Full base game content (we have placeholders - content is mod work, not platform work)
- Full SF-scale campaign with storyline and balanced progression

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

Higher priority mods override lower priority resources with matching IDs. Want to rebalance Max? Create a `max.tres` in your mod with priority 5000 (or edit Mod Settings in the Sparkling Editor!). Your version wins. Mod conflicts are resolved alphabetically, but the overall design was intended to provide flexibility to the modding community while utilizing something of an "honor system" when it comes to setting your mod's priority. 

---

## Who This Is For

- **SF fans** who've wanted to create their own campaigns, characters, and spells
- **Modders** frustrated by ROM hacking limitations
- **Game designers** who want SF-authentic tactical combat without building from scratch
- **Content creators** who want visual tools, not hex editors
- **Nostalgia enjoyers** who want the SF feel with modern QoL

---

## Who This Is NOT For

- People expecting a finished game right now (it's a platform; for this project, content is a secondary priority)
- Those wanting SF "fixed" into something else (we preserve the feel, not reinvent it, or presume to "improve" it)
- Fire Emblem fans wanting FE mechanics (SRPG Studio or FEBuilder might be more appropriate)

---

## Get Involved

We're building this for the community, and we'd love your input:

- **What features matter most to you?**
- **What would your dream SF mod add?**
- **What editor tools would help you create content?**

The platform is in active development. We're showing working code because we've seen too many fan projects announce grand visions but struggle with delivery. We'd rather show a functional foundation and grow from there.

---

## Technical Details

- **Engine:** Godot 4.5
- **Language:** GDScript (strict typing throughout)
- **Test Coverage:** 36 test files, gdUnit4 framework
- **Platforms:** Development on Linux, but Godot exports to **Windows, Mac, Linux, and more**. Cross-platform from day one - this isn't a Linux-only project.

**Want to see it in action?** We're working on video demonstrations of the current systems. We know the SF community has seen too many "coming soon" promises - we'd rather show you working code than render trailers.

---

*We're huge SF fans building the modding platform we wish existed. Not trying to replace the classics - trying to give the community tools to celebrate and expand them.*

*Shining Force taught us that tactical RPGs could be warm, accessible, and full of personality. We're not reinventing that. We're building a platform that captures what made SF magical and lets you run with it.*

---

**tl;dr:** Open-source Godot platform for creating Shining Force-style tactical RPG campaigns THAT ALREADY WORKS. SF2-authentic mechanics (yes, including the Caravan, the retreat system, buying in stacks, and previewing attacks!). Full mod support with 15+ visual editors. Cross-platform (Windows/Mac/Linux). No ROM hacking, no hex editing, no permadeath. *Working code you can see today.* Come help us build the tools the SF community deserves.

---

*May your fire forever burn like Kiwi's breath*
