PLACEHOLDER TILESET ART
========================

These are simple placeholder tiles for engine testing and development.

TILE REFERENCE:
---------------
Terrain Tiles (walkable):
- grass.png (green #50C878) - Plains terrain, no effect
- road.png (brown #8B7355) - Walkable path, reduced MOV cost
- forest.png (dark green #228B22) - Forest, +1 DEF
- sand.png (tan #D2B48C) - Desert/beach, +1 MOV cost
- dirt.png (earthy brown #6B4423) - Dirt path, no effect
- bridge.png (wooden brown #8B4513) - Crosses water

Obstacle Tiles (impassable):
- wall.png (gray #808080) - Impassable obstacle
- water.png (blue #4682B4) - Impassable water (except flyers/swimmers)
- mountain.png (gray-brown #8B7765) - Impassable mountain, +2 DEF if adjacent

Interactive Tiles:
- door.png (yellow #FFD700) - Trigger interaction
- battle_trigger.png (red #DC143C) - Battle encounter trigger (testing only)

TILESET SOURCE IDs:
------------------
0 = grass (Plains)
1 = wall (Obstacle)
2 = water (Water)
3 = road (Road)
4 = forest (Forest)
5 = mountain (Mountain)
6 = sand (Sand)
7 = bridge (Bridge)
8 = dirt (Dirt Path)

REPLACEMENT WORKFLOW:
====================

These tiles are intentionally basic to serve as:
1. Reference implementation for tileset organization
2. Functional placeholders for collision/trigger testing
3. Templates for mod creators to replace

TO REPLACE THESE TILES:
-----------------------

Option 1: Direct Replacement (same mod)
  - Replace the PNG files in this directory with your own 16x16 art
  - Keep the same filenames
  - TileSet resources will automatically use the new art

Option 2: Override Mod (separate mod)
  - Create a new mod with higher priority (e.g., priority: 50)
  - Create matching directory structure: art/tilesets/placeholder/
  - Place your replacement PNGs with the same filenames
  - ModLoader will use your versions instead

Option 3: New TileSet (custom implementation)
  - Create your own tileset with custom organization
  - Create new TileSet resources in your mod
  - Reference your art assets
  - Use your custom tilesets in your maps

TECHNICAL NOTES:
===============
- All tiles are 16x16 pixels
- 8-bit sRGB PNG format
- Some tiles have noise/texture for visual distinction
- Designed for grid-based collision testing
- Battle trigger tile (red) should not appear in final games

GENERATING NEW TILES:
====================
Tiles can be generated with ImageMagick. Examples:

  # Solid color tile
  magick -size 16x16 xc:'#HEXCOLOR' -depth 8 tile.png

  # Tile with noise texture
  magick -size 16x16 xc:'#HEXCOLOR' -seed 42 +noise Uniform \
    -evaluate multiply 0.15 -depth 8 tile.png

  # Tile with horizontal lines (wood grain)
  magick -size 16x16 xc:'#8B4513' \
    \( -size 16x1 xc:'#654321' \) -geometry +0+5 -composite \
    -depth 8 tile.png

For more information on creating tileset mods, see:
/docs/MOD_SYSTEM.md
