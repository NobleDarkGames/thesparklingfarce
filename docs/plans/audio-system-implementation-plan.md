# Audio System Implementation Plan

**Version**: 1.0
**Created**: 2025-12-06
**Status**: Draft
**Estimated Total Effort**: ~45 hours across 3 phases

---

## Executive Summary

The current AudioManager provides basic SFX pooling and single-track music playback, but lacks the infrastructure needed for a professional tactical RPG audio experience. This plan addresses six critical gaps identified by Fark's audio architecture analysis:

1. **No Vertical Mixing** - AudioStreamSynchronized unused despite excellent research
2. **Primitive Transitions** - Stop-silence-play instead of crossfade
3. **No Audio Bus Layout** - No `default_bus_layout.tres`, `_update_volumes()` is empty
4. **No MusicData Resource** - Audio bypasses ModLoader.registry
5. **No Dialog Ducking** - Music should reduce during dialog
6. **No Spatial Audio** - All AudioStreamPlayer, no 2D positional audio

The plan follows the "game is just a mod" philosophy: all audio content lives in `mods/`, the platform provides infrastructure in `core/`.

---

## Current State Analysis

### Existing Implementation (`/home/user/dev/sparklingfarce/core/systems/audio_manager.gd`)

**Strengths:**
- Mod-aware path construction (`current_mod_path + "/audio/sfx/..."`)
- 8-player SFX pool with availability checking
- Audio caching to prevent repeated disk reads
- Signal connection to ModLoader's `active_mod_changed`
- Basic fade-in/out for music via Tween
- Category enum for future per-category volume (unused)
- `play_sfx_no_overlap()` for continuous sounds (walk loop)

**Gaps:**
- `_update_volumes()` is a stub (line 212-215: `pass`)
- No audio bus layout file exists (searched `**/*bus*.tres`)
- Single `_music_player` cannot do layered/synchronized playback
- No MusicData resource - music loaded by string name only
- No crossfade between tracks (stop old, await, start new)
- No connection to DialogManager for ducking
- All AudioStreamPlayer (non-spatial), no AudioStreamPlayer2D

### Related Systems

| System | Audio Integration |
|--------|-------------------|
| BattleManager | `play_music("battle_theme")`, `play_sfx()` for attacks |
| DialogManager | No audio integration - signals exist but unused |
| CinematicsManager | `play_music` and `play_sound` command executors |
| MapMetadata | `music_id` and `ambient_id` fields (placeholder strings) |
| BattleData | `background_music`, `victory_music` as AudioStream refs |

---

## Phase 1: Foundation (7-8 hours)

Establish proper audio bus architecture and improve basic playback quality.

### Task 1.1: Create Audio Bus Layout

**File**: `/home/user/dev/sparklingfarce/default_bus_layout.tres`

**Rationale**: Godot's AudioServer requires a bus layout for proper mixing. Without it, bus volume controls are ineffective and category-based mixing is impossible.

**Bus Structure**:
```
Master
  +-- Music (for background music, ducking target)
  +-- Ambient (for environmental loops)
  +-- SFX (for sound effects)
  |     +-- UI (menu sounds)
  |     +-- Combat (attack sounds)
  |     +-- Movement (footsteps)
  +-- Dialog (for future voice, high priority)
```

**Implementation Details**:
1. Create `default_bus_layout.tres` in project root
2. Configure buses with proper routing (all -> Master)
3. Add volume, compressor, and limiter effects as appropriate
4. Set `audio/buses/default_bus_layout` in project.godot

**Acceptance Criteria**:
- [ ] `default_bus_layout.tres` exists with documented bus structure
- [ ] Project settings reference the layout
- [ ] AudioManager's `_update_volumes()` applies settings to buses via `AudioServer.set_bus_volume_db()`
- [ ] Volume changes persist and affect playback

**Test Requirements**:
- Unit test: Verify buses exist via `AudioServer.get_bus_index("Music")` etc.
- Manual test: Adjust volume sliders, confirm audible change

---

### Task 1.2: Implement Proper Crossfade

**File**: `/home/user/dev/sparklingfarce/core/systems/audio_manager.gd`

**Rationale**: Current `play_music()` stops old track abruptly before starting new one. Professional games crossfade for seamless transitions.

**Current Code (lines 106-131)**:
```gdscript
func play_music(music_name: String, fade_in_duration: float = 0.5) -> void:
    # ...
    if _music_player.playing:
        stop_music(fade_in_duration * 0.5)  # Fade out faster
        await get_tree().create_timer(fade_in_duration * 0.5).timeout  # SILENCE GAP!
    # Start new music...
```

