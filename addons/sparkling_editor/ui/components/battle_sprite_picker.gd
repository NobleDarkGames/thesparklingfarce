@tool
class_name BattleSpritePicker
extends TexturePickerBase

## Battle sprite picker component for selecting tactical battle grid sprites.
## Extends TexturePickerBase with battle sprite-specific validation rules.
##
## Battle sprites are expected to be 32x32 or 64x64 pixels (standard grid sizes).
## Non-standard sizes receive warnings, but are still considered valid to allow
## flexibility for custom battle systems.
##
## Usage:
##   var picker: BattleSpritePicker = BattleSpritePicker.new()
##   picker.texture_selected.connect(_on_battle_sprite_selected)
##   add_child(picker)

# =============================================================================
# CONSTANTS
# =============================================================================

## Valid battle sprite sizes for standard grid alignment
const VALID_SIZES: Array[Vector2i] = [Vector2i(32, 32), Vector2i(64, 64)]


func _init() -> void:
	super._init()

	# Configure for battle sprite selection
	label_text = "Battle Sprite:"
	placeholder_text = "res://mods/<mod>/assets/sprites/battle/..."
	preview_size = Vector2(48, 48)
	default_browse_subpath = "assets/sprites/battle/"


func _validate_texture(path: String, texture: Texture2D) -> Dictionary:
	## Validate battle sprite texture with size-specific rules.
	## Returns validation result with appropriate severity.

	# ERROR: File not found or not a texture
	if texture == null:
		return {
			"valid": false,
			"message": "File not found",
			"severity": "error"
		}

	var width: int = texture.get_width()
	var height: int = texture.get_height()
	var size: Vector2i = Vector2i(width, height)

	# SUCCESS: Size is one of the valid standard sizes (32x32 or 64x64)
	if size in VALID_SIZES:
		return {
			"valid": true,
			"message": "",
			"severity": "success"
		}

	# WARNING: Size is square but non-standard
	if width == height:
		return {
			"valid": true,
			"message": "Non-standard size %dx%d (expected 32x32 or 64x64)" % [width, height],
			"severity": "warning"
		}

	# WARNING: Size is not square
	return {
		"valid": true,
		"message": "Non-square dimensions %dx%d (expected square)" % [width, height],
		"severity": "warning"
	}
