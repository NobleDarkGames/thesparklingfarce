@tool
class_name EditorThemeUtils
extends RefCounted

## Utility class for accessing Godot editor theme colors and standardized UI constants
## Use this instead of hardcoding colors to maintain consistency
## with the user's editor theme (light/dark modes, custom themes)

# =============================================================================
# UI Constants
# =============================================================================

## Standard label width for form fields across all editors
const DEFAULT_LABEL_WIDTH: int = 140

## Standard font sizes for consistency
const SECTION_FONT_SIZE: int = 16
const HELP_FONT_SIZE: int = 12

# =============================================================================
# Color Access
# =============================================================================

## Get a color from the editor theme
## Common names: "error_color", "warning_color", "success_color",
## "font_color", "font_disabled_color", "accent_color"
static func get_editor_color(color_name: String) -> Color:
	if not Engine.is_editor_hint():
		# Fallback colors for runtime (shouldn't happen but be safe)
		return _get_fallback_color(color_name)

	var base_control: Control = EditorInterface.get_base_control()
	if not base_control:
		return _get_fallback_color(color_name)

	return base_control.get_theme_color(color_name, "Editor")


## Get error color (red) - for validation errors
static func get_error_color() -> Color:
	return get_editor_color("error_color")


## Get warning color (orange/yellow) - for non-blocking issues
static func get_warning_color() -> Color:
	return get_editor_color("warning_color")


## Get success color (green) - for confirmations
static func get_success_color() -> Color:
	# Godot doesn't have a standard "success_color", so we define one
	# that works well with both light and dark themes
	if Engine.is_editor_hint():
		var base_control: Control = EditorInterface.get_base_control()
		if base_control:
			# Try to get a green-ish color from the theme
			var accent: Color = base_control.get_theme_color("accent_color", "Editor")
			# Create a green variant
			return Color(0.4, 0.8, 0.4)
	return Color(0.4, 0.8, 0.4)


## Get disabled/hint text color
static func get_disabled_color() -> Color:
	return get_editor_color("font_disabled_color")


## Get help text color (subdued, for hints and secondary info)
static func get_help_color() -> Color:
	var base_control: Control = EditorInterface.get_base_control() if Engine.is_editor_hint() else null
	if base_control:
		return base_control.get_theme_color("font_disabled_color", "Editor")
	return Color(0.7, 0.7, 0.7)


## Get accent color (used for highlights, selections)
static func get_accent_color() -> Color:
	return get_editor_color("accent_color")


## Get font color (main text)
static func get_font_color() -> Color:
	return get_editor_color("font_color")


# =============================================================================
# StyleBox Creation
# =============================================================================

## Create a panel StyleBox for error display
static func create_error_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var error_color: Color = get_error_color()

	# Use a darker/lighter version for background based on error color
	style.bg_color = Color(error_color.r * 0.3, error_color.g * 0.3, error_color.b * 0.3, 0.95)
	style.border_color = error_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)

	return style


## Create a panel StyleBox for info display
static func create_info_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var accent_color: Color = get_accent_color()

	style.bg_color = Color(accent_color.r * 0.2, accent_color.g * 0.2, accent_color.b * 0.3, 0.95)
	style.border_color = Color(accent_color.r * 0.6, accent_color.g * 0.6, accent_color.b * 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)

	return style


## Create a panel StyleBox for success display
static func create_success_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var success_color: Color = get_success_color()

	style.bg_color = Color(success_color.r * 0.2, success_color.g * 0.3, success_color.b * 0.2, 0.95)
	style.border_color = success_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)

	return style


# =============================================================================
# Fallback Colors
# =============================================================================

## Provide fallback colors when editor theme is unavailable
static func _get_fallback_color(color_name: String) -> Color:
	match color_name:
		"error_color":
			return Color(1.0, 0.3, 0.3)
		"warning_color":
			return Color(1.0, 0.7, 0.2)
		"font_color":
			return Color(0.9, 0.9, 0.9)
		"font_disabled_color":
			return Color(0.6, 0.6, 0.6)
		"accent_color":
			return Color(0.4, 0.6, 1.0)
		_:
			return Color(1.0, 1.0, 1.0)