**Proposed Change**:
- Add second music player `_music_player_b` for crossfade
- Fade out old while fading in new simultaneously
- Track "active" player (A/B alternating pattern)

**Implementation Details**:
```gdscript
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer  # Points to current

func play_music(music_name: String, crossfade_duration: float = 1.0) -> void:
    var new_player: AudioStreamPlayer = _get_inactive_music_player()
    new_player.stream = _load_audio(music_name, "music")
    new_player.volume_db = linear_to_db(0.0)
    new_player.play()

    var tween: Tween = create_tween().set_parallel()
    if _active_music_player.playing:
        tween.tween_method(_set_player_volume.bind(_active_music_player),
                          music_volume, 0.0, crossfade_duration)
        tween.tween_callback(_active_music_player.stop).set_delay(crossfade_duration)
    tween.tween_method(_set_player_volume.bind(new_player),
                      0.0, music_volume, crossfade_duration)

    _active_music_player = new_player
```

**Acceptance Criteria**:
- [ ] No audible gap when changing music tracks
- [ ] Crossfade duration is configurable
- [ ] Works correctly when no music is playing
- [ ] Handles rapid track changes gracefully (cancels pending tweens)

**Test Requirements**:
- Unit test: Call `play_music()` twice rapidly, verify no errors
- Manual test: Transition between two tracks, confirm smooth crossfade

---

### Task 1.3: Implement Working Volume Controls

**File**: `/home/user/dev/sparklingfarce/core/systems/audio_manager.gd`

**Rationale**: `_update_volumes()` is empty. Volume settings have no effect on audio buses.

**Implementation Details**:
```gdscript
func _update_volumes() -> void:
    var music_bus_idx: int = AudioServer.get_bus_index("Music")
    var sfx_bus_idx: int = AudioServer.get_bus_index("SFX")
    var ambient_bus_idx: int = AudioServer.get_bus_index("Ambient")

    if music_bus_idx >= 0:
        AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(music_volume))
    if sfx_bus_idx >= 0:
        AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(sfx_volume))
    if ambient_bus_idx >= 0:
        AudioServer.set_bus_volume_db(ambient_bus_idx, linear_to_db(ambient_volume))

func set_music_volume(volume: float) -> void:
    music_volume = clampf(volume, 0.0, 1.0)
    _update_volumes()  # Apply to bus immediately

func set_sfx_volume(volume: float) -> void:
    sfx_volume = clampf(volume, 0.0, 1.0)
    _update_volumes()
```

**New Properties**:
```gdscript
var ambient_volume: float = 0.6
var master_volume: float = 1.0  # Optional, for global mute
```

**Acceptance Criteria**:
- [ ] `set_music_volume(0.5)` reduces music to 50%
- [ ] `set_sfx_volume(0.0)` mutes all sound effects
- [ ] Settings persist across scene changes (autoload)
- [ ] Volume changes apply immediately (no restart needed)

**Test Requirements**:
- Unit test: Set volume, read back from AudioServer, verify match
- Integration test: Play SFX, change volume mid-playback, confirm change

---

### Task 1.4: Implement Dialog Ducking

**Files**:
- `/home/user/dev/sparklingfarce/core/systems/audio_manager.gd`
- `/home/user/dev/sparklingfarce/core/systems/dialog_manager.gd`

**Rationale**: Music should reduce volume during dialog so text is the focus. This is standard practice in narrative games.

**Implementation Details**:

In DialogManager, emit signals (already exist):
```gdscript
signal dialog_started(dialogue_data: DialogueData)  # Line 34
signal dialog_ended(dialogue_data: DialogueData)    # Line 35
```

In AudioManager, connect and respond:
```gdscript
const DUCK_VOLUME: float = 0.3  # Music reduces to 30% during dialog
const DUCK_FADE_TIME: float = 0.3

var _is_ducked: bool = false
var _pre_duck_volume: float = 1.0

func _ready() -> void:
    # ... existing setup ...
    DialogManager.dialog_started.connect(_on_dialog_started)
    DialogManager.dialog_ended.connect(_on_dialog_ended)

func _on_dialog_started(_dialogue: DialogueData) -> void:
    if not _is_ducked:
        _is_ducked = true
        _pre_duck_volume = music_volume
        var tween: Tween = create_tween()
        tween.tween_method(set_music_volume, music_volume,
                          music_volume * DUCK_VOLUME, DUCK_FADE_TIME)

func _on_dialog_ended(_dialogue: DialogueData) -> void:
    if _is_ducked:
        _is_ducked = false
        var tween: Tween = create_tween()
        tween.tween_method(set_music_volume, music_volume,
                          _pre_duck_volume, DUCK_FADE_TIME)
```

