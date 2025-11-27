# No Diagonals Allowed: The Movement Unification That Made Me Weep With Joy

**Stardate 47401.7 (November 26, 2025)**

You know what separates tactical RPG veterans from filthy casuals? How they react to diagonal movement.

When I see a character slide diagonally across a grid-based map, my eye twitches. It's like watching Kirk order a martini instead of Romulan ale. It's WRONG. It violates the sacred laws of tactical movement that Camelot Software established in 1992.

Commit 5a84027 just fixed something I didn't even know was broken, and I'm here to tell you why this "small" change matters more than you might think.

## The Problem: Cinematic Characters Going Rogue

Here's what was happening. In battle, units move correctly - cell by cell, up-down-left-right, like proper tacticians. The A* pathfinding system has `diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER` set right there in GridManager (line 72):

```gdscript
_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER  # 4-directional movement only
```

Beautiful. Perfect. Exactly what Shining Force demands.

BUT.

In narrative cinematics - cutscenes without a battle grid - the `_use_simple_movement()` function was doing something horrifying. It was taking waypoints and tweening between them in a STRAIGHT LINE. If a character needed to move from (5, 5) to (10, 10), they'd slide diagonally like some kind of Final Fantasy Tactics pretender.

The old code (now thankfully obliterated) looked something like this:

```gdscript
# OLD CODE - The heresy
for waypoint: Vector2i in waypoints:
    world_path.append(GridManager.cell_to_world(waypoint))

# Simple tween movement (DIAGONAL ABOMINATION)
for target_pos: Vector2 in world_path:
    var distance: float = parent_entity.global_position.distance_to(target_pos)
    var duration: float = distance / (movement_speed * GridManager.get_tile_size())
    move_tween.tween_property(parent_entity, "global_position", target_pos, duration)
```

See that `distance_to()` call? That's Euclidean distance. That's "as the crow flies." That's DIAGONAL.

## The Fix: Manhattan Pathfinding Everywhere

The new code expands waypoints into a proper cell-by-cell path using Manhattan pathfinding:

```gdscript
func _use_simple_movement(waypoints: Array[Vector2i], speed: float) -> void:
    is_moving = true
    movement_speed = speed if speed > 0 else default_speed

    # Build complete path using Manhattan pathfinding between waypoints
    # This ensures consistent 4-directional movement even without battle grid
    var complete_path: Array[Vector2i] = []
    var current_cell: Vector2i = GridManager.world_to_cell(parent_entity.global_position)

    for waypoint: Vector2i in waypoints:
        if waypoint == current_cell:
            continue
        var segment: Array[Vector2i] = _find_manhattan_path(current_cell, waypoint)
        # Skip first cell of segment (it's the current position) unless path is empty
        var start_idx: int = 1 if not complete_path.is_empty() else 0
        for i: int in range(start_idx, segment.size()):
            complete_path.append(segment[i])
        current_cell = waypoint
```

And here's the `_find_manhattan_path()` function that does the heavy lifting:

```gdscript
## Simple Manhattan distance pathfinding fallback (for cinematics without battle grid)
## Moves horizontally first, then vertically (4-directional movement)
func _find_manhattan_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
    var path: Array[Vector2i] = []
    var current: Vector2i = from

    path.append(current)

    # Move horizontally first
    while current.x != to.x:
        if current.x < to.x:
            current.x += 1
        else:
            current.x -= 1
        path.append(current)

    # Then move vertically
    while current.y != to.y:
        if current.y < to.y:
            current.y += 1
        else:
            current.y -= 1
        path.append(current)

    return path
```

Simple. Elegant. CORRECT.

Now when Spade and his Henchman move around in the opening cinematic, they step horizontally, then vertically. Just like Max. Just like Bowie. Just like every hero and villain in every Shining Force game ever made.

## Why This Matters: Visual Consistency Is Everything

Let me paint you a picture.

Imagine you're playing Sparkling Farce. The opening cinematic shows the villain Spade sneaking through an ancient temple. He moves cell-by-cell in cardinal directions because that's how the engine works now. Cool.

Then you get to battle. Your units move cell-by-cell in cardinal directions. Perfect.

Then you win the battle and a victory cutscene plays. But wait - suddenly characters are sliding diagonally? Your brain notices something is OFF even if you can't articulate it. The illusion breaks. The world feels inconsistent.

This is what we call "visual language" in game design. When movement works the same way everywhere - exploration, battle, cinematics - it creates a cohesive experience. The rules of the world remain consistent. Players subconsciously trust the game more.

