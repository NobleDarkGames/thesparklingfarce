# Dialog System Architecture for The Sparkling Farce

**Status**: ✅ PHASES 1-3 COMPLETE & TESTED
**Date**: November 25, 2025
**Architect**: Lt. Claudbrain, USS Torvalds
**Implementation**: Claude Code (Phases 1-3)

---

## Implementation Status

### ✅ Phase 1: Core Dialog System (Complete - Commit 3159628)
- DialogManager autoload singleton with state machine
- DialogBox UI with ColorRect borders
- Text reveal with typewriter effect (30 chars/sec, punctuation pauses)
- Portrait display system (64x64, pixel-perfect positioning)
- ModRegistry integration for dialog discovery
- Continue indicator with blink animation
- Test scene and test dialog

### ✅ Phase 2: Visual Polish (Complete - Commit 74f49b0)
- Portrait slide-in animation when speaker changes (0.15s)
- Dialog box fade-in/fade-out transitions (0.2s)
- Emotion-aware portrait loading ({speaker}_{emotion}.png pattern)
- Speaker name yellow highlight on change
- Text completion glow effect
- 4 test portrait assets (Max & Anri, neutral & emotion variants)

### ✅ Phase 3: Choice & Branching (Complete - Commit b28688f)
- ChoiceSelector UI with slide-in animation
- Keyboard (UP/DOWN/ENTER) and mouse navigation
- Yellow highlight on selected choice
- Branching dialog tree support (2-4 choices)
- 7 test branching dialogs (YES/NO + 3-way Warrior/Mage/Archer)
- Bug fix: Dialog chaining fade animation conflict resolved

### ⏳ Phase 4: Battle Integration (Planned)
- BattleManager dialog hooks (pre-battle, victory, defeat, turn dialogs)
- Input priority handling during battles
- Dialog positioning based on battle camera

### ⏳ Phase 5: Audio & Story Flags (Planned)
- Text sound effects per character
- Background music integration
- Story flag persistence in SaveManager
- Conditional dialog based on flags

---

## Executive Summary

This document defines the complete architecture for The Sparkling Farce dialog system, a critical component for delivering narrative content in this Shining Force-inspired tactical RPG platform. The design follows the project's core principle: **dialog system = ENGINE CODE, dialog content = MOD DATA**.

### Key Design Principles

1. **Engine/Content Separation**: Dialog display system is core engine code; all dialog text/conversations are mod data
2. **Resource-Based**: Uses Godot Resources for all dialog data (already partially implemented)
3. **Signal-Driven**: Follows project's signal-based architecture for loose coupling
4. **Mod-Aware**: Multiple mods can contribute dialogs; registry handles discovery and conflicts
5. **Genre-Appropriate**: Designed for tactical RPG use cases (story, battle dialog, NPC conversations)
6. **Strictly Typed**: Follows project's strict typing requirements

---

## Current State Analysis

### What Already Exists ✅

The project has a **solid foundation** for dialogs:

1. **DialogueData Resource** (`core/resources/dialogue_data.gd`)
   - Line-based dialog structure with speaker, text, emotion, portrait support
   - Choice/branching system with next_dialogue references
   - Audio/visual metadata (background music, text sounds, backgrounds)
   - Auto-advance and flow control
   - Validation methods

2. **Dialogue Editor** (`addons/sparkling_editor/ui/dialogue_editor.gd`)
   - Complete editor GUI for creating/editing DialogueData
   - Line management (add, remove, reorder)
   - Choice management with next-dialogue selection
   - Reference checking before deletion

3. **Integration Points**
   - `BattleData` has dialog hooks (pre_battle_dialogue, victory_dialogue, defeat_dialogue, turn_dialogues)
   - Mod directory structure includes `/data/dialogues/` folders
   - Sample dialog exists in `_base_game` mod

### What's Missing ❌

1. **Dialog Display UI** - No runtime dialog box scene/script
2. **DialogManager Autoload** - No singleton to orchestrate dialog playback
3. **Portrait System** - No portrait rendering/positioning
4. **Text Advancement** - No text reveal/advancement mechanics
5. **Choice Selection UI** - No runtime UI for player choices
6. **Integration with Game Flow** - No hooks in BattleManager/SceneManager
7. **Audio Integration** - No text sound effects or background music playback
8. **Mod Registry Integration** - DialogueData not registered in ModRegistry

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        GAME SYSTEMS                              │
│  (BattleManager, SceneManager, InputManager, etc.)              │
└───────────────┬─────────────────────────────────┬───────────────┘
                │                                 │
                │ signals: dialog_requested       │ signals: dialog_completed
                │           dialog_choice_needed  │           dialog_cancelled
                ↓                                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                     DialogManager (Autoload)                     │
│  - Orchestrates dialog playback                                 │
│  - Manages dialog state (current line, choices)                 │
│  - Loads DialogueData from ModRegistry                          │
│  - Emits signals for UI and game flow                           │
└───────────────┬─────────────────────────────────────────────────┘
                │
                │ calls: show_dialog(), advance_text(), etc.
                ↓
┌─────────────────────────────────────────────────────────────────┐
│                   DialogBox (UI Scene)                           │
│  - Displays text, portraits, speaker names                      │
│  - Text reveal animation (typewriter effect)                    │
│  - Player input handling (advance, skip)                        │
│  - Positioned based on context (bottom, top, center)            │
└───────────────┬─────────────────────────────────────────────────┘
                │
                │ uses if choices exist
                ↓
┌─────────────────────────────────────────────────────────────────┐
│                 ChoiceSelector (UI Scene)                        │
│  - Displays branching choices                                   │
│  - Keyboard/mouse selection                                     │
│  - Emits selected choice to DialogManager                       │
└─────────────────────────────────────────────────────────────────┘

                DATA FLOW (Mod System)

