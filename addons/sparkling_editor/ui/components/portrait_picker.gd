@tool
class_name PortraitPicker
extends TexturePickerBase

## Portrait picker component for selecting character portrait images.
## Extends TexturePickerBase with portrait-specific validation rules.
##
## Portrait images are flexible in dimensions but receive warnings for:
## - Unusual aspect ratios (< 0.5 or > 2.0)
## - Very small images (< 16x16)
## - Large images that may affect performance (> 512x512)
##
## Usage:
##   var picker: PortraitPicker = PortraitPicker.new()
##   picker.texture_selected.connect(_on_portrait_selected)
##   add_child(picker)


func _init() -> void:
	super._init()

	# Configure for portrait selection
	label_text = "Portrait:"
	placeholder_text = "res://mods/<mod>/assets/portraits/..."
	preview_size = Vector2(64, 64)
	default_browse_subpath = "assets/portraits/"


func _validate_texture(path: String, texture: Texture2D) -> Dictionary:
	## Validate portrait texture with flexible rules.
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

	# WARNING: Very small image
	if width < 16 or height < 16:
		return {
			"valid": true,
			"message": "Very small image (%dx%d)" % [width, height],
			"severity": "warning"
		}

	# WARNING: Unusual aspect ratio
	var aspect_ratio: float = float(width) / float(height)
	if aspect_ratio < 0.5 or aspect_ratio > 2.0:
		return {
			"valid": true,
			"message": "Unusual aspect ratio (%.1f:1)" % aspect_ratio,
			"severity": "warning"
		}

	# INFO: Large image may affect performance
	if width > 512 or height > 512:
		return {
			"valid": true,
			"message": "Large image may affect performance",
			"severity": "info"
		}

	# SUCCESS: All checks pass
	return {
		"valid": true,
		"message": "",
		"severity": "success"
	}
