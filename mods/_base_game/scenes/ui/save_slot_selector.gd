extends Control

## Save Slot Selector - Choose which save slot to use
## Displays metadata for each slot and allows selection for new game or load

signal slot_selected(slot_number: int)

@onready var slot_container: VBoxContainer = %SlotContainer
@onready var back_button: Button = %BackButton
@onready var title_label: Label = $TitleContainer/Title

const SLOT_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/save_slot_button.tscn")

## Animation settings
const TITLE_FADE_DURATION: float = 0.4
const BUTTON_STAGGER_DELAY: float = 0.1
const BUTTON_SLIDE_DURATION: float = 0.35  # Longer slide so motion is visible
const BUTTON_FADE_DURATION: float = 0.12   # Quick fade so button is visible during slide
const BUTTON_SLIDE_OFFSET: float = 200.0   # Start well off-screen
const BUTTON_EFFECT_DURATION: float = 0.1
## Pixel-perfect brightness effects (no scaling)
const BUTTON_HOVER_BRIGHTNESS: Color = Color(1.15, 1.15, 1.0, 1.0)
const BUTTON_FOCUS_BRIGHTNESS: Color = Color(1.25, 1.25, 0.9, 1.0)  # Golden tint for focus

var slot_buttons: Array[Button] = []
var _button_original_positions: Dictionary = {}


func _ready() -> void:
	# Create slot buttons
	_create_slot_buttons()

	# Connect back button
	back_button.pressed.connect(_on_back_pressed)

	# Setup button effects
	_setup_button_effects(back_button)
	for button: Button in slot_buttons:
		_setup_button_effects(button)

	# Wait for layout to finalize before capturing positions
	await get_tree().process_frame

	# Play entrance animation
	await _play_entrance_animation()

	# Focus first slot after animation
	if slot_buttons.size() > 0:
		slot_buttons[0].grab_focus()


## Setup hover and focus effects for a button
func _setup_button_effects(button: Button) -> void:
	button.focus_entered.connect(_on_button_focus_entered.bind(button))
	button.focus_exited.connect(_on_button_focus_exited.bind(button))
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button))


## Animate button brightness on focus (pixel-perfect, no scaling)
func _on_button_focus_entered(button: Button) -> void:
	AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)
	var tween: Tween = create_tween()
	tween.tween_property(button, "modulate", BUTTON_FOCUS_BRIGHTNESS, BUTTON_EFFECT_DURATION)


func _on_button_focus_exited(button: Button) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(button, "modulate", Color.WHITE, BUTTON_EFFECT_DURATION)


func _on_button_mouse_entered(button: Button) -> void:
	AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)
	if not button.has_focus():
		var tween: Tween = create_tween()
		tween.tween_property(button, "modulate", BUTTON_HOVER_BRIGHTNESS, BUTTON_EFFECT_DURATION)


func _on_button_mouse_exited(button: Button) -> void:
	if not button.has_focus():
		var tween: Tween = create_tween()
		tween.tween_property(button, "modulate", Color.WHITE, BUTTON_EFFECT_DURATION)