┌─────────────────────────────────────────────────────────────────┐
│                         Mods                                     │
│  mods/_base_game/data/dialogues/*.tres                          │
│  mods/my_campaign/data/dialogues/*.tres                         │
└───────────────┬─────────────────────────────────────────────────┘
                │
                │ loaded by ModLoader at startup
                ↓
┌─────────────────────────────────────────────────────────────────┐
│                      ModRegistry                                 │
│  get_all_resources("dialogue")                                  │
│  get_resource("dialogue", "intro_001")                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Design

### 1. DialogueData Resource (EXISTS - Minor Enhancements Needed)

**Location**: `core/resources/dialogue_data.gd`

**Current Structure**: Already well-designed! Minor additions recommended:

```gdscript
class_name DialogueData
extends Resource

# EXISTING FIELDS (KEEP AS-IS)
@export var dialogue_id: String
@export var dialogue_title: String
@export var lines: Array[Dictionary]
@export var choices: Array[Dictionary]
@export var next_dialogue: DialogueData
@export var auto_advance: bool
@export var advance_delay: float
@export var background_music: AudioStream
@export var text_sound: AudioStream
@export var background: Texture2D
@export var fade_duration: float

# RECOMMENDED ADDITIONS
@export_group("Display Settings")
## Position of dialog box ("bottom", "top", "center", "auto")
@export var box_position: String = "bottom"
## Text scroll speed multiplier (1.0 = normal, 2.0 = faster)
@export var text_speed: float = 1.0
## Allow skipping text reveal with button press
@export var allow_text_skip: bool = true
## Pause before auto-advancing (if auto_advance is true)
@export var pause_before_advance: float = 0.5

@export_group("Integration")
## Story flags to set when dialog completes
@export var completion_flags: Array[String] = []
## Required story flags to display this dialog
@export var required_flags: Array[String] = []
```

**Line Dictionary Structure** (already defined, document here):
```gdscript
{
  "speaker_name": String,      # Who is speaking
  "text": String,              # Dialog text
  "emotion": String,           # "neutral", "happy", "sad", "angry", etc.
  "portrait": Texture2D,       # Optional: speaker portrait
  "voice_clip": AudioStream    # Optional: voice audio
}
```

**Choice Dictionary Structure** (already defined):
```gdscript
{
  "choice_text": String,           # Text shown to player
  "next_dialogue": DialogueData,   # Dialog to play if chosen
  "condition_script": GDScript     # Optional: Only show if condition met
}
```

---

### 2. DialogManager (NEW - Core System)

**Location**: `core/systems/dialog_manager.gd` (autoload as "DialogManager")

**Responsibilities**:
- Load DialogueData from ModRegistry
- Manage dialog playback state machine
- Emit signals for UI updates and game flow
- Handle dialog chains (next_dialogue references)
- Process choices and branching
- Track story flags integration
- Audio coordination

**State Machine**:
```
IDLE → DIALOG_STARTING → SHOWING_LINE → (choice?) → WAITING_FOR_CHOICE → DIALOG_ENDING → IDLE
                            ↓                              ↓
                         LINE_COMPLETE              CHOICE_SELECTED
                            ↓                              ↓
                     (next line or end)            (branch to next)
```

**API Design**:

```gdscript
class_name DialogManager
extends Node

## Signals
signal dialog_started(dialogue_data: DialogueData)
signal line_changed(line_index: int, line_data: Dictionary)
signal choices_ready(choices: Array[Dictionary])
signal dialog_completed(dialogue_data: DialogueData)
signal dialog_cancelled()

## Current dialog state
enum State {
	IDLE,
	DIALOG_STARTING,
	SHOWING_LINE,
	WAITING_FOR_CHOICE,
	DIALOG_ENDING
}

var current_state: State = State.IDLE
var current_dialogue: DialogueData = null
var current_line_index: int = 0
var is_paused: bool = false

## Start a dialog by ID (loads from ModRegistry)
func start_dialog(dialogue_id: String) -> bool:
	var dialogue: DialogueData = ModLoader.registry.get_resource("dialogue", dialogue_id)
	if not dialogue:
		push_error("DialogManager: Dialogue '%s' not found in registry" % dialogue_id)
		return false
	return start_dialog_from_resource(dialogue)

## Start a dialog from DialogueData resource
func start_dialog_from_resource(dialogue: DialogueData) -> bool:
	if current_state != State.IDLE:
		push_warning("DialogManager: Dialog already active, cannot start new one")
		return false

	if not dialogue or not dialogue.validate():
		push_error("DialogManager: Invalid dialogue data")
		return false

	current_dialogue = dialogue
	current_line_index = 0
	current_state = State.DIALOG_STARTING

	# Handle background music
	if dialogue.background_music:
		AudioManager.play_music(dialogue.background_music)

	emit_signal("dialog_started", dialogue)
	_show_current_line()
	return true

## Advance to next line (called by UI when player presses button)
func advance_dialog() -> void:
	if current_state != State.SHOWING_LINE:
		return

	current_line_index += 1

	if current_line_index >= current_dialogue.get_line_count():
		# No more lines, check for choices or next dialog
		if current_dialogue.has_choices():
			_show_choices()
		elif current_dialogue.has_next():
			# Chain to next dialog
			var next_dialogue: DialogueData = current_dialogue.next_dialogue
			_end_dialog()
			start_dialog_from_resource(next_dialogue)
		else:
			_end_dialog()
	else:
		_show_current_line()

## Player selected a choice
func select_choice(choice_index: int) -> void:
	if current_state != State.WAITING_FOR_CHOICE:
		return

	var choice: Dictionary = current_dialogue.get_choice(choice_index)
	if choice.is_empty():
		return

	var next_dialogue: DialogueData = choice.get("next_dialogue", null)
	_end_dialog()

	if next_dialogue:
		start_dialog_from_resource(next_dialogue)

## Cancel current dialog
func cancel_dialog() -> void:
	if current_state == State.IDLE:
		return
	_end_dialog()
	emit_signal("dialog_cancelled")

## Pause/resume dialog
func pause_dialog() -> void:
	is_paused = true

func resume_dialog() -> void:
	is_paused = false

## Check if dialog is active
func is_dialog_active() -> bool:
	return current_state != State.IDLE

## PRIVATE METHODS

func _show_current_line() -> void:
	current_state = State.SHOWING_LINE
	var line: Dictionary = current_dialogue.get_line(current_line_index)
	emit_signal("line_changed", current_line_index, line)

	# Play text sound if defined
	if current_dialogue.text_sound:
		AudioManager.play_sfx(current_dialogue.text_sound)

func _show_choices() -> void:
	current_state = State.WAITING_FOR_CHOICE
	var choices: Array[Dictionary] = []
	for i in range(current_dialogue.get_choice_count()):
		choices.append(current_dialogue.get_choice(i))
	emit_signal("choices_ready", choices)

func _end_dialog() -> void:
	current_state = State.DIALOG_ENDING

	# Set completion flags if defined
	if current_dialogue and not current_dialogue.completion_flags.is_empty():
		for flag: String in current_dialogue.completion_flags:
			# TODO: Integration with SaveManager story flags
			pass

	emit_signal("dialog_completed", current_dialogue)

	current_dialogue = null
	current_line_index = 0
	current_state = State.IDLE
```

---

### 3. DialogBox (NEW - UI Scene)

**Location**: `scenes/ui/dialog_box.tscn` + `scenes/ui/dialog_box.gd`

**Visual Design** (Shining Force-inspired):

```
┌─────────────────────────────────────────────────────────┐
│ [Portrait]  SPEAKER NAME                                │
│             ────────────────                            │
│                                                         │
│   Dialog text appears here with typewriter effect.     │
│   Multiple lines supported.                             │
│                                                         │
│                                    [▼ Continue Indicator]│
└─────────────────────────────────────────────────────────┘
```

**Node Structure**:
```
DialogBox (Control)
├── Background (NinePatchRect) - Semi-transparent box with border
├── PortraitContainer (MarginContainer)
│   └── Portrait (TextureRect) - Speaker portrait
├── SpeakerNameLabel (Label) - Character name in bold
├── DialogTextLabel (RichTextLabel) - Main text with typewriter
└── ContinueIndicator (AnimatedSprite2D) - Blinking arrow
```

**Script Design**:

```gdscript
extends Control

## Signals
signal text_reveal_completed()
signal advance_requested()

## Node references
@onready var background: NinePatchRect = $Background
@onready var portrait: TextureRect = $PortraitContainer/Portrait
@onready var speaker_label: Label = $SpeakerNameLabel
@onready var text_label: RichTextLabel = $DialogTextLabel
@onready var continue_indicator: AnimatedSprite2D = $ContinueIndicator

## Text reveal state
var full_text: String = ""
var visible_characters: int = 0
var text_reveal_speed: float = 30.0  # chars per second
var is_revealing: bool = false
var can_skip: bool = true

## Current line data
var current_line: Dictionary = {}

func _ready() -> void:
	# Connect to DialogManager
	DialogManager.line_changed.connect(_on_line_changed)
	DialogManager.dialog_completed.connect(_on_dialog_completed)

	# Hide by default
	visible = false
	continue_indicator.visible = false

func _input(event: InputEvent) -> void:
	if not visible or not is_revealing:
		return

	# Skip text reveal
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		if is_revealing and can_skip:
			_finish_text_reveal()
			get_viewport().set_input_as_handled()
		else:
			emit_signal("advance_requested")
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if is_revealing:
		_update_text_reveal(delta)

## Show a new line of dialog
func _on_line_changed(line_index: int, line_data: Dictionary) -> void:
	current_line = line_data

	# Set speaker name
	speaker_label.text = line_data.get("speaker_name", "")

	# Set portrait
	var portrait_texture: Texture2D = line_data.get("portrait", null)
	if portrait_texture:
		portrait.texture = portrait_texture
		portrait.visible = true
	else:
		portrait.visible = false

	# Start text reveal
	full_text = line_data.get("text", "")
	_start_text_reveal()

	# Show dialog box
	visible = true

func _on_dialog_completed(dialogue_data: DialogueData) -> void:
	# Hide dialog box
	visible = false

## Start typewriter text reveal effect
func _start_text_reveal() -> void:
	visible_characters = 0
	is_revealing = true
	continue_indicator.visible = false
	text_label.visible_characters = 0

## Update text reveal per frame
func _update_text_reveal(delta: float) -> void:
	var chars_to_reveal: float = text_reveal_speed * delta
	visible_characters += chars_to_reveal

	text_label.visible_characters = int(visible_characters)

	if text_label.visible_characters >= full_text.length():
		_finish_text_reveal()

## Instantly complete text reveal
func _finish_text_reveal() -> void:
	is_revealing = false
	text_label.visible_characters = -1  # Show all
	continue_indicator.visible = true
	continue_indicator.play("blink")
	emit_signal("text_reveal_completed")

## Set text reveal speed multiplier
func set_text_speed(speed_mult: float) -> void:
	text_reveal_speed = 30.0 * speed_mult
```

---

### 4. ChoiceSelector (NEW - UI Scene)

**Location**: `scenes/ui/choice_selector.tscn` + `scenes/ui/choice_selector.gd`

**Visual Design**:

```
┌──────────────────────────┐
│  Please choose:          │
│                          │
│  ▶ Yes, let's go!        │
│    No, maybe later.      │
│    Ask for more info.    │
└──────────────────────────┘
```

**Script Design**:

```gdscript
extends Control

## Signals
signal choice_selected(choice_index: int)

## Node references
@onready var choice_container: VBoxContainer = $Panel/MarginContainer/ChoiceContainer

## State
var choices: Array[Dictionary] = []
var selected_index: int = 0
var choice_buttons: Array[Button] = []

const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)

func _ready() -> void:
	DialogManager.choices_ready.connect(_on_choices_ready)
	visible = false

func _on_choices_ready(choice_array: Array[Dictionary]) -> void:
	choices = choice_array
	_build_choice_ui()
	visible = true

func _build_choice_ui() -> void:
	# Clear existing buttons
	for button: Button in choice_buttons:
		button.queue_free()
	choice_buttons.clear()

	# Create button for each choice
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button: Button = Button.new()
		button.text = choice.get("choice_text", "Option " + str(i + 1))
		button.pressed.connect(_on_choice_button_pressed.bind(i))
		button.focus_entered.connect(_on_choice_focused.bind(i))
		choice_container.add_child(button)
		choice_buttons.append(button)

	# Focus first button
	if not choice_buttons.is_empty():
		choice_buttons[0].grab_focus()
		selected_index = 0

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_confirm_choice()
		get_viewport().set_input_as_handled()

func _move_selection(direction: int) -> void:
	selected_index = wrapi(selected_index + direction, 0, choice_buttons.size())
	choice_buttons[selected_index].grab_focus()

func _on_choice_focused(choice_index: int) -> void:
	selected_index = choice_index

func _on_choice_button_pressed(choice_index: int) -> void:
	selected_index = choice_index
	_confirm_choice()

func _confirm_choice() -> void:
	visible = false
	emit_signal("choice_selected", selected_index)
	DialogManager.select_choice(selected_index)
```

---

## Integration with Existing Systems

### ModLoader Integration

**Location**: `core/mod_system/mod_loader.gd`

Add dialogue resource loading to `_load_mod_resources()`:

```gdscript
func _load_mod_resources(mod: ModManifest) -> void:
	# ... existing resource loading (characters, classes, items, etc.)

	# Load dialogues
	var dialogues_path: String = mod.get_data_path() + "dialogues/"
	if DirAccess.dir_exists_absolute(dialogues_path):
		_load_resources_from_directory(dialogues_path, "dialogue", mod.id)
```

This automatically discovers all `.tres` files in `mods/*/data/dialogues/` and registers them.

### BattleManager Integration

**Location**: `core/systems/battle_manager.gd`

Add dialog hooks at appropriate battle events:

```gdscript
func start_battle(battle_data: BattleData) -> void:
	current_battle = battle_data

	# Show pre-battle dialog
	if battle_data.pre_battle_dialogue:
		DialogManager.start_dialog_from_resource(battle_data.pre_battle_dialogue)
		await DialogManager.dialog_completed

	# ... existing battle start code

