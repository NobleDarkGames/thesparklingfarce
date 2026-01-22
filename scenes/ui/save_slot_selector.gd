extends Control

## SaveSlotSelector - Save slot selection and new game flow
##
## Handles both new game and load game modes:
## - new_game: Select slot -> Name entry -> Start campaign
## - load_game: Select occupied slot -> Load game

const HeroNameEntryScene: PackedScene = preload("res://scenes/ui/hero_name_entry.tscn")
const DialogBoxScene: PackedScene = preload("res://scenes/ui/dialog_box.tscn")
const CinematicLoader = preload("res://core/systems/cinematic_loader.gd")
const NO_CAMPAIGN_ERROR_CINEMATIC: String = "res://core/defaults/cinematics/no_campaign_error.json"

# Node references
var _title_label: Label
var _slot_container: VBoxContainer
var _back_button: Button
var _slot_buttons: Array[Button] = []
var _name_entry: Control = null
var _dialog_box: Control = null

# State
var _mode: String = "new_game"  # "new_game" or "load_game"
var _selected_slot: int = -1


func _ready() -> void:
	# Get mode from SceneManager
	_mode = SceneManager.save_slot_mode
	_setup_ui()
	_refresh_slot_display()

	# Focus on first slot after a frame
	await get_tree().process_frame
	if not _slot_buttons.is_empty():
		_slot_buttons[0].grab_focus()


func _setup_ui() -> void:
	# Background
	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.1, 0.1, 0.15, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Main container
	var main_container: VBoxContainer = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_CENTER)
	main_container.anchor_left = 0.5
	main_container.anchor_top = 0.5
	main_container.anchor_right = 0.5
	main_container.anchor_bottom = 0.5
	main_container.offset_left = -220
	main_container.offset_top = -150
	main_container.offset_right = 220
	main_container.offset_bottom = 150
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)

	# Title
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_update_title()
	main_container.add_child(_title_label)

	# Slot container
	_slot_container = VBoxContainer.new()
	_slot_container.name = "SlotContainer"
	_slot_container.add_theme_constant_override("separation", 10)
	main_container.add_child(_slot_container)

	# Create slot buttons
	for i: int in range(SaveManager.MAX_SLOTS):
		var slot_button: Button = Button.new()
		slot_button.name = "Slot%d" % (i + 1)
		slot_button.custom_minimum_size = Vector2(400, 60)
		slot_button.add_theme_font_size_override("font_size", 16)  # Monogram requires multiples of 8
		slot_button.pressed.connect(_on_slot_pressed.bind(i + 1))
		_slot_container.add_child(slot_button)
		_slot_buttons.append(slot_button)

	# Back button
	var button_container: CenterContainer = CenterContainer.new()
	main_container.add_child(button_container)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(120, 40)
	_back_button.pressed.connect(_on_back_pressed)
	button_container.add_child(_back_button)

	# Set focus neighbors
	if not _slot_buttons.is_empty():
		_slot_buttons[_slot_buttons.size() - 1].focus_neighbor_bottom = _back_button.get_path()
		_back_button.focus_neighbor_top = _slot_buttons[_slot_buttons.size() - 1].get_path()


func _update_title() -> void:
	if _title_label:
		if _mode == "new_game":
			_title_label.text = "Select Save Slot"
		else:
			_title_label.text = "Load Game"


func _refresh_slot_display() -> void:
	var metadata: Array[SlotMetadata] = SaveManager.get_all_slot_metadata()

	for i: int in range(_slot_buttons.size()):
		var button: Button = _slot_buttons[i]
		var meta: SlotMetadata = metadata[i] if i < metadata.size() else null

		if meta and meta.is_occupied:
			button.text = "Slot %d: %s" % [i + 1, meta.get_display_string()]
			# In load mode, only occupied slots are selectable
			# In new mode, all slots are selectable (will overwrite)
			button.disabled = false
		else:
			button.text = "Slot %d: [Empty]" % (i + 1)
			# In load mode, empty slots are not selectable
			button.disabled = (_mode == "load_game")


func _on_slot_pressed(slot_number: int) -> void:
	_selected_slot = slot_number

	if _mode == "new_game":
		_show_name_entry()
	else:
		_load_game()


func _show_name_entry() -> void:
	# Hide the selector UI
	for child: Node in get_children():
		if child is Control:
			child.visible = false

	# Instantiate and add name entry
	_name_entry = HeroNameEntryScene.instantiate()
	add_child(_name_entry)

	# Get default hero data
	var party: Array[CharacterData] = ModLoader.get_default_party()
	if not party.is_empty():
		_name_entry.set_hero_data(party[0])

	# Connect to confirmation signal
	_name_entry.name_confirmed.connect(_on_name_confirmed)


func _on_name_confirmed(hero_name: String) -> void:
	_start_new_game(hero_name)