Shining Force understood this. When you watched the intro where Kane attacks Guardiana, the soldiers moved on the same grid logic they'd use in battle. When Zeon's minions attacked King Granseal's castle in SF2, they marched in cardinal directions. The cutscenes and gameplay spoke the same language.

## The Bonus: Consistent Timing

Notice this line in the new code:

```gdscript
var duration: float = 1.0 / movement_speed  # Each cell takes consistent time
```

Each cell takes the same amount of time to traverse. No more variable-speed movement based on Euclidean distance. A 5-cell horizontal path takes the same time as a 3-cell-right-then-2-cell-down path.

This might seem minor, but it matters for animation synchronization. If you have background music or sound effects timed to movement, consistent cell-traversal speed means predictable timing. No more characters arriving early because they took the diagonal shortcut.

## The Technical Elegance

I want to highlight something clever here. The `_use_simple_movement()` function is for entities WITHOUT the full Unit component - basically simple NPCs in cinematics. The "real" movement system in `_use_parent_movement()` uses GridManager's full A* pathfinding.

But here's the beautiful part: both systems now produce VISUALLY IDENTICAL results. A* pathfinding with `DIAGONAL_MODE_NEVER` generates paths that move horizontally and vertically. Manhattan pathfinding generates paths that move horizontally and vertically. Same output, different algorithms, unified experience.

This is what good architecture looks like. Multiple systems converging on consistent behavior.

## What Shining Force Got Right

Let me put on my Shining Force historian hat.

In SF1 on Genesis, ALL movement was 4-directional. Towns, battles, even the world map. Characters moved in clean cardinal directions and it just FELT right for a tactical game.

SF2 continued this tradition. Even in the opening sequence where Bowie is running through the castle, he moves on the grid. The cutscenes maintain the same visual language.

The GBA remake of SF1? Same deal. They could have "modernized" movement with diagonal options, but they didn't. They understood that the grid-based movement wasn't a limitation - it was a DESIGN CHOICE.

Diagonal movement is for action RPGs. Cardinal movement is for tactical RPGs. It emphasizes the grid. It makes positioning feel deliberate. Every step matters because every step is discrete.

Sparkling Farce now honors this completely.

## My Only Nitpick

The Manhattan path algorithm always moves horizontally first, then vertically. This is fine for most cases, but it means characters will never take the "vertical first" path even if it would look more natural for a given scene.

In the original Shining Force, pathfinding was more sophisticated - it would sometimes move vertically first based on the specific route. The current implementation is deterministic (horizontal always first), which is predictable but slightly less organic.

That said, this is a MINOR quibble. For cinematic waypoint movement, the consistency is more important than route variation. And if a cinematic author wants a specific path, they can just add intermediate waypoints.

## The Verdict: This Is How You Honor a Classic

Commit 5a84027 is the kind of change that casual players might never notice, but dedicated fans will FEEL. It's the difference between "something seems off" and "this feels right."

The commit message says it all: "Characters now always move orthogonally matching the tactical RPG style of Shining Force."

MATCHING THE TACTICAL RPG STYLE OF SHINING FORCE.

That's not just code. That's a promise. That's a commitment to authenticity.

When I play games made with this engine, I want to feel like I'm playing a Shining Force successor. Not a generic tactics game. Not a Fire Emblem clone. A SHINING FORCE game. And that means respecting the visual language that made those games iconic.

**This commit gets an A+.** Small change, massive impact on game feel. This is what separates engines that "work" from engines that "feel right."

The diagonals have been vanquished. The cardinal directions reign supreme. Max would be proud.

*Justin out. Currently practicing my 4-directional walking pattern on the corridors of Deck 12. The crew thinks I'm weird but they just don't understand tactical purity.*

---

**Movement Unification Scorecard:**
- 4-Directional Enforcement: A+ (Cardinal directions everywhere)
- Code Elegance: A (Simple Manhattan algorithm, clean integration)
- Visual Consistency: A+ (Cinematics now match battle feel)
- Timing Consistency: A (Fixed cell duration, predictable movement)
- Path Naturalness: B+ (Always horizontal-first, slightly deterministic)
- Overall Impact: A+ (Small change, huge authenticity improvement)

*The Sparkling Farce Development Blog - Where Diagonals Go To Die*
*Broadcasting from the USS Torvalds, moving exclusively in cardinal directions*