func _check_victory_conditions() -> void:
	# ... existing victory check

	if victory_achieved:
		if current_battle.victory_dialogue:
			DialogManager.start_dialog_from_resource(current_battle.victory_dialogue)
			await DialogManager.dialog_completed

		_handle_battle_victory()

func _check_defeat_conditions() -> void:
	# ... existing defeat check

	if defeat_occurred:
		if current_battle.defeat_dialogue:
			DialogManager.start_dialog_from_resource(current_battle.defeat_dialogue)
			await DialogManager.dialog_completed

		_handle_battle_defeat()

func _on_turn_started(turn_number: int) -> void:
	# Check for turn-specific dialogs
	if turn_number in current_battle.turn_dialogues:
		var turn_dialogue: DialogueData = current_battle.turn_dialogues[turn_number]
		DialogManager.start_dialog_from_resource(turn_dialogue)
		await DialogManager.dialog_completed

	# ... existing turn logic
```

### InputManager Integration

**Location**: `core/systems/input_manager.gd`

Add dialog state handling:

```gdscript
func _input(event: InputEvent) -> void:
	# Dialog takes priority over battle input
	if DialogManager.is_dialog_active():
		return  # Let DialogManager/DialogBox handle input

	# ... existing battle input handling
```

### SaveManager Integration

**Location**: `core/systems/save_manager.gd`

Story flags for dialog conditions:

```gdscript
# Add to SaveData resource
@export var story_flags: Array[String] = []

