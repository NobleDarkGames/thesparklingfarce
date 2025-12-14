# The Sparkling Farce: A Modding Platform for Shining Force Fans

*A love letter to the tactical RPGs that shaped us*

---

Hey r/ShiningForce (and crossposting to r/JRPG, r/Godot, r/TacticalRPG),

We've been quietly building something for the past while, and we're finally ready to share it with the community that inspired it.

**The Sparkling Farce** is a Godot 4.5-based low/no-code modding platform designed to let fans create their own Shining Force-style campaigns. It's not a remake. It's not trying to "fix" the classics. It's a toolkit for the community to build the SF content we've all been dreaming about for years.

Oh, and it's fully free and open source.

Let's chat.

---

## Why We're Building This

Like many of you, we grew up with Shining Force. The promotion fanfare is burned into our souls. We've argued about whether Domingo is overpowered (duh) and whether Gort is worth training (Team Gort!). We've restarted SF1 because we missed that one chest in Chapter 2, and squealed in delight when Slade made the second-attack that saved the battle.

We've also watched the Fire Emblem community thrive with tools like FEBuilder while the SF community has hex editors and dreams. We wanted to change that.

**Our philosophy is simple:** The platform provides infrastructure, the game is just a mod. Read that again. **The game is just a mod.**

You can play the Shining Force style game you like, but *so can everyone else*. 

Everything - characters, items, battles, campaigns - lives in the `mods/` folder. The "base game" uses the exact same systems that your total conversion mod will use. There's no hardcoded content. If we can override it, you can override it. And if we can't, then we redesign until we CAN. 

---

## What's Actually Working Right Now

