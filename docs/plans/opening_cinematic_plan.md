# Opening Cinematic Implementation Plan

**Status:** ✅ COMPLETE (Scene implemented in _sandbox mod)
**Author:** Lt. Claudbrain
**Date:** November 2025
**Last Reviewed:** December 1, 2025

---

## Mission Brief

Captain, this document outlines the implementation plan for the opening cinematic of The Sparkling Farce. Inspired by Shining Force 2's iconic temple opening (where Slade discovers the jewel), our version will feature Spade and Henchman in an original scenario that establishes intrigue while demonstrating the cinematic system's capabilities.

---

## Part 1: System Analysis

### Current Cinematic System Architecture

The cinematic system is mature and well-architected. Here is what we have to work with:

#### CinematicData Resource (`/home/user/dev/sparklingfarce/core/resources/cinematic_data.gd`)

A Resource-based data container that defines cinematic sequences through an array of command dictionaries. Key features:

- **Commands Array**: Each command has `type`, `target` (optional), and `params`
- **Settings**: `disable_player_input`, `fade_in_duration`, `fade_out_duration`, `can_skip`
- **Flow Control**: `next_cinematic` for chaining, `condition_script` for conditional playback

Helper methods exist for common commands:
- `add_move_entity(actor_id, path, speed, wait)`
- `add_set_facing(actor_id, direction)`
- `add_play_animation(actor_id, animation, wait)`
- `add_show_dialog(dialogue_id)`
- `add_camera_move(target_pos, speed, wait)`
- `add_camera_follow(actor_id)`
- `add_wait(duration)`
- `add_fade_screen(fade_type, duration)`
- `add_spawn_entity(actor_id, position, facing)`
- `add_despawn_entity(actor_id)`

#### CinematicsManager (`/home/user/dev/sparklingfarce/core/systems/cinematics_manager.gd`)

An autoload singleton that orchestrates cinematic playback:

- **States**: IDLE, LOADING, PLAYING, WAITING_FOR_COMMAND, WAITING_FOR_DIALOG, PAUSED, SKIPPING, TRANSITIONING, ENDING
- **Actor Registry**: Maps `actor_id` strings to CinematicActor components
- **Command Executor Pattern**: Extensible via `register_command_executor()`
- **Signals**: `cinematic_started`, `cinematic_ended`, `command_executed`, `cinematic_paused`, `cinematic_resumed`, `cinematic_skipped`

#### Command Executors (14 Built-in)

All located in `/home/user/dev/sparklingfarce/core/systems/cinematic_commands/`:

| Executor | Status | Notes |
|----------|--------|-------|
| `wait_executor.gd` | Fully Implemented | Uses manager's wait timer |
| `dialog_executor.gd` | Fully Implemented | Delegates to DialogManager |
| `set_facing_executor.gd` | Fully Implemented | Synchronous |
| `play_animation_executor.gd` | Fully Implemented | Supports wait parameter |
| `move_entity_executor.gd` | Fully Implemented | Uses GridManager path expansion |
| `camera_move_executor.gd` | Fully Implemented | Delegates to CameraController |
| `camera_follow_executor.gd` | Fully Implemented | Continuous following |
| `camera_shake_executor.gd` | Fully Implemented | Via CameraController |
| `fade_screen_executor.gd` | Fully Implemented | Creates overlay dynamically |
| `play_sound_executor.gd` | Stub | Needs AudioManager integration |
| `play_music_executor.gd` | Stub | Needs AudioManager integration |
| `spawn_entity_executor.gd` | **NOT IMPLEMENTED** | Returns immediately |
| `despawn_entity_executor.gd` | Stub | Needs entity management |
| `set_variable_executor.gd` | Implemented | Uses GameState |

#### CinematicActor (`/home/user/dev/sparklingfarce/core/components/cinematic_actor.gd`)

A component that makes entities controllable during cinematics:

- **Properties**: `actor_id`, `default_speed`, `sprite_node`, `collision_shape`
- **Methods**: `move_along_path()`, `move_along_path_direct()`, `set_facing()`, `play_animation()`, `teleport_to()`
- **Signals**: `movement_completed`, `animation_completed`, `facing_completed`

