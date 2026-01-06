extends Control

## HeroNameEntry - SF2-style character name entry screen
##
## Displays a grid of characters for the player to select from
## to name their hero. Supports keyboard navigation.

signal name_confirmed(hero_name: String)

const MAX_NAME_LENGTH: int = 8
const GRID_COLUMNS: int = 10

# Character grid content (SF2-style layout)
const CHARACTER_GRID: Array[String] = [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
	"K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
	"U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d",
	"e", "f", "g", "h", "i", "j", "k", "l", "m", "n",
	"o", "p", "q", "r", "s", "t", "u", "v", "w", "x",
	"y", "z", "0", "1", "2", "3", "4", "5", "6", "7",
	"8", "9", ".", ",", "-", "!", "?", "&", "'", " ",
]

# Node references (set in _ready)
var _portrait_rect: TextureRect
var _name_label: Label
var _grid_container: GridContainer
var _del_button: Button
var _end_button: Button

# State
var _current_name: String = ""
var _cursor_position: int = 0
var _character_buttons: Array[Button] = []
var _hero_data: CharacterData = null

# Cursor blink timer
var _blink_timer: float = 0.0
var _cursor_visible: bool = true
const BLINK_INTERVAL: float = 0.5


func _ready() -> void:
	_setup_ui()
	_populate_character_grid()
	_update_display()

	# Focus on first character after a frame
	await get_tree().process_frame
	if not _character_buttons.is_empty():
		_character_buttons[0].grab_focus()


func _process(delta: float) -> void:
	# Handle cursor blinking
	_blink_timer += delta
	if _blink_timer >= BLINK_INTERVAL:
		_blink_timer = 0.0
		_cursor_visible = not _cursor_visible
		_update_name_display()


## Initialize with hero data for portrait and default name
func set_hero_data(hero: CharacterData) -> void:
	_hero_data = hero
	if hero:
		_current_name = hero.character_name
		if _portrait_rect:
			_portrait_rect.texture = hero.get_portrait_safe()
	_update_display()


func _setup_ui() -> void:
	# Create background
	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.1, 0.1, 0.15, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Main container - increased size to fit all content
	var main_container: VBoxContainer = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_CENTER)
	main_container.anchor_left = 0.5
	main_container.anchor_top = 0.5
	main_container.anchor_right = 0.5
	main_container.anchor_bottom = 0.5
	main_container.offset_left = -300
	main_container.offset_top = -160
	main_container.offset_right = 300
	main_container.offset_bottom = 320
	main_container.add_theme_constant_override("separation", 12)
	add_child(main_container)

	# Title
	var title: Label = Label.new()
	title.text = "Enter Hero Name"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)  # Monogram requires multiples of 8
	main_container.add_child(title)

	# Content area - side-by-side layout (portrait section | character grid)
	var content_area: HBoxContainer = HBoxContainer.new()
	content_area.name = "ContentArea"
	content_area.add_theme_constant_override("separation", 24)
	content_area.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(content_area)

	# Left side: Portrait and name stacked vertically
	var portrait_section: VBoxContainer = VBoxContainer.new()
	portrait_section.name = "PortraitSection"
	portrait_section.add_theme_constant_override("separation", 12)
	portrait_section.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(portrait_section)

	# Portrait
	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "Portrait"
	_portrait_rect.custom_minimum_size = Vector2(64, 64)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_section.add_child(_portrait_rect)

	# Name display with frame
	var name_frame: PanelContainer = PanelContainer.new()
	name_frame.custom_minimum_size = Vector2(160, 40)
	portrait_section.add_child(name_frame)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 24)
	name_frame.add_child(_name_label)

	# Right side: Character grid
	_grid_container = GridContainer.new()
	_grid_container.name = "CharacterGrid"
	_grid_container.columns = GRID_COLUMNS
	_grid_container.add_theme_constant_override("h_separation", 4)
	_grid_container.add_theme_constant_override("v_separation", 2)
	content_area.add_child(_grid_container)

	# Control buttons (DEL, END) - bottom center
	var button_container: HBoxContainer = HBoxContainer.new()
	button_container.name = "ControlButtons"
	button_container.add_theme_constant_override("separation", 20)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(button_container)

	_del_button = Button.new()
	_del_button.name = "DelButton"
	_del_button.text = "DEL"
	_del_button.custom_minimum_size = Vector2(80, 40)
	_del_button.pressed.connect(_on_del_pressed)
	_del_button.focus_neighbor_top = NodePath("")  # Will be set after grid is built
	button_container.add_child(_del_button)

	_end_button = Button.new()
	_end_button.name = "EndButton"
	_end_button.text = "END"
	_end_button.custom_minimum_size = Vector2(80, 40)
	_end_button.pressed.connect(_on_end_pressed)
	_end_button.focus_neighbor_top = NodePath("")  # Will be set after grid is built
	button_container.add_child(_end_button)


func _populate_character_grid() -> void:
	_character_buttons.clear()

	for i: int in range(CHARACTER_GRID.size()):
		var char_text: String = CHARACTER_GRID[i]
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(32, 32)

		# Display space as visible character
		if char_text == " ":
			button.text = "_"
		else:
			button.text = char_text

		button.pressed.connect(_on_character_selected.bind(char_text))
		_grid_container.add_child(button)
		_character_buttons.append(button)

	# Set up focus neighbors for better navigation
	_setup_focus_neighbors()


func _setup_focus_neighbors() -> void:
	var grid_size: int = CHARACTER_GRID.size()
	var last_row_start: int = grid_size - GRID_COLUMNS

	for i: int in range(grid_size):
		var button: Button = _character_buttons[i]

		# Bottom row connects to DEL/END buttons
		if i >= last_row_start:
			# Left half goes to DEL, right half goes to END
			if i - last_row_start < GRID_COLUMNS / 2:
				button.focus_neighbor_bottom = _del_button.get_path()
			else:
				button.focus_neighbor_bottom = _end_button.get_path()

	# DEL and END connect to bottom row
	if grid_size > 0:
		var left_bottom: Button = _character_buttons[last_row_start]
		var right_bottom: Button = _character_buttons[grid_size - 1]
		_del_button.focus_neighbor_top = left_bottom.get_path()
		_end_button.focus_neighbor_top = right_bottom.get_path()

	# DEL and END neighbor each other
	_del_button.focus_neighbor_right = _end_button.get_path()
	_end_button.focus_neighbor_left = _del_button.get_path()


func _on_character_selected(char_text: String) -> void:
	if _current_name.length() < MAX_NAME_LENGTH:
		_current_name += char_text
		_update_display()
		_play_select_sound()


func _on_del_pressed() -> void:
	if not _current_name.is_empty():
		_current_name = _current_name.substr(0, _current_name.length() - 1)
		_update_display()
		_play_select_sound()


func _on_end_pressed() -> void:
	if not _current_name.is_empty():
		_play_confirm_sound()
		name_confirmed.emit(_current_name)


func _update_display() -> void:
	_update_name_display()
	_update_button_states()


func _update_name_display() -> void:
	if _name_label:
		var cursor: String = "_" if _cursor_visible else " "
		if _current_name.length() < MAX_NAME_LENGTH:
			_name_label.text = _current_name + cursor
		else:
			_name_label.text = _current_name


func _update_button_states() -> void:
	if _end_button:
		_end_button.disabled = _current_name.is_empty()


func _play_select_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_select", AudioManager.SFXCategory.UI)


func _play_confirm_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_confirm", AudioManager.SFXCategory.UI)


## Capture unhandled input to prevent leaking to game controls
func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
