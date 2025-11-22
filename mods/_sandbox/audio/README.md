# Audio Assets for Sandbox Mod

This directory contains sound effects and music for the sandbox mod.

## Directory Structure

```
audio/
├── sfx/          # Sound effects
│   ├── cursor_move.ogg
│   ├── menu_select.ogg
│   ├── menu_cancel.ogg
│   ├── attack_hit.ogg
│   ├── attack_miss.ogg
│   ├── attack_critical.ogg
│   ├── damage_taken.ogg
│   └── unit_death.ogg
└── music/        # Background music
    ├── battle_theme.ogg
    ├── victory_theme.ogg
    └── defeat_theme.ogg
```

## Supported Formats

- **OGG Vorbis** (.ogg) - Recommended for music and long sounds
- **WAV** (.wav) - Good for short sound effects
- **MP3** (.mp3) - Supported but OGG is preferred for licensing

## Sound Effect Categories

### UI Sounds
- `cursor_move` - When cursor moves between cells
- `menu_select` - When menu option is selected
- `menu_cancel` - When backing out of a menu

### Combat Sounds
- `attack_hit` - Normal attack connects
- `attack_miss` - Attack misses
- `attack_critical` - Critical hit
- `damage_taken` - Unit takes damage
- `unit_death` - Unit is defeated

### System Sounds
- `turn_start` - New turn begins
- `victory` - Battle won
- `defeat` - Battle lost

## Music Tracks

### Battle Music
- `battle_theme` - Main battle background music (loops)
- `victory_theme` - Plays when battle is won
- `defeat_theme` - Plays when battle is lost

## Usage

Audio files are automatically loaded by the AudioManager when needed:

```gdscript
AudioManager.play_sfx("attack_hit")
AudioManager.play_music("battle_theme")
```

The AudioManager will search for files in this order:
1. .ogg
2. .wav
3. .mp3

If a sound file is not found, the game continues without error (no audio spam).

## Tips

- Keep sound effects short (< 2 seconds)
- Use mono for sound effects, stereo for music
- Normalize volume levels across all sounds
- Target -6dB to -3dB peak for sound effects
- Target -12dB to -9dB for music (leaves headroom for SFX)
- Use OGG for smaller file sizes and better looping
