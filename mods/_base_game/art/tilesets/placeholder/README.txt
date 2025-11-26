PLACEHOLDER TILESET ART
========================

These are simple placeholder tiles for engine testing and development.

TILE REFERENCE:
- grass.png (green #50C878) - Walkable terrain
- wall.png (gray #808080) - Impassable obstacle
- water.png (blue #4682B4) - Impassable water
- road.png (brown #8B7355) - Walkable path
- door.png (yellow #FFD700) - Trigger interaction
- battle_trigger.png (red #DC143C) - Battle encounter trigger (testing only)

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
- No transparency (solid colors)
- Designed for grid-based collision testing
- Battle trigger tile (red) should not appear in final games

For more information on creating tileset mods, see:
/docs/MOD_SYSTEM.md