If we've already got your interest, here's a **live, working demo** of the sample campaign with developer art
(http://placeholder.url)

We believe in showing, not promising. Here's what's **implemented and functional**:

### Core Platform
- [x] **Full mod system** with priority-based loading (user mods can override base content)
- [x] **16 moddable resource types** (characters, classes, items, abilities, battles, campaigns, maps, terrain, and more)
- [x] **Type registries** - mods can add new weapon types, equipment slots, terrain types, and AI behaviors without touching code
- [x] **Dependency system** - mods can require other mods (for expansion packs, compatibility patches, etc.)
- [x] **Total conversion support** - high-priority mods can *completely* replace the base game

### Full Tile-Based Map Editing 
- [x] **Utilizes Godot** - No need to reinvent when we've got a powerful open source engine
- [x] **Conditional Map Elements** - Sometimes you've got to beat the troll before you can cross the bridge
- [x] **Placeable NPCs and Triggers** - What's life without the search for Mithril?
- [x] **Border Sensitivity** - Trigger new scenes on reaching the edge of a map, definable by edge

### JRPG Style Dialog & Cinematic System
- [x] **Visual Goodies** - Character portraits, dialog animations, typewriter effect. Emotions are partly supported, not currently implemented
- [x] **Dialogs are Cinematics** - Every interaction with every chicken can be a rock opera - with a few clicks in the Cinematic editor
- [x] **Choices and Multiple Choices** - Sometimes it takes more than a yes/no

### Combat System
- [x] **SF2-authentic battle mechanics** - Authentic SF-style turn order calculation, damage formulas, terrain bonuses, the works (moddable of course)
- [x] **Double/second attack system** - class-based rates, just like SF2
- [x] **Counter system** - with the exact SF2 rates (3%/6%/12%/25% by class)
- [x] **Terrain defense and evasion bonuses** - positioning matters
- [x] **Session-based combat display** - one battle screen for the full exchange (attack, double, counter)
- [x] **Weapon stat integration** - weapon attack power, range, and modifiers fully factored into combat

### Magic System (Class-Based, Like SF2!)
- [x] **Class-based spell learning** - spells come from your class, (Mages learn Blaze, Healers learn Heal, etc) but personal spells also supported
- [x] **Level-gated unlocks** - spells unlock at specific class levels (Blaze 1 at level 1, Blaze 2 at level 8, etc.)
- [x] **Unique character abilities** - exceptions for special characters (Domingo's Freeze)
- [x] **Spell combat routing** - spells use the same combat screen as physical attacks (consistent damage numbers, XP awards)
- [x] **MP costs and management** - proper resource management for casters

### Experience & Progression
- [x] **Level-difference XP tables** - Less XP for weak enemies, more xp for more
- [x] **Formation XP bonuses** - reward tactical positioning by giving allies nearby a cut
- [x] **Catch-up mechanics** - underleveled characters get bonus XP to stay relevant
- [x] **Support XP** - healers and buffers earn XP too (with anti-spam protection)
- [x] **30+ configurable parameters** - mods can tune every aspect of progression

### Class & Promotion System
- [x] **SF2-style promotions WITHOUT the complex meta** - level resets to 1, stats carry over, but promoted growth rates always beat base class. But moddable!
- [x] **Branching promotions via items** - want Knight + Pegasus Wing = Pegasus Knight? Supported. Mods can create unlimited branches
- [x] **Movement types** - walking, flying, floating, etc (with terrain cost tables)
- [x] **Equipment restrictions** - by weapon type, class, whatever you configure

### Shop System
- [x] **Five shop types** - Weapon, Item, Church, Crafter, Special
- [x] **Moddable. Caravan. NPCs.** - I'll let that one simmer
- [x] **"Who equips this?" flow, but streamlined** - SF-style equipment purchasing **with quantities**.  Buy 10 healing herbs at once, pass them out to **multiple** party members at once.
- [x] **Church services** - heal, revive (level-scaled cost), uncurse
- [x] **Sell from inventory or depot** - with price multipliers and deals
- [x] **Configurable Rare Resources** - Want mithril AND dragon scales AND fairy dust as special materials? Supported. All moddable.

### Quality of Life
- [x] **Debug console** with mod-extensible commands (mods can register their own!)
- [x] **No chapter lockouts** - SF2's open world philosophy, not SF1's (unless you want it. Check out the campaign editor, with node style GUI!)
- [x] **Battle Previews** - See hit chance, counter chance, and more all before you attack
- [x] **Multiple Item Purchasing** - With friendly item distribution to party - even straight to caravan in bulk!
- [x] **SF2-authentic field menu** - Press confirm on empty space or cancel to open the classic Item/Magic/Search/Member menu (yes, "Member" - that's the SF2 term!)

### A High Quality No-Code Mod Editor
- [x] **Visual Campaign Creator** - Node-style connections between campaign locations and events with flags and conditionals
- [x] **Graphical Cinematic Maker** - Chain together actions to make a cinematic.  Dialog line > move character > camera shake > fade out > done! Supports flags, conditionals, and multiple choices
- [x] **Built-in Save Slot Editor** - Give that hex editor a little break
- [x] **Create Items & Characters in Moments** - Click Items tab, click New, set a few properties, and save. New item ready to play.

---

## The SF2 Details That Matter

These are the things that separate "tactical RPG" from "feels like Shining Force":

### The Mobile Caravan (SF2's Soul)
The Caravan was SF2's defining feature - your mobile HQ that follows you across the overworld. We've implemented it with:
- **Breadcrumb trail following** - the wagon follows right along with you, creating that classic trailing effect
- **12-slot active party grid** with reserves - swap characters anytime you're at the Caravan
- **Hero locked to slot 0** - your protagonist can never be benched, just like Bowie
- **Unlimited depot storage** - never throw away that weird item you might need later
- **Overworld-only visibility** - Caravan disappears in towns (that's what churches are for)
- **SF2-inspired depot UI** - Take/Store modes with equipment compatibility warnings, L/R filter cycling, and the classic "click = action" UX

### Combat That FEELS Right
- **Damage at impact** - numbers appear when the hit lands, not just after the animation. HP bars drain in real-time.
- **Session-based battles** - one fade-in, full exchange (attack, double, counter, **or spell**), one fade-out. No jarring transitions.
- **XP pooling for double attacks** - one XP award for the total damage, not two separate popups
- **Class-based magic** - your class determines your spells, just like SF2. Promote to Wizard, get Wizard spells. Simple and elegant.

---

## Classic SF Complaints We've (Respectfully!) Addressed

We love these games, but we also know their rough edges. Here's what the platform handles differently:

| Classic Complaint | Our Approach |
|-------------------|--------------|
| **SF1's chapter lockouts** | Both linear and sandbox campaigns fully supported, or any combination |
| **4-item inventory limit** | Configurable unit inventory size - Additional depot storage via mobile Caravan |
| **"Trap" characters falling behind** | Catch-up XP mechanics (configurable or disable-able) |
| **Grinding tedium vs. no-grind frustration** | Configurable: enable/disable anti-grinding (ability repetition), tune XP curves |
| **Save only at churches** | OPTIONAL Save anywhere (mods can enable/disable, we default to disable) |
| **Limited replayability** | Branching promotions, **eeeexxxxxteeeeensive mod support**, configurable difficulty |
| **Sparse character development** | Dialogue system + cinematic engine for deeper storytelling. We know a chicken in Granseal who needs a backstory |

---

## Optional Modern Features (Off By Default)

We've heard the debates. "SF should stay SF." We agree completely.

These features may at some point exist in the platform but would be **off by default** or **require mod configuration**:

- **Extended character dialogue system** - infrastructure exists for deeper character interactions and relationship-building conversations (off by default)
- **Adjutant system** - bench characters earning partial XP (disabled, skeleton only - planned for future)
- **Weapon durability** - NOT implemented, and we're not planning to unless heavily requested
- **Save Anywhere** - If you want to take the shine out of your force, you can. We may give you looks, but you can.

**What we will NEVER change:**

- **No permadeath. Period.** This is a Shining Force style platform. Your units retreat, they don't die. The retreat system is sacred - lose the battle, lose half your gold, keep your XP, wake up at HQ, and march right back in. That's the SF way, and we have no plans to add logic saying otherwise. But this is open source! You do you!

All in all, the platform design is meant to support the best of all the games - plus whatever YOU want to do. If you want different mechanics, **you click a few buttons in the Sparkling Editor** and you've got a custom mod. This is a toolkit, and this toolkit is for you.

---

## The Editor Tooling

This is where we're most proud. No hex editing. No ROM corruption. Visual tools built right into the Godot editor.

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

We're not the first SF fan project, and we're standing on the shoulders of giants. Projects like **Shining Force Unleashed**, **Shining Force Alternate**, and the various **Caravan** stat tools have kept this community alive for decades. Their creators figured out how to bend these old ROMs to their will with hex editors and determination. That work inspired us, and we hope this project can sit alongside those efforts.

The SF community has built incredible things with the tools available:

- **ROM Hacks** like Unleashed and Alternate prove the demand is real - people want more SF content. We're hoping to offer another path: creating entirely new campaigns without ROM limitations.
- **Stat Editors** like the Caravan tools are fantastic for tweaking and analyzing what exists. We're trying to extend that same spirit to full content creation.
- **Fan Remakes** have shown how much love exists for these games, even when scope becomes challenging. Our platform-first approach separates engine from content, so the community can share assets and build incrementally.

We're not trying to replace any of this. We're just adding another option.

**What we're NOT doing:**
- We're not promising to remake SF1 or SF2 (though if we do our job, mods could)
- We're not trying to replace the originals or existing projects
- We're not making "SF but better" - we're making "SF but *yours*"

---

## What Modders Can Do

Things you can't easily do with ROM hacking that The Sparkling Farce is **designed for**:

- Create entirely new campaigns with original characters, battles, and story
- Add new weapon types, equipment slots, and class categories via Sparkling Editor or JSON
- Design branching class trees with special promotion items
- **Define class spell lists with level-gated unlocks** - your custom Wizard class can learn Fireball at level 5, Meteor at level 15, etc
- Build custom XP curves and progression systems
- Create total conversion mods that completely replace the base game
- Share mod packs that depend on other mods (expansion pack ecosystem)
- Register custom debug console commands for testing (oh right, we also have a debug command console built in)
- Use 15 cinematic commands to create cutscenes **without code**
- Configure AI behaviors without programming

All in a cross-platform engine that exports to Windows, Linux, Mac, and potentially more.

---

## Current State & Near-Term Roadmap

**Honest assessment of where we are:**

### Solid & Working:
- Mod system (production-ready)
- Combat mechanics (roughly SF2-authentic, but still some UX polish to go)
- **Magic system** (class-based spells, level-gated unlocks, combat integration)
- Editor tooling (15+ graphical editor tools)
- Experience/progression system
- Shop system with all SF features plus several new ones
- Caravan depot system (SF2-style item storage/transfer)
- Field menu system (Item/Magic/Search/Member/Moddable!)
- Save/load system
- Debug infrastructure
- Terrain effects (also fully moddable!)
- Area-of-effect spells

### Partially Implemented:
- Crafting system (resource classes exist, UI/logic pending)
- Adjutant system (config exists, processing pending)
- Demo campaign to show off working features
- Adaptive ("vertically mixed") audio system!! Trust us, even the most rabid Shining Force purist is going to **looove** this!!
- AI behavior variety (currently: aggressive and stationary only)

### Not Yet Started:
- Full base game content (we have placeholders - platform work is priority over content)
- Full SF-scale campaign with storyline and balanced progression

### Near-Term Focus:
2. Adding AI behavior variety
3. Polishing the editor experience
4. Demo campaign expansion and polish

---

## The "Game is a Mod" Architecture

For the technically curious:

```
core/           # Platform code - battle systems, shop logic, save/load
mods/           # ALL game content lives here
  _base_game/   # Our official content (priority 0)
  your_mod/     # Your content (priority 100+, overrides base)
```

Higher priority mods override lower priority resources with matching IDs. Want to rebalance Max? Create a `max.tres` in your mod with priority 5000 (or edit Mod Settings in the Sparkling Editor!). Your version wins. Mod conflicts are resolved alphabetically. Tut the overall design was intended to provide flexibility to the modding community while utilizing something of an "honor system" when it comes to setting your mod's priority. 

---

## Quick FAQ

**"Is this a finished game I can play right now?"**
Not yet - it's a platform first. We have working systems and placeholder content, but a full polished campaign is still in progress. If you want to create content or help test, come on in. If you want a complete game experience, please check back later.

**"Are you trying to 'fix' Shining Force?"**
Nope. We love SF as it is. The goal is to capture that feel faithfully, then let modders decide how they want to build on that.

**"I'm more of a Fire Emblem fan - is this for me?"**
The mechanics are specifically SF-flavored (no permadeath, different stat formulas, the Caravan system). If you want FE mechanics, SRPG Studio or FEBuilder are probably better fits. But if you're curious about SF-style tactical RPGs, welcome aboard.

---
## Who the hell are you and where did this come from??
Hi, I'm Josh - software enginner, lifelong Shining Force enthusiast, and fan of the Oxford comma. While not a name on Reddit, Imgurians may know me as Magnebro, Eden DaoC players as TungstenMan, or obscure podcast fans as 'the guy who made Space Busker 2061'.

**Sparkling Farce Origin Story**
I've been developing code since QBASIC on a Packard Bell 386, and playing Shining Force since about the same time. Like many others, I'd always dreamed of making my OWN, but even for a seasoned developer, that's a monumental task. I'm a Python developer first, Godot hobbyist second.  Recently my day job made agentic AI assistants mandatory, and I thought "If it can't help me with my dream project, it can't help me with my work project, so let's find out."

If you're anything like me, this likely triggered some "AI slop" alarm bells. If that's the case, check the code for yourself. I designed every system, I directed every workflow, I reviewed every commit. We've got extensive platform tests to verify new changes don't break existing functionaly.  We've got proper resource-based, data-driven architecture with exhaustive strict typing. This code works. There's plenty of room for polish, but it works.

Claude was the dogsled, I was the driver. If the design is weak, I'm the one to talk to.

In addition, there are two other people currently working on the art and content creation. 

---

## Moving Foward with the Community

It's probably clear from the above that while the foundation is strong, making this platform Peter-tier, and keeping it that way, will take more than three people and a robot. We're actively seeking co-maintainers for the project to improve quality and ensure that it can never be abandoned. If you've got Godot chops, come pick up your keys.  

The platform is in active development. We're showing working code because we've seen too many fan projects announce grand visions but struggle with delivery, **so we aimed to cover all the hard parts first**, then ask your help with making it shine. We'd rather show a functional foundation without relying on hope and trust, so kept this quiet until it would (hopefully) meet with community approval. At least as a starting point.

---

## Technical Details

- **Engine:** Godot 4.5
- **Language:** GDScript (strict typing throughout)
- **Test Coverage:** 36 test files, gdUnit4 framework
- **Platforms:** Development on Linux, but Godot exports to **Windows, Mac, Linux, and more**. Cross-platform from day one - this isn't a Linux-only project.

**Want to see it in action?** 

Here's the **live, working demo campaign** running on itch.io (http://placeholder.url)
And the GitHub repo (http://placeholder.url)
A video demonstrating a little bit of town, shop, caravan, and **battle action** (http://placeholder.url)
And another video of the process of creating a new mod, class, weapon and character and having them in-game in under 5 minutes (http://placeholder.url)

(Yeah, we thought you'd like that one)

---

**tl;dr:** Open-source Godot platform for creating Shining Force-style tactical RPG campaigns THAT ALREADY WORKS. SF2-authentic mechanics (yes, including the Caravan, the retreat system, class-based spells, and the field menu!). Full mod support with 15+ visual editors. Cross-platform (Windows/Mac/Linux). No ROM hacking, no hex editing. *Working code you can see today.* Come help us build the tools the SF community deserves.

---

*May your fire forever burn like Kiwi's breath*
