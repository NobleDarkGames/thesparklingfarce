@tool
class_name CinematicCommandDefs
extends RefCounted

## Cinematic Command Definitions
## Contains static data and utilities for cinematic command types.
## Extracted from CinematicEditor to reduce file size.

# =============================================================================
# Parameter Bound Constants
# =============================================================================
# These define reasonable limits for cinematic command parameters.
const SPEED_MIN: float = 0.5
const SPEED_MAX: float = 20.0
const DURATION_SHORT_MAX: float = 5.0
const DURATION_LONG_MAX: float = 60.0
const SHAKE_INTENSITY_MIN: float = 0.5
const SHAKE_INTENSITY_MAX: float = 20.0
const SHAKE_FREQUENCY_MIN: float = 5.0
const SHAKE_FREQUENCY_MAX: float = 60.0

# =============================================================================
# Command Type Definitions
# =============================================================================
# Each command type defines its parameters and their types for the inspector
const COMMAND_DEFINITIONS: Dictionary = {
	"wait": {
		"description": "Pause execution for a duration",
		"icon": "Timer",
		"params": {
			"duration": {"type": "float", "default": 1.0, "min": 0.0, "max": 60.0, "hint": "Seconds to wait"}
		}
	},
	"dialog_line": {
		"description": "Show a single dialog line with character portrait",
		"icon": "RichTextLabel",
		"params": {
			"character_id": {"type": "character", "default": "", "hint": "Character UID"},
			"text": {"type": "text", "default": "", "hint": "Variables: {player_name}, {char:id}, {gold}, {party_count}, {flag:name}, {var:key}"},
			"emotion": {"type": "enum", "default": "neutral", "options": ["neutral", "happy", "sad", "angry", "worried", "surprised", "determined", "thinking"], "hint": "Character emotion"},
			"auto_follow": {"type": "bool", "default": true, "hint": "Auto-follow speaker with camera"}
		}
	},
	"show_dialog": {
		"description": "Show dialog from a DialogueData resource",
		"icon": "AcceptDialog",
		"params": {
			"dialogue_id": {"type": "string", "default": "", "hint": "DialogueData resource ID"}
		}
	},
	"move_entity": {
		"description": "Move an entity along a path",
		"icon": "MoveLocal",
		"has_target": true,
		"params": {
			"path": {"type": "path", "default": [], "hint": "Array of [x, y] grid positions"},
			"speed": {"type": "float", "default": 3.0, "min": 0.5, "max": 20.0, "hint": "Movement speed"},
			"wait": {"type": "bool", "default": true, "hint": "Wait for movement to complete"}
		}
	},
	"set_facing": {
		"description": "Set entity facing direction",
		"icon": "MeshTexture",
		"has_target": true,
		"params": {
			"direction": {"type": "enum", "default": "down", "options": ["up", "down", "left", "right"], "hint": "Facing direction"}
		}
	},
	"set_position": {
		"description": "Instantly teleport entity to position (no animation)",
		"icon": "Transform2D",
		"has_target": true,
		"params": {
			"position": {"type": "vector2", "default": [0, 0], "hint": "Target position (grid)"},
			"facing": {"type": "enum", "default": "", "options": ["", "up", "down", "left", "right"], "hint": "Facing after teleport (optional)"}
		}
	},
	"play_animation": {
		"description": "Play an animation on an entity",
		"icon": "Animation",
		"has_target": true,
		"params": {
			"animation": {"type": "string", "default": "", "hint": "Animation name"},
			"wait": {"type": "bool", "default": false, "hint": "Wait for animation to complete"}
		}
	},
	"camera_move": {
		"description": "Move camera to a position",
		"icon": "Camera2D",
		"params": {
			"target_pos": {"type": "vector2", "default": [0, 0], "hint": "Target position"},
			"speed": {"type": "float", "default": 2.0, "min": 0.5, "max": 20.0, "hint": "Camera speed (tiles/sec)"},
			"wait": {"type": "bool", "default": true, "hint": "Wait for movement to complete"},
			"is_grid": {"type": "bool", "default": false, "hint": "Position is in grid coordinates"}
		}
	},
	"camera_follow": {
		"description": "Make camera follow an entity",
		"icon": "ViewportTexture",
		"has_target": true,
		"params": {
			"wait": {"type": "bool", "default": false, "hint": "Wait for initial movement"},
			"duration": {"type": "float", "default": 0.5, "min": 0.0, "max": 5.0, "hint": "Transition duration"},
			"continuous": {"type": "bool", "default": true, "hint": "Keep following until stopped"},
			"speed": {"type": "float", "default": 8.0, "min": 1.0, "max": 20.0, "hint": "Follow speed"}
		}
	},
	"camera_shake": {
		"description": "Shake the camera for dramatic effect",
		"icon": "AudioStreamRandomizer",
		"params": {
			"intensity": {"type": "float", "default": 2.0, "min": 0.5, "max": 20.0, "hint": "Shake intensity (pixels)"},
			"duration": {"type": "float", "default": 0.5, "min": 0.1, "max": 5.0, "hint": "Shake duration"},
			"frequency": {"type": "float", "default": 30.0, "min": 5.0, "max": 60.0, "hint": "Shake frequency"},
			"wait": {"type": "bool", "default": false, "hint": "Wait for shake to complete"}
		}
	},
	"fade_screen": {
		"description": "Fade screen in or out",
		"icon": "ColorRect",
		"params": {
			"fade_type": {"type": "enum", "default": "out", "options": ["in", "out"], "hint": "Fade direction"},
			"duration": {"type": "float", "default": 1.0, "min": 0.1, "max": 5.0, "hint": "Fade duration"},
			"color": {"type": "color", "default": [0, 0, 0, 1], "hint": "Fade color"}
		}
	},
	"play_sound": {
		"description": "Play a sound effect",
		"icon": "AudioStreamPlayer",
		"params": {
			"sound_id": {"type": "string", "default": "", "hint": "Sound effect ID"}
		}
	},
	"play_music": {
		"description": "Play background music",
		"icon": "AudioStreamPlayer2D",
		"params": {
			"music_id": {"type": "string", "default": "", "hint": "Music track ID"},
			"fade_duration": {"type": "float", "default": 0.5, "min": 0.0, "max": 5.0, "hint": "Fade-in duration"}
		}
	},
	"spawn_entity": {
		"description": "Spawn an entity at a position",
		"icon": "Node2D",
		"params": {
			"actor_id": {"type": "actor", "default": "", "hint": "Actor ID to assign"},
			"position": {"type": "vector2", "default": [0, 0], "hint": "Spawn position (grid)"},
			"facing": {"type": "enum", "default": "down", "options": ["up", "down", "left", "right"], "hint": "Initial facing"},
			"character_id": {"type": "character", "default": "", "hint": "CharacterData to spawn"}
		}
	},
	"despawn_entity": {
		"description": "Remove an entity from the scene",
		"icon": "Remove",
		"has_target": true,
		"params": {
			"fade": {"type": "float", "default": 0.0, "min": 0.0, "max": 3.0, "hint": "Fade out duration (0 = instant)"}
		}
	},
	"set_variable": {
		"description": "Set a game state variable or flag",
		"icon": "PinJoint2D",
		"params": {
			"variable": {"type": "string", "default": "", "hint": "Variable name"},
			"value": {"type": "variant", "default": true, "hint": "Value to set (true for flags)"}
		}
	},
	"open_shop": {
		"description": "Open a shop interface (weapon/item shop, church, crafter)",
		"icon": "ShoppingCart",
		"params": {
			"shop_id": {"type": "shop", "default": "", "hint": "ShopData resource ID"}
		}
	},
	"show_choice": {
		"description": "Show choices to player, each triggers an action",
		"icon": "OptionButton",
		"params": {
			"choices": {"type": "choices", "default": [], "hint": "Each choice has a label, action type, and value"}
		}
	}
}