**Acceptance Criteria**:
- [ ] Music volume reduces when dialog starts
- [ ] Music volume restores when dialog ends
- [ ] Nested dialogs don't cause volume issues
- [ ] Ducking works with both music players (crossfade scenario)

**Test Requirements**:
- Unit test: Simulate dialog signals, verify volume changes
- Manual test: Trigger NPC dialog, confirm music ducks smoothly

---

### Task 1.5: Add Ambient Sound Support

**File**: `/home/user/dev/sparklingfarce/core/systems/audio_manager.gd`

**Rationale**: MapMetadata has `ambient_id` field but nothing plays it. Ambient loops enhance atmosphere.

**Implementation Details**:
```gdscript
var _ambient_player: AudioStreamPlayer = null
var current_ambient_id: String = ""

func _ready() -> void:
    # ... existing setup ...
    _ambient_player = AudioStreamPlayer.new()
    _ambient_player.bus = "Ambient"
    add_child(_ambient_player)

func play_ambient(ambient_name: String, crossfade_duration: float = 2.0) -> void:
    if ambient_name == current_ambient_id:
        return  # Already playing

    var stream: AudioStream = _load_audio(ambient_name, "ambient")
    if not stream:
        stop_ambient(crossfade_duration)
        return

    # Crossfade logic similar to music
    current_ambient_id = ambient_name
    # ... implement crossfade ...

func stop_ambient(fade_duration: float = 1.0) -> void:
    if not _ambient_player.playing:
        return
    current_ambient_id = ""
    # Fade out and stop
```

**Directory Structure Addition**:
```
mods/_base_game/audio/
  sfx/          # Existing
  music/        # Existing
  ambient/      # NEW - looping environmental sounds
```

**Acceptance Criteria**:
- [ ] `play_ambient("forest")` plays looping ambient sound
- [ ] Ambient has independent volume control
- [ ] Ambient crossfades on map transitions
- [ ] MapMetadata.ambient_id is honored on map load

**Test Requirements**:
- Unit test: Verify ambient player exists and routes to correct bus
- Integration test: Load map with ambient_id, verify playback starts

**Dependencies**:
- Task 1.1 (Audio Bus Layout) - needs Ambient bus

---

## Phase 2: Vertical Mixing (26-28 hours)

Implement the adaptive music system using AudioStreamSynchronized, based on ADAPTIVE_MUSIC_RESEARCH.md.

### Task 2.1: Create MusicData Resource

**File**: `/home/user/dev/sparklingfarce/core/resources/music_data.gd`

**Rationale**: Music needs metadata for vertical mixing (layers, tempo, transitions). Current string-based lookup provides no structure.

**Resource Definition**:
```gdscript
@tool
class_name MusicData
extends Resource

## Unique identifier for this music track
@export var music_id: String = ""

## Display name for UI/debugging
@export var display_name: String = ""

## For simple single-track music (non-layered)
@export var audio_stream: AudioStream

## For vertical mixing - multiple synchronized layers
@export_group("Vertical Layers")
## If true, uses layer system instead of single audio_stream
@export var use_layers: bool = false
## Tempo in BPM (all layers must match)
@export var tempo_bpm: int = 120
## Layer definitions with AudioStreams
@export var layers: Array[MusicLayerData] = []

## Transition settings
@export_group("Transitions")
@export var default_fade_in: float = 1.0
@export var default_fade_out: float = 1.0
## Can this track crossfade with itself? (for intensity changes)
@export var allow_self_crossfade: bool = false

## Validation
func validate() -> bool:
    if music_id.is_empty():
        push_error("MusicData: music_id is required")
        return false
    if use_layers and layers.is_empty():
        push_error("MusicData: use_layers=true but no layers defined")
        return false
    if not use_layers and audio_stream == null:
        push_error("MusicData: Single-track mode requires audio_stream")
        return false
    return true
```

