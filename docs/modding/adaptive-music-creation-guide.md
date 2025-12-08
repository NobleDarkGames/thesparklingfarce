# Adaptive Music Creation Guide

**Audience**: Composers and audio designers creating music for The Sparkling Farce
**Prerequisite**: Familiarity with audio production and export workflows
**Assumes**: The platform's vertical mixing system is fully implemented

---

## Overview

The Sparkling Farce uses a **vertical mixing** (also called "layered" or "adaptive") music system. Rather than separate tracks for different game states, you compose a single piece with multiple synchronized layers that fade in and out based on gameplay.

This creates seamless emotional transitions—the music never stops or restarts, it simply *evolves*.

---

## Core Concepts

### Layers, Not Tracks

Traditional game audio: "Play exploration.ogg, then stop and play battle.ogg"

Vertical mixing: "Play all five layers simultaneously, but only let the player *hear* layers 1-2 during exploration, then fade in layers 3-5 when combat begins"

All layers play in perfect sync from the moment music starts. The platform controls which layers are audible.

### The Five-Layer Model

The platform expects up to five logical layers, though simpler compositions may use fewer:

| Layer ID | Purpose | When Audible |
|----------|---------|--------------|
| `base` | Harmonic foundation, pads, ambient texture | Always |
| `melody` | Main melodic content, lead instruments | Exploration, calm moments |
| `tension` | Suspended chords, rising phrases, anticipation | Unit selected, menu open |
| `rhythm` | Percussion, driving beat | Movement, action imminent |
| `combat` | Full intensity, aggressive elements | Attack animations, critical moments |

You don't need all five. A peaceful town theme might only have `base` and `melody`. A boss battle might use all five with `combat` being particularly intense.

### Synchronization Requirements

**All layers must:**
- Share identical tempo (BPM)
- Share identical length (loop point)
- Start from the same musical downbeat
- Export at the same sample rate and bit depth

The platform uses Godot's `AudioStreamSynchronized` to keep layers perfectly aligned. If your layers drift even slightly, the system cannot correct it.

---

## Composition Workflow

### Step 1: Plan Your Emotional Arc

Before opening your DAW, answer these questions:

1. **What is the baseline mood?** (The `base` layer that never stops)
2. **What adds gentle interest?** (The `melody` layer for exploration)
3. **What creates anticipation?** (The `tension` layer before action)
4. **What drives forward momentum?** (The `rhythm` layer for movement)
5. **What signals peak intensity?** (The `combat` layer for attacks)

Not every piece needs all states. Match layers to the context where this music plays.

### Step 2: Establish Your Grid

Choose a tempo and loop length that accommodates smooth transitions:

- **Tempo**: 80-160 BPM typical for tactical RPGs
- **Loop length**: 8, 16, or 32 bars work well
- **Time signature**: 4/4 is safest; odd meters require careful layer design

The loop point is where seamless repetition occurs. All layers must have clean loops at this exact point.

### Step 3: Compose the Base Layer First

The `base` layer is the foundation everything else builds upon. It should:

- Establish the harmonic progression
- Be satisfying on its own (players may hear only this during idle moments)
- Leave sonic space for other layers to occupy
- Avoid strong melodic hooks (save those for `melody`)

Think: sustained pads, gentle arpeggios, ambient texture, or sparse harmonic rhythm.

### Step 4: Add Layers That Stack Cleanly

Each subsequent layer adds energy without muddying the mix. Consider:

**Frequency separation**: If `base` occupies low-mids, put `tension` in upper-mids
**Rhythmic contrast**: If `base` is sustained, make `rhythm` staccato
**Dynamic headroom**: Leave room for `combat` to be loudest without clipping

When all layers play simultaneously, the mix should be powerful but not distorted. Master your stems assuming all will play at once.

### Step 5: Test Transitions in Your DAW

Before exporting, simulate what the platform will do:

1. Solo only `base` — is this satisfying for idle gameplay?
2. Add `melody` — does the piece feel complete for exploration?
3. Add `tension` — does anticipation build without fatiguing?
4. Add `rhythm` — does energy increase appropriately?
5. Add `combat` — does this feel like a climax?

Also test:
- Removing layers in reverse order (de-escalation)
- Jumping directly from `base` to `combat` (sudden encounter)
- Looping each configuration for 2+ minutes (repetition fatigue)

---

## Export Requirements

### File Format

Export each layer as a separate audio file:

- **Format**: Ogg Vorbis (`.ogg`) preferred, WAV acceptable for source
- **Sample rate**: 44100 Hz
- **Channels**: Stereo
- **Quality**: 192 kbps minimum for Ogg

### Naming Convention

Use the layer ID as a suffix:

```
battle_theme_base.ogg
battle_theme_melody.ogg
battle_theme_tension.ogg
battle_theme_rhythm.ogg
battle_theme_combat.ogg
```

