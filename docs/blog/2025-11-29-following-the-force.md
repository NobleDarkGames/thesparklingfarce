# Following the Force: Nine Commits That Made Me Believe Again

**Stardate 88429.2** | Justin's Tactical Analysis from Deck 7

---

Alright, fellow tacticians. Grab your Chirrup Sandwiches and settle in, because the past 24 hours on the USS Torvalds have been *wild*. We went from "promising prototype" to "holy Creed, this actually feels like Shining Force 2" faster than Zynk can steal your best equipment and join the enemy.

I'm covering **nine commits** today, and I need to lead with the thing that made me literally stand up from my console and do a little fist pump: **they rejected Fire Emblem mechanics.** But I'm getting ahead of myself. Let's break this down like Mae breaks goblin formations.

---

## The Big Picture: Open World or Bust

Before we dive into the individual commits, I need to talk about the elephant in the room - or rather, the *Caravan* on the world map.

Commit `20ec850` dropped an 807-line implementation plan and a full research document called `sf1_vs_sf2_world_map_analysis.md`. The team didn't just pick SF2's open world model over SF1's chapter system - they *documented why* with actual fan quotes.

Here's my favorite excerpt from the analysis:

> "I HATE being pushed chapter to chapter. I love overworlds... soooo SF2 wins my vote"

SAME, anonymous internet person. SAME.

For those of you who've only played SF1 (or worse, only know Shining Force from that one mobile game we don't talk about), SF1 locks you out of areas permanently when chapters end. Missed Domingo's egg? Too bad. Forgot to recruit Hanzou? He's gone forever. It's the tactical RPG equivalent of a one-way airlock.

SF2 said "what if players could... go places?" Revolutionary, I know. But that Caravan system - your mobile HQ that follows you on the overworld - was genuinely brilliant for 1993 and remains brilliant now.

The Sparkling Farce is building SF2's model from the ground up, not bolting it on later. That's the kind of decision that separates a love letter from a fan wiki printout.

---

## The Chain Following System: Finally, Someone Gets It

**Commit:** `3f0f49e` - "refactor: Implement SF2-style chain following for party members"

This is the commit that made me message Captain Obvious at 0200 hours ship time. Look at this code from `party_follower.gd`:

```gdscript
## SF2-AUTHENTIC: All followers read from HERO's history at different depths
const TILES_PER_FOLLOWER: int = 1  ## Spacing between followers (1 = tight, 2 = loose)
const CASCADE_DELAY_MS: float = 80.0  ## Milliseconds delay per follower in chain
```

You know what this is? This is someone who actually PLAYED Shining Force 2 on the world map and paid attention to how your party moves.

In SF2, when Bowie walks north, Sarah doesn't teleport to his previous position - she *follows the path*. And Chester doesn't mirror Sarah - he follows *her* trail. It creates this beautiful ripple effect, like dominoes falling in formation.

The old system was position-based following. Characters would lerp toward the hero's old coordinates like GPS units recalculating. It worked, technically. But it felt like herding cats, not leading the Shining Force.

The new system tracks *tile history*:

```gdscript
## Get a tile from the hero's tile history (SF2-style).
## tiles_back: How many tiles back in history (0 = current tile, 1 = previous tile, etc.)
func get_historical_tile(tiles_back: int) -> Vector2i:
    tiles_back = clampi(tiles_back, 0, tile_history.size() - 1)
    return tile_history[tiles_back]
```

Hero maintains 32 tiles of history. Follower 1 reads from `tile_history[1]`. Follower 2 reads from `tile_history[2]`. The 80ms cascade delay between movements creates that satisfying "snake game" ripple.

**Verdict: Thumbs WAY up.** This is the kind of authentic detail that separates fan games from fangames.

---

## Map Metadata: The Unsexy Foundation

**Commit:** `20ec850` - "feat: Implement Map System Phase 1 - MapMetadata, SpawnPoints, spawn resolution"

80+ unit tests. EIGHTY. PLUS.

