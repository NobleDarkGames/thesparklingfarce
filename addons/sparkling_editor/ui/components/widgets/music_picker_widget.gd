@tool
class_name MusicPickerWidget
extends EditorWidgetBase

## Dropdown picker for music tracks and SFX
## Uses MusicDiscovery to scan mods/*/assets/audio/ directories
##
## Usage:
##   var picker: MusicPickerWidget = MusicPickerWidget.new(MusicPickerWidget.AudioType.MUSIC)
##   picker.set_value("battle_theme")
##   picker.value_changed.connect(_on_music_changed)
##   add_child(picker)

enum AudioType {
	MUSIC,  # Scans mods/*/assets/audio/music/
	SFX     # Scans mods/*/assets/audio/sfx/
}

## The type of audio this picker displays
var audio_type: AudioType = AudioType.MUSIC

## Whether to allow selecting "(None)" / empty
var allow_none: bool = true

## Label shown for the none option
var none_label: String = "(None)"

var _option_button: OptionButton
var _current_value: String = ""


func _init(p_audio_type: AudioType = AudioType.MUSIC) -> void:
	audio_type = p_audio_type


func _ready() -> void:
	_setup_ui()
	refresh()


func _setup_ui() -> void:
	_option_button = OptionButton.new()
	_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_button.item_selected.connect(_on_item_selected)
	add_child(_option_button)


## Override: Set the current value and update selection
func set_value(value: Variant) -> void:
	_current_value = str(value) if value != null else ""
	_select_current_value()


## Override: Get the current value
func get_value() -> Variant:
	return _current_value


## Override: Rebuild the dropdown from discovered audio files
func refresh() -> void:
	if not _option_button:
		return

	_option_button.clear()

	# Add none option if allowed
	if allow_none:
		_option_button.add_item(none_label)
		_option_button.set_item_metadata(0, "")

	# Get audio tracks based on type
	var tracks: Array[Dictionary] = []
	if audio_type == AudioType.MUSIC:
		tracks = MusicDiscovery.get_available_music_with_labels()
	else:
		tracks = MusicDiscovery.get_available_sfx_with_labels()

	# Add tracks to dropdown
	var base_index: int = 1 if allow_none else 0
	for i: int in range(tracks.size()):
		var track: Dictionary = tracks[i]
		var label: String = "[%s] %s" % [track.mod, track.display_name]
		_option_button.add_item(label)
		_option_button.set_item_metadata(base_index + i, track.id)

	# Select current value
	_select_current_value()


## Select the item matching _current_value
func _select_current_value() -> void:
	if not _option_button:
		return

	# Empty value = select none
	if _current_value.is_empty():
		if allow_none:
			_option_button.selected = 0
		return

	# Find matching item
	for i: int in range(_option_button.item_count):
		var metadata: Variant = _option_button.get_item_metadata(i)
		if metadata == _current_value:
			_option_button.selected = i
			return

	# Value not found - add as custom entry
	var item_index: int = _option_button.item_count
	_option_button.add_item("[custom] %s" % _current_value)
	_option_button.set_item_metadata(item_index, _current_value)
	_option_button.selected = item_index


func _on_item_selected(index: int) -> void:
	var metadata: Variant = _option_button.get_item_metadata(index)
	var new_value: String = str(metadata) if metadata != null else ""

	if new_value != _current_value:
		_current_value = new_value
		value_changed.emit(new_value)