**Supporting Resource** (`/home/user/dev/sparklingfarce/core/resources/music_layer_data.gd`):
```gdscript
@tool
class_name MusicLayerData
extends Resource

## Layer identifier (e.g., "base", "drums", "tension", "combat")
@export var layer_id: String = ""

## The audio stream for this layer
@export var audio_stream: AudioStream

## Initial volume (0.0 = silent, 1.0 = full)
@export_range(0.0, 1.0) var default_volume: float = 1.0

## Which game states activate this layer
## Empty means always active
@export var active_states: Array[String] = []
```

**Acceptance Criteria**:
- [ ] MusicData resource can be created in Godot editor
- [ ] Both single-track and layered modes work
- [ ] Validation catches common mistakes
- [ ] Resources save/load correctly as .tres files

**Test Requirements**:
- Unit test: Create MusicData programmatically, validate
- Unit test: Verify layer array serialization

---

### Task 2.2: Register MusicData with ModLoader

**File**: `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd`

**Rationale**: MusicData should follow the "game is just a mod" pattern. Music resources should be discoverable like characters and items.

**Changes to RESOURCE_TYPE_DIRS**:
```gdscript
const RESOURCE_TYPE_DIRS: Dictionary = {
    "characters": "character",
    "classes": "class",
    "items": "item",
    # ... existing entries ...
    "music": "music",  # NEW
}
```

**Directory Structure**:
```
mods/_base_game/
  data/
    music/
      town_theme.tres      # MusicData resource
      battle_theme.tres
      boss_theme.tres
  audio/
    music/                  # Raw audio files (referenced by MusicData)
      town_base.ogg
      town_percussion.ogg
      battle_base.ogg
      battle_drums.ogg
      battle_tension.ogg
```

**Acceptance Criteria**:
- [ ] `ModLoader.registry.get_resource("music", "battle_theme")` returns MusicData
- [ ] All mods' music directories are scanned
- [ ] Override priority works (higher priority mod replaces music)

**Test Requirements**:
- Unit test: Register music, retrieve via registry
- Integration test: Create music in _sandbox, verify discovery

**Dependencies**:
- Task 2.1 (MusicData Resource)

---

### Task 2.3: Create AdaptiveMusicPlayer Component

**File**: `/home/user/dev/sparklingfarce/core/components/adaptive_music_player.gd`

**Rationale**: Encapsulates AudioStreamSynchronized complexity. Can be used by AudioManager or instantiated directly in scenes.

**Implementation**:
```gdscript
class_name AdaptiveMusicPlayer
extends Node

signal layer_changed(layer_id: String, is_active: bool)
signal all_layers_ready()

var _synchronized_stream: AudioStreamSynchronized
var _player: AudioStreamPlayer
var _layer_volumes: Dictionary = {}  # layer_id -> current volume
var _target_volumes: Dictionary = {}  # layer_id -> target volume
var _music_data: MusicData

const LAYER_FADE_TIME: float = 0.5

func load_music(music_data: MusicData) -> void:
    if not music_data.use_layers:
        push_warning("AdaptiveMusicPlayer: Use AudioManager for single-track music")
        return

    _music_data = music_data
    _synchronized_stream = AudioStreamSynchronized.new()
    _synchronized_stream.stream_count = music_data.layers.size()

    for i in range(music_data.layers.size()):
        var layer: MusicLayerData = music_data.layers[i]
        _synchronized_stream.set_sync_stream(i, layer.audio_stream)
        _layer_volumes[layer.layer_id] = layer.default_volume
        _target_volumes[layer.layer_id] = layer.default_volume

    _player.stream = _synchronized_stream
    emit_signal("all_layers_ready")

func play() -> void:
    _player.play()
    _apply_layer_volumes()

func set_layer_active(layer_id: String, active: bool, fade_time: float = LAYER_FADE_TIME) -> void:
    if layer_id not in _target_volumes:
        push_warning("AdaptiveMusicPlayer: Unknown layer '%s'" % layer_id)
        return

    var target: float = 1.0 if active else 0.0
    _target_volumes[layer_id] = target
    _tween_layer_volume(layer_id, target, fade_time)
    emit_signal("layer_changed", layer_id, active)

func set_layer_volume(layer_id: String, volume: float, fade_time: float = LAYER_FADE_TIME) -> void:
    if layer_id not in _target_volumes:
        return
    _target_volumes[layer_id] = clampf(volume, 0.0, 1.0)
    _tween_layer_volume(layer_id, volume, fade_time)

func _tween_layer_volume(layer_id: String, target: float, duration: float) -> void:
    var layer_index: int = _get_layer_index(layer_id)
    if layer_index < 0:
        return

    var tween: Tween = create_tween()
    tween.tween_method(
        func(vol: float) -> void:
            _synchronized_stream.set_sync_stream_volume(layer_index, linear_to_db(vol)),
        _layer_volumes[layer_id],
        target,
        duration
    )
    _layer_volumes[layer_id] = target

func _get_layer_index(layer_id: String) -> int:
    for i in range(_music_data.layers.size()):
        if _music_data.layers[i].layer_id == layer_id:
            return i
    return -1
```

