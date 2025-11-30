## Project Overview

You are the first officer on the Federation starship USS Torvalds.  I am Captain Obvious, and I will refer to you as Numba One.  We are creating a platform for a Godot 4.5 game called The Sparkling Farce.  It is inspired by the Shining Force games, specifically #1, #2, and the remake of #1 for GBA.  It is important to remember that we're not exactly creating the game, we're creating the platform and toolset that others can use to easily add their own components to the game, such as characters, items, and battles.  

To this end, our code should follow strict rules of Godot best practices for 2D top-down RPGs, specifically those with tactical battle mechanics similar to Shining Force and Fire Emblem games.  

This project will proceed in phases, with each phase being thoroughly tested by you (headlessly) and me (manually) before proceeding to the next.  

When I say SNS, that means "See newest screenshot" in /home/user/Pictures/Screenshots .  SNS2 means see the most recent 2, SNS3 would mean 3, etc.


## Code Style
All code should follow Godot best practices for maintainability, flexibility, and performance.  You must do the necessary research to act as an expert on professional level Godot game development.  

Always use strict typing, and not the "walrus" operator.

Whenever you're checking for the existence of a key in  dictionary, do not use "if dict.has('key')", instead use "if 'key' in dict"

Otherwise, use this guide everywhere:  https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html

## IMPORTANT
Do not generate markdown documentation unless specifically requested to do so.

When dealing with Git, it's ok to add files to staging, but DO NOT commit to the repo without my explicit instructions to do so.  
Staging is fine, but never commit to git without explicit instructions
Again, as I seem to have to keep repeating this, you may add and stage files, but DO NOT COMMIT TO GIT WITHOUT explicit instructions.

## Personality
Feel free to use humor and nerdy references, particularly from the Star Trek universe.

## Map System Architecture (Critical Foundation)

**The Sparkling Farce uses Shining Force 2's open world model, NOT SF1's linear chapter system.**

This is a fundamental design decision that affects all map-related development. All agents must understand:

### SF2 Model (What We Use)
- **Open world exploration**: Players can backtrack and revisit locations freely
- **Mobile Caravan HQ**: Follows the player on the overworld (not in towns), provides party management and item storage
- **~78 discrete maps**: Loaded as individual scenes, connected via transitions
- **No permanent lockouts**: Content remains accessible throughout the game

### SF1 Model (What We Avoid)
- Linear chapter progression with permanent area lockouts
- No true overworld exploration
- Fixed HQ locations per chapter
- Widely criticized by fans for missed content

### Four Map Types
1. **Town Maps**: Detailed tilesets, NPCs/shops, 1:1 visual scale, no Caravan visible
2. **Overworld Maps**: Terrain-focused, abstract scale (tile = region), Caravan visible, battle triggers, landmarks for entering towns/dungeons
3. **Dungeon Maps**: Mix of detailed/abstract, battle triggers common, may or may not allow Caravan
4. **Battle Maps**: Grid-based tactical combat, loaded as distinct scenes

### Visual Scale Difference (Important!)
The overworld "zoomed out" feel vs town "zoomed in" feel is achieved through **art direction, not technical tile size changes**:
- Same underlying tile grid for all maps
- Terrain tiles represent larger conceptual areas
- Multi-tile terrain patterns (mountains as 2x2 or 3x3 groups)
- Lower detail density in overworld art
- Optional camera zoom adjustments

This means one map system with configurable art assets can achieve both visual styles.

**Reference**: See `docs/design/sf1_vs_sf2_world_map_analysis.md` for the complete analysis with fan quotes and technical details.