#### DialogueData Resource (`/home/user/dev/sparklingfarce/core/resources/dialogue_data.gd`)

- **Lines Array**: Each line has `speaker_name`, `text`, `portrait` (optional), `emotion`
- **Box Positions**: BOTTOM, TOP, CENTER, AUTO
- **Emotions**: NEUTRAL, HAPPY, SAD, ANGRY, WORRIED, SURPRISED, DETERMINED, THINKING
- **Portrait Auto-Loading**: Dialog box attempts to load `{speaker}_{emotion}.png` automatically

#### CameraController (`/home/user/dev/sparklingfarce/core/systems/camera_controller.gd`)

- **Follow Modes**: NONE, CURSOR, ACTIVE_UNIT, TARGET_POSITION
- **Methods**: `move_to_position()`, `follow_actor()`, `shake()`, `stop_follow()`
- **Signals**: `movement_completed`, `shake_completed`, `operation_completed`

### Existing Characters

Located in `/home/user/dev/sparklingfarce/mods/_sandbox/data/characters/`:

- **Spade** (`character_1764195361.tres`): unit_category = "player" (default), is_unique = true (default)
- **Henchman** (`character_1764212173.tres`): unit_category = "neutral", is_unique = false

Both characters use the same class (`class_1764195319.tres`) and have default stats.

### Current Opening Cinematic

The existing opening (`/home/user/dev/sparklingfarce/scenes/ui/opening_cinematic.tscn`) is a simple splash screen with "THE SPARKLING FARCE" title and "Press any key to continue" - it does not use the cinematic system at all.

---

## Part 2: Design

### Story Concept: "The Pilfered Prism"

**Setting**: An ancient temple vault, late at night. Flickering torchlight casts shadows on weathered stone walls adorned with faded murals of a great hero's deeds.

**Premise**: Spade, a cunning thief with more ambition than sense, has hired a henchman to help retrieve a legendary artifact - the Prismatic Shard - from its sealed resting place. Unknown to them, disturbing the shard will set into motion events that will shake the kingdom.

**Tone**: Light-hearted with an undercurrent of foreboding. The dialog should establish Spade as roguish and confident, while Henchman provides comic relief through earnest dim-wittedness. The ending should hint at consequences to come.

### Dialog Script (6 Exchanges)

```
[Scene: Dark temple interior. Camera fades in to show Spade examining an ornate pedestal with a glowing gem.]

HENCHMAN: "Boss, I don't like this place. The statues keep starin' at me."

SPADE: "Those statues haven't moved in a thousand years. Now keep watch while I work."

HENCHMAN: "But the old guy in town said bad things happen to folks who mess with this stuff..."

SPADE: "The 'old guy' also thought I was a traveling minstrel. Not exactly a reliable source."

[Spade reaches for the gem. A brief flash of light.]

SPADE: "Ha! See? Nothing to worry about. This little beauty is going to make us very rich."

[The ground trembles slightly. Dust falls from the ceiling.]

HENCHMAN: "Uh, Boss? Is the temple supposed to do that?"

SPADE: "...We should probably go. Quickly."

[Screen shakes. Fade to black.]
```

### Cinematic Structure

**Phase 1: Setup (0-2s)**
- Fade in from black
- Camera positioned on Spade near pedestal
- Henchman positioned to the side

**Phase 2: Dialog Exchange (2-30s)**
- 8 dialog lines with emotion variants
- Subtle camera movements to frame speakers

**Phase 3: The Heist (30-35s)**
- Spade animation (reaching gesture)
- Brief wait for tension

**Phase 4: Consequence (35-45s)**
- Camera shake
- Final warning dialog
- Fade to black

---

## Part 3: Implementation Plan

### File Structure

```
mods/
  _base_game/
    data/
      cinematics/
        opening_cinematic.tres          # NEW: CinematicData resource
      dialogues/
        opening_dialog_01.tres          # NEW: First dialog sequence
        opening_dialog_02.tres          # NEW: Second dialog sequence
        opening_dialog_03.tres          # NEW: Third dialog sequence
      portraits/
        spade_neutral.png               # NEW: Spade portrait (neutral)
        spade_confident.png             # NEW: Spade portrait (confident/smug)
        henchman_neutral.png            # NEW: Henchman portrait (neutral)
        henchman_worried.png            # NEW: Henchman portrait (worried)

scenes/
  cinematics/
    opening_cinematic_stage.tscn        # NEW: Scene with stage setup
    opening_cinematic_stage.gd          # NEW: Stage controller script
```