**Acceptance Criteria**:
- [ ] Loads MusicData and creates AudioStreamSynchronized
- [ ] All layers play in perfect sync
- [ ] `set_layer_active()` fades layers in/out smoothly
- [ ] Works when instantiated as child of any scene

**Test Requirements**:
- Unit test: Create mock MusicData, verify layer count matches
- Integration test: Load real audio files, verify synchronized playback

**Dependencies**:
- Task 2.1 (MusicData Resource)
- Task 2.2 (MusicData Registration)

---

### Task 2.4: Integrate AdaptiveMusicPlayer with AudioManager

**File**: `/home/user/dev/sparklingfarce/core/systems/audio_manager.gd`

**Rationale**: AudioManager should seamlessly handle both simple and adaptive music. Systems like BattleManager should not need to know the difference.

**API Changes**:
```gdscript
## Play music by ID (looks up in ModRegistry)
## Automatically uses AdaptiveMusicPlayer for layered tracks
func play_music_by_id(music_id: String, crossfade_duration: float = 1.0) -> void:
    var music_data: MusicData = ModLoader.registry.get_resource("music", music_id)
    if not music_data:
        # Fallback to legacy string-based loading
        play_music(music_id, crossfade_duration)
        return

    if music_data.use_layers:
        _play_adaptive_music(music_data, crossfade_duration)
    else:
        _play_simple_music(music_data.audio_stream, crossfade_duration)

## Control vertical layers (only works if current music is adaptive)
func set_music_layer(layer_id: String, active: bool) -> void:
    if _adaptive_player and _adaptive_player.is_playing():
        _adaptive_player.set_layer_active(layer_id, active)

func set_music_intensity(intensity: float) -> void:
    # Convenience method: maps 0.0-1.0 to layer configuration
    # 0.0 = ambient only, 0.5 = add rhythm, 1.0 = full intensity
    pass
```

**Backward Compatibility**:
- Existing `play_music(name, fade)` continues to work for string lookups
- New `play_music_by_id()` is preferred for registry-based access
- BattleManager updated to use `play_music_by_id()` when MusicData exists

**Acceptance Criteria**:
- [ ] `play_music_by_id("battle_theme")` works for both simple and layered tracks
- [ ] `set_music_layer("drums", true)` activates drum layer during combat
- [ ] Fallback to string-based loading works when MusicData not found
- [ ] Music ducking works with adaptive player

**Test Requirements**:
- Unit test: Verify play_music_by_id resolves from registry
- Integration test: Play layered music, toggle layers, verify audio

**Dependencies**:
- Task 2.3 (AdaptiveMusicPlayer)
- Task 1.4 (Dialog Ducking) - must work with adaptive player

---

### Task 2.5: Integrate with BattleManager

**File**: `/home/user/dev/sparklingfarce/core/systems/battle_manager.gd`

**Rationale**: Battle is the primary use case for vertical mixing. Music should intensify during combat actions.

**Integration Points**:

```gdscript
# In _start_battle():
AudioManager.play_music_by_id(battle_data.music_id, 1.0)
AudioManager.set_music_layer("drums", false)  # Start calm

# When unit selected:
AudioManager.set_music_layer("tension", true)

# When attack initiated:
AudioManager.set_music_layer("drums", true)
AudioManager.set_music_layer("combat", true)

# When attack animation completes:
AudioManager.set_music_layer("combat", false)

# When turn ends with no units selected:
AudioManager.set_music_layer("tension", false)
AudioManager.set_music_layer("drums", false)
```

**State Mapping** (per ADAPTIVE_MUSIC_RESEARCH.md):
| Game State | Active Layers |
|------------|---------------|
| Map View (idle) | base, ambient |
| Unit Selected | base, ambient, tension |
| Attack Initiated | base, ambient, tension, drums |
| Critical Hit | all layers + stinger |
| Attack Complete | fade drums over 1s |
| Return to idle | base, ambient |

**Acceptance Criteria**:
- [ ] Music intensifies when unit is selected
- [ ] Drums layer activates during attack animation
- [ ] Layers fade smoothly, never cut abruptly
- [ ] Works correctly when BattleData has no MusicData (fallback)

