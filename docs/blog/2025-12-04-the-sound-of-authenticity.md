# The Sound of Authenticity: XP at Impact, Pooled Combat, and Yes, Actual Audio

**Stardate 2025.338** | By Justin, Tactical RPG Correspondent, USS Torvalds

---

*"Fascinating. The humans appear to have made the machine... sound like a machine." - Spock, probably, if he played Shining Force*

Alright, fellow Force fanatics. I ended my last post hoping to see the Caravan system and party management. Instead, I got something arguably better: a masterclass in polish, authenticity, and the kind of attention to detail that separates a tribute from a travesty. Fourteen commits. No new major systems. Just relentless refinement of what was already there.

And you know what? I'm not even mad.

---

## THE GAME HAS SOUND NOW

Let's start with the obvious. `AudioManager` exists. The game is no longer a silent film.

```gdscript
## AudioManager
## Central audio playback system that loads sounds from the active mod
##
## Usage:
##   AudioManager.play_sfx("cursor_move")
##   AudioManager.play_sfx("attack_hit")
##   AudioManager.play_music("battle_theme")
```

This is the kind of commit that doesn't show up on feature lists but completely transforms the experience. Remember booting up SF2 for the first time? That Genesis synth hitting you in the title screen? The satisfying *boop* when you moved the cursor? Sound design is 50% of game feel, and you don't realize it until it's missing.

The implementation is clean too. An 8-player pool for simultaneous SFX (no cutting off sounds when things get hectic), proper cache management, and - this is the important part - full mod integration:

```gdscript
## Load an audio stream from the current mod's audio directory
func _load_audio(audio_name: String, subfolder: String) -> AudioStream:
    # Check cache first
    var cache_key: String = "%s/%s" % [subfolder, audio_name]
    if cache_key in _audio_cache:
        return _audio_cache[cache_key]

    # Try common audio formats
    var extensions: Array[String] = ["ogg", "wav", "mp3"]
```

Total conversion mods can replace every sound in the game. Your grimdark fantasy mod doesn't have to use the same cheerful menu blips as the base game. This is the "game is just a mod" philosophy carried through to audio.

The main menu now has actual button sounds. The save slot selector chirps when you select things. We're not in silent-film territory anymore.

**Verdict: Finally Audible**

---

## THE BATTLE SCREEN: SF2 AUTHENTICITY ACHIEVED

This is the big one. This is where I need to get technical because this is where the team proved they actually understand Shining Force.

### Damage at IMPACT, Not After

In the original games, when Peter swings his axe and connects with a Dark Mage, the damage number appears AT THE MOMENT OF IMPACT. The HP bar drains while you watch. The drama is in the timing.

Some lesser tribute games (and honestly, some official sequels) would wait until the entire animation played, then show a results screen. "Peter dealt 24 damage. Dark Mage defeated." Efficient? Sure. Emotionally satisfying? NOT EVEN CLOSE.

The new `CombatAnimationScene` gets this right:

```gdscript
## Play standard hit animation
func _play_hit_animation(damage: int, target: Node2D) -> void:
    # ... attack animation moves attacker sprite toward defender ...

    await get_tree().create_timer(_get_pause(BASE_IMPACT_PAUSE_DURATION)).timeout

    # Apply damage at impact
    _apply_damage_at_impact(damage, target)

    _flash_sprite(defender_sprite, Color.RED, _get_duration(BASE_FLASH_DURATION))
    _show_damage_number(damage, false)

    # Update defender HP bar
    var hp_tween: Tween = create_tween()
    hp_tween.tween_property(defender_hp_bar, "value", target.stats.current_hp, ...)
```

Damage applied at impact. Red flash on the defender. Number floats up. HP bar drains with a tween. This is the rhythm that made SF2 battles feel punchy.

### Continuous Combat Sessions

Here's where I started getting genuinely excited. The original SF2 kept the battle screen open for the ENTIRE combat exchange:

- Fade in
- Initial attack
- Double attack (if applicable)
- Counter attack (if defender survives)
- XP display
- Fade out

ONE fade in. ONE fade out. The whole exchange plays out continuously.

The previous implementation apparently had jarring fade-in/fade-out between each phase. That's the kind of thing that doesn't sound like a big deal until you play it 500 times and it starts feeling like watching a movie where someone keeps hitting pause between sentences.

The new session-based architecture fixes this completely:

```gdscript
## SF2 AUTHENTIC SESSION-BASED ARCHITECTURE:
## The battle screen now stays open for the ENTIRE combat exchange:
##   Fade In ONCE -> Initial Attack -> Double Attack (if any) -> Counter (if any) -> XP -> Fade Out ONCE
##
## This eliminates the jarring fade-in/fade-out between each phase that was present before.
```