# Methods in SaveManager
func set_story_flag(flag: String) -> void:
	if current_save_data and flag not in current_save_data.story_flags:
		current_save_data.story_flags.append(flag)

func has_story_flag(flag: String) -> bool:
	return current_save_data and flag in current_save_data.story_flags
```

Use in DialogManager:

```gdscript
func _check_dialog_requirements(dialogue: DialogueData) -> bool:
	for flag: String in dialogue.required_flags:
		if not SaveManager.has_story_flag(flag):
			return false
	return true
```

---

## File Organization

### Engine Code (Core Systems)

```
core/
├── systems/
│   └── dialog_manager.gd         # NEW: Dialog orchestration autoload
└── resources/
    └── dialogue_data.gd           # EXISTS: Minor enhancements needed
```

### UI Components (Scenes)

```
scenes/ui/
├── dialog_box.tscn                # NEW: Main dialog display
├── dialog_box.gd                  # NEW: Text reveal, portraits
├── choice_selector.tscn           # NEW: Choice selection UI
└── choice_selector.gd             # NEW: Choice input handling
```

### Editor Tools (Already Exists)

```
addons/sparkling_editor/ui/
├── dialogue_editor.tscn           # EXISTS: Dialog content editor
└── dialogue_editor.gd             # EXISTS: Already complete
```

### Mod Data (Content)

```
mods/_base_game/data/dialogues/    # Base game dialogs
mods/my_campaign/data/dialogues/   # Campaign-specific dialogs
mods/character_pack/data/dialogues/ # Character interactions
```

### Asset Structure (Per Mod)

```
mods/my_campaign/
├── data/
│   └── dialogues/
│       ├── intro_001.tres         # Story intro
│       ├── chapter_01_start.tres  # Chapter opening
│       └── npc_merchant.tres      # NPC conversation
└── assets/
    └── portraits/                 # Character portrait images
        ├── hero_neutral.png
        ├── hero_happy.png
        ├── villain_angry.png
        └── merchant_neutral.png
```

---

## Dialog Use Cases

### 1. Story Dialog (Non-Interactive)

**Use Case**: Opening cinematic, chapter introductions, cutscenes

**Example DialogueData**:
```gdscript
dialogue_id = "chapter_01_intro"
dialogue_title = "Chapter 1: The Journey Begins"
box_position = "bottom"
auto_advance = false  # Player advances manually

lines = [
	{
		"speaker_name": "Narrator",
		"text": "The kingdom of Guardiana was at peace...",
		"emotion": "neutral"
	},
	{
		"speaker_name": "Narrator",
		"text": "But dark forces were stirring in the north.",
		"emotion": "neutral"
	},
	{
		"speaker_name": "Max",
		"text": "Commander! Something's wrong at the gate!",
		"emotion": "worried",
		"portrait": preload("res://assets/portraits/max_worried.png")
	}
]