**Test Requirements**:
- Integration test: Mock battle sequence, verify layer state transitions
- Manual test: Play battle, confirm music responds to player actions

**Dependencies**:
- Task 2.4 (AudioManager Integration)
- Existing BattleManager signals (unit_selected, attack_started, etc.)

---

### Task 2.6: Create Base Game Music Assets Structure

**Location**: `mods/_base_game/data/music/`

**Rationale**: Demonstrate proper MusicData configuration for modders.

**Example Files**:

`battle_theme.tres`:
```gdscript
[gd_resource type="Resource" script_class="MusicData"]

[resource]
music_id = "battle_theme"
display_name = "Standard Battle Theme"
use_layers = true
tempo_bpm = 140
layers = [
    # SubResources or external .tres references
]
default_fade_in = 0.5
default_fade_out = 1.0
```

`town_theme.tres`:
```gdscript
[gd_resource type="Resource" script_class="MusicData"]

[resource]
music_id = "town_theme"
display_name = "Peaceful Town"
use_layers = false
audio_stream = # Reference to town_theme.ogg
```

**Documentation Update**: Add section to `/home/user/dev/sparklingfarce/docs/modding/audio-sfx-reference.md` explaining MusicData creation.

**Acceptance Criteria**:
- [ ] At least one layered MusicData exists for battle
- [ ] At least one simple MusicData exists for town
- [ ] Both play correctly in-game
- [ ] Modder documentation explains the resource format

**Test Requirements**:
- Manual test: Verify music plays on game start
- Unit test: Validate all MusicData resources in _base_game

**Dependencies**:
- Task 2.2 (ModLoader Registration)
- Audio asset creation (external to this plan)

---

## Phase 3: Polish (10 hours)

Add spatial audio and stinger system for maximum audio immersion.

### Task 3.1: Add Spatial Audio for SFX

**Files**:
- `/home/user/dev/sparklingfarce/core/systems/audio_manager.gd`
- `/home/user/dev/sparklingfarce/core/components/spatial_sfx_player.gd` (NEW)

**Rationale**: Battle sounds should emanate from unit positions. Attack sounds at tile (5,3) should be spatially positioned there.

**Implementation**:
```gdscript
# In AudioManager:
func play_sfx_at_position(sfx_name: String, world_position: Vector2,
                          category: SFXCategory = SFXCategory.SYSTEM) -> void:
    var stream: AudioStream = _load_audio(sfx_name, "sfx")
    if not stream:
        return

    var player: AudioStreamPlayer2D = _get_available_spatial_player()
    if not player:
        # Fallback to non-spatial
        play_sfx(sfx_name, category)
        return

    player.global_position = world_position
    player.stream = stream
    player.play()
```

**Spatial Player Pool**:
```gdscript
var _spatial_sfx_players: Array[AudioStreamPlayer2D] = []

func _ready() -> void:
    # Create spatial player pool
    for i in range(4):  # Fewer than regular pool
        var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
        player.bus = SFX_BUS
        player.max_distance = 500.0  # Audible across battle map
        player.attenuation = 1.0
        add_child(player)
        _spatial_sfx_players.append(player)
```

**BattleManager Updates**:
```gdscript
# Instead of:
AudioManager.play_sfx("attack_hit", AudioManager.SFXCategory.COMBAT)

# Use:
var world_pos: Vector2 = GridManager.grid_to_world(target.grid_position)
AudioManager.play_sfx_at_position("attack_hit", world_pos, AudioManager.SFXCategory.COMBAT)
```

**Acceptance Criteria**:
- [ ] Attacks sound positioned at target unit location
- [ ] Panning follows camera (left side of screen = left audio)
- [ ] Distant sounds are quieter (attenuation)
- [ ] Falls back to non-spatial when pool exhausted

**Test Requirements**:
- Unit test: Verify spatial player creation and bus routing
- Manual test: Attack unit on left vs right side of map, hear panning

**Dependencies**:
- Task 1.1 (Audio Bus Layout)

---

### Task 3.2: Implement Stinger System

**File**: `/home/user/dev/sparklingfarce/core/systems/audio_manager.gd`

**Rationale**: Short musical stingers (2-5 seconds) punctuate key moments: critical hits, level-ups, promotions. These should layer over music, not replace it.