# Default category assignments for commands without explicit category metadata
const DEFAULT_CATEGORIES: Dictionary = {
	"dialog_line": "Dialog",
	"show_dialog": "Dialog",
	"move_entity": "Entity",
	"set_facing": "Entity",
	"set_position": "Entity",
	"play_animation": "Entity",
	"spawn_entity": "Entity",
	"despawn_entity": "Entity",
	"camera_move": "Camera",
	"camera_follow": "Camera",
	"camera_shake": "Camera",
	"fade_screen": "Screen",
	"wait": "Screen",
	"play_sound": "Audio",
	"play_music": "Audio",
	"set_variable": "Game State",
	"open_shop": "Interaction",
	"show_choice": "Dialog"
}


## Get merged command definitions (hardcoded + dynamic from executor scripts)
## Dynamic definitions take priority over hardcoded ones
static func get_merged_definitions() -> Dictionary:
	var merged: Dictionary = COMMAND_DEFINITIONS.duplicate(true)

	# Scan executor scripts directly for metadata (works reliably in @tool scripts)
	# This approach doesn't depend on CinematicsManager being initialized
	var executor_dir: String = "res://core/systems/cinematic_commands/"
	var dir: DirAccess = DirAccess.open(executor_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with("_executor.gd") and not dir.current_is_dir():
				var script_path: String = executor_dir + file_name
				var script: GDScript = load(script_path) as GDScript
				if script:
					# Extract command type from filename (e.g., "add_party_member_executor.gd" -> "add_party_member")
					var cmd_type: String = file_name.replace("_executor.gd", "")

					# Instantiate to get metadata
					var executor: RefCounted = script.new()
					if executor.has_method("get_editor_metadata"):
						var metadata: Dictionary = executor.get_editor_metadata()
						if not metadata.is_empty():
							if cmd_type in merged:
								# Merge: overlay dynamic onto hardcoded
								var base: Dictionary = merged[cmd_type]
								for key: String in metadata.keys():
									base[key] = metadata[key]
							else:
								# New command type from executor
								merged[cmd_type] = metadata
			file_name = dir.get_next()
		dir.list_dir_end()

	return merged


## Build categories dictionary from command definitions
## Commands provide their own category via metadata, or use DEFAULT_CATEGORIES fallback
static func build_categories(definitions: Dictionary) -> Dictionary:
	var categories: Dictionary = {}

	for cmd_type: String in definitions:
		var def: Dictionary = definitions[cmd_type]
		var category: String = ""

		# Get category from metadata, or fallback to default
		if "category" in def:
			category = def.get("category", "")
		elif cmd_type in DEFAULT_CATEGORIES:
			category = DEFAULT_CATEGORIES[cmd_type]
		else:
			category = "Other"

		if category not in categories:
			categories[category] = []
		var category_list: Array = categories[category]
		category_list.append(cmd_type)

	# Sort categories in a sensible order
	var ordered: Dictionary = {}
	var preferred_order: Array = ["Dialog", "Entity", "Camera", "Screen", "Scene", "Audio", "Game State", "Interaction", "Party"]
	for cat: String in preferred_order:
		if cat in categories:
			ordered[cat] = categories[cat]
			categories.erase(cat)
	# Add any remaining categories at the end
	for cat: String in categories:
		ordered[cat] = categories[cat]

	return ordered