Look, I know test-driven development isn't as exciting as new battle animations. But when Captain Obvious decides to add the Caravan system in Phase 2, or when a modder wants to create a whole new continent, they're going to be *very* glad someone wrote tests for spawn point resolution.

The `MapMetadata` resource defines five map types:

```gdscript
enum MapType {
    TOWN,       ## Detailed interior/building tilesets, no Caravan visible, 1:1 scale
    OVERWORLD,  ## Terrain-focused, Caravan visible and accessible, zoomed out
    DUNGEON,    ## Mix of styles, battle triggers common, Caravan optional
    BATTLE,     ## Tactical grid combat (loaded separately from exploration)
    INTERIOR    ## Sub-locations within towns (shops, houses, churches)
}
```

And here's where the SF2 authenticity shines - the overworld gets a 0.8x camera zoom:

```gdscript
MapType.OVERWORLD:
    caravan_visible = true
    caravan_accessible = true
    camera_zoom = 0.8
    random_encounters_enabled = true
```

That slight zoom-out creates the "traveling across the land" feeling without changing the underlying tile system. Same grid, different art direction. It's exactly how SF2 achieved its dual-scale feel.

**Verdict: Thumbs up.** Not flashy, but absolutely essential infrastructure.

---

## The Game Juice: Polish That Doesn't Compromise

**Commit:** `08ad9f5` - "feat: Add game juice polish and SF2-style turn order panel"

Okay, here's where things get *interesting*.

The commit message mentions that turn phase banners and double-attack mechanics were "initially added but REMOVED because they were Fire Emblem mechanics, not Shining Force."

*They removed features because they weren't authentic.*

In an era where every tactics game copies Fire Emblem's player-phase/enemy-phase structure, the Sparkling Farce team said "No. Shining Force uses AGI-based individual turns, and that's what we're building."

The turn order panel they DID implement is pure SF2:

```gdscript
## TurnOrderPanel - Shows upcoming unit turns in the AGI-based queue
##
## Displays current unit + next 2 units in turn order with faction color bars.
## Authentic to Shining Force 2's individual turn system (no phases).
```

Current unit plus the next two. Faction color bars (blue for allies, red for enemies, yellow for neutrals). Visual hierarchy with brightness levels for emphasis. It's clean, it's useful, and it doesn't lie to you about how the turn system works.

The `GameJuice` autoload is similarly restrained:

```gdscript
enum CombatAnimationMode {
    FULL,      ## Show full combat animation with all effects
    FAST,      ## Play at 2x speed
    MAP_ONLY,  ## Skip animation entirely, show damage on map
}
```

No "cinematic camera" option. No "dramatic zoom" toggle. Just the settings SF2 would have had if it could pause and ask "do you want to watch this attack animation for the 300th time?"

The cursor bob animation is a nice touch too - 2 pixels of vertical movement on a 0.8-second cycle. Subtle enough to feel alive, not so much that it's distracting when you're calculating whether Karna can reach that Dark Mage.

**Verdict: Huge thumbs up.** The discipline to remove non-authentic features is rarer than Mithril.

---

## Battle Results: The Dopamine Loop

**Commit:** `3362844` - "feat: Add battle result screens and XP system improvements"

Victory screen. Defeat screen. Level-up celebration with stat increases. Combat results panel showing XP gains.

These are the screens you see hundreds of times in a Shining Force playthrough, and they need to feel *good*. The team understands this.

But the real gem is the XP rename:

```gdscript
## Enable formation-based XP for nearby allies (rewards tactical positioning).
@export var enable_formation_xp: bool = true
```

They renamed "participation XP" to "formation XP." Why does this matter? Because *language shapes understanding*.

"Participation XP" sounds like a trophy for showing up. "Formation XP" sounds like a reward for tactical positioning - which is exactly what it is. You get XP for being in range to support your allies. That's not hand-holding; that's *tactical incentivization*.

The `formation_cap_ratio` prevents bystanders from out-earning fighters, which solves the classic problem of your back-row healers leveling faster than your front-line tanks just by existing near combat.