## Play entrance animation
func _play_entrance_animation() -> void:
	# Setup initial states
	title_label.modulate.a = 0.0
	back_button.modulate.a = 0.0
	_button_original_positions[back_button] = back_button.position
	back_button.position.y += 30

	for button: Button in slot_buttons:
		button.modulate.a = 0.0
		_button_original_positions[button] = button.position
		button.position.x -= BUTTON_SLIDE_OFFSET  # Start well off-screen left

	# Brief pause after scene transition
	await get_tree().create_timer(0.1).timeout

	# Fade in title
	var title_tween: Tween = create_tween()
	title_tween.tween_property(title_label, "modulate:a", 1.0, TITLE_FADE_DURATION)

	await get_tree().create_timer(0.15).timeout

	# Stagger in slot buttons - fade quickly so slide is visible
	for i: int in range(slot_buttons.size()):
		var button: Button = slot_buttons[i]
		var delay: float = i * BUTTON_STAGGER_DELAY

		var button_tween: Tween = create_tween()
		button_tween.set_parallel(true)
		# Quick fade so button becomes visible early in the slide
		button_tween.tween_property(button, "modulate:a", 1.0, BUTTON_FADE_DURATION).set_delay(delay)
		# Longer slide with nice easing - visible motion from off-screen
		button_tween.tween_property(button, "position:x", _button_original_positions[button].x, BUTTON_SLIDE_DURATION).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Fade in back button last
	await get_tree().create_timer(slot_buttons.size() * BUTTON_STAGGER_DELAY + 0.15).timeout
	var back_tween: Tween = create_tween()
	back_tween.set_parallel(true)
	back_tween.tween_property(back_button, "modulate:a", 1.0, 0.2)
	back_tween.tween_property(back_button, "position:y", _button_original_positions[back_button].y, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	AudioManager.play_sfx("menu_select", AudioManager.SFXCategory.UI)

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

	# CRITICAL: Reset modal UI state from any previous session
	# Autoloads persist across scene changes, so stale state can block hero input
	if ShopManager and ShopManager.is_shop_open():
		ShopManager.close_shop()
	if DialogManager and DialogManager.is_dialog_active():
		DialogManager.end_dialog()
	if CinematicsManager and CinematicsManager.is_cinematic_active():
		CinematicsManager.skip_cinematic()

	# Get new game configuration from mods (highest-priority mod's default config)
	var config: NewGameConfigData = ModLoader.get_new_game_config()

	# DEBUG: Trace config resolution
	print("[DEBUG] NewGameConfig resolved: %s" % (config.config_id if config else "NULL"))
	if config:
		print("[DEBUG]   config.starting_party_id = '%s'" % config.starting_party_id)
		print("[DEBUG]   Available party resources: %s" % ModLoader.registry.get_resource_ids("party"))

	# Create a new save with configuration values (or defaults)
	var save_data: SaveData = SaveData.new()
	save_data.slot_number = slot_num
	save_data.created_timestamp = Time.get_unix_time_from_system()
	save_data.last_played_timestamp = save_data.created_timestamp

	# Apply config values or use backward-compatible defaults
	if config:
		save_data.current_location = config.starting_location_label
		save_data.gold = config.starting_gold
		save_data.depot_items = config.starting_depot_items.duplicate()
		save_data.story_flags = config.starting_story_flags.duplicate()
		print("[FLOW] Using NewGameConfig '%s' from mod system" % config.config_id)
	else:
		# Fallback defaults (backward compatibility if no config exists)
		save_data.current_location = "Prologue"
		# gold, depot_items, story_flags use SaveData defaults (0, [], {})
		print("[FLOW] No NewGameConfig found, using defaults")

	# Populate active mods
	for manifest: ModManifest in ModLoader.loaded_mods:
		save_data.active_mods.append({
			"mod_id": manifest.mod_id,
			"version": manifest.version
		})

	# Initialize party - use config's party override if specified, otherwise default resolution
	var party_characters: Array[CharacterData] = []
	if config and not config.starting_party_id.is_empty():
		# Use explicit party from config (completely replaces default party resolution)
		print("[DEBUG] Looking up party: '%s'" % config.starting_party_id)
		var party_data: PartyData = ModLoader.registry.get_resource("party", config.starting_party_id)
		print("[DEBUG] Party lookup result: %s" % (party_data.party_name if party_data else "NULL"))
		if party_data:
			for member_dict: Dictionary in party_data.members:
				if "character" in member_dict and member_dict.character:
					party_characters.append(member_dict.character)
			print("[FLOW] Party loaded from PartyData '%s'" % config.starting_party_id)
		else:
			push_warning("SaveSlotSelector: Party '%s' not found, falling back to default" % config.starting_party_id)
			party_characters = ModLoader.get_default_party()
	else:
		# Standard mod-priority party resolution (is_hero + is_default_party_member)
		party_characters = ModLoader.get_default_party()

	if party_characters.is_empty():
		push_error("SaveSlotSelector: No party characters found!")
	else:
		for character: CharacterData in party_characters:
			var char_save: CharacterSaveData = CharacterSaveData.new()
			char_save.populate_from_character_data(character)
			save_data.party_members.append(char_save)

	# Save the new game
	var success: bool = SaveManager.save_to_slot(slot_num, save_data)
	if success:
		# Set as active save for this session (used by ShopManager, debug console, etc.)
		SaveManager.set_current_save(save_data)

		# Initialize PartyManager with the party
		PartyManager.import_from_save(save_data.party_members)

		# Apply config story flags to GameState
		if config:
			for flag_name: String in config.starting_story_flags.keys():
				GameState.set_flag(flag_name, config.starting_story_flags[flag_name])
			# Apply caravan unlock state
			GameState.set_flag("caravan_unlocked", config.caravan_unlocked)

		# Initialize depot with starting items
		if config and not config.starting_depot_items.is_empty():
			StorageManager.clear_depot()
			for item_id: String in config.starting_depot_items:
				StorageManager.add_to_depot(item_id)

		# Start campaign via CampaignManager
		# Use config's campaign if specified, otherwise first available
		var target_campaign_id: String = ""
		if config and not config.starting_campaign_id.is_empty():
			target_campaign_id = config.starting_campaign_id

		var campaigns: Array[Resource] = CampaignManager.get_available_campaigns()
		var target_campaign: Resource = null

		if not target_campaign_id.is_empty():
			# Find the specified campaign
			for campaign: Resource in campaigns:
				if campaign.campaign_id == target_campaign_id:
					target_campaign = campaign
					break
			if not target_campaign:
				push_warning("SaveSlotSelector: Campaign '%s' not found, using first available" % target_campaign_id)

		if not target_campaign and campaigns.size() > 0:
			target_campaign = campaigns[0]

		if target_campaign:
			await CampaignManager.start_campaign(target_campaign.campaign_id)
		else:
			push_warning("SaveSlotSelector: No campaigns found, falling back to legacy battle")
			TriggerManager.start_battle("battle_1763763677")
	else:
		push_error("SaveSlotSelector: Failed to create new save")


func _load_game(slot_num: int) -> void:
	print("[FLOW] Load game from slot %d" % slot_num)

	# CRITICAL: Reset modal UI state from any previous session
	# Autoloads persist across scene changes, so stale state can block hero input
	if ShopManager and ShopManager.is_shop_open():
		ShopManager.close_shop()
	if DialogManager and DialogManager.is_dialog_active():
		DialogManager.end_dialog()
	if CinematicsManager and CinematicsManager.is_cinematic_active():
		CinematicsManager.skip_cinematic()

	var save_data: SaveData = SaveManager.load_from_slot(slot_num)
	if save_data:
		# Set as active save for this session (used by ShopManager, debug console, etc.)
		SaveManager.set_current_save(save_data)

		# Populate PartyManager with loaded data
		PartyManager.import_from_save(save_data.party_members)

		# Restore GameState from save
		GameState.story_flags = save_data.story_flags.duplicate()

		# Resume campaign if we have campaign data
		# NOTE: Must await to ensure scene transition completes before this function returns
		if not save_data.current_campaign_id.is_empty() and not save_data.current_node_id.is_empty():
			await CampaignManager.resume_campaign(save_data.current_campaign_id, save_data.current_node_id)
		else:
			# Legacy save without campaign data - start first available campaign
			var campaigns: Array[Resource] = CampaignManager.get_available_campaigns()
			if campaigns.size() > 0:
				var campaign: Resource = campaigns[0]
				await CampaignManager.start_campaign(campaign.campaign_id)
			else:
				push_warning("SaveSlotSelector: No campaigns found, falling back to legacy battle")
				TriggerManager.start_battle("battle_1763763677")
	else:
		push_error("SaveSlotSelector: Failed to load save from slot %d" % slot_num)


func _on_back_pressed() -> void:
	AudioManager.play_sfx("menu_select", AudioManager.SFXCategory.UI)
	SceneManager.goto_main_menu()
