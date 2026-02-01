class_name SettingToggleWidget
extends HBoxContainer

## SettingToggleWidget - A reusable ON/OFF toggle for boolean settings.
##
## Visual layout: Label (left) + value Label showing [ON] or [OFF] (right).
## ON is shown in yellow, OFF in gray.
## Designed for pause menu settings (screen shake, fullscreen, etc.).
##
## Built entirely in code -- no .tscn file required.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the value changes via adjust() or toggle()
signal value_changed(new_value: bool)

# =============================================================================
# CONSTANTS
# =============================================================================

const FONT_SIZE: int = 16

## Colors - use centralized UIColors class

## Label width so all toggles align with sliders
const LABEL_MIN_WIDTH: int = 80

# =============================================================================
# STATE
# =============================================================================

var _current_value: bool = false

# =============================================================================
# UI REFERENCES
# =============================================================================

var _label: Label = null
var _value_label: Label = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Configure the root HBoxContainer
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_BEGIN

	# Left label (setting name)
	_label = Label.new()
	_label.name = "SettingLabel"
	_label.custom_minimum_size.x = LABEL_MIN_WIDTH
	UIUtils.apply_monogram_style(_label, FONT_SIZE)
	_label.add_theme_color_override("font_color", UIColors.SETTINGS_LABEL)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

	# Value label (right side, shows [ON] or [OFF])
	_value_label = Label.new()
	_value_label.name = "ValueLabel"
	UIUtils.apply_monogram_style(_value_label, FONT_SIZE)
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_value_label)

# =============================================================================
# PUBLIC API
# =============================================================================

## Initialize the toggle with label and starting value.
func setup(label_text: String, current_value: bool) -> void:
	_current_value = current_value

	if _label:
		_label.text = label_text

	_update_display()


## Adjust the value (any direction toggles).
## Plays cursor_move SFX on change.
func adjust(direction: int) -> void:
	toggle()


## Toggle the current value. Plays cursor_move SFX.
func toggle() -> void:
	_current_value = not _current_value
	_update_display()
	AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)
	value_changed.emit(_current_value)


## Set the value directly (no SFX).
func set_value(value: bool) -> void:
	_current_value = value
	_update_display()


## Get the current value.
func get_value() -> bool:
	return _current_value


## Set selected state -- yellow label when selected, gray when not.
func set_selected(is_selected: bool) -> void:
	if _label:
		var color: Color = UIColors.SETTINGS_SELECTED if is_selected else UIColors.SETTINGS_LABEL
		_label.add_theme_color_override("font_color", color)

# =============================================================================
# INTERNAL
# =============================================================================

func _update_display() -> void:
	if not _value_label:
		return

	if _current_value:
		_value_label.text = "[ON]"
		_value_label.add_theme_color_override("font_color", UIColors.SETTINGS_SELECTED)
	else:
		_value_label.text = "[OFF]"
		_value_label.add_theme_color_override("font_color", UIColors.SETTINGS_INACTIVE)