### Phase A: Create Portraits (Prerequisite)

Before the cinematic can display dialog properly, we need character portraits.

**Required Assets** (64x64 pixel art, PNG format):

1. `spade_neutral.png` - Default expression
2. `spade_confident.png` - Smug/self-satisfied expression
3. `henchman_neutral.png` - Default expression
4. `henchman_worried.png` - Nervous/concerned expression

**Location**: `/home/user/dev/sparklingfarce/mods/_base_game/assets/portraits/`

**Note**: The dialog box system (`dialog_box.gd` lines 122-153) automatically attempts to load portraits based on speaker name and emotion. If `spade_confident.png` exists, using `"emotion": "confident"` will load it automatically.

### Phase B: Create Dialog Data Resources

**File**: `/home/user/dev/sparklingfarce/mods/_base_game/data/dialogues/opening_dialog_01.tres`

```gdscript
[gd_resource type="Resource" script_class="DialogueData" load_steps=2 format=3]

[ext_resource type="Script" path="res://core/resources/dialogue_data.gd" id="1_dialogue_data"]

[resource]
script = ExtResource("1_dialogue_data")
dialogue_id = "opening_dialog_01"
dialogue_title = "Opening - Temple Discovery"
lines = Array[Dictionary]([{
"emotion": "worried",
"speaker_name": "Henchman",
"text": "Boss, I don't like this place. The statues keep starin' at me."
}, {
"emotion": "neutral",
"speaker_name": "Spade",
"text": "Those statues haven't moved in a thousand years. Now keep watch while I work."
}])
choices = Array[Dictionary]([])
box_position = 0
```

**File**: `/home/user/dev/sparklingfarce/mods/_base_game/data/dialogues/opening_dialog_02.tres`

```gdscript
[gd_resource type="Resource" script_class="DialogueData" load_steps=2 format=3]

[ext_resource type="Script" path="res://core/resources/dialogue_data.gd" id="1_dialogue_data"]

[resource]
script = ExtResource("1_dialogue_data")
dialogue_id = "opening_dialog_02"
dialogue_title = "Opening - The Warning"
lines = Array[Dictionary]([{
"emotion": "worried",
"speaker_name": "Henchman",
"text": "But the old guy in town said bad things happen to folks who mess with this stuff..."
}, {
"emotion": "confident",
"speaker_name": "Spade",
"text": "The 'old guy' also thought I was a traveling minstrel. Not exactly a reliable source."
}])
choices = Array[Dictionary]([])
box_position = 0
```

**File**: `/home/user/dev/sparklingfarce/mods/_base_game/data/dialogues/opening_dialog_03.tres`

```gdscript
[gd_resource type="Resource" script_class="DialogueData" load_steps=2 format=3]

[ext_resource type="Script" path="res://core/resources/dialogue_data.gd" id="1_dialogue_data"]

[resource]
script = ExtResource("1_dialogue_data")
dialogue_id = "opening_dialog_03"
dialogue_title = "Opening - The Heist"
lines = Array[Dictionary]([{
"emotion": "confident",
"speaker_name": "Spade",
"text": "Ha! See? Nothing to worry about. This little beauty is going to make us very rich."
}, {
"emotion": "worried",
"speaker_name": "Henchman",
"text": "Uh, Boss? Is the temple supposed to do that?"
}, {
"emotion": "neutral",
"speaker_name": "Spade",
"text": "...We should probably go. Quickly."
}])
choices = Array[Dictionary]([])
box_position = 0
```

### Phase C: Create the Cinematic Stage Scene

The stage scene provides the visual backdrop and actor setup for the cinematic.

**File**: `/home/user/dev/sparklingfarce/scenes/cinematics/opening_cinematic_stage.tscn`