func _start_new_game(hero_name: String) -> void:
	# Get default party
	var party: Array[CharacterData] = ModLoader.get_default_party()
	if party.is_empty():
		push_error("SaveSlotSelector: No default party found!")
		return

	# Apply hero name to first character (the hero)
	# We need to duplicate to avoid modifying the original resource
	var original_path: String = party[0].resource_path
	var hero: CharacterData = party[0].duplicate()
	# Use take_over_path() instead of direct assignment - Godot 4 protects resource_path
	hero.take_over_path(original_path)
	hero.character_name = hero_name
	party[0] = hero

	# Initialize party
	PartyManager.set_party(party)

	# Get new game config
	var config: NewGameConfigData = ModLoader.get_new_game_config() as NewGameConfigData
	if config:
		# Set starting gold
		SaveManager.current_save = SaveData.new()
		SaveManager.current_save.slot_number = _selected_slot
		SaveManager.current_save.gold = config.starting_gold
		SaveManager.current_save.current_location = config.starting_location_label

		# Set starting story flags
		var starting_flags: Dictionary = config.starting_story_flags
		for flag_name: String in starting_flags:
			var flag_value: bool = starting_flags[flag_name]
			GameState.set_flag(flag_name, flag_value)

		# Get starting scene path
		var scene_path: String = config.starting_scene_path

		if scene_path.is_empty():
			push_warning("SaveSlotSelector: No starting_scene_path in config")
			_show_no_scene_error()
			return

		# Store in save data
		SaveManager.current_save.current_scene_path = scene_path
		SaveManager.current_save.current_spawn_point = config.starting_spawn_point

		# Play intro cinematic if specified, then load scene
		if not config.intro_cinematic_id.is_empty():
			CinematicsManager.cinematic_ended.connect(_on_intro_cinematic_ended.bind(scene_path), CONNECT_ONE_SHOT)
			CinematicsManager.play_cinematic(config.intro_cinematic_id)
		else:
			# Load starting scene directly
			SceneManager.change_scene(scene_path)
	else:
		push_warning("SaveSlotSelector: No new game config found")
		_show_no_scene_error()


func _on_intro_cinematic_ended(_cinematic_id: String, scene_path: String) -> void:
	SceneManager.change_scene(scene_path)


func _show_no_scene_error() -> void:
	# Hide current UI
	for child: Node in get_children():
		if child is Control:
			child.visible = false

	# Create and register dialog box for the cinematic
	_dialog_box = DialogBoxScene.instantiate()
	add_child(_dialog_box)
	DialogManager.dialog_box = _dialog_box
	_dialog_box.hide()

	# Load and play the error cinematic, then return to main menu
	var error_cinematic: CinematicData = CinematicLoader.load_from_json(NO_CAMPAIGN_ERROR_CINEMATIC) as CinematicData
	if error_cinematic:
		# Connect to cinematic_ended to return to main menu after
		if not CinematicsManager.cinematic_ended.is_connected(_on_error_cinematic_ended):
			CinematicsManager.cinematic_ended.connect(_on_error_cinematic_ended, CONNECT_ONE_SHOT)
		CinematicsManager.play_cinematic_from_resource(error_cinematic)
	else:
		push_error("SaveSlotSelector: Failed to load error cinematic")
		SceneManager.goto_main_menu()


func _on_error_cinematic_ended(_cinematic_id: String) -> void:
	# Clean up dialog box reference
	if DialogManager.dialog_box == _dialog_box:
		DialogManager.dialog_box = null
	SceneManager.goto_main_menu()


func _load_game() -> void:
	var save_data: SaveData = SaveManager.load_from_slot(_selected_slot)
	if not save_data:
		push_error("SaveSlotSelector: Failed to load save from slot %d" % _selected_slot)
		return

	# Set as current save
	SaveManager.current_save = save_data

	# Restore story flags
	var saved_flags: Dictionary = save_data.story_flags
	for flag_name: String in saved_flags:
		var flag_value: bool = saved_flags[flag_name]
		GameState.set_flag(flag_name, flag_value)

	# Restore last safe location
	if not save_data.last_safe_location.is_empty():
		GameState.set_last_safe_location(save_data.last_safe_location)

	# Restore party from save
	PartyManager.import_from_save(save_data.party_members)

	# Load saved scene
	if not save_data.current_scene_path.is_empty():
		SceneManager.change_scene(save_data.current_scene_path)
	else:
		push_warning("SaveSlotSelector: No scene path in save, returning to main menu")
		SceneManager.goto_main_menu()


func _on_back_pressed() -> void:
	SceneManager.goto_main_menu()


## Handle cancel input
func _input(event: InputEvent) -> void:
	if not visible:
		return

	# If name entry is active, let it handle input
	if _name_entry and _name_entry.visible:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


## Capture unhandled input to prevent leaking to game controls
func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
