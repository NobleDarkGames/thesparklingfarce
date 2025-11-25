extends Control

## Save Slot Selector - Choose which save slot to use
## Displays metadata for each slot and allows selection for new game or load

signal slot_selected(slot_number: int)

@onready var slot_container: VBoxContainer = %SlotContainer
@onready var back_button: Button = %BackButton

const SLOT_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/save_slot_button.tscn")

var slot_buttons: Array[Button] = []


func _ready() -> void:
	# Create slot buttons
	_create_slot_buttons()

	# Connect back button
	back_button.pressed.connect(_on_back_pressed)

	# Focus first slot
	if slot_buttons.size() > 0:
		slot_buttons[0].grab_focus()


func _create_slot_buttons() -> void:
	for slot_num: int in range(1, 4):  # Slots 1, 2, 3
		var button: Button = SLOT_BUTTON_SCENE.instantiate()
		slot_container.add_child(button)
		slot_buttons.append(button)

		# Get slot metadata
		var metadata: SlotMetadata = SaveManager.get_slot_metadata(slot_num)

		# Configure button
		_configure_slot_button(button, slot_num, metadata)

		# Connect signal
		button.pressed.connect(_on_slot_selected.bind(slot_num))


func _configure_slot_button(button: Button, slot_num: int, metadata: SlotMetadata) -> void:
	if metadata and metadata.is_occupied:
		# Slot has a save
		var text: String = "Slot %d: %s\n" % [slot_num, metadata.current_location]
		text += "Level %d - " % metadata.average_level
		text += metadata.get_last_played_string()
		button.text = text
	else:
		# Empty slot
		button.text = "Slot %d: [Empty]" % slot_num


func _on_slot_selected(slot_num: int) -> void:
	print("SaveSlotSelector: Slot %d selected" % slot_num)

	var metadata: SlotMetadata = SaveManager.get_slot_metadata(slot_num)

	if metadata and metadata.is_occupied:
		# Load existing save
		_load_game(slot_num)
	else:
		# Create new save
		_new_game(slot_num)


func _new_game(slot_num: int) -> void:
	print("SaveSlotSelector: Starting new game in slot %d" % slot_num)

	# Create a new save with default party
	var save_data: SaveData = SaveData.new()
	save_data.slot_number = slot_num
	save_data.current_location = "Prologue"
	save_data.created_timestamp = Time.get_unix_time_from_system()
	save_data.last_played_timestamp = save_data.created_timestamp

	# Populate active mods
	for manifest: ModManifest in ModLoader.loaded_mods:
		save_data.active_mods.append({
			"mod_id": manifest.mod_id,
			"version": manifest.version
		})

	# Create default party (for now, just empty - battle scene will populate)
	# In the future, this would set up the initial party composition

	# Save the new game
	var success: bool = SaveManager.save_to_slot(slot_num, save_data)
	if success:
		print("SaveSlotSelector: New save created successfully")
		# Go to first battle
		SceneManager.goto_battle()
	else:
		push_error("SaveSlotSelector: Failed to create new save")


func _load_game(slot_num: int) -> void:
	print("SaveSlotSelector: Loading game from slot %d" % slot_num)

	var save_data: SaveData = SaveManager.load_from_slot(slot_num)
	if save_data:
		print("SaveSlotSelector: Save loaded successfully")

		# Populate PartyManager with loaded data
		PartyManager.import_from_save(save_data.party_members)

		# Go to battle (or HQ in the future)
		SceneManager.goto_battle()
	else:
		push_error("SaveSlotSelector: Failed to load save from slot %d" % slot_num)


func _on_back_pressed() -> void:
	SceneManager.goto_main_menu()
