class_name SettingSliderWidget
extends HBoxContainer

## SettingSliderWidget - A reusable horizontal slider for numeric settings.
##
## Visual layout: Label (left) + 20 small bar segments (center) + value Label (right).
## Filled segments use yellow/highlight color, empty segments use dark gray.
## Designed for pause menu settings (volume, brightness, etc.).
##
## Built entirely in code -- no .tscn file required.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the value changes via adjust() or toggle input
signal value_changed(new_value: float)

# =============================================================================
# CONSTANTS
# =============================================================================

const FONT_SIZE: int = 16

## Bar segment count
const SEGMENT_COUNT: int = 20

## Segment visual dimensions
const SEGMENT_WIDTH: int = 4
const SEGMENT_HEIGHT: int = 8
const SEGMENT_GAP: int = 1

## Colors
const COLOR_LABEL_NORMAL: Color = Color(0.85, 0.85, 0.85)
const COLOR_LABEL_SELECTED: Color = Color(1.0, 0.95, 0.4)
const COLOR_SEGMENT_FILLED: Color = Color(1.0, 0.95, 0.4)
const COLOR_SEGMENT_EMPTY: Color = Color(0.25, 0.25, 0.3)
const COLOR_VALUE_TEXT: Color = Color(0.85, 0.85, 0.85)

## Label width so all sliders align
const LABEL_MIN_WIDTH: int = 80
const VALUE_LABEL_MIN_WIDTH: int = 40

# =============================================================================
# STATE
# =============================================================================

var _min_value: float = 0.0
var _max_value: float = 1.0
var _step: float = 0.05
var _current_value: float = 0.0

## Optional callable for custom value display (e.g., "1 HP" instead of "50%")
## Signature: func(value: float) -> String
var format_callback: Callable = Callable()

# =============================================================================
# UI REFERENCES
# =============================================================================

var _label: Label = null
var _bar_container: HBoxContainer = null
var _segments: Array[ColorRect] = []
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
	_label.add_theme_color_override("font_color", COLOR_LABEL_NORMAL)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

	# Bar container (holds the 20 segments)
	_bar_container = HBoxContainer.new()
	_bar_container.name = "BarContainer"
	_bar_container.add_theme_constant_override("separation", SEGMENT_GAP)
	_bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_bar_container)

	# Create bar segments
	for i: int in range(SEGMENT_COUNT):
		var segment: ColorRect = ColorRect.new()
		segment.name = "Segment%d" % i
		segment.custom_minimum_size = Vector2(SEGMENT_WIDTH, SEGMENT_HEIGHT)
		segment.color = COLOR_SEGMENT_EMPTY
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar_container.add_child(segment)
		_segments.append(segment)

	# Value label (right side, shows percentage or custom text)
	_value_label = Label.new()
	_value_label.name = "ValueLabel"
	_value_label.custom_minimum_size.x = VALUE_LABEL_MIN_WIDTH
	UIUtils.apply_monogram_style(_value_label, FONT_SIZE)
	_value_label.add_theme_color_override("font_color", COLOR_VALUE_TEXT)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_value_label)

# =============================================================================
# PUBLIC API
# =============================================================================

## Initialize the slider with label, range, step, and starting value.
func setup(label_text: String, min_value: float, max_value: float, step: float, current_value: float) -> void:
	_min_value = min_value
	_max_value = max_value
	_step = step
	_current_value = clampf(current_value, _min_value, _max_value)

	if _label:
		_label.text = label_text

	_update_bar()
	_update_value_label()


## Adjust the value by one step in the given direction (-1 or +1).
## Plays cursor_move SFX on change. No sound at min/max boundaries.
func adjust(direction: int) -> void:
	var old_value: float = _current_value
	var new_value: float = clampf(_current_value + _step * direction, _min_value, _max_value)

	if absf(new_value - old_value) < 0.0001:
		# Already at boundary -- no change, no sound
		return

	_current_value = new_value
	_update_bar()
	_update_value_label()
	AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)
	value_changed.emit(_current_value)


## Set the value directly (no SFX).
func set_value(value: float) -> void:
	_current_value = clampf(value, _min_value, _max_value)
	_update_bar()
	_update_value_label()


## Get the current value.
func get_value() -> float:
	return _current_value


## Set selected state -- yellow label when selected, gray when not.
func set_selected(is_selected: bool) -> void:
	if _label:
		var color: Color = COLOR_LABEL_SELECTED if is_selected else COLOR_LABEL_NORMAL
		_label.add_theme_color_override("font_color", color)

# =============================================================================
# INTERNAL
# =============================================================================

func _update_bar() -> void:
	if _segments.is_empty():
		return

	var range_size: float = _max_value - _min_value
	if range_size <= 0.0:
		return

	var fill_ratio: float = (_current_value - _min_value) / range_size
	var filled_count: int = roundi(fill_ratio * SEGMENT_COUNT)

	for i: int in range(SEGMENT_COUNT):
		var segment: ColorRect = _segments[i]
		if i < filled_count:
			segment.color = COLOR_SEGMENT_FILLED
		else:
			segment.color = COLOR_SEGMENT_EMPTY


func _update_value_label() -> void:
	if not _value_label:
		return

	if format_callback.is_valid():
		_value_label.text = format_callback.call(_current_value)
	else:
		# Default: show percentage
		var range_size: float = _max_value - _min_value
		if range_size <= 0.0:
			_value_label.text = "0%"
			return
		var percent: int = roundi((_current_value - _min_value) / range_size * 100.0)
		_value_label.text = "%d%%" % percent