For non-layered music (simple single-track):
```
town_theme.ogg
```

### Directory Structure

Place audio files in your mod's audio directory:

```
mods/your_mod/
  audio/
    music/
      battle_theme_base.ogg
      battle_theme_melody.ogg
      battle_theme_tension.ogg
      battle_theme_rhythm.ogg
      battle_theme_combat.ogg
      town_theme.ogg
```

---

## MusicData Resource Creation

After exporting audio, create a MusicData resource (`.tres` file) that tells the platform how to use your layers.

### Location

```
mods/your_mod/
  data/
    music/
      battle_theme.tres
      town_theme.tres
```

### Layered Music Example

Create `battle_theme.tres` in the Godot editor:

1. Create new Resource of type `MusicData`
2. Set `music_id` to `"battle_theme"` (unique identifier)
3. Set `display_name` to `"Standard Battle Theme"` (for UI/debugging)
4. Enable `use_layers`
5. Set `tempo_bpm` to your composition's tempo
6. Add layer entries to the `layers` array

Each layer entry (MusicLayerData) needs:
- `layer_id`: One of `base`, `melody`, `tension`, `rhythm`, `combat`
- `audio_stream`: Reference to the `.ogg` file
- `default_volume`: Initial volume (0.0-1.0), typically 1.0 for `base`, 0.0 for others

### Simple Music Example

For non-layered music like a town theme:

1. Create new Resource of type `MusicData`
2. Set `music_id` to `"town_theme"`
3. Leave `use_layers` disabled
4. Set `audio_stream` to reference your single audio file

---

## How the Platform Uses Your Music

Understanding the playback system helps you compose effectively.

### Layer Activation

The platform activates layers based on game state:

| Game State | Layers Audible |
|------------|----------------|
| Map idle (no selection) | `base`, `melody` |
| Unit selected | `base`, `melody`, `tension` |
| Move command issued | `base`, `melody`, `tension`, `rhythm` |
| Attack initiated | `base`, `melody`, `tension`, `rhythm`, `combat` |
| Attack complete | Fades `combat` out over ~1 second |
| Turn ends | Returns to `base`, `melody` |

### Fade Behavior

Layer transitions use 0.5-second fades by default. Your composition should sound good with layers appearing or disappearing over this duration. Avoid:

- Layers that sound wrong when partially faded
- Critical musical moments that could be missed during fade-in
- Abrupt timbral changes that reveal the layer boundary

### Loop Points

When the music loops, all layers reset together. The platform does not support per-layer loop points. Design your loop to be seamless across all layer combinations.

---

## Testing Your Music

### In-Engine Testing

1. Place your files in the correct mod directories
2. Launch the game
3. Navigate to a map that uses your music (or set it in MapMetadata)
4. Trigger different game states and listen for:
   - Smooth layer transitions
   - No audio glitches at loop points
   - Appropriate energy levels for each state

### Common Issues

**Layers out of sync**: Re-export with identical settings, ensure same start point
**Popping at loop**: Add tiny fade at loop boundary, verify sample-accurate editing
**Mix too quiet/loud**: Adjust `default_volume` in MusicLayerData
**Wrong layer activating**: Verify `layer_id` matches expected values exactly

---

## Best Practices

### Do

- Compose with all layers playing, then verify each subset sounds good
- Leave 3-6 dB headroom in your full mix for platform volume control
- Make `base` interesting enough to sustain extended idle periods
- Consider the emotional journey from calm to intense and back
- Test your loop points obsessively

### Don't

- Create layers that only work in combination (each should add, not require)
- Put essential melodic content only in `combat` (it may rarely play)
- Exceed 5 layers (platform expects this maximum)
- Use different tempos or loop lengths across layers
- Forget that players may hear any subset of your layers

---

## Quick Reference

| Element | Requirement |
|---------|-------------|
| File format | Ogg Vorbis preferred |
| Sample rate | 44100 Hz |
| Bit depth | 16-bit or higher |
| Layers | Up to 5: `base`, `melody`, `tension`, `rhythm`, `combat` |
| Loop length | Identical across all layers |
| Tempo | Identical across all layers, specified in MusicData |
| Fade time | Platform uses ~0.5 seconds |
| Resource type | MusicData (.tres) |
| Audio location | `mods/your_mod/audio/music/` |
| Resource location | `mods/your_mod/data/music/` |

---

## Further Reading

- `docs/plans/ADAPTIVE_MUSIC_RESEARCH.md` — Technical research behind the system
- `docs/plans/audio-system-implementation-plan.md` — Platform implementation details
- `docs/modding/audio-sfx-reference.md` — Sound effect creation guide

---

*"The 47th Rule of Acquisition: Don't trust a man wearing a better suit than your own. But always trust a composer who understands vertical mixing."*