```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scenes/cinematics/opening_cinematic_stage.gd" id="1_stage_script"]
[ext_resource type="PackedScene" path="res://scenes/ui/dialog_box.tscn" id="2_dialog_box"]
[ext_resource type="Theme" path="res://assets/themes/ui_theme.tres" id="3_ui_theme"]

[node name="OpeningCinematicStage" type="Node2D"]
script = ExtResource("1_stage_script")

[node name="Background" type="ColorRect" parent="."]
offset_right = 640.0
offset_bottom = 360.0
color = Color(0.08, 0.06, 0.12, 1)

[node name="TempleFloor" type="ColorRect" parent="."]
offset_left = 0.0
offset_top = 280.0
offset_right = 640.0
offset_bottom = 360.0
color = Color(0.15, 0.12, 0.1, 1)

[node name="Pedestal" type="ColorRect" parent="."]
offset_left = 288.0
offset_top = 200.0
offset_right = 352.0
offset_bottom = 280.0
color = Color(0.25, 0.22, 0.2, 1)

[node name="PrismaticShard" type="ColorRect" parent="Pedestal"]
offset_left = 20.0
offset_top = -20.0
offset_right = 44.0
offset_bottom = 4.0
color = Color(0.6, 0.8, 1.0, 1)

[node name="SpadeActor" type="CharacterBody2D" parent="." groups=["cinematic_actors"]]
position = Vector2(320, 256)

[node name="Visual" type="ColorRect" parent="SpadeActor"]
offset_left = -16.0
offset_top = -32.0
offset_right = 16.0
offset_bottom = 0.0
color = Color(0.2, 0.3, 0.5, 1)

[node name="CinematicActor" type="Node" parent="SpadeActor"]
script = ExtResource("res://core/components/cinematic_actor.gd")
actor_id = "spade"

[node name="HenchmanActor" type="CharacterBody2D" parent="." groups=["cinematic_actors"]]
position = Vector2(480, 256)

[node name="Visual" type="ColorRect" parent="HenchmanActor"]
offset_left = -16.0
offset_top = -32.0
offset_right = 16.0
offset_bottom = 0.0
color = Color(0.4, 0.35, 0.3, 1)

[node name="CinematicActor" type="Node" parent="HenchmanActor"]
script = ExtResource("res://core/components/cinematic_actor.gd")
actor_id = "henchman"

[node name="CameraController" type="Camera2D" parent="."]
script = ExtResource("res://core/systems/camera_controller.gd")
position = Vector2(320, 180)
enabled = true

[node name="UILayer" type="CanvasLayer" parent="."]
layer = 10

[node name="DialogBox" parent="UILayer" instance=ExtResource("2_dialog_box")]
```

**File**: `/home/user/dev/sparklingfarce/scenes/cinematics/opening_cinematic_stage.gd`

