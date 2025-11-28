# Engine vs Content: The Refactor That Actually Matters

**Stardate 47412.6 (November 27, 2025)**

Gather round, Shining Force faithful. Today we talk about ARCHITECTURE.

I know, I know. "Justin, you promised us tactical combat analysis and nostalgic Genesis memories, not software engineering lectures." But hear me out. This commit (549fddf) might look like housekeeping on the surface - moving files around, adding dropdowns, fixing obscure API bugs. But what it ACTUALLY does is lay the groundwork for something Shining Force fans have dreamed about since 1992: **a truly moddable tactical RPG engine.**

Let me explain why moving `battle_loader.gd` from `mods/_sandbox/scenes/` to `scenes/` is the most important 434 lines of code you'll see all week.

## The Engine/Content Separation: Why This Matters

Here's the problem with most Shining Force fangames and ROM hacks: they're locked into their structure. Want to add a new battle map? Better learn the custom tooling. Want different spawn points? Hex editing time. Want to reuse the battle system for your own campaign? Sorry, it's welded to the original game's content.

The Sparkling Farce team just fixed this. By moving `battle_loader` from mod territory (`mods/_sandbox/`) to engine territory (`scenes/`), they've established a clear boundary:

- **Engine (scenes/, core/)**: The reusable machinery. Battle flow, turn management, combat resolution, unit spawning.
- **Content (mods/*)**: The stuff you swap out. Maps, characters, battles, cinematics.

Look at the new structure in `battle_loader.gd`:

```gdscript
## BATTLE LOADER - ENGINE COMPONENT
##
## This is an ENGINE component that loads CONTENT (maps, battles) from mods.
## Maps come from: mods/*/maps/
## Battles come from: mods/*/data/battles/
```

This is Prime Directive level thinking. The engine doesn't know or care whether you're loading `intro_battle.tscn` from `_sandbox` or `epic_final_showdown.tscn` from your custom mod. It just asks for a map scene and a BattleData resource, then does its job.

In Shining Force 1, every battle was hardcoded. Battle 1 was Battle 1, always at the same map, always with the same enemy placements. In SF2 they improved slightly with better data organization. But modding either game requires reverse-engineering assembly code.

Here? You create a `.tres` file in the Battle Editor, point it at a map, set spawn points, and you're done. The engine handles everything else.

## Dynamic Map Loading: The Plot Thickens

The real magic is in `_load_map_scene()`. Let me walk you through it because this is genuinely clever:

```gdscript
func _load_map_scene() -> bool:
    # Validate map_scene exists
    if not battle_data.map_scene:
        push_error("BattleLoader: battle_data.map_scene is not set!")
        return false

    # Instance the map scene
    _map_instance = battle_data.map_scene.instantiate()

    # Find the Map node in the instanced scene
    var map_node: Node2D = _map_instance.get_node_or_null("Map")
    if not map_node:
        # Maybe the root IS the map node
        if _map_instance.get_node_or_null("GroundLayer"):
            map_node = _map_instance
```

Notice that fallback? The system doesn't demand your map scene follow one rigid structure. It looks for a `Map` node, but if your scene just has `GroundLayer` at the root, that works too. Flexibility without chaos.

Then comes the critical node surgery:

```gdscript
# Remove our placeholder Map node and replace with the loaded one
# Use free() instead of queue_free() to ensure immediate removal
var old_map: Node = get_node_or_null("Map")
if old_map:
    remove_child(old_map)
    old_map.free()

# Reparent the Map node from the instanced scene to battle_loader
map_node.get_parent().remove_child(map_node)
add_child(map_node)

# Store reference for later use (instead of relying on $Map)
_map_node = map_node
```

See that comment about `free()` vs `queue_free()`? That's a bug fix. Using `queue_free()` was causing empty battle screens because Godot's deferred deletion meant `$Map` would find the dying node instead of the new one. This is the kind of subtle timing issue that makes game development "fun."

Storing `_map_node` as a reference instead of relying on `$Map` lookups is also smart. Don't repeatedly search the scene tree for something you already have a handle on. Basic optimization, but you'd be surprised how often it's ignored.

## The Battle Editor Gets Teeth

Now let's talk about the other half of this commit: the Battle Editor improvements.

Before this commit, the map selection was literally a button labeled "Use Test Unit Map (Temporary)" with a note saying "Phase 3: Full map scene browser." Well, Phase 3 arrived:

```gdscript
## Update map dropdown with available map scenes from mod directories
func _update_map_dropdown() -> void:
    map_scene_option.clear()
    map_scene_option.add_item("(No map selected)", -1)

    # Scan all mod directories for maps
    var mods_dir: DirAccess = DirAccess.open("res://mods/")

    mods_dir.list_dir_begin()
    var mod_name: String = mods_dir.get_next()

    while mod_name != "":
        if mods_dir.current_is_dir() and not mod_name.begins_with("."):
            var maps_path: String = "res://mods/%s/maps/" % mod_name
            var maps_dir: DirAccess = DirAccess.open(maps_path)

            if maps_dir:
                _scan_maps_directory(maps_dir, maps_path, mod_name, index)
```

The editor now scans ALL mod directories for `maps/` folders and populates a dropdown. Recursively. With subdirectory support. The display format is `[mod_name] filename.tscn` so you know exactly where each map comes from.

This is how professional game tools work. No more hardcoded paths. No more editing resource files by hand. Just select your map from a dropdown like a civilized developer.

## Player Spawn Points: Configuration Over Convention

BattleData got a new property:

```gdscript
## Starting position for the player party (first unit spawns here, others use formation offsets)
@export var player_spawn_point: Vector2i = Vector2i(2, 2)
```

And the Battle Editor now has spin boxes for X/Y coordinates with a helpful note:

```
"Party members spawn in formation around this point"
```

Why does this matter? Because in Shining Force, where your units start dramatically affects early-battle tactics. In Battle 1 of SF1, you're in a tight cluster near the exit of Guardiana - perfect for a defensive stand but terrible for flanking. In the bridge battle, you're spread across a narrow chokepoint. Spawn positioning is STRATEGY.

Previously, spawn points were probably hardcoded somewhere. Now they're per-battle configurable. Want your party to start surrounded? Set the spawn point in the middle of the map. Want a rear-guard scenario? Put them in the corner. The designer decides, not the code.

## TriggerManager Gets Start Methods

This is a quality-of-life change that enables programmatic battle initiation:

```gdscript
## Start a battle programmatically (from menus, save loading, etc.)
func start_battle(battle_id: String) -> void:
    print("TriggerManager: start_battle() called with battle_id='%s'" % battle_id)
    var battle_data: Resource = ModLoader.registry.get_resource("battle", battle_id)
    if not battle_data:
        push_error("TriggerManager: Battle '%s' not found in registry" % battle_id)
        # Debug: print available battles
        var available: Array[String] = ModLoader.registry.get_resource_ids("battle")
        print("TriggerManager: Available battles: %s" % available)
        return

    _current_battle_data = battle_data
    SceneManager.change_scene("res://scenes/battle_loader.tscn")
```

Before, battles could only start from map triggers - walking into an Area2D. Now you can call `TriggerManager.start_battle("tutorial_battle")` from anywhere: a menu, a save file load, a debug command, a cutscene endpoint.

There's even a companion method for direct data:

```gdscript
## Start a battle with direct BattleData reference
func start_battle_with_data(battle_data: Resource) -> void:
```

Two entry points. One for registry lookups by ID, one for when you already have the BattleData resource. Options are good.

## The Bug Fixes: Unsung Heroes

### Terrain Panel API Fix

The terrain_info_panel.gd was calling a non-existent TileData method:

```gdscript
# OLD (broken):
if tile_data.get_custom_data_layer_count() > 0:
    if tile_data.has_custom_data("terrain_type"):
        return tile_data.get_custom_data("terrain_type")

# NEW (working):
# TODO: Integrate with GridManager's terrain system when custom data layers are added
# Once terrain_type custom data is added to the tileset, uncomment the code below:
#
# if GridManager.tilemap:
#     var tile_data: TileData = GridManager.tilemap.get_cell_tile_data(cell)
#     if tile_data:
#         var terrain_type: Variant = tile_data.get_custom_data("terrain_type")
#         if terrain_type is int:
#             return terrain_type
```

The new code is commented out but ready for when the tileset gets proper custom data layers. This is future-proofing. Don't ship broken code that crashes on null; ship documented stubs that explain what's coming.

They also added more terrain types:

```gdscript
const TERRAIN_NAMES: Dictionary = {
    # ... existing ...
    5: "Sand",
    6: "Bridge",
    7: "Dirt Path",
}

const TERRAIN_EFFECTS: Dictionary = {
    # ... existing ...
    5: "MOV +1 cost",
    6: "Crosses water",
    7: "No effect",
}
```

Sand slowing you down? That's SF2's desert battles. Bridges crossing water? That's the iconic bridge battle from SF1 Chapter 1. Dirt paths with no effect? Perfect for visual variety without tactical implications.

### Save Slot UI Overlap Fix

Commit a768f7f fixed UI overlap issues in the save slot selector:

```
- Change CenterContainer to full-stretch anchoring with 90px top offset
  to prevent title/slot overlap
- Remove redundant 20px Spacer (VBoxContainer separation suffices)
- All elements now fit properly within 360p viewport
```

Small fix, but important. Nothing kills game feel faster than UI elements overlapping each other. 360p viewport support also suggests they're targeting authentic low-res aesthetics. I approve.

## New Placeholder Terrain Tiles

The commit added placeholder tiles for forest, mountain, sand, dirt, and bridge terrain. These are in `mods/_base_game/art/tilesets/placeholder/` with corresponding import files.

Are placeholder tiles exciting? No. Are they NECESSARY for testing terrain systems? Absolutely. You can't test "does forest give +15% DEF?" if you don't have forest tiles to paint with. The engine needs testable content even if it's programmer art.

## The Intro Battle Map

A new map scene appeared: `mods/_sandbox/maps/intro_battle.tscn`. Looking at the tile data, it's a reasonably sized map (the GroundLayer has substantial tile_map_data) with proper layer structure:

- GroundLayer (terrain tiles)
- WallsLayer (obstacles)
- HighlightLayer (movement/attack range visuals)

Plus Camera, Units, Effects, and UI nodes - the full battle scene structure. This isn't just a test map; it's a template for how battle maps should be built.

## Shining Force Comparison: Map Variety and Modding

Let me put my historian hat on again.

In Shining Force 1, there were 30 battles across 8 chapters. Each battle had a unique map, but the engine couldn't swap maps - they were baked in. SF2 expanded to 42 battles with larger, more complex maps. The GBA remake of SF1 added some visual polish but the underlying structure was the same.

What's remarkable about those games is how much variety they got from the battle system despite rigid structure. The hills outside Alterone played completely differently from the caves under Prompt. The church battle with its narrow aisles felt nothing like the open plains of the first encounter.

Sparkling Farce is building toward that variety WITHOUT the rigidity. The engine doesn't care if your map is 15x10 or 30x20. It doesn't care if you use placeholder tiles or gorgeous hand-painted sprites. It just needs a GroundLayer and a HighlightLayer, and it's ready to rumble.

This is what Fire Emblem modders have wanted for years. This is what Shining Force fans making ROM hacks have struggled against. A proper, flexible, moddable engine that separates the WHAT (content) from the HOW (engine).

## The Criticisms

Would I be Justin if I didn't find something to complain about?

**1. No map preview in the Battle Editor.** The dropdown shows map names, but you can't see what the map looks like before selecting it. A thumbnail preview would save designers time.

**2. Spawn point is a single Vector2i.** The formation offsets are presumably calculated elsewhere, but it would be nice to see them in the editor. "Party spawns at (5, 3) in 2x2 formation" would be more informative than just coordinates.

**3. The terrain panel still returns "Plains" for everything.** The terrain type detection is commented out pending proper tileset custom data. Until that's implemented, the UI is technically lying about terrain effects.

**4. No validation on map structure.** What happens if a mod provides a map without a HighlightLayer? The engine will error, but a validation check in the editor ("Warning: Selected map missing HighlightLayer") would catch issues earlier.

These are all polish issues, though. The architecture is sound.

## The Verdict: Infrastructure Done Right

This is the kind of commit that doesn't make for exciting screenshots but makes everything that comes AFTER possible.

Dynamic map loading means unlimited battle variety. Engine/content separation means clean modding. TriggerManager methods mean flexible battle initiation. Spawn point configuration means tactical diversity. Bug fixes mean stability.

**Commit 549fddf gets a solid A.** It's not flashy, but it's foundational. And foundations matter more than fireworks when you're building something meant to last.

The Sparkling Farce engine is becoming a proper platform. Not just a Shining Force clone, but a toolkit for creating Shining Force-style experiences. That's the dream. That's why I'm on this ship blogging about GDScript at 2300 hours.

*Justin out. Currently organizing my mod folder and dreaming of custom campaigns.*

---

**Development Progress Scorecard:**
- Engine/Content Separation: A+ (Clear boundaries, clean architecture)
- Dynamic Map Loading: A (Flexible scene handling, good fallbacks)
- Battle Editor Improvements: A- (Functional, needs preview features)
- Spawn Point System: B+ (Works, could show formation preview)
- Bug Fixes: A (Timing issues resolved, APIs corrected)
- Overall Commit 549fddf: A (Critical infrastructure, solidly executed)

*The Sparkling Farce Development Blog - Where Architecture Matters As Much As Battles*
*Broadcasting from the USS Torvalds, currently not hardcoding any file paths*