**Implementation**:
```gdscript
var _stinger_player: AudioStreamPlayer

func _ready() -> void:
    # ... existing setup ...
    _stinger_player = AudioStreamPlayer.new()
    _stinger_player.bus = "Music"  # Same bus as music for cohesion
    add_child(_stinger_player)

func play_stinger(stinger_name: String, duck_music: bool = true) -> void:
    var stream: AudioStream = _load_audio(stinger_name, "stingers")
    if not stream:
        return

    if duck_music:
        # Temporarily reduce music volume
        _duck_for_stinger(stream.get_length())

    _stinger_player.stream = stream
    _stinger_player.play()

func _duck_for_stinger(duration: float) -> void:
    var original_volume: float = music_volume
    var tween: Tween = create_tween()
    tween.tween_method(set_music_volume, music_volume, music_volume * 0.4, 0.1)
    tween.tween_interval(duration - 0.2)
    tween.tween_method(set_music_volume, music_volume * 0.4, original_volume, 0.1)
```

**Directory Addition**:
```
mods/_base_game/audio/
  stingers/         # NEW
    critical_hit.ogg
    level_up.ogg
    promotion.ogg
    victory.ogg
```

**Usage Examples**:
```gdscript
# In combat when critical hit lands:
AudioManager.play_stinger("critical_hit")

# In level_up_celebration.gd:
AudioManager.play_stinger("level_up", false)  # Don't duck, it's already fanfare

# In promotion_ceremony.gd:
AudioManager.play_stinger("promotion")
```

**Acceptance Criteria**:
- [ ] Stingers play immediately on trigger
- [ ] Music ducks appropriately during stinger
- [ ] Stingers don't interrupt each other (queue or skip)
- [ ] Works during both simple and adaptive music

**Test Requirements**:
- Unit test: Verify stinger player exists
- Manual test: Trigger critical hit, hear stinger layer over music

---

### Task 3.3: Update Cinematic Commands

**Files**:
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/play_music_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/play_sound_executor.gd`
- `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/play_stinger_executor.gd` (NEW)

**Rationale**: Cinematics should be able to use the new audio features.

**play_music_executor.gd updates**:
```gdscript
func execute(command: Dictionary, _manager: Node) -> bool:
    var params: Dictionary = command.get("params", {})
    var music_id: String = params.get("music_id", "")
    var fade_duration: float = params.get("fade_duration", 0.5)
    var start_layer: String = params.get("start_layer", "")  # NEW

    if music_id.is_empty():
        push_warning("PlayMusicExecutor: No music_id specified")
        return true

    AudioManager.play_music_by_id(music_id, fade_duration)

    # Optionally set initial layer state
    if not start_layer.is_empty():
        AudioManager.set_music_layer(start_layer, true)

    return true
```

**New command: play_stinger_executor.gd**:
```gdscript
class_name PlayStingerExecutor
extends CinematicCommandExecutor

func execute(command: Dictionary, _manager: Node) -> bool:
    var params: Dictionary = command.get("params", {})
    var stinger_id: String = params.get("stinger_id", "")
    var duck_music: bool = params.get("duck_music", true)

    if stinger_id.is_empty():
        push_warning("PlayStingerExecutor: No stinger_id specified")
        return true

    AudioManager.play_stinger(stinger_id, duck_music)
    return true