```gdscript
extends Node2D

## Opening Cinematic Stage
## Sets up the temple scene and plays the opening cinematic sequence.

@onready var spade_actor: CharacterBody2D = $SpadeActor
@onready var henchman_actor: CharacterBody2D = $HenchmanActor
@onready var camera: CameraController = $CameraController
@onready var prismatic_shard: ColorRect = $Pedestal/PrismaticShard

var cinematic_data: CinematicData = null


func _ready() -> void:
    # Wait for scene to be fully loaded
    await get_tree().process_frame

    # Register actors with CinematicsManager
    _register_actors()

    # Register camera
    camera.register_with_systems()

    # Build and start the cinematic
    _build_cinematic()
    _start_cinematic()


func _register_actors() -> void:
    # Get CinematicActor components and register them
    var spade_cinematic: CinematicActor = spade_actor.get_node("CinematicActor")
    var henchman_cinematic: CinematicActor = henchman_actor.get_node("CinematicActor")

    CinematicsManager.register_actor(spade_cinematic)
    CinematicsManager.register_actor(henchman_cinematic)

    print("Opening Cinematic: Registered actors 'spade' and 'henchman'")


func _build_cinematic() -> void:
    cinematic_data = CinematicData.new()
    cinematic_data.cinematic_id = "opening_cinematic"
    cinematic_data.cinematic_name = "Opening - The Pilfered Prism"
    cinematic_data.disable_player_input = true
    cinematic_data.can_skip = true
    cinematic_data.fade_in_duration = 1.0
    cinematic_data.fade_out_duration = 1.0

    # Phase 1: Fade in
    cinematic_data.add_fade_screen("in", 1.5)
    cinematic_data.add_wait(0.5)

    # Phase 2: First dialog exchange
    cinematic_data.add_show_dialog("opening_dialog_01")
    cinematic_data.add_wait(0.3)

    # Phase 2b: Second dialog exchange
    cinematic_data.add_show_dialog("opening_dialog_02")
    cinematic_data.add_wait(0.3)

    # Phase 3: Spade approaches pedestal
    cinematic_data.add_set_facing("spade", "up")
    cinematic_data.add_wait(1.0)

    # Phase 4: Final dialog and consequences
    cinematic_data.add_show_dialog("opening_dialog_03")

    # Phase 5: Camera shake (consequences)
    cinematic_data.commands.append({
        "type": "camera_shake",
        "params": {
            "intensity": 8.0,
            "duration": 1.5,
            "frequency": 25.0
        }
    })
    cinematic_data.add_wait(0.5)

    # Phase 6: Fade out
    cinematic_data.add_fade_screen("out", 1.5)

    print("Opening Cinematic: Built sequence with %d commands" % cinematic_data.commands.size())


func _start_cinematic() -> void:
    # Connect to cinematic_ended to transition after
    CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)

    # Play the cinematic
    var success: bool = CinematicsManager.play_cinematic_from_resource(cinematic_data)
    if not success:
        push_error("Opening Cinematic: Failed to start cinematic!")
        _on_cinematic_ended("")


func _on_cinematic_ended(cinematic_id: String) -> void:
    print("Opening Cinematic: Sequence complete, transitioning to main menu...")

    # Clean up actors
    CinematicsManager.unregister_actor("spade")
    CinematicsManager.unregister_actor("henchman")

    # Transition to main menu
    await get_tree().create_timer(0.5).timeout
    SceneManager.goto_main_menu()
```

### Phase D: Create CinematicData Resource (Alternative Approach)

As an alternative to building the cinematic in code, you can create it as a `.tres` resource file for easier editing:

**File**: `/home/user/dev/sparklingfarce/mods/_base_game/data/cinematics/opening_cinematic.tres`

```gdscript
[gd_resource type="Resource" script_class="CinematicData" load_steps=2 format=3]

[ext_resource type="Script" path="res://core/resources/cinematic_data.gd" id="1_cinematic_data"]

[resource]
script = ExtResource("1_cinematic_data")
cinematic_id = "opening_cinematic"
cinematic_name = "Opening - The Pilfered Prism"
description = "Spade and Henchman steal the Prismatic Shard from an ancient temple."
commands = Array[Dictionary]([
{
    "type": "fade_screen",
    "params": {"fade_type": "in", "duration": 1.5}
},
{
    "type": "wait",
    "params": {"duration": 0.5}
},
{
    "type": "show_dialog",
    "params": {"dialogue_id": "opening_dialog_01"}
},
{
    "type": "wait",
    "params": {"duration": 0.3}
},
{
    "type": "show_dialog",
    "params": {"dialogue_id": "opening_dialog_02"}
},
{
    "type": "wait",
    "params": {"duration": 0.3}
},
{
    "type": "set_facing",
    "target": "spade",
    "params": {"direction": "up"}
},
{
    "type": "wait",
    "params": {"duration": 1.0}
},
{
    "type": "show_dialog",
    "params": {"dialogue_id": "opening_dialog_03"}
},
{
    "type": "camera_shake",
    "params": {"intensity": 8.0, "duration": 1.5, "frequency": 25.0}
},
{
    "type": "wait",
    "params": {"duration": 0.5}
},
{
    "type": "fade_screen",
    "params": {"fade_type": "out", "duration": 1.5}
}
])
disable_player_input = true
fade_in_duration = 1.0
fade_out_duration = 1.0
can_skip = true
```

### Phase E: Wire Up the Opening Cinematic

Modify the game's startup flow to use the new cinematic scene instead of the simple splash.

**Option 1**: Replace the existing opening_cinematic.tscn

