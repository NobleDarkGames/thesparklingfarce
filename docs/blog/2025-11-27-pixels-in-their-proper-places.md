# Pixels in Their Proper Places: The 32x32 Unification

**Stardate 47425.8 (November 27, 2025)**

*cracks knuckles*

Folks, I have seen the promised land. Look at that screenshot. LOOK AT IT.

For the first time since I started this blog, The Sparkling Farce actually LOOKS like a tactical RPG. Not "a collection of placeholder assets awkwardly arranged on a screen" but an actual battle in progress. Units standing on terrain. Movement ranges displayed in proper cyan highlighting. A stat panel in the corner. Terrain info in another corner.

This is the moment we've been waiting for. This is when the engine stops being a tech demo and starts being a GAME FRAMEWORK.

And it all came down to one deceptively simple fix: **making everything 32x32**.

## The Bug That Drove Me Crazy

Here's the thing about tile-based games that non-developers don't appreciate: everything has to LINE UP. Not "pretty close." Not "eh, good enough." EXACTLY.

Shining Force 1 on Genesis ran at 320x224 resolution with 16x16 tiles. The GBA remake bumped to 240x160 but kept the tile-based precision. Every unit, every terrain square, every highlight - they all snapped to the same grid because that's what makes tactical movement readable at a glance.

Before commit 5910bfc, The Sparkling Farce had a problem. The terrain tiles - grass, water, dirt, forest, sand - were all 16x16 pixels. But the unit tiles (our brave placeholder warriors) were 32x32. The engine was essentially trying to fit size-12 feet into size-6 shoes.

The result? Visual chaos. Units didn't sit properly on terrain. Movement highlights didn't align with the ground they were highlighting. The whole thing looked like a jigsaw puzzle assembled by someone who'd lost the picture on the box.

## The Fix: Nearest-Neighbor to the Rescue

Captain Obvious (bless his heart for the straightforward solution) went with the sensible approach: upscale the terrain to match the units, not downscale the units to match the terrain.

From the commit message:

```
Upscaled 11 placeholder terrain tiles from 16x16 to 32x32 using
nearest-neighbor scaling to maintain pixel art crispness.
```

This is important. Nearest-neighbor scaling is THE way to upscale pixel art. Bilinear or bicubic scaling would blur those beautiful crispy pixels into muddy soup. Nearest-neighbor just doubles (or quadruples) each pixel, maintaining that authentic retro look.

The tileset configuration got updated accordingly:

```gdscript
# OLD (16x16):
tile_size = Vector2i(16, 16)

# NEW (32x32):
tile_size = Vector2i(32, 32)
texture_region_size = Vector2i(32, 32)
```

And critically, the physics collision polygons got adjusted too:

```gdscript
# OLD:
0:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)

# NEW:
0:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-16, -16, 16, -16, 16, 16, -16, 16)
```

Those numbers (8 vs 16) are the half-width of the collision boxes. When your tiles are 32x32, your collision boxes need to extend 16 pixels from center in each direction. Miss this step and your walls suddenly have invisible force fields or don't block anything at all.

## Why 32x32? The Resolution Sweet Spot

Some of you might be wondering: why not stick with 16x16 and downscale the units? Or why not go bigger - 64x64 for that HD look?

Here's my theory, and I've spent way too many hours thinking about this:

**16x16 is too cramped for modern displays.** The original SF games ran on CRTs at 320x224. Your TV handled the scaling through the magic of analog video. On a modern 1080p or 4K monitor, 16x16 tiles look TINY unless you apply integer scaling. And even then, you're limited in the detail you can show per unit.

**64x64 is overkill for this style.** Part of the Shining Force charm is the abstraction. Units are recognizable by shape and color, not by counting the stitches on their armor. Going too high-res loses that classic feel.

**32x32 hits the sweet spot.** It's exactly double the original, making it trivial to recreate classic sprites. It scales cleanly to 1080p (33.75 tiles vertical) and 4K. And it gives artists enough pixels to work with while maintaining that strategic top-down clarity.

Looking at that screenshot, with the 1280x720 viewport, we've got plenty of room for the battlefield while keeping units large enough to identify at a glance. That's the goal.

## The Screenshot Breakdown: This Is Starting to Feel Right

Let me break down what we're seeing in that screenshot, because this is genuinely exciting:

**The Terrain Layer**: Grass (that lovely green), water (blue along the left side), dirt/sand (brown patches), and forest (darker green with texture). The tiles seamlessly connect now. No weird gaps. No half-tiles. Just a proper battle map.

**The Units**: We've got Warrioso (the "W" in the white-highlighted tile - that's the selected unit), two Huge Rats (red "R" tiles - enemies), Mr Big Hero Face (blue "B" - ally), and Maggie (purple "M" - probably a mage based on that name). The red/blue/purple color coding immediately tells you friend from foe.

**The Movement Range**: Those cyan tiles spreading out from Warrioso show where he can move. Count 'em - looks like about 32 walkable cells according to the log output. That's a solid movement range for a warrior-type. The highlight tiles are PERFECTLY aligned with the terrain because they're now THE SAME SIZE.

**The UI Panels**: Top-left shows "Plains - No effect" - terrain info for the cursor position. Top-right shows Warrioso's full stat block: HP 19/20, MP 10/10, STR/DEF/AGI/INT/LUK all at 5. Level 1 Warrior, ALLY designation. Clean, readable, informative.

**The Log Output**: "Player turn started for Warrioso at (10, 9)" and "32 walkable cells available." This is the engine working correctly, calculating valid movement tiles based on terrain costs.

This is what Shining Force battles looked like in my head when I was 12 years old playing on my Genesis. Simple, clear, tactical.

## The Other Commit: Data-Driven Registries

