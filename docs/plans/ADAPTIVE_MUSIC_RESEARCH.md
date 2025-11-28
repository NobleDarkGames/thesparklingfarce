# Adaptive Music System Research

## Summary

Vertical layering: Multiple synchronized audio stems play simultaneously, with layers faded in/out based on game state. This eliminates jarring track restarts when transitioning between map view and combat overlays.

## Industry Examples

### Fire Emblem: Three Houses - "Rain/Thunder" System
- "Rain" version: Map exploration/tactical planning (lighter)
- "Thunder" version: Same track with intensity layers during combat
- Music never stops, just intensifies
- Source: https://fireemblem.fandom.com/wiki/List_of_Music_in_Fire_Emblem:_Three_Houses

### Hades (Darren Korb, via FMOD)
- 5-8 stems per track combined in real-time
- Exploring: Only synth/ambient layers
- Combat starts: Drum stem kicks in
- Active fighting: Guitar and bass layers join
- Boss fights: All stems + "rocking section"
- Combat ends: Drums fade out
- Source: https://www.spin.com/2021/08/hades-darren-korb-soundtrack-interview/

### DOOM 2016 (Mick Gordon)
- Ambient → Medium Combat → Heavy Combat → Boss layers
- Responds to combat intensity in real-time
- Source: https://ensigame.com/articles/gaming/secrets-of-dooms-music-mick-gordons-adaptive-soundtrack-and-its-impact-on-gameplay-2

## Godot 4.3+ Native Support

**AudioStreamSynchronized** - built specifically for vertical layering:
- Play multiple streams in perfect sync
- Individual layer muting/unmuting
- No middleware required

```gdscript
# Setup:
# 1. Create AudioStreamPlayer
# 2. Set stream to new AudioStreamSynchronized
# 3. Add layer streams (base, drums, strings, etc.)
# 4. Control layer volumes based on game state
```

Documentation: https://docs.godotengine.org/en/4.3/classes/class_audiostreamsynchronized.html
Tutorial: https://blog.blips.fm/articles/the-new-music-features-in-godot-43-explained

**Alternative**: Godot Mixing Desk plugin for more complex needs
- https://github.com/kyzfrintin/Godot-Mixing-Desk

## Tempo Synchronization

All layers must share identical tempo and key. Octopath Traveler fixed all boss music at 164 BPM / G Minor for seamless transitions.

Options:
1. **Fixed tempo composition** (recommended) - all layers same BPM/key
2. **Beat-synchronized transitions** - queue changes on beat boundaries
3. **Stingers** - short 2-5 second cues to mask transitions

## Proposed Layer Structure for Sparkling Farce

| Layer | Content | When Active |
|-------|---------|-------------|
| 1 | Orchestral base (strings, woodwinds) | Always |
| 2 | Light percussion, rhythmic elements | Map movement |
| 3 | Tension (brass swells) | Unit selected / enemy near |
| 4 | Battle drums (taiko, snare rolls) | Attack overlay |
| 5 | Full intensity (orchestra hits) | Critical moments |

## Transition Logic

```
Map View (idle):        Layers 1-2
Unit Selected:          Layers 1-3
Attack Initiated:       Layers 1-4 (fade in ~0.5s)
Critical Hit:           Layer 5 stinger
Attack Complete:        Fade Layer 4 out (~1s)
Return to Map:          Layers 1-2
```

## Composition Requirements

- All layers: identical tempo and key
- Loops: identical length or exact multiples
- Drum layer: must work entering at any beat
- Suggested loop points: 4-bar or 8-bar

## Key Sources

- Vertical Layering Techniques: https://www.thegameaudioco.com/making-your-game-s-music-more-dynamic-vertical-layering-vs-horizontal-resequencing
- Adaptive Music Overview: https://en.wikipedia.org/wiki/Adaptive_music
- Banjo-Kazooie Pioneer Analysis: https://www.pastemagazine.com/games/banjo-kazooie/banjo-kazooie-music
- Stingers Technique: https://www.audiokinetic.com/learn/videos/YFC8gV_bcwc/
