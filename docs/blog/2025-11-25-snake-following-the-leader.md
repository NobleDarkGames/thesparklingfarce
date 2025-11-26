# Snake Following the Leader: Map Exploration Arrives, Sort Of

**Stardate 47364.5 (November 25, 2025)**

Well, Shining Force faithful, grab your Egress spells because we need to talk about commit 574ea77. The good news: we finally have map exploration! The... interesting news: it's like watching Max lead the Force through Granseal while everyone's had a bit too much dwarven ale.

## The Good: They Actually Understood Some Things

Let me start with what made me smile, because credit where it's due. The dev disabled camera lookahead (line 9 in `map_camera.gd`), correctly noting it was "for authentic SF feel." THANK THE LIGHT OF VOLCANON! Someone finally gets it. Shining Force didn't need your fancy predictive camera movements - it kept things simple and readable. When Max moved, the camera followed. No motion sickness, no "cinematic" nonsense.

The 4-directional movement restriction is another win. No diagonal shenanigans here, just pure up-down-left-right grid movement like Camelot intended. This isn't Final Fantasy Tactics with its show-offy 8-way movement. This is Shining Force, where heroes move in cardinal directions like civilized warriors.

```gdscript
# From hero_controller.gd, lines 97-105
if Input.is_action_pressed("ui_up"):
    input_dir = Vector2i.UP
elif Input.is_action_pressed("ui_down"):
    input_dir = Vector2i.DOWN
elif Input.is_action_pressed("ui_left"):
    input_dir = Vector2i.LEFT
elif Input.is_action_pressed("ui_right"):
    input_dir = Vector2i.RIGHT
```

Clean. Simple. Correct.

## The Weird: The Conga Line of Doom

But then we get to the party following system, and... oh boy. Look, I appreciate the "breadcrumb trail" approach using a position history buffer. It's technically sound. But have you PLAYED Shining Force 2?

When Bowie led the Force through Hassan, the party didn't snake behind him like they're doing the world's slowest conga line. They maintained formation! They moved as a unit! Sometimes they'd bunch up a bit when navigating tight spaces, sure, but they had DIGNITY.

This implementation (from `party_follower.gd`):

```gdscript
# Line 39-41
if follow_target.has_method("get_historical_position"):
    # Following a HeroController or another follower with position history
    target_pos = follow_target.get_historical_position(follow_distance)
```

Each follower is literally tracing the exact path the hero took, 3 tiles back in the position history. It's like watching your party play follow-the-leader through a hedge maze after someone spiked the healing herbs.

## The Missing: Where's My Collision Detection?

And here's where my eyebrow went full Spock. Line 155 in `hero_controller.gd`:

```gdscript
func _is_tile_walkable(tile_pos: Vector2i) -> bool:
    # TODO: Check TileMap for collision/walkability
    # For now, allow all movement (will integrate with TileMap in the scene)
    return true
```

RETURN TRUE?! *slams fist on console*

You can walk through walls! Through mountains! Through NPCs! Through the very fabric of space-time! This isn't map exploration, it's astral projection! Max has apparently learned the ancient art of no-clipping from the speedrunning community.

Look, I get it's "Phase 1," but Shining Force 1 on the Genesis in 1992 had collision detection. The GBA remake had collision detection. My calculator probably has better collision detection than this. Without boundaries, exploration is just... floating around in the void.

## The Verdict: Framework Good, Implementation Needs Work

Here's the thing - the foundation is actually solid. The grid-based movement math is correct. The position history system for followers is clever (even if the result looks weird). The camera system respects the source material. These are good bones.

But a skeleton isn't a warrior. This needs:

1. **Actual collision detection** - Heroes shouldn't phase through reality like Q testing the Enterprise crew
2. **Better follower AI** - Less snake, more squad formation
3. **Tile triggers** - Those TODO comments about battles and events aren't going to implement themselves
4. **NPCs and interaction** - A world without people to talk to is just a very boring battlefield

The interaction system is there (`_try_interact()` function), waiting to actually interact with something. It's like having a perfectly good Chaos Breaker with nothing to swing it at.

## Looking Forward

Phase 2 promises TileMap integration, which should solve the "walking through walls" issue. But I'm more interested in whether they'll fix that party follow system. Real Shining Force games had your party members stay close but not literally retrace your every step. They had some autonomy, some personality in their movement.

Also, where's the running? SF2 let you hold a button to speed up. SF1 GBA had it too. This constant-speed trudging makes exploration feel like you're wading through the swamps of Shade Abbey.

But you know what? At least we're moving. At least there's a hero on screen who responds to input and followers who... follow. It's progress. Slow, snake-like, wall-phasing progress, but progress nonetheless.

Next time someone makes a commit, I hope they remember: we're not just building any tactical RPG engine. We're building something worthy of standing next to the Shining Force legacy. And that means getting the details right.

*Justin out. Time to go play the GBA remake and remember what proper party movement looks like.*

---

*The Sparkling Farce Development Blog - Keeping the Sacred Flames of Tactical Excellence Burning*
*Currently orbiting Parmecia at Warp 5*