next_dialogue = preload("res://data/dialogues/chapter_01_battle_intro.tres")
```

**How It's Triggered**:
```gdscript
# In SceneManager or campaign progression
DialogManager.start_dialog("chapter_01_intro")
await DialogManager.dialog_completed
# Continue to next scene
```

### 2. Pre-Battle Dialog

**Use Case**: Setup battle context, introduce enemies, give objectives

**Example in BattleData**:
```gdscript
# In battle_data resource
pre_battle_dialogue = preload("res://data/dialogues/battle_01_intro.tres")
```

**DialogueData**:
```gdscript
dialogue_id = "battle_01_intro"
lines = [
	{
		"speaker_name": "Enemy Commander",
		"text": "You'll never stop us, Shining Force!",
		"emotion": "angry",
		"portrait": preload("res://assets/portraits/enemy_commander.png")
	},
	{
		"speaker_name": "Max",
		"text": "We'll see about that!",
		"emotion": "determined",
		"portrait": preload("res://assets/portraits/max_determined.png")
	}
]
# No next_dialogue - returns to battle
```

### 3. Victory/Defeat Dialog

**Use Case**: Post-battle commentary, XP summary, story progression

**BattleData Setup**:
```gdscript
victory_dialogue = preload("res://data/dialogues/battle_01_victory.tres")
defeat_dialogue = preload("res://data/dialogues/battle_01_defeat.tres")
```

**Victory Dialog**:
```gdscript
dialogue_id = "battle_01_victory"
lines = [
	{
		"speaker_name": "Max",
		"text": "We did it! The town is safe.",
		"emotion": "happy"
	}
]
completion_flags = ["battle_01_complete", "guardiana_saved"]
next_dialogue = preload("res://data/dialogues/chapter_01_complete.tres")
```

### 4. Turn-Based Dialog

**Use Case**: Mid-battle events, reinforcements, boss transformations

**BattleData Setup**:
```gdscript
turn_dialogues = {
	3: preload("res://data/dialogues/battle_02_reinforcements.tres"),
	10: preload("res://data/dialogues/battle_02_boss_rage.tres")
}
```

**Turn Dialog**:
```gdscript
dialogue_id = "battle_02_reinforcements"
lines = [
	{
		"speaker_name": "Enemy Messenger",
		"text": "Commander! Reinforcements have arrived!",
		"emotion": "excited"
	}
]
# Dialog pauses battle, then resumes
```

### 5. Branching Choice Dialog

**Use Case**: Player decisions, NPC interactions, recruitment

**DialogueData with Choices**:
```gdscript
dialogue_id = "npc_merchant_greeting"
lines = [
	{
		"speaker_name": "Merchant",
		"text": "Welcome, traveler! Care to see my wares?",
		"emotion": "friendly",
		"portrait": preload("res://assets/portraits/merchant.png")
	}
]

choices = [
	{
		"choice_text": "Yes, show me what you have.",
		"next_dialogue": preload("res://data/dialogues/merchant_shop.tres")
	},
	{
		"choice_text": "Not right now, thanks.",
		"next_dialogue": preload("res://data/dialogues/merchant_goodbye.tres")
	},
	{
		"choice_text": "Tell me about this town.",
		"next_dialogue": preload("res://data/dialogues/merchant_town_info.tres")
	}
]
```

### 6. Conditional Dialog (Story Flags)

**Use Case**: Different dialog based on player progress

**DialogueData**:
```gdscript
dialogue_id = "npc_guard_guardiana"
required_flags = ["visited_manarina", "met_anri"]  # Only show if conditions met

lines = [
	{
		"speaker_name": "Guard",
		"text": "I heard you met Princess Anri in Manarina!",
		"emotion": "impressed"
	}
]
```

**Alternative if flags not met**:
```gdscript
dialogue_id = "npc_guard_guardiana_default"
required_flags = []  # No requirements

lines = [
	{
		"speaker_name": "Guard",
		"text": "Welcome to Guardiana. Stay safe out there.",
		"emotion": "neutral"
	}
]
```

**Triggering Logic** (in NPC interaction):
```gdscript
# Try specific dialog first
if DialogManager.can_play_dialog("npc_guard_guardiana"):
	DialogManager.start_dialog("npc_guard_guardiana")
else:
	# Fallback to default
	DialogManager.start_dialog("npc_guard_guardiana_default")
```

---

## Visual Design Guidelines

### Positioning

Based on Shining Force style:

1. **Bottom Position** (default): Story dialog, NPC conversations
   - Anchored to bottom of screen
   - Portraits on left side
   - Does not obscure most of playfield

2. **Top Position**: Battle dialog when action is happening below
   - Anchored to top of screen
   - Used sparingly

3. **Center Position**: Dramatic moments, important announcements
   - Full-screen takeover
   - Centered dialog box
   - Background dimmed

### Portrait Display

Following Fire Emblem/Shining Force conventions:

1. **Portrait Size**: 64x64 or 96x96 pixels (HD: 128x128)
2. **Position**: Left side of dialog box
3. **Emotion Variants**: Store multiple portraits per character
   - `character_neutral.png`
   - `character_happy.png`
   - `character_sad.png`
   - `character_angry.png`
   - `character_worried.png`

4. **Portrait Animation** (future enhancement):
   - Slide in when speaker changes
   - Subtle bounce on text reveal
   - Fade/dim when not active speaker (multi-character scenes)

### Text Formatting

1. **Font**: Use Monogram font (project standard)
2. **Text Speed**: 30 characters/second (configurable)
3. **RichTextLabel**: Support BBCode for emphasis
   - `[b]bold text[/b]` for important words
   - `[i]italic[/i]` for thoughts
   - `[color=yellow]highlighted[/color]` for key terms

4. **Text Wrapping**: Auto-wrap to box width
5. **Line Breaks**: Respect manual line breaks in dialog text

### Continue Indicator

1. **Visual**: Blinking down arrow (▼) or "PRESS A" text
2. **Position**: Bottom-right corner of dialog box
3. **Animation**: Blink cycle (1 second on, 0.5 second off)
4. **Only Show**: When text reveal is complete

### Background Box

1. **Style**: Semi-transparent dark panel with border
2. **NinePatchRect**: Scalable border texture
3. **Opacity**: 85% opaque (allows seeing map beneath)
4. **Border**: 2-3 pixel white/gold border

---

## Audio Integration

### Text Sound Effects

**Per-Character Text Sounds**:
```gdscript
# In DialogueData
text_sound = preload("res://assets/sfx/text_beep.wav")

