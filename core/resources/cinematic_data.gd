class_name CinematicData
extends Resource

## Represents a cinematic sequence with scripted commands.
## Cinematics can control character movement, camera, dialog, and game state.
## Inspired by Shining Force 2's command-based cutscene system.

## Command type enumeration for type safety and editor dropdowns
enum CommandType {
	MOVE_ENTITY,      ## Move a character along a path
	SET_FACING,       ## Change character facing direction
	PLAY_ANIMATION,   ## Trigger sprite animation
	SHOW_DIALOG,      ## Display dialog sequence
	CAMERA_MOVE,      ## Move camera to position
	CAMERA_FOLLOW,    ## Set camera to follow entity
	CAMERA_SHAKE,     ## Shake camera for dramatic effect
	WAIT,             ## Pause for duration
	FADE_SCREEN,      ## Fade in/out effects
	PLAY_SOUND,       ## Play sound effect
	PLAY_MUSIC,       ## Change background music
	SPAWN_ENTITY,     ## Create NPC/object
	DESPAWN_ENTITY,   ## Remove NPC/object
	TRIGGER_BATTLE,   ## Start battle encounter
	CHANGE_SCENE,     ## Scene transition
	SET_VARIABLE,     ## Set game state variable
	CONDITIONAL,      ## Branch based on condition
	PARALLEL          ## Execute commands simultaneously
}

@export var cinematic_id: String = ""
@export var cinematic_name: String = ""
@export_multiline var description: String = ""

@export_group("Commands")
## Array of command dictionaries to execute in sequence
## Each command has: type (String), target (String, optional), params (Dictionary)
@export var commands: Array[Dictionary] = []

@export_group("Settings")
## Disable player input during cinematic
@export var disable_player_input: bool = true
## Fade in at start
@export var fade_in_duration: float = 0.5
## Fade out at end
@export var fade_out_duration: float = 0.5
## Allow skipping with cancel key
@export var can_skip: bool = true
## Key to skip cinematic
@export var skip_key: String = "ui_cancel"
## Auto-play after previous cinematic
@export var auto_play: bool = false

@export_group("Flow Control")
## Next cinematic to play after this one
@export var next_cinematic: CinematicData
## Condition script to check before playing
@export var condition_script: GDScript


## Add a move entity command
func add_move_entity(actor_id: String, path: Array, speed: float = 3.0, wait: bool = true) -> void:
	var command: Dictionary = {
		"type": "move_entity",
		"target": actor_id,
		"params": {
			"path": path,
			"speed": speed,
			"wait": wait
		}
	}
	commands.append(command)


## Add a set facing command
func add_set_facing(actor_id: String, direction: String) -> void:
	var command: Dictionary = {
		"type": "set_facing",
		"target": actor_id,
		"params": {
			"direction": direction
		}
	}
	commands.append(command)


## Add a play animation command
func add_play_animation(actor_id: String, animation: String, wait: bool = true) -> void:
	var command: Dictionary = {
		"type": "play_animation",
		"target": actor_id,
		"params": {
			"animation": animation,
			"wait": wait
		}
	}
	commands.append(command)


## Add a show dialog command (loads from ModRegistry by ID)
func add_show_dialog(dialogue_id: String) -> void:
	var command: Dictionary = {
		"type": "show_dialog",
		"params": {
			"dialogue_id": dialogue_id
		}
	}
	commands.append(command)


## Add a single inline dialog line command
## Use this when you need to interleave dialog with other commands (camera shake, movement, etc.)
## Each call creates a separate dialog command that waits for player to advance.
func add_dialog_line(speaker: String, text: String, emotion: String = "neutral") -> void:
	var line: Dictionary = {
		"speaker_name": speaker,
		"text": text,
		"emotion": emotion
	}

	var command: Dictionary = {
		"type": "show_dialog",
		"params": {
			"lines": [line]
		}
	}
	commands.append(command)


## Add multiple inline dialog lines as a single dialog sequence
## All lines will play sequentially before the next cinematic command executes.
## Use add_dialog_line() instead if you need to interleave with other commands.
func add_inline_dialog(lines: Array[Dictionary]) -> void:
	if lines.is_empty():
		push_warning("CinematicData: add_inline_dialog called with empty lines array")
		return

	var command: Dictionary = {
		"type": "show_dialog",
		"params": {
			"lines": lines
		}
	}
	commands.append(command)


## Add a camera move command
func add_camera_move(target_pos: Vector2, speed: float = 2.0, wait: bool = true) -> void:
	var command: Dictionary = {
		"type": "camera_move",
		"params": {
			"target_pos": target_pos,
			"speed": speed,
			"wait": wait
		}
	}
	commands.append(command)


## Add a camera follow command
func add_camera_follow(actor_id: String) -> void:
	var command: Dictionary = {
		"type": "camera_follow",
		"target": actor_id,
		"params": {}
	}
	commands.append(command)


## Add a camera shake command for dramatic effect
## intensity: Maximum pixel offset for shake
## duration: How long the shake lasts in seconds
## frequency: Oscillation frequency (higher = faster shaking)
## wait: If true, cinematic waits for shake to complete before continuing
func add_camera_shake(intensity: float = 6.0, duration: float = 0.5, frequency: float = 30.0, wait: bool = false) -> void:
	var command: Dictionary = {
		"type": "camera_shake",
		"params": {
			"intensity": intensity,
			"duration": duration,
			"frequency": frequency,
			"wait": wait
		}
	}
	commands.append(command)


## Add a wait command
func add_wait(duration: float) -> void:
	var command: Dictionary = {
		"type": "wait",
		"params": {
			"duration": duration
		}
	}
	commands.append(command)


## Add a fade screen command
func add_fade_screen(fade_type: String, duration: float = 1.0) -> void:
	var command: Dictionary = {
		"type": "fade_screen",
		"params": {
			"fade_type": fade_type,  # "in" or "out"
			"duration": duration
		}
	}
	commands.append(command)


## Add a spawn entity command
func add_spawn_entity(actor_id: String, position: Vector2, facing: String = "down") -> void:
	var command: Dictionary = {
		"type": "spawn_entity",
		"params": {
			"actor_id": actor_id,
			"position": position,
			"facing": facing
		}
	}
	commands.append(command)


## Add a despawn entity command
func add_despawn_entity(actor_id: String) -> void:
	var command: Dictionary = {
		"type": "despawn_entity",
		"target": actor_id,
		"params": {}
	}
	commands.append(command)


## Get a specific command by index
func get_command(index: int) -> Dictionary:
	if index >= 0 and index < commands.size():
		return commands[index]
	return {}


## Get total number of commands
func get_command_count() -> int:
	return commands.size()


## Check if this cinematic has a next cinematic
func has_next() -> bool:
	return next_cinematic != null


## Validate that required fields are set
func validate() -> bool:
	if cinematic_id.is_empty():
		push_error("CinematicData: cinematic_id is required")
		return false

	if commands.is_empty():
		push_error("CinematicData: cinematic must have at least one command")
		return false

	# Validate each command has required fields
	for i: int in range(commands.size()):
		var command: Dictionary = commands[i]
		if not "type" in command:
			push_error("CinematicData: command " + str(i) + " has no type")
			return false
		if not "params" in command:
			push_error("CinematicData: command " + str(i) + " has no params")
			return false

	return true