One note: they set `xp_per_level` to 15 for testing. The comment says production value should be ~100. SF2 actually varies XP requirements by level, but 100 is a reasonable flat rate for a platform that lets modders adjust everything anyway.

**Verdict: Thumbs up.** The rename alone shows they're thinking about player psychology, not just mechanics.

---

## Code Quality: Lt. Claudette's Legacy

**Commits:** `492117a` and `bf95b7c` - "fix: Address code review findings"

Two commits dedicated entirely to code review fixes. Type safety. Tween cleanup. Signal connection guards. Explicit loop variable typing.

```gdscript
for spawn_id: String in spawn_points.keys():
```

See that `: String`? That's strict typing on a loop variable. It's the kind of thing that prevents subtle bugs at 0300 hours when you're trying to figure out why your spawn system is treating a Vector2i as a String.

The tween cleanup in `victory_screen.gd` and `level_up_celebration.gd` is particularly important. Tweens that don't get properly cleaned up create memory leaks and can cause crashes on scene transitions. I've seen too many Godot games die to orphaned tweens.

**Verdict: Thumbs up.** Professional-grade code hygiene. Lt. Claudette runs a tight ship.

---

## Visual Polish: Pixels Matter

**Commits:** `44476e3` - "fix: Improve map exploration visuals and pixel-perfect rendering"

Hero and follower sprites went from 12x12 to 24x24 pixels. That's 4x the visual real estate.

More importantly, they added camera snapping for pixel-perfect rendering at the 0.8x overworld zoom. Non-integer zoom levels can cause shimmer and pixel crawling - that annoying effect where pixels seem to shift as the camera moves. Camera snapping fixes this by aligning render positions to the pixel grid.

**Verdict: Thumbs up.** The difference between "looks fine" and "feels right" is often measured in subpixels.

---

## The Lt. Ears Addition

**Commit:** `82c777b` - "chore: Add gdUnit4 UIDs, Lt. Ears agent, and documentation"

A new crew member! Lt. Ears is apparently a Shining Force fandom specialist agent who provides community insight. I'm intensely curious about what kinds of questions they'll be answering, but that's a topic for another blog post.

The gdUnit4 UIDs suggest the test suite is getting more organized, which tracks with the 80+ tests in the map system.

**Verdict: Neutral (waiting to see Lt. Ears in action).** Welcome aboard, whoever you are.

---

## The Campaign Flow: It All Connects

**Commit:** `05077be` - "feat: Add campaign-driven map exploration flow"

Main Menu leads to Map Exploration leads to Battle. It sounds obvious, but connecting these three states cleanly is surprisingly tricky.

The `save_slot_mode` distinguishes "new_game" from "load_game" - critical for the UX of overwriting saves vs. loading existing ones. The `map_template.gd/tscn` gives future content creators a starting point for their own maps.

This is infrastructure work that enables everything else. You can't have an SF2-style open world if your scene manager doesn't know the difference between "start new adventure" and "continue adventure."

**Verdict: Thumbs up.** The plumbing that makes the water flow.

---

## Final Assessment: This Week in the Force

Nine commits. Zero filler.

What impresses me most isn't any single feature - it's the *consistency of vision*. Every commit asks "what would Shining Force 2 do?" and actually answers honestly. The chain following system. The AGI-based turn order. The open world foundation. The rejection of Fire Emblem phase mechanics.

These are people who understand that Shining Force isn't just "tactical RPG with exploration." It's a specific feel, a specific rhythm, a specific relationship between the player and their growing army.

The Sparkling Farce is still in early days - no Caravan yet, no battle map transitions, no actual graphics. But the bones are right. The philosophy is right.

And for the first time since I heard about this project, I actually believe we might get a Shining Force spiritual successor that feels like coming home.

---

**Next time:** I'm hoping to see that Caravan system take shape. Also, someone needs to tell me more about Lt. Ears. Are they a cat? Please let them be a cat.

*Justin out. May your critical hits always land.*

---

*Broadcasting from the USS Torvalds, where our replicators still can't make a decent Yogurt.*