# Or per-line for variety
lines = [
	{
		"speaker_name": "Robot",
		"text": "BEEP BOOP. SYSTEMS NOMINAL.",
		"voice_clip": preload("res://assets/sfx/robot_beep.wav")
	}
]
```

**Implementation in DialogBox**:
```gdscript
func _update_text_reveal(delta: float) -> void:
	# ... text reveal logic

	# Play sound every N characters revealed
	if int(visible_characters) % 3 == 0:  # Every 3rd character
		if current_line.get("voice_clip"):
			AudioManager.play_sfx(current_line["voice_clip"])
		elif current_dialogue.text_sound:
			AudioManager.play_sfx(current_dialogue.text_sound)
```

### Background Music

**Dialog-Specific Music**:
```gdscript
# In DialogueData
background_music = preload("res://assets/music/emotional_scene.ogg")

# Plays when dialog starts, fades out when ends
```

**Implementation in DialogManager**:
```gdscript
func start_dialog_from_resource(dialogue: DialogueData) -> bool:
	# ...

	if dialogue.background_music:
		AudioManager.play_music(dialogue.background_music, fade_in=0.5)

	# ...

func _end_dialog() -> void:
	# Fade out dialog music, return to previous
	if current_dialogue.background_music:
		AudioManager.stop_music(fade_out=0.5)

	# ...
```

### Sound Effect Timing

1. **Dialog Start**: Soft "whoosh" or "chime" when box appears
2. **Text Reveal**: Gentle beep/blip per character
3. **Line Complete**: Subtle "ding" when full text shown
4. **Choice Hover**: Quiet cursor move sound
5. **Choice Select**: Confirmation beep

---

## Performance Considerations

### Text Reveal Optimization

1. **Visible Characters**: Use `RichTextLabel.visible_characters` property
   - Efficient: Only renders visible portion
   - Supports BBCode formatting
   - No manual string slicing needed

2. **Update Rate**: Update text reveal in `_process()` not `_physics_process()`
   - 60 FPS is sufficient for smooth typewriter
   - Reduces CPU usage

### Portrait Loading

1. **Preload Strategy**: Load portraits with DialogueData
   - Portraits preloaded when dialog resource loads
   - No runtime disk access during dialog

2. **Texture Reuse**: Cache commonly used portraits
   - Hero portraits used frequently
   - Keep in memory across dialogs

3. **Lazy Loading**: For memory-constrained targets
   - Only load portrait when line displays
   - Release when dialog ends

### Dialog Caching

1. **Frequent Dialogs**: Keep in memory
   - NPC greeting dialogs
   - Common battle dialogs
   - Tutorial messages

2. **One-Time Dialogs**: Release after use
   - Story cutscenes
   - Boss introductions

**Implementation**:
```gdscript
# In DialogManager
var cached_dialogs: Dictionary = {}

func get_cached_dialog(dialogue_id: String) -> DialogueData:
	if dialogue_id in cached_dialogs:
		return cached_dialogs[dialogue_id]

	var dialogue: DialogueData = ModLoader.registry.get_resource("dialogue", dialogue_id)

	# Cache if marked as frequently used
	if dialogue and dialogue.get("cache_in_memory", false):
		cached_dialogs[dialogue_id] = dialogue

	return dialogue
```

---

## Accessibility Features

### Text Display

1. **Adjustable Text Speed**: Settings menu option
   - Slow (15 chars/sec)
   - Normal (30 chars/sec)
   - Fast (60 chars/sec)
   - Instant (reveal all immediately)

2. **Skip Text Reveal**: Press A to finish reveal instantly
3. **Auto-Advance Option**: Configurable delay before next line
4. **Text Size**: Respect system accessibility settings

### Visual Clarity

1. **High Contrast Mode**: Optional higher opacity background
2. **Outline Text**: Black outline on white text for readability
3. **Colorblind Support**: Don't rely solely on color for choices

### Input Options

1. **Keyboard**: Arrow keys + Enter/Escape
2. **Mouse**: Click anywhere to advance, click choices
3. **Gamepad**: D-pad/Stick + A/B buttons
4. **Touch**: Tap to advance, tap choices (future mobile support)

---

## Testing Strategy

### Unit Tests (Headless)

**DialogueData Validation**:
```gdscript
func test_dialogue_validation():
	var dialogue = DialogueData.new()
	assert_false(dialogue.validate(), "Empty dialogue should fail validation")

	dialogue.dialogue_id = "test"
	dialogue.add_line("Hero", "Test text")
	assert_true(dialogue.validate(), "Valid dialogue should pass")

func test_dialogue_line_access():
	var dialogue = DialogueData.new()
	dialogue.add_line("Hero", "Line 1")
	dialogue.add_line("Mage", "Line 2")

	assert_equal(dialogue.get_line_count(), 2)
	assert_equal(dialogue.get_line(0)["text"], "Line 1")
	assert_equal(dialogue.get_line(1)["speaker_name"], "Mage")
```

**DialogManager State Machine**:
```gdscript
func test_dialog_manager_flow():
	var manager = DialogManager.new()
	var dialogue = _create_test_dialogue()

	assert_equal(manager.current_state, DialogManager.State.IDLE)

	manager.start_dialog_from_resource(dialogue)
	assert_equal(manager.current_state, DialogManager.State.SHOWING_LINE)

	manager.advance_dialog()
	assert_equal(manager.current_line_index, 1)

	manager.cancel_dialog()
	assert_equal(manager.current_state, DialogManager.State.IDLE)