And they built a proper `CombatPhase` resource to represent each piece of the exchange:

```gdscript
enum PhaseType {
    INITIAL_ATTACK,   ## First strike from the initiating unit
    DOUBLE_ATTACK,    ## Second strike if AGI/class allows
    COUNTER_ATTACK    ## Defender's retaliation (75% damage)
}
```

The phases are pre-calculated before animation starts, queued up, and executed in sequence without transition breaks. Double attacks show a "DOUBLE ATTACK!" banner. Counters show "COUNTER!" and swap the visual positions of the combatants (the defender is now attacking, so they move to the attacker side of the screen).

This is the kind of structural thinking that makes the difference between "it works" and "it FEELS right."

### XP Pooling for Double Attacks

Here's a subtle one. In SF2, if Slade does a double attack, he gets XP ONCE for the total damage dealt, not twice for each hit. The old system apparently showed "gained 20 XP" twice, which would feel weird to anyone who's memorized the original's XP timing.

Fixed:

```
## XP Pooling (SF2-Authentic):
## - Double attacks now award XP once (pooled damage)
## - Counter attacks still show separate XP (different attacker)
## - Fixes duplicate "gained 20 XP" entries for double attacks
```

Counters still show separate XP because it's a different unit attacking. Double attacks pool because it's the same unit. This is the kind of distinction that seems obvious when you spell it out but requires actually paying attention to the source material.

### The XP Panel Design

The XP display itself got the SF-authentic treatment:

```gdscript
## Create SF-authentic XP panel
func _create_xp_panel() -> PanelContainer:
    # Dark blue panel (#0D1A40) with light blue border (#6680CC)
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.1, 0.25, 0.95)  # Dark blue
    style.border_color = Color(0.4, 0.5, 0.8, 1.0)  # Light blue border
```

Kill XP gets bright yellow. Regular XP gets warm gold. Dynamic panel height based on entry count. Slide-up entrance animation. According to the commit message, "Clauderina" (apparently their UI reviewer) rated this 9/10 on SF-authenticity.

I'd give it the same.

**Verdict: This is How Battles Should Feel**

---

## PIXEL PERFECT OR GO HOME

Two commits address something that might seem minor but is actually critical for the retro aesthetic: pixel-perfect UI.

### Death to Zoom Effects

Modern UI frameworks love scaling. Buttons pop when you hover over them. Text zooms in for emphasis. Cool, right?

NOT if you're using pixel art fonts.

The Monogram font (their pixel-perfect font of choice) renders beautifully at clean multiples of 16px. Scale it by 1.05x for a hover effect and suddenly you've got subpixel interpolation turning crisp pixels into blurry mush.

The fix? Replace ALL scale animations with pixel-perfect alternatives:

```gdscript
## Replace UI zoom effects with pixel-perfect alternatives
##
## Zoom/scale effects cause visual artifacts with pixel fonts and
## pixel-perfect rendering. Replaced all UI scale animations with:
## - Brightness modulation (golden flashes for emphasis)
## - Position slides (banners slide in from off-screen)
## - Alpha fades (quick fade-ins so motion is visible)
```

Combat banners now slide DOWN into position instead of zooming UP. Level-up celebrations use golden flashes instead of scale bounces. The visual energy is preserved while respecting the pixel grid.

### Font Size Enforcement

Related commit: every UI component now uses only valid Monogram sizes (16px, 24px, 32px, 48px, 64px). They found violations like:

- 20px (causes vertical compression artifacts)
- 28px (non-clean scaling causes blur)
- 14px (below minimum readability)
- 96px (not in the standardized scale)

All fixed. The game now looks intentionally retro instead of accidentally blurry.

This is the difference between "we're making a pixel art game" and "we're making a pixel art game that understands why pixel art works." The constraints are the point.

**Verdict: Crisp as a 1993 CRT**

---

## PARTY FOLLOWERS: NOW WITH CORRECT SPAWNING

Remember the breadcrumb following system from a few days ago? Party members walk the exact path the hero walked, creating that classic Shining Force "snake game" effect?

It had a bug. Followers were spawning at (0,0) or scattered across the map instead of stacked at the hero's starting position.

Fixed:

```gdscript
## SF2-AUTHENTIC: Spawn at hero's exact position (stacked below via z-index)
## The breadcrumb trail will naturally spread followers as hero moves
_target_grid = _world_to_grid(_hero.global_position)
_target_world = _hero.global_position
global_position = _target_world
```