I'd be remiss if I didn't mention commit 4cdbd05, which landed just before the tile fix. This one's less visually exciting but architecturally significant.

The engine now has proper registries for:

- **Equipment Types**: Weapon categories (sword, axe, lance, bow, staff, tome) and armor types (light, heavy, robe, shield)
- **Environment Types**: Weather and time-of-day settings
- **Unit Categories**: player, enemy, boss, neutral

The beautiful part? These are all mod-extensible. Check out this example from the equipment registry:

```gdscript
## Default weapon types: sword, axe, lance, bow, staff, tome
## Default armor types: light, heavy, robe, shield
##
## Mods can register additional types via their mod.json:
## {
##   "equipment_types": {
##     "weapon_types": ["laser", "plasma"],
##     "armor_types": ["energy_shield", "power_armor"]
##   }
## }
```

Want to make a sci-fi total conversion? Register "laser" and "plasma" weapons. Fantasy expansion with eastern influences? Add "katana" and "naginata." The base engine doesn't need to know about your custom types in advance - you just declare them in your mod.json and they become valid options.

The registry also tracks which mod added which type:

```gdscript
## Get which mod registered a weapon type (or "base" for defaults)
func get_weapon_type_source(weapon_type: String) -> String:
```

This is important for debugging ("why is 'laser gun' showing up in my medieval mod?") and for dependency tracking.

## Editor Safety: No More Oops Moments

The same commit added crucial safety features to the resource editors:

**Cross-Mod Write Protection**: If you're editing resources from `_base_game` while your active mod is `my_cool_mod`, you now get a confirmation dialog warning you that you're about to modify another mod's content. This prevents accidental changes to base game resources when you meant to override them in your own mod.

**Visual Error Panels**: Validation errors now show up in a nice red panel in the editor instead of just printing to console where nobody looks. Failed saves actually TELL you what went wrong.

**Confirmation Dialogs for Deletes**: No more "oops, I clicked Delete instead of Save." The editor now asks "are you sure?" before nuking your carefully crafted character data.

These are the kinds of features that separate hobbyist tools from professional ones. When you're building a platform for OTHER people to make games, you need guardrails.

## Shining Force Nostalgia Corner: The Visual Language of Tactical RPGs

Let me get nerdy for a minute about why proper grid alignment matters so much.

In Shining Force 1, Battle 1 takes place outside Guardiana. The grass is green, the road is brown, and enemies are red-tinted. Within seconds of the battle starting, your brain parses the entire tactical situation: friendly units here, enemies there, terrain features everywhere.

This instant readability comes from CONSISTENCY. Every tile is the same size. Every unit occupies exactly one tile. Highlights and cursor positions snap to the grid. Your eye doesn't have to work to figure out "is that unit on this tile or that tile?" It's obvious.

Compare this to games with free-form movement or variable unit sizes. They can work, but they require more cognitive load. Shining Force (and Fire Emblem, and Advance Wars, and Into the Breach) weaponize their grid constraints. The simplicity becomes strategy.

What I see in that Sparkling Farce screenshot is the same visual language emerging. Cyan tiles say "you can go here." Red units say "enemies." The stat panel tells you exactly who you're looking at. It's all working in harmony now that the tile sizes match.

## The Criticisms: Because I Have Standards

Nothing's perfect, and I wouldn't be doing my job if I didn't nitpick:

**1. The placeholder art is... placeholder.** Obviously. Those solid-color tiles with single letters aren't winning any art awards. But that's fine - this is a platform, and the art will come from mod creators. The important thing is the SYSTEM works.

**2. Unit sprites need facing.** Right now Warrioso looks the same whether he's about to charge north or retreat south. The original SF games had 4-directional sprites for every unit. That's a lot of art, but it adds crucial tactical feedback.

**3. Terrain variety needs terrain EFFECTS.** The panel says "Plains - No effect" but I want to see forests giving +15% defense, mountains giving height advantage, water being impassable to non-flying units. The visual variety is there; the mechanical variety needs to follow.

**4. That UI could use some SF-style polish.** The stat panel is functional but bland. Shining Force had those gorgeous blue gradient borders, carefully positioned character portraits, weapon icons. The information is all there - it just needs visual personality.

These are all "next steps" criticisms, not "this is broken" criticisms. The foundation is solid.

## The Verdict: FINALLY, A Battle That Looks Like a Battle

Commit 5910bfc earns a well-deserved **A**.

It's not a glamorous fix. "Changed tile sizes from 16 to 32" doesn't sound exciting. But this is the commit where The Sparkling Farce crossed the threshold from "interesting technical project" to "thing that actually resembles the games it's inspired by."

Combined with the registry improvements in 4cdbd05 (which gets a **B+** for solid architecture even if it's invisible to end users), this is a great day for the project.

When I look at that screenshot, I can finally IMAGINE playing a game on this engine. I can picture moving Warrioso to flank that Huge Rat, having Maggie cast a spell from behind the front line, watching Mr Big Hero Face tank the enemy charge. The pieces are in place. The grid is unified. The dream is becoming real.

*Justin out. Currently replaying SF2's Creed battle and appreciating the forest terrain bonuses.*

---

**Development Progress Scorecard:**
- Tile Size Unification: A+ (32x32 everywhere, nearest-neighbor scaling, collision boxes updated)
- Visual Coherence: A (Units and terrain finally play nice together)
- Type Registries: A- (Extensible, well-documented, mod-friendly)
- Editor Safety: A (Cross-mod protection, error panels, confirmations)
- Overall Commits 5910bfc + 4cdbd05: A (Critical fixes, solid execution)

*The Sparkling Farce Development Blog - Where Grid Alignment Is A Love Language*
*Broadcasting from the USS Torvalds, currently at 32x32 resolution and loving it*