Update `/home/user/dev/sparklingfarce/scenes/ui/opening_cinematic.tscn` to instance the new stage scene, or simply change SceneManager to load the new scene.

**Option 2**: Update SceneManager (if it exists)

Look for where the opening cinematic is loaded and change the path to `res://scenes/cinematics/opening_cinematic_stage.tscn`.

---

## Part 4: Testing Strategy

### Headless Tests

1. **CinematicData Validation Test**
   - Create CinematicData programmatically
   - Call `validate()` and verify it returns true
   - Verify command count matches expected

2. **Dialog Resource Loading Test**
   - Verify all three dialog resources load via ModLoader
   - Verify each dialog has correct line counts
   - Verify dialogue_id matches expected values

3. **Actor Registration Test**
   - Create mock actors with CinematicActor components
   - Register with CinematicsManager
   - Verify `get_actor()` returns correct references

### Manual Tests

1. **Full Cinematic Playthrough**
   - Launch the opening cinematic scene directly
   - Verify fade in works
   - Verify all dialogs display with correct speaker names and text
   - Verify camera shake occurs
   - Verify fade out works
   - Verify transition to main menu

2. **Skip Functionality**
   - Press ESC/Cancel during cinematic
   - Verify cinematic is skipped
   - Verify transition still occurs correctly

3. **Portrait Display** (if portraits exist)
   - Verify portraits load correctly for each speaker
   - Verify emotion variants display when speaker emotion changes

---

## Part 5: Risks and Mitigations

### Risk 1: Missing Portraits

**Impact**: Dialog will display without portraits (functional but less polished)
**Mitigation**: The dialog box gracefully handles missing portraits. Create placeholder colored rectangles if needed initially.

### Risk 2: Spawn Entity Not Implemented

**Impact**: Cannot dynamically spawn actors during cinematic
**Mitigation**: Pre-place all actors in the stage scene. This is actually the recommended approach for opening cinematics anyway.

### Risk 3: Audio Not Implemented

**Impact**: No background music or sound effects
**Mitigation**: The cinematic will be silent but functional. Audio can be added in a future phase when AudioManager is implemented.

### Risk 4: GridManager Dependency

**Impact**: MoveEntityExecutor requires GridManager for path expansion
**Mitigation**: The opening cinematic does not require character movement (actors are pre-positioned). If movement is added later, ensure GridManager is initialized or use the fallback simple movement.

---

## Part 6: Future Enhancements

1. **Background Music**: Add ambient temple music when play_music_executor is implemented
2. **Sound Effects**: Add stone rumbling for camera shake, footsteps for movement
3. **Animated Sprites**: Replace ColorRect placeholders with actual character sprites
4. **Particle Effects**: Add dust particles during shake, gem glow effect
5. **Tilemap Background**: Replace ColorRect background with proper temple tilemap

---

## Summary

The cinematic system is well-prepared for this implementation. The primary work involves:

1. Creating 4 portrait assets (can be placeholder art initially)
2. Creating 3 DialogueData resource files
3. Creating the stage scene with actor setup
4. Creating the stage controller script
5. Optionally creating a CinematicData resource file

The architecture is sound, the executors are implemented, and the integration points are clear. This is a straightforward implementation that will serve as a template for future cinematics.

Make it so, Captain.

---

*Plan authored by Lt. Claudbrain, Stardate 2025.330*

---

## Implementation Notes (December 1, 2025)

**Status: ✅ COMPLETE**

The opening cinematic scene has been implemented in the _sandbox mod:

**Implementation Files:**
- `mods/_sandbox/scenes/cinematics/opening_cinematic_stage.tscn` - Stage scene with actors
- `mods/_sandbox/scenes/cinematics/opening_cinematic_stage.gd` - Stage controller script

**Features Implemented:**
- CinematicActor registration with CinematicsManager
- Camera registration
- Dialog box integration with DialogManager
- Cinematic playback from ModRegistry (game_opening)
- Scene transition to main menu after completion

**Future Polish (from Part 6):**
- Background music (awaiting AudioManager)
- Sound effects
- Animated sprites (currently ColorRect placeholders)
- Particle effects
- Proper tilemap background