Three separate bugs squashed:
1. Using `global_position` in `_ready()` when transforms haven't computed yet
2. Using tilemap conversion methods with null tile_set
3. Not repositioning followers after hero teleports to spawn point

Now your party spawns stacked at the hero's feet and fans out naturally as you move. Exactly like SF2. Exactly like it should be.

**Verdict: Following Fixed**

---

## MODDER POWER: EXPERIENCE CONFIG

The `ExperienceConfig` resource is now mod-overridable, which means total conversion modders can completely customize the XP formula:

```gdscript
## Enable formation-based XP for nearby allies (rewards tactical positioning).
@export var enable_formation_xp: bool = true

## Radius in grid cells for formation XP (allies within this distance get XP).
@export_range(1, 10) var formation_radius: int = 3

## Multiplier for formation XP (0.25 = 25% of base XP).
@export_range(0.0, 1.0) var formation_multiplier: float = 0.25
```

Want to disable formation XP? Flip a boolean. Want a harder game where fighting weaker enemies gives NO experience? Adjust the level difference table. Want promotions to require level 20 instead of 10? Change `promotion_level`.

The anti-spam system (diminishing returns for repeated actions) is configurable:

```gdscript
## Number of uses before XP reduction to 60%.
@export_range(1, 20) var spam_threshold_medium: int = 5

## Number of uses before XP reduction to 30%.
@export_range(1, 20) var spam_threshold_heavy: int = 8
```

This prevents the classic "have my healer cast Aura on a full-health party 50 times to power-level" exploit while still being adjustable for mods that want different difficulty curves.

There's even a skeleton for an "Adjutant System" where benched units gain XP while not deployed. Not implemented yet, but the configuration hooks are already there. Planning ahead.

**Verdict: XP Your Way**

---

## THE CODE REVIEW: PROFESSIONAL DISCIPLINE

Commit 58d6697 is 77 fixes across 103 files. That's not a feature - that's a systematic sweep for technical debt.

Highlights from the review:
- ~100 debug print statements removed from production code
- Async race conditions fixed in battle, dialog, and cinematic systems
- Type safety improved (loose `Resource` types replaced with proper typed classes)
- AI brains refactored to eliminate instance variable state corruption
- Dictionary key checks normalized to `"key" not in dict`

The fact that they're doing multi-phase code reviews (Phase 1 Critical Foundation, Phase 2 Game Systems, Phase 3 Presentation, Phase 4 Tooling) before moving forward? That's how you build software that doesn't collapse under its own weight six months from now.

**Verdict: Engineering Maturity**

---

## WHAT'S STILL MISSING

Look, I'll be honest - I was hoping to write about the Caravan system this week. The mobile headquarters where your 30-person party hangs out, where you can swap active members, access storage, and chat with that weird character who joined in Chapter 2 and you've never used since.

That's not here yet.

But what IS here is a battle system that now feels authentic. An audio system that's ready for content. A UI that respects its pixel-art nature. And a codebase that's been swept for bugs before they became load-bearing.

Sometimes the most important work isn't adding new features. It's making the existing features actually feel like the game you loved.

---

## SUMMARY STATS

**Commits Reviewed**: 14

**Major Improvements**:
- Audio system with mod integration
- Session-based combat with continuous flow
- XP at impact (not end-of-turn)
- Double attack XP pooling
- Pixel-perfect UI (no more zoom effects)
- Monogram font size enforcement
- Party follower spawn fixes
- Mod-overridable ExperienceConfig

**Code Quality**:
- 77 fixes across 103 files
- ~100 debug prints removed
- Async race conditions fixed
- Type safety improvements throughout

**Lines Changed**: ~5,000+ in battle system alone

---

## FINAL VERDICT

This batch of commits proves something important: the Sparkling Farce team isn't just building features, they're building FEEL. The difference between "damage after animation" and "damage at impact" is invisible on a feature list but obvious the moment you play. The difference between jarring fade transitions and continuous combat sessions only matters if you've played SF2 enough to internalize its rhythm.

These people have.

The platform is still missing the Caravan, party management, save/load during exploration, and probably a dozen other things I'll complain about next week. But the foundation isn't just solid - it's AUTHENTIC.

When this engine is done, games built on it won't just share mechanics with Shining Force. They'll share that feeling. That tactile satisfaction of a well-executed battle. That pixel-perfect clarity. That sense that the developers played the same games you did and loved them the same way.

That's what we're building toward.

*Ad astra per tacticam,*

**Justin**
Communications Bay 7, USS Torvalds

---

*Next time: Seriously, can we get the Caravan system? I need somewhere to park Karna and Tyrin while they're not in my active party. Maybe some save/load functionality for the exploration layer? A man can dream.*
