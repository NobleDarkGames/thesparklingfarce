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
	print("[FLOW] Save slot %d selected (mode: %s)" % [slot_num, SceneManager.save_slot_mode])

	var metadata: SlotMetadata = SaveManager.get_slot_metadata(slot_num)
	var is_occupied: bool = metadata != null and metadata.is_occupied

	if SceneManager.save_slot_mode == "new_game":
		_new_game(slot_num)
	else:
		# Load game mode: only load if occupied
		if is_occupied:
			_load_game(slot_num)
		else:
			push_warning("SaveSlotSelector: Cannot load empty slot %d" % slot_num)


func _new_game(slot_num: int) -> void:
	print("[FLOW] New game in slot %d" % slot_num)

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

	# Initialize party with default party (Hero, Warrioso, Maggie)
	var default_party: PartyData = load("res://mods/_base_game/data/parties/default_party.tres")
	if default_party:
		for member_dict: Dictionary in default_party.members:
			if "character" in member_dict and member_dict.character:
				var character: CharacterData = member_dict.character
				var char_save: CharacterSaveData = CharacterSaveData.new()
				char_save.populate_from_character_data(character)
				save_data.party_members.append(char_save)

		if save_data.party_members.is_empty():
			push_warning("SaveSlotSelector: Default party was empty!")
	else:
		push_warning("SaveSlotSelector: Could not load default party!")

	# Save the new game
	var success: bool = SaveManager.save_to_slot(slot_num, save_data)
	if success:
		# Initialize PartyManager with the party
		PartyManager.import_from_save(save_data.party_members)

		# Start campaign via CampaignManager
		var campaigns: Array[Resource] = CampaignManager.get_available_campaigns()
		if campaigns.size() > 0:
			var campaign: Resource = campaigns[0]
			CampaignManager.start_campaign(campaign.campaign_id)
		else:
			push_warning("SaveSlotSelector: No campaigns found, falling back to legacy battle")
			TriggerManager.start_battle("battle_1763763677")
	else:
		push_error("SaveSlotSelector: Failed to create new save")


func _load_game(slot_num: int) -> void:
	print("[FLOW] Load game from slot %d" % slot_num)

	var save_data: SaveData = SaveManager.load_from_slot(slot_num)
	if save_data:
		# Populate PartyManager with loaded data
		PartyManager.import_from_save(save_data.party_members)

		# Restore GameState from save
		GameState.story_flags = save_data.story_flags.duplicate()

		# Resume campaign if we have campaign data
		if not save_data.current_campaign_id.is_empty() and not save_data.current_node_id.is_empty():
			CampaignManager.resume_campaign(save_data.current_campaign_id, save_data.current_node_id)
		else:
			# Legacy save without campaign data - start first available campaign
			var campaigns: Array[Resource] = CampaignManager.get_available_campaigns()
			if campaigns.size() > 0:
				var campaign: Resource = campaigns[0]
				CampaignManager.start_campaign(campaign.campaign_id)
			else:
				push_warning("SaveSlotSelector: No campaigns found, falling back to legacy battle")
				TriggerManager.start_battle("battle_1763763677")
	else:
		push_error("SaveSlotSelector: Failed to load save from slot %d" % slot_num)


func _on_back_pressed() -> void:
	SceneManager.goto_main_menu()