```

### Integration Tests (Manual)

**Test Scenario 1: Story Dialog Chain**
1. Trigger dialog with 3 lines
2. Verify text reveals character by character
3. Press A to advance each line
4. Verify next_dialogue chain activates
5. Verify completion flags set

**Test Scenario 2: Battle Dialog**
1. Start battle with pre_battle_dialogue
2. Verify dialog shows before battle begins
3. Complete battle
4. Verify victory_dialogue shows after win

**Test Scenario 3: Branching Choices**
1. Trigger dialog with 3 choices
2. Verify choice UI appears
3. Navigate with arrow keys
4. Select choice 2
5. Verify next_dialogue corresponds to choice 2

**Test Scenario 4: Turn Dialog**
1. Start battle with turn_dialogues configured
2. Play through turns
3. Verify dialog triggers on correct turn
4. Verify battle pauses during dialog
5. Verify battle resumes after dialog

**Test Scenario 5: Mod Override**
1. Create two mods with same dialogue_id
2. Higher priority mod should override
3. Verify correct dialog text displays

### Performance Tests

1. **Memory**: Load 100 dialogs, measure memory usage
2. **FPS**: Display dialog during battle, verify no frame drops
3. **Load Time**: Measure dialog start latency (should be < 100ms)

---

## Implementation Phases

### Phase 1: Core Dialog System (Week 1)

**Goal**: Get basic dialog display working

**Tasks**:
1. Create DialogManager autoload singleton
   - State machine implementation
   - Signal definitions
   - Basic line advancement
2. Create DialogBox UI scene
   - Layout with speaker name, text, portrait
   - Basic show/hide functionality
3. Integrate with ModLoader
   - Add "dialogue" resource type loading
4. Manual test scene
   - Trigger dialog by pressing key
   - Verify text displays

**Completion Criteria**:
- Can display a single dialog with multiple lines
- Text shows instantly (no typewriter yet)
- Can advance with key press
- Mod dialogs load from registry

### Phase 2: Text Reveal & Polish (Week 1)

**Goal**: Add typewriter effect and visual polish

**Tasks**:
1. Implement text reveal in DialogBox
   - Typewriter character-by-character reveal
   - Adjustable speed
   - Skip functionality
2. Add continue indicator
   - Animated arrow sprite
   - Show when text complete
3. Add portraits
   - Portrait texture display
   - Positioning and scaling
4. Add dialog box styling
   - NinePatchRect background
   - Border and opacity
   - Positioning (bottom/top/center)

**Completion Criteria**:
- Text reveals smoothly at configurable speed
- Can skip text reveal with button press
- Portraits display correctly
- Dialog box looks polished

### Phase 3: Choice System (Week 2)

**Goal**: Branching dialog and player choices

**Tasks**:
1. Create ChoiceSelector UI scene
   - Button list for choices
   - Keyboard/mouse navigation
2. Implement choice handling in DialogManager
   - Detect when choices present
   - Route to next dialog based on choice
3. Test branching dialog chains
   - Create multi-path dialog tree
   - Verify correct paths taken

**Completion Criteria**:
- Can display 2-4 choices
- Player can select with keyboard or mouse
- Selected choice leads to correct next dialog
- Cancel returns to previous state

### Phase 4: Battle Integration (Week 2)

**Goal**: Dialog works in battle context

**Tasks**:
1. Add dialog hooks to BattleManager
   - Pre-battle dialog
   - Victory/defeat dialog
   - Turn dialog
2. Input priority handling
   - Dialog blocks battle input
   - Battle resumes after dialog
3. Test in actual battles
   - Create test battle with dialogs
   - Verify timing and flow

**Completion Criteria**:
- Pre-battle dialog shows before battle starts
- Victory dialog shows after win
- Turn dialogs trigger on correct turns
- Battle input disabled during dialog

### Phase 5: Audio & Story Flags (Week 3)

**Goal**: Audio integration and save system hooks

**Tasks**:
1. Text sound effects
   - Play sound per character reveal
   - Per-character voice clips
2. Background music
   - Dialog-specific music playback
   - Fade in/out handling
3. Story flag integration
   - Set completion_flags when dialog ends
   - Check required_flags before showing
4. SaveManager integration
   - Persistent story flag storage

**Completion Criteria**:
- Text sounds play during reveal
- Background music changes for dialogs
- Story flags save to SaveData
- Conditional dialogs work based on flags

### Phase 6: Advanced Features (Week 3-4)

**Goal**: Auto-advance, visual effects, editor improvements

**Tasks**:
1. Auto-advance dialog
   - Timer-based advancement
   - Configurable delays
2. Visual transitions
   - Fade in/out
   - Slide animations
3. Portrait animations
   - Slide in when speaker changes
   - Emotion transitions
4. Editor enhancements
   - Preview dialog in editor
   - Bulk import from spreadsheet

**Completion Criteria**:
- Auto-advance works with configurable timing
- Dialog box transitions smoothly
- Portraits animate on speaker change
- Editor has quality-of-life improvements

### Phase 7: Documentation & Polish (Week 4)

**Goal**: Content creator-ready system

**Tasks**:
1. Write comprehensive documentation
   - "Creating Dialogs" tutorial
   - DialogueData field reference
   - Best practices guide
2. Create example dialogs
   - Story dialog examples
   - Battle dialog examples
   - Choice dialog examples
3. Performance optimization
   - Profile and optimize hotspots
   - Memory usage reduction
4. Accessibility testing
   - Text size options
   - Skip functionality
   - Input method testing

**Completion Criteria**:
- Documentation complete and tested
- 10+ example dialogs in base_game mod
- Performance meets targets (60 FPS)
- Accessibility features verified

---

## Edge Cases & Error Handling

### Missing Resources

**Problem**: DialogueData references portrait that doesn't exist

**Solution**:
```gdscript
# In DialogBox._on_line_changed()
var portrait_texture: Texture2D = line_data.get("portrait", null)
if portrait_texture:
	portrait.texture = portrait_texture
	portrait.visible = true
else:
	# Use fallback or hide portrait
	portrait.visible = false
```

### Circular Dialog References

**Problem**: Dialog A → Dialog B → Dialog A (infinite loop)

**Solution**:
```gdscript
# In DialogManager
var _dialog_chain_stack: Array[String] = []  # Track dialog IDs

func start_dialog_from_resource(dialogue: DialogueData) -> bool:
	if dialogue.dialogue_id in _dialog_chain_stack:
		push_error("DialogManager: Circular reference detected: " + dialogue.dialogue_id)
		return false

	_dialog_chain_stack.append(dialogue.dialogue_id)
	# ... start dialog

func _end_dialog() -> void:
	if not _dialog_chain_stack.is_empty():
		_dialog_chain_stack.pop_back()
	# ... rest of end logic