```

**Register new command** in CinematicsManager command registry.

**Acceptance Criteria**:
- [ ] `play_music` command works with new registry-based lookup
- [ ] `play_music` supports optional layer control
- [ ] New `play_stinger` command available in cinematics
- [ ] Cinematic Editor updated to show new parameters

**Test Requirements**:
- Unit test: Execute commands with mock parameters
- Integration test: Create cinematic with music commands, play through

**Dependencies**:
- Task 2.4 (play_music_by_id in AudioManager)
- Task 3.2 (Stinger System)

---

## Test Strategy

### Headless Unit Tests

All tests in `/home/user/dev/sparklingfarce/tests/unit/audio/`:

| Test File | Coverage |
|-----------|----------|
| `test_audio_bus_layout.gd` | Verify buses exist, volume controls work |
| `test_audio_crossfade.gd` | Verify no silence gap during transitions |
| `test_audio_ducking.gd` | Verify dialog signals trigger volume changes |
| `test_music_data_resource.gd` | Validate MusicData serialization |
| `test_adaptive_music_player.gd` | Verify layer creation and control |
| `test_spatial_audio.gd` | Verify 2D player creation and positioning |
| `test_stinger_system.gd` | Verify stinger playback and ducking |

### Manual Testing Checklist

| Scenario | Expected Result |
|----------|-----------------|
| Launch game, hear menu music | Music plays immediately |
| Enter battle | Smooth crossfade to battle theme |
| Select unit | Music tension increases (layer) |
| Attack enemy | Drums layer activates |
| Land critical hit | Stinger plays over music |
| Open dialog | Music ducks to ~30% |
| Close dialog | Music returns to full |
| Change music volume in settings | Immediate audible change |
| Visit different map | Ambient loop plays |

---

## Risk Analysis

### High Risk

| Risk | Mitigation |
|------|------------|
| AudioStreamSynchronized API changes in Godot 4.6 | Pin to Godot 4.5.x, monitor release notes |
| Performance impact of multiple audio streams | Limit layer count, lazy-load MusicData |
| Audio asset creation bottleneck | Placeholder assets for testing, parallelize with asset team |

### Medium Risk

| Risk | Mitigation |
|------|------------|
| Crossfade timing issues | Extensive manual testing across various transitions |
| Dialog ducking race conditions | Use mutex or deferred signal processing |
| Mod audio discovery performance | Cache scan results, incremental updates |

### Low Risk

| Risk | Mitigation |
|------|------------|
| Bus layout conflicts with mods | Document bus names as API contract |
| Spatial audio too subtle | Configurable attenuation parameters |

---

## File Summary

### New Files

| Path | Purpose |
|------|---------|
| `/home/user/dev/sparklingfarce/default_bus_layout.tres` | Audio bus configuration |
| `/home/user/dev/sparklingfarce/core/resources/music_data.gd` | MusicData resource class |
| `/home/user/dev/sparklingfarce/core/resources/music_layer_data.gd` | Layer configuration |
| `/home/user/dev/sparklingfarce/core/components/adaptive_music_player.gd` | Vertical mixing component |
| `/home/user/dev/sparklingfarce/core/components/spatial_sfx_player.gd` | 2D positional audio |
| `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/play_stinger_executor.gd` | Stinger command |
| `/home/user/dev/sparklingfarce/mods/_base_game/data/music/*.tres` | MusicData resources |
| `/home/user/dev/sparklingfarce/tests/unit/audio/test_*.gd` | New test files |

### Modified Files

| Path | Changes |
|------|---------|
| `/home/user/dev/sparklingfarce/core/systems/audio_manager.gd` | Major expansion |
| `/home/user/dev/sparklingfarce/core/systems/dialog_manager.gd` | No changes needed (signals exist) |
| `/home/user/dev/sparklingfarce/core/systems/battle_manager.gd` | Use new audio APIs |
| `/home/user/dev/sparklingfarce/core/mod_system/mod_loader.gd` | Add music type |
| `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/play_music_executor.gd` | Support registry lookup |
| `/home/user/dev/sparklingfarce/project.godot` | Audio bus layout reference |
| `/home/user/dev/sparklingfarce/docs/modding/audio-sfx-reference.md` | Add MusicData docs |

---

## Phase Dependencies

```
Phase 1 (Foundation)
  |
  +-- Task 1.1 (Bus Layout) --+
  |                           |
  +-- Task 1.2 (Crossfade) ---+-- Task 1.3 (Volume Controls)
  |                           |
  +-- Task 1.4 (Ducking) -----+
  |                           |
  +-- Task 1.5 (Ambient) -----+
                              |
                              v
Phase 2 (Vertical Mixing)
  |
  +-- Task 2.1 (MusicData) ---+-- Task 2.2 (ModLoader) ---+-- Task 2.3 (AdaptivePlayer)
                              |                           |
                              +---------------------------+-- Task 2.4 (AudioManager)
                                                          |
                                                          +-- Task 2.5 (BattleManager)
                                                          |
                                                          +-- Task 2.6 (Base Assets)
                                                          |
                                                          v
Phase 3 (Polish)
  |
  +-- Task 3.1 (Spatial Audio)
  |
  +-- Task 3.2 (Stingers)
  |
  +-- Task 3.3 (Cinematic Commands)
```

---

## Success Metrics

1. **No Silent Gaps**: Music transitions never have perceptible silence
2. **Responsive Layers**: Layer changes complete within 500ms of game state change
3. **Dialog Clarity**: Music volume drops to <40% during dialog automatically
4. **Mod Compatibility**: Third-party mods can add custom MusicData without code changes
5. **Performance**: Audio system adds <1ms per frame overhead
6. **Test Coverage**: >80% of new code covered by unit tests

---

*Live long and prosper in glorious stereo.*
