class_name SettingOptionsWidget
extends HBoxContainer

## SettingOptionsWidget - A reusable option selector for multi-choice settings.
##
## Visual layout: Label (left) + "< Option1  [Option2]  Option3 >" (right).
## The selected option is shown in brackets with yellow highlight; others are gray.
## Arrow indicators < > shown at edges. Wraps around on cycling.
## Designed for pause menu settings (window mode, text speed, etc.).
##
## Built entirely in code -- no .tscn file required.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the selected option changes via adjust()
signal value_changed(new_value: Variant)

# =============================================================================
# CONSTANTS
# =============================================================================

const FONT_SIZE: int = 16

## Colors - use centralized UIColors class

## Label width so all option widgets align with sliders/toggles
const LABEL_MIN_WIDTH: int = 80

# =============================================================================
# STATE
# =============================================================================

## Array of {"label": String, "value": Variant}
var _options: Array[Dictionary] = []
var _current_index: int = 0

# =============================================================================
# UI REFERENCES
# =============================================================================

var _label: Label = null
var _options_label: Label = null

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

	# Options display label (shows "< Opt1  [Opt2]  Opt3 >")
	_options_label = Label.new()
	_options_label.name = "OptionsLabel"
	UIUtils.apply_monogram_style(_options_label, FONT_SIZE)
	_options_label.add_theme_color_override("font_color", UIColors.SETTINGS_LABEL)
	_options_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_options_label)

# =============================================================================
# PUBLIC API
# =============================================================================

## Initialize the widget with label, option list, and starting index.
## Each option: {"label": String, "value": Variant}
func setup(label_text: String, options: Array[Dictionary], current_index: int) -> void:
	_options = options
	_current_index = clampi(current_index, 0, maxi(_options.size() - 1, 0))

	if _label:
		_label.text = label_text

	_update_display()


## Adjust the selected option by direction (-1 = left, +1 = right).
## Wraps around at boundaries. Plays cursor_move SFX on change.
func adjust(direction: int) -> void:
	if _options.is_empty():
		return

	var old_index: int = _current_index
	_current_index = wrapi(_current_index + direction, 0, _options.size())

	if _current_index == old_index:
		# Single option -- nothing to cycle, no sound
		return

	_update_display()
	AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)
	value_changed.emit(get_value())


## Set the value by finding a matching option value. No SFX.
func set_value(value: Variant) -> void:
	for i: int in range(_options.size()):
		var option: Dictionary = _options[i]
		if "value" in option and option["value"] == value:
			_current_index = i
			_update_display()
			return


## Get the current option's value.
func get_value() -> Variant:
	if _options.is_empty():
		return null
	var option: Dictionary = _options[_current_index]
	if "value" in option:
		return option["value"]
	return null


## Set selected state -- yellow label when selected, gray when not.
func set_selected(is_selected: bool) -> void:
	if _label:
		var color: Color = UIColors.SETTINGS_SELECTED if is_selected else UIColors.SETTINGS_LABEL
		_label.add_theme_color_override("font_color", color)

# =============================================================================
# INTERNAL
# =============================================================================

func _update_display() -> void:
	if not _options_label:
		return

	if _options.is_empty():
		_options_label.text = ""
		return

	# Build the display string: "< Opt1  [Opt2]  Opt3 >"
	var parts: PackedStringArray = PackedStringArray()
	parts.append("<")

	for i: int in range(_options.size()):
		var option: Dictionary = _options[i]
		var option_label: String = ""
		if "label" in option:
			option_label = str(option["label"])

		if i == _current_index:
			parts.append("[%s]" % option_label)
		else:
			parts.append(option_label)

	parts.append(">")

	_options_label.text = " ".join(parts)

	# Color the entire options label based on whether it contains the selection.
	# For a richer display we use BBCode-style coloring via the label text itself,
	# but since Label doesn't support inline colors, we highlight the whole line
	# when the widget row is selected (handled by set_selected on the left label).
	# The options label uses the active color to draw attention to the bracketed item.
	_options_label.add_theme_color_override("font_color", UIColors.SETTINGS_SELECTED)