```

### Invalid Choice Index

**Problem**: Player somehow selects choice_index = 5 when only 3 choices exist

**Solution**:
```gdscript
# In DialogManager.select_choice()
func select_choice(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= current_dialogue.get_choice_count():
		push_warning("DialogManager: Invalid choice index %d" % choice_index)
		return
	# ... process choice
```

### Dialog Triggered During Dialog

**Problem**: Battle system tries to start turn dialog while story dialog is active

**Solution**:
```gdscript
# In DialogManager
func start_dialog_from_resource(dialogue: DialogueData) -> bool:
	if current_state != State.IDLE:
		push_warning("DialogManager: Dialog '%s' blocked, already active" % dialogue.dialogue_id)
		# Queue for later or ignore
		return false
	# ... start dialog
```

### Null DialogueData in BattleData

**Problem**: BattleData.pre_battle_dialogue is null

**Solution**:
```gdscript
# In BattleManager
func start_battle(battle_data: BattleData) -> void:
	if battle_data.pre_battle_dialogue:  # Check if exists
		DialogManager.start_dialog_from_resource(battle_data.pre_battle_dialogue)
		await DialogManager.dialog_completed
	# ... continue
```

### Mod Conflicts

**Problem**: Two mods both provide "intro_dialog" with different text

**Solution**: ModRegistry priority system already handles this:
```gdscript
# ModRegistry automatically uses highest priority mod's version
# Log warning so user knows:
print("ModRegistry: Mod 'expansion_pack' overriding dialog 'intro_dialog' from 'base_game'")
```

---

## Future Enhancements (Post-MVP)

### Phase 8+: Advanced Features

1. **Animated Portraits**
   - Multi-frame portrait animations
   - Lip-sync with voice clips
   - Idle animations (blinking, breathing)

2. **Dialog Skipping**
   - Skip entire dialog chain with hold button
   - Resume at next non-skippable dialog
   - Mark dialogs as skippable/non-skippable

3. **Dialog History**
   - Backlog window (press button to review previous lines)
   - Scroll through conversation history
   - Useful for re-reading missed text

4. **Voice Acting Support**
   - Full voice clip per line
   - Auto-timing based on audio duration
   - Volume controls

5. **Multiple Speakers Per Line**
   - Split-screen portraits
   - Multiple characters visible
   - Highlight active speaker

6. **Cinematic Camera**
   - Camera moves during dialog
   - Focus on specific map areas
   - Zoom effects for dramatic moments

7. **Dynamic Text Insertion**
   - Variable substitution: "{hero_name}, you must..."
   - Stat display: "You need {gold_required} gold."
   - Conditional text: "[if has_item sword]I see you found the sword![/if]"

8. **Dialog Templates**
   - Reusable dialog patterns
   - Variable speaker/text
   - Reduce duplicate dialog resources

9. **Localization**
   - Multi-language support
   - Translation file import/export
   - Language switching at runtime

10. **Dialog Analytics**
    - Track which choices players select
    - Measure dialog completion rates
    - Identify skipped dialogs

---

## Risk Assessment

### High Risk

1. **Performance with Long Dialogs**
   - **Risk**: 100+ line dialog causes lag
   - **Mitigation**: Pagination, chunk loading
   - **Status**: Monitor during testing

2. **Complex Choice Trees**
   - **Risk**: Deeply nested choices confuse players
   - **Mitigation**: Editor validation, depth warnings
   - **Status**: Add depth limit (10 levels max)

### Medium Risk

1. **Portrait Asset Size**
   - **Risk**: High-res portraits consume memory
   - **Mitigation**: Recommend 128x128 max size, compression
   - **Status**: Document guidelines

2. **Audio File Management**
   - **Risk**: Many voice clips = large mod size
   - **Mitigation**: Optional voice acting, audio compression
   - **Status**: Provide guidance

### Low Risk

1. **Input Conflicts**
   - **Risk**: Dialog input interferes with battle
   - **Mitigation**: Clear input priority handling
   - **Status**: Handled by InputManager check

2. **Mod Compatibility**
   - **Risk**: Mods override each other's dialogs
   - **Mitigation**: Priority system + override warnings
   - **Status**: Already solved by ModRegistry

---

## Success Metrics

### Technical Metrics

- **Load Time**: Dialog starts in < 100ms
- **FPS**: No frame drops during text reveal (60 FPS maintained)
- **Memory**: 100 dialogs load in < 50 MB
- **Input Latency**: Button press to action < 50ms

### User Experience Metrics

- **Readability**: Text legible at 1920x1080 and 1280x720
- **Comprehension**: Players understand choices
- **Pacing**: Dialog doesn't feel too slow or too fast
- **Immersion**: Portraits and audio enhance experience

### Content Creator Metrics

- **Creation Time**: Create simple dialog in < 5 minutes
- **Error Rate**: < 10% validation failures
- **Documentation**: 90%+ find docs sufficient
- **Flexibility**: Can implement 80%+ of desired dialog scenarios

---

## Conclusion

This dialog system architecture provides **a robust, extensible foundation** for narrative content in The Sparkling Farce. The design adheres to the project's core principles:

1. ✅ **Engine/Content Separation**: Dialog system is engine code, content is mod data
2. ✅ **Resource-Based**: All data uses Godot Resources
3. ✅ **Signal-Driven**: Loose coupling via signals
4. ✅ **Mod-Aware**: Full ModRegistry integration
5. ✅ **Strictly Typed**: All code follows project standards
6. ✅ **Genre-Appropriate**: Designed for tactical RPG use cases

The phased implementation plan allows for **incremental development and testing**, with each phase building on the previous. By Phase 4, the system will be functional for battle integration. By Phase 7, it will be **content creator-ready**.

### Estimated Development Time

- **Phase 1-2**: 2 weeks (Core + Polish)
- **Phase 3-4**: 2 weeks (Choices + Battle)
- **Phase 5-6**: 2 weeks (Audio + Advanced)
- **Phase 7**: 1 week (Documentation)
- **Total**: 7 weeks for complete system

### Immediate Next Steps

1. Review this architecture with the team
2. Create Phase 1 implementation tasks
3. Set up test scenes for manual testing
4. Begin DialogManager implementation

**Status**: Architecture review complete. Ready to engage!

---

**Lt. Claudbrain**
*Software Analyst & Technical Lead*
*USS Torvalds*

*"The finest dialog system in the fleet - one that honors both the genre's legacy and modern best practices. Make it so."*
