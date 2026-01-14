@tool
extends Control

## Save Slot Party Editor UI
## Runtime editor for player save data - edit party composition in save slots
## This is NOT a resource editor - it directly manipulates save files

# Save slot management
var save_slot_selector: OptionButton
var load_slot_button: Button
var save_changes_button: Button
var slot_info_label: RichTextLabel
var current_save_slot: int = 1
var current_save_data: SaveData = null

# Current party display
var player_members_list: ItemList
var move_up_button: Button
var move_down_button: Button
var remove_from_party_button: Button

# Available characters
var available_characters_list: ItemList
var add_to_party_button: Button

# Preview and info
var character_preview_label: RichTextLabel
var party_info_label: RichTextLabel

# Feedback panel for success/error messages
var feedback_panel: PanelContainer
var feedback_label: RichTextLabel

# No local character cache - query registry directly

# File access constants
const SAVE_DIRECTORY: String = "user://saves/"
const SLOT_FILE_PATTERN: String = "slot_%d.sav"
const METADATA_FILE: String = "slots.meta"


func _ready() -> void:
	_setup_ui()
	_connect_event_bus()


func _exit_tree() -> void:
	_disconnect_event_bus()


## Standard refresh method for EditorTabRegistry
## Save slot editor operates on save files, not mod resources,
## so it only needs to refresh UI when mods change
func refresh() -> void:
	_refresh_available_characters()
	_refresh_player_party()


func _connect_event_bus() -> void:
	# Listen for character changes from other editor tabs via EditorEventBus
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		if not event_bus.resource_saved.is_connected(_on_resource_event):
			event_bus.resource_saved.connect(_on_resource_event)
		if not event_bus.resource_created.is_connected(_on_resource_event):
			event_bus.resource_created.connect(_on_resource_event)
		if not event_bus.resource_deleted.is_connected(_on_resource_deleted_event):
			event_bus.resource_deleted.connect(_on_resource_deleted_event)


func _disconnect_event_bus() -> void:
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		if event_bus.resource_saved.is_connected(_on_resource_event):
			event_bus.resource_saved.disconnect(_on_resource_event)
		if event_bus.resource_created.is_connected(_on_resource_event):
			event_bus.resource_created.disconnect(_on_resource_event)
		if event_bus.resource_deleted.is_connected(_on_resource_deleted_event):
			event_bus.resource_deleted.disconnect(_on_resource_deleted_event)


## Handle resource saved/created events from EditorEventBus
func _on_resource_event(res_type: String, _res_id: String, _resource: Resource) -> void:
	if res_type == "character":
		_refresh_player_party()
		_refresh_available_characters()


## Handle resource deleted events from EditorEventBus
func _on_resource_deleted_event(res_type: String, _res_id: String) -> void:
	if res_type == "character":
		_refresh_player_party()
		_refresh_available_characters()


# ============================================================================
# UI SETUP
# ============================================================================

func _setup_ui() -> void:
	# Root Control uses layout_mode = 1 with anchors in .tscn for proper TabContainer containment
	# Wrap everything in a ScrollContainer for proper scrolling
	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(main_vbox)

	# Title
	var title_label: Label = Label.new()
	title_label.text = "Save Slot Party Editor"
	title_label.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(title_label)

	var help_label: Label = Label.new()
	help_label.text = "Edit party composition for save slots. Select a slot, modify the party, then save changes."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(help_label)

	SparklingEditorUtils.add_separator(main_vbox)

	# Save slot selector section
	_create_save_slot_selector(main_vbox)

	SparklingEditorUtils.add_separator(main_vbox)

	# Main split container
	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.custom_minimum_size = Vector2(0, 400)
	main_vbox.add_child(hsplit)

	# Left panel: Current party
	_create_current_party_panel(hsplit)

	# Right panel: Available characters
	_create_available_characters_panel(hsplit)

	# Bottom: Party info
	_create_party_info_panel(main_vbox)

	# Feedback panel for success/error messages
	_create_feedback_panel(main_vbox)

	# Initial refresh
	_refresh_player_party()
	_refresh_available_characters()


## Create save slot selector UI
func _create_save_slot_selector(parent: VBoxContainer) -> void:
	var selector_container: VBoxContainer = VBoxContainer.new()
	parent.add_child(selector_container)

	# Slot selection row
	var slot_row: HBoxContainer = HBoxContainer.new()
	selector_container.add_child(slot_row)

	var slot_label: Label = Label.new()
	slot_label.text = "Select Save Slot:"
	slot_label.custom_minimum_size.x = 120
	slot_row.add_child(slot_label)

	save_slot_selector = OptionButton.new()
	save_slot_selector.add_item("Slot 1", 0)
	save_slot_selector.add_item("Slot 2", 1)
	save_slot_selector.add_item("Slot 3", 2)
	save_slot_selector.selected = 0
	save_slot_selector.custom_minimum_size.x = 150
	save_slot_selector.item_selected.connect(_on_slot_selected)
	slot_row.add_child(save_slot_selector)

	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size.x = 20
	slot_row.add_child(spacer)

	# Load button
	load_slot_button = Button.new()
	load_slot_button.text = "Load Slot"
	load_slot_button.custom_minimum_size.x = 100
	load_slot_button.pressed.connect(_on_load_slot)
	slot_row.add_child(load_slot_button)

	# Save button
	save_changes_button = Button.new()
	save_changes_button.text = "Save Changes"
	save_changes_button.custom_minimum_size.x = 120
	save_changes_button.disabled = true  # Disabled until slot loaded
	save_changes_button.pressed.connect(_on_save_changes)
	slot_row.add_child(save_changes_button)

	# Slot info display
	slot_info_label = RichTextLabel.new()
	slot_info_label.custom_minimum_size = Vector2(0, 60)
	slot_info_label.bbcode_enabled = true
	slot_info_label.fit_content = true
	slot_info_label.text = "[i]No save slot loaded. Select a slot and click 'Load Slot' to begin.[/i]"
	selector_container.add_child(slot_info_label)


## Create current party panel (left side)
func _create_current_party_panel(parent: Control) -> void:
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(left_panel)

	var current_label: Label = Label.new()
	current_label.text = "Current Party Members"
	current_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	left_panel.add_child(current_label)

	# Party members list
	player_members_list = ItemList.new()
	player_members_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_members_list.custom_minimum_size = Vector2(0, 300)
	player_members_list.item_selected.connect(_on_player_member_selected)
	left_panel.add_child(player_members_list)

	# Reorder buttons
	var reorder_container: HBoxContainer = HBoxContainer.new()
	left_panel.add_child(reorder_container)

	move_up_button = Button.new()
	move_up_button.text = "Move Up"
	move_up_button.pressed.connect(_on_move_up)
	reorder_container.add_child(move_up_button)

	move_down_button = Button.new()
	move_down_button.text = "Move Down"
	move_down_button.pressed.connect(_on_move_down)
	reorder_container.add_child(move_down_button)

	# Remove button
	remove_from_party_button = Button.new()
	remove_from_party_button.text = "Remove from Party"
	remove_from_party_button.pressed.connect(_on_remove_from_party)
	left_panel.add_child(remove_from_party_button)


## Create available characters panel (right side)
func _create_available_characters_panel(parent: Control) -> void:
	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(right_panel)

	var available_label: Label = Label.new()
	available_label.text = "Available Characters"
	available_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	right_panel.add_child(available_label)

	# Available characters list
	available_characters_list = ItemList.new()
	available_characters_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	available_characters_list.custom_minimum_size = Vector2(0, 200)
	available_characters_list.item_selected.connect(_on_available_character_selected)
	right_panel.add_child(available_characters_list)

	# Add button
	add_to_party_button = Button.new()
	add_to_party_button.text = "Add to Party"
	add_to_party_button.pressed.connect(_on_add_to_party)
	right_panel.add_child(add_to_party_button)

	# Character preview
	var preview_label: Label = Label.new()
	preview_label.text = "Character Preview:"
	preview_label.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(preview_label)

	character_preview_label = RichTextLabel.new()
	character_preview_label.custom_minimum_size = Vector2(0, 150)
	character_preview_label.bbcode_enabled = true
	character_preview_label.fit_content = true
	right_panel.add_child(character_preview_label)


## Create party info panel (bottom)
func _create_party_info_panel(parent: VBoxContainer) -> void:
	var info_label: Label = Label.new()
	info_label.text = "Party Statistics:"
	info_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(info_label)

	party_info_label = RichTextLabel.new()
	party_info_label.custom_minimum_size = Vector2(0, 100)
	party_info_label.bbcode_enabled = true
	party_info_label.fit_content = true
	parent.add_child(party_info_label)


## Create feedback panel for success/error messages
func _create_feedback_panel(parent: VBoxContainer) -> void:
	feedback_panel = PanelContainer.new()
	feedback_panel.visible = false
	parent.add_child(feedback_panel)

	feedback_label = RichTextLabel.new()
	feedback_label.bbcode_enabled = true
	feedback_label.fit_content = true
	feedback_label.custom_minimum_size = Vector2(0, 40)
	feedback_panel.add_child(feedback_label)


# ============================================================================
# CHARACTER LOADING
# ============================================================================



# ============================================================================
# PARTY DISPLAY
# ============================================================================

## Refresh the player party list from current SaveData
func _refresh_player_party() -> void:
	if not player_members_list:
		return

	if not current_save_data:
		player_members_list.clear()
		if party_info_label:
			party_info_label.text = "No save slot loaded"
		return

	player_members_list.clear()

	for i: int in range(current_save_data.party_members.size()):
		var char_save: CharacterSaveData = current_save_data.party_members[i]
		var display_text: String = char_save.fallback_character_name

		# Mark hero
		if char_save.is_hero:
			display_text = "[*] " + display_text + " (Hero)"

		# Show level and class
		display_text += " - Lv.%d %s" % [char_save.level, char_save.fallback_class_name]

		# Check if character still exists in mods
		var char_data: CharacterData = ModLoader.registry.get_resource(
			"character",
			char_save.character_resource_id
		)
		if not char_data:
			display_text += " [Missing!]"

		player_members_list.add_item(display_text)

	_update_party_info()


## Refresh available characters list - queries registry directly
func _refresh_available_characters() -> void:
	if not available_characters_list:
		return

	available_characters_list.clear()

	# Query registry fresh each time
	if not ModLoader or not ModLoader.registry:
		push_warning("SaveSlotEditor: ModLoader or registry not available")
		return

	var all_characters: Array[Resource] = ModLoader.registry.get_all_resources("character")
	var idx: int = 0
	for char_data: CharacterData in all_characters:
		if not char_data:
			continue

		# Get mod source for this character (ResourcePicker pattern)
		var resource_id: String = char_data.resource_path.get_file().get_basename()
		var mod_id: String = ModLoader.registry.get_resource_source(resource_id)

		# Format: [mod_id] Name [*] - Class (matching ResourcePicker style)
		var display_text: String = ""
		if not mod_id.is_empty():
			display_text = "[%s] " % mod_id

		display_text += char_data.character_name

		if char_data.is_hero:
			display_text += " [*]"

		if char_data.character_class:
			display_text += " - " + char_data.character_class.display_name

		available_characters_list.add_item(display_text)
		available_characters_list.set_item_metadata(idx, char_data)
		idx += 1


## Update character preview panel (for available characters - shows template data)
func _update_character_preview(character: CharacterData) -> void:
	if not character_preview_label:
		return

	var preview_text: String = "[b]%s[/b] [i](Template)[/i]\n" % character.character_name

	if character.is_hero:
		preview_text += "[color=gold]HERO CHARACTER[/color]\n"

	preview_text += "Starting Level: %d\n" % character.starting_level

	if character.character_class:
		preview_text += "Class: %s\n" % character.character_class.display_name
		preview_text += "Movement: %d tiles\n" % character.character_class.movement_range

	# Stats (base template stats)
	preview_text += "\n[b]Base Stats:[/b]\n"
	preview_text += "HP: %d / MP: %d\n" % [character.base_hp, character.base_mp]
	preview_text += "STR: %d / DEF: %d\n" % [character.base_strength, character.base_defense]
	preview_text += "AGI: %d / INT: %d\n" % [character.base_agility, character.base_intelligence]
	preview_text += "LUK: %d\n" % character.base_luck

	character_preview_label.text = preview_text


## Update character preview panel (for party members - shows saved data)
func _update_party_member_preview(char_save: CharacterSaveData) -> void:
	if not character_preview_label:
		return

	var preview_text: String = "[b]%s[/b] [i](Saved)[/i]\n" % char_save.fallback_character_name

	if char_save.is_hero:
		preview_text += "[color=gold]HERO CHARACTER[/color]\n"

	preview_text += "Level: %d\n" % char_save.level
	preview_text += "Experience: %d\n" % char_save.experience
	preview_text += "Class: %s\n" % char_save.fallback_class_name

	# Current stats from save
	preview_text += "\n[b]Current Stats:[/b]\n"
	preview_text += "HP: %d/%d | MP: %d/%d\n" % [char_save.current_hp, char_save.max_hp, char_save.current_mp, char_save.max_mp]
	preview_text += "STR: %d / DEF: %d\n" % [char_save.strength, char_save.defense]
	preview_text += "AGI: %d / INT: %d\n" % [char_save.agility, char_save.intelligence]
	preview_text += "LUK: %d\n" % char_save.luck

	# Equipment if any
	if not char_save.equipped_weapon_id.is_empty() or not char_save.equipped_armor_id.is_empty() or not char_save.equipped_accessory_id.is_empty():
		preview_text += "\n[b]Equipment:[/b]\n"
		if not char_save.equipped_weapon_id.is_empty():
			preview_text += "Weapon: %s\n" % char_save.equipped_weapon_id
		if not char_save.equipped_armor_id.is_empty():
			preview_text += "Armor: %s\n" % char_save.equipped_armor_id
		if not char_save.equipped_accessory_id.is_empty():
			preview_text += "Accessory: %s\n" % char_save.equipped_accessory_id

	# Check if source character still exists
	var source_exists: bool = ModLoader.registry.get_resource("character", char_save.character_resource_id) != null
	if not source_exists:
		preview_text += "\n[color=red][b]Warning:[/b] Source character not found in mods![/color]"

	character_preview_label.text = preview_text


## Update party statistics display
func _update_party_info() -> void:
	if not party_info_label or not current_save_data:
		return

	var info_text: String = "[b]Party Statistics:[/b]\n"
	info_text += "Members: %d / %d\n" % [
		current_save_data.party_members.size(),
		current_save_data.max_party_size
	]

	# Calculate average level
	if not current_save_data.party_members.is_empty():
		var total_level: int = 0
		for char_save: CharacterSaveData in current_save_data.party_members:
			total_level += char_save.level
		var avg_level: float = float(total_level) / current_save_data.party_members.size()
		info_text += "Average Level: %.1f\n" % avg_level

	# Show active mods
	if not current_save_data.active_mods.is_empty():
		info_text += "\n[b]Active Mods:[/b]\n"
		for mod_info: Dictionary in current_save_data.active_mods:
			if "mod_id" in mod_info:
				var mod_id: String = DictUtils.get_string(mod_info, "mod_id", "")
				info_text += "- %s" % mod_id
				if "version" in mod_info:
					var version: String = DictUtils.get_string(mod_info, "version", "")
					info_text += " (v%s)" % version
				info_text += "\n"

	party_info_label.text = info_text


## Show error message with visual feedback
func _show_error(message: String) -> void:
	push_warning("SaveSlotEditor: " + message)
	if feedback_panel and feedback_label:
		var error_color: Color = SparklingEditorUtils.get_error_color()
		feedback_label.text = "[color=#%s][b]Error:[/b] %s[/color]" % [error_color.to_html(false), message]
		var error_style: StyleBoxFlat = SparklingEditorUtils.create_error_panel_style()
		feedback_panel.add_theme_stylebox_override("panel", error_style)
		feedback_panel.visible = true

		# Auto-dismiss after 5 seconds
		var tween: Tween = create_tween()
		tween.tween_interval(5.0)
		tween.tween_callback(_hide_feedback_panel)


## Show success message with visual feedback
func _show_success(message: String) -> void:
	if feedback_panel and feedback_label:
		var success_color: Color = SparklingEditorUtils.get_success_color()
		feedback_label.text = "[color=#%s][b]Success:[/b] %s[/color]" % [success_color.to_html(false), message]
		var success_style: StyleBoxFlat = SparklingEditorUtils.create_success_panel_style()
		feedback_panel.add_theme_stylebox_override("panel", success_style)
		feedback_panel.visible = true

		# Auto-dismiss after 3 seconds
		var tween: Tween = create_tween()
		tween.tween_interval(3.0)
		tween.tween_callback(_hide_feedback_panel)


## Hide feedback panel
func _hide_feedback_panel() -> void:
	if feedback_panel:
		feedback_panel.visible = false


# ============================================================================
# PARTY MANIPULATION
# ============================================================================

## Add selected character to party
func _on_add_to_party() -> void:
	if not current_save_data:
		_show_error("No save slot loaded")
		return

	var selected_indices: PackedInt32Array = available_characters_list.get_selected_items()
	if selected_indices.is_empty():
		_show_error("Please select a character to add")
		return

	var char_index: int = selected_indices[0]
	var character: CharacterData = available_characters_list.get_item_metadata(char_index) as CharacterData
	if not character:
		_show_error("Invalid character selection")
		return

	# Check party size limit
	if current_save_data.party_members.size() >= current_save_data.max_party_size:
		_show_error("Party is full! Maximum size is %d" % current_save_data.max_party_size)
		return

	# Check for duplicate hero
	if character.is_hero:
		for char_save: CharacterSaveData in current_save_data.party_members:
			if char_save.is_hero:
				_show_error("Party already has a hero!")
				return

	# Create CharacterSaveData from CharacterData template
	var char_save: CharacterSaveData = CharacterSaveData.new()
	char_save.populate_from_character_data(character)

	# Add to save data party
	current_save_data.party_members.append(char_save)

	_refresh_player_party()


## Remove selected character from party
func _on_remove_from_party() -> void:
	if not current_save_data:
		_show_error("No save slot loaded")
		return

	var selected_indices: PackedInt32Array = player_members_list.get_selected_items()
	if selected_indices.is_empty():
		_show_error("Please select a party member to remove")
		return

	var index: int = selected_indices[0]
	if index < 0 or index >= current_save_data.party_members.size():
		return

	var char_save: CharacterSaveData = current_save_data.party_members[index]

	# Prevent removing hero
	if char_save.is_hero:
		_show_error("Cannot remove the hero from the party!")
		return

	current_save_data.party_members.remove_at(index)
	_refresh_player_party()


## Move selected party member up
func _on_move_up() -> void:
	if not current_save_data:
		return

	var selected_indices: PackedInt32Array = player_members_list.get_selected_items()
	if selected_indices.is_empty():
		return

	var index: int = selected_indices[0]

	# Can't move up if at top or if trying to move above hero (position 0)
	if index <= 1:
		_show_error("Cannot move above the hero!")
		return

	# Swap positions
	var temp: CharacterSaveData = current_save_data.party_members[index]
	current_save_data.party_members[index] = current_save_data.party_members[index - 1]
	current_save_data.party_members[index - 1] = temp

	_refresh_player_party()
	player_members_list.select(index - 1)


## Move selected party member down
func _on_move_down() -> void:
	if not current_save_data:
		return

	var selected_indices: PackedInt32Array = player_members_list.get_selected_items()
	if selected_indices.is_empty():
		return

	var index: int = selected_indices[0]

	# Can't move down if at bottom
	if index >= current_save_data.party_members.size() - 1:
		return

	# Hero (position 0) can't move down
	if index == 0:
		_show_error("Cannot move the hero!")
		return

	# Swap positions
	var temp: CharacterSaveData = current_save_data.party_members[index]
	current_save_data.party_members[index] = current_save_data.party_members[index + 1]
	current_save_data.party_members[index + 1] = temp

	_refresh_player_party()
	player_members_list.select(index + 1)


## Update character preview when selection changes
func _on_available_character_selected(index: int) -> void:
	var character: CharacterData = available_characters_list.get_item_metadata(index) as CharacterData
	if not character:
		return

	_update_character_preview(character)


## Update party member preview when selection changes
func _on_player_member_selected(index: int) -> void:
	if not current_save_data or index < 0 or index >= current_save_data.party_members.size():
		return

	var char_save: CharacterSaveData = current_save_data.party_members[index]
	_update_party_member_preview(char_save)


# ============================================================================
# SAVE SLOT MANAGEMENT
# ============================================================================

## Slot selection changed
func _on_slot_selected(index: int) -> void:
	current_save_slot = index + 1


## Load selected save slot
func _on_load_slot() -> void:
	if _editor_is_slot_occupied(current_save_slot):
		# Load existing save
		current_save_data = _editor_load_from_slot(current_save_slot)
		if current_save_data:
			_update_slot_info_display()
			_refresh_player_party()
			_refresh_available_characters()
			save_changes_button.disabled = false
		else:
			_show_error("Failed to load slot %d" % current_save_slot)
			current_save_data = null
			save_changes_button.disabled = true
	else:
		# Create new save data for empty slot
		current_save_data = SaveData.new()
		current_save_data.slot_number = current_save_slot
		current_save_data.current_location = "Headquarters"
		current_save_data.created_timestamp = Time.get_unix_time_from_system()
		current_save_data.last_played_timestamp = current_save_data.created_timestamp
		current_save_data.game_version = "0.1.0"
		current_save_data.max_party_size = 8

		# Populate active mods
		if ModLoader:
			for manifest: ModManifest in ModLoader.loaded_mods:
				current_save_data.active_mods.append({
					"mod_id": manifest.mod_id,
					"version": manifest.version
				})

		_update_slot_info_display()
		_refresh_player_party()
		_refresh_available_characters()
		save_changes_button.disabled = false


## Save changes to current slot
func _on_save_changes() -> void:
	if not current_save_data:
		_show_error("No save slot loaded")
		return

	# Validate hero requirement (if party not empty)
	if not current_save_data.party_members.is_empty():
		var has_hero: bool = false
		for char_save: CharacterSaveData in current_save_data.party_members:
			if char_save.is_hero:
				has_hero = true
				break

		if not has_hero:
			_show_error("Party must have a hero character!")
			return

	# Ensure hero is at position 0
	_ensure_hero_is_leader()

	# Validate save data
	if not current_save_data.validate():
		_show_error("Save data validation failed! Check console for details.")
		return

	# Update timestamps
	current_save_data.last_played_timestamp = Time.get_unix_time_from_system()
	if current_save_data.created_timestamp == 0:
		current_save_data.created_timestamp = current_save_data.last_played_timestamp

	# Update active mods list
	_update_active_mods_list()

	# Save to slot
	if _editor_save_to_slot(current_save_slot, current_save_data):
		_update_slot_info_display()
		_show_success("Saved to slot %d successfully!" % current_save_slot)
	else:
		_show_error("Failed to save to slot %d!" % current_save_slot)


## Update slot info display with metadata
func _update_slot_info_display() -> void:
	if not slot_info_label or not current_save_data:
		return

	var info_text: String = "[b]Slot %d:[/b] " % current_save_slot

	var metadata: SlotMetadata = _editor_get_slot_metadata(current_save_slot)

	if metadata and metadata.is_occupied:
		# Show existing save info
		info_text += "%s - Lv.%d - %s\n" % [
			metadata.party_leader_name if metadata.party_leader_name else "Unknown",
			metadata.average_level,
			metadata.current_location
		]
		info_text += "Playtime: %s | Last Played: %s" % [
			metadata.get_playtime_string(),
			metadata.get_last_played_string()
		]

		if metadata.has_mod_mismatch:
			info_text += "\n[color=yellow]Mod mismatch detected[/color]"
	else:
		# Empty slot or new save
		info_text += "[color=green]Empty Slot[/color] - New save (not yet saved to disk)\n"
		info_text += "Location: %s | Party Size: %d/%d" % [
			current_save_data.current_location,
			current_save_data.party_members.size(),
			current_save_data.max_party_size
		]

	slot_info_label.text = info_text


## Ensure hero is at position 0 (similar to PartyManager logic)
func _ensure_hero_is_leader() -> void:
	if not current_save_data or current_save_data.party_members.is_empty():
		return

	var hero_index: int = -1
	for i: int in range(current_save_data.party_members.size()):
		if current_save_data.party_members[i].is_hero:
			hero_index = i
			break

	# Move hero to position 0 if not already there
	if hero_index > 0:
		var hero: CharacterSaveData = current_save_data.party_members[hero_index]
		current_save_data.party_members.remove_at(hero_index)
		current_save_data.party_members.insert(0, hero)


## Update active mods list in save data
func _update_active_mods_list() -> void:
	if not current_save_data:
		return

	current_save_data.active_mods.clear()

	if ModLoader:
		for manifest: ModManifest in ModLoader.loaded_mods:
			current_save_data.active_mods.append({
				"mod_id": manifest.mod_id,
				"version": manifest.version
			})


# ============================================================================
# DIRECT FILE ACCESS (SaveManager doesn't work in editor tool mode)
# ============================================================================

## Check if slot is occupied (direct file access for editor)
func _editor_is_slot_occupied(slot_number: int) -> bool:
	var file_path: String = SAVE_DIRECTORY.path_join(SLOT_FILE_PATTERN % slot_number)
	return FileAccess.file_exists(file_path)


## Load save data from slot (direct file access for editor)
func _editor_load_from_slot(slot_number: int) -> SaveData:
	var file_path: String = SAVE_DIRECTORY.path_join(SLOT_FILE_PATTERN % slot_number)

	if not FileAccess.file_exists(file_path):
		push_warning("SaveSlotEditor: Slot %d file does not exist" % slot_number)
		return null

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("SaveSlotEditor: Failed to open slot %d for reading" % slot_number)
		return null

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("SaveSlotEditor: Failed to parse JSON from slot %d: %s" % [slot_number, json.get_error_message()])
		return null

	var save_dict: Dictionary = json.data
	var save_data: SaveData = SaveData.new()
	save_data.deserialize_from_dict(save_dict)

	if not save_data.validate():
		push_error("SaveSlotEditor: Loaded SaveData from slot %d failed validation" % slot_number)
		return null

	return save_data


## Save data to slot (direct file access for editor)
func _editor_save_to_slot(slot_number: int, save_data: SaveData) -> bool:
	if not save_data:
		push_error("SaveSlotEditor: Cannot save null SaveData")
		return false

	if not save_data.validate():
		push_error("SaveSlotEditor: SaveData validation failed")
		return false

	# Ensure save directory exists
	var dir: DirAccess = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")

	# Serialize to JSON
	save_data.slot_number = slot_number
	var save_dict: Dictionary = save_data.serialize_to_dict()
	var json_string: String = JSON.stringify(save_dict, "\t")

	# Write to file
	var file_path: String = SAVE_DIRECTORY.path_join(SLOT_FILE_PATTERN % slot_number)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("SaveSlotEditor: Failed to open slot %d for writing" % slot_number)
		return false

	file.store_string(json_string)
	file.close()

	# Update metadata
	_editor_update_metadata_for_slot(slot_number, save_data)

	return true


## Get slot metadata (direct file access for editor)
func _editor_get_slot_metadata(slot_number: int) -> SlotMetadata:
	var metadata_path: String = SAVE_DIRECTORY.path_join(METADATA_FILE)

	var meta: SlotMetadata = SlotMetadata.new()
	meta.slot_number = slot_number
	meta.is_occupied = _editor_is_slot_occupied(slot_number)

	if not FileAccess.file_exists(metadata_path):
		return meta

	var file: FileAccess = FileAccess.open(metadata_path, FileAccess.READ)
	if not file:
		return meta

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(json_string) != OK:
		return meta

	var meta_array: Array = json.data
	for meta_dict: Dictionary in meta_array:
		var meta_slot: int = meta_dict.get("slot_number", 0)
		if meta_slot == slot_number:
			meta.deserialize_from_dict(meta_dict)
			break

	return meta


## Update metadata for slot (direct file access for editor)
func _editor_update_metadata_for_slot(slot_number: int, save_data: SaveData) -> void:
	var metadata_path: String = SAVE_DIRECTORY.path_join(METADATA_FILE)

	# Load existing metadata
	var all_metadata: Array[Dictionary] = []
	if FileAccess.file_exists(metadata_path):
		var file: FileAccess = FileAccess.open(metadata_path, FileAccess.READ)
		if file:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var metadata_array: Array = json.data
				for i: int in range(metadata_array.size()):
					var meta_dict: Dictionary = metadata_array[i]
					all_metadata.append(meta_dict)
			file.close()

	# Find or create metadata for this slot
	var slot_meta_dict: Dictionary = {}
	var found: bool = false
	for i: int in range(all_metadata.size()):
		var existing_meta: Dictionary = all_metadata[i]
		var existing_slot: int = existing_meta.get("slot_number", 0)
		if existing_slot == slot_number:
			slot_meta_dict = existing_meta
			found = true
			break

	if not found:
		slot_meta_dict = {"slot_number": slot_number}
		all_metadata.append(slot_meta_dict)

	# Update metadata from save data
	var slot_meta: SlotMetadata = SlotMetadata.new()
	slot_meta.populate_from_save_data(save_data)
	slot_meta_dict = slot_meta.serialize_to_dict()

	# Find and replace in array
	for i: int in range(all_metadata.size()):
		var check_meta: Dictionary = all_metadata[i]
		var check_slot: int = check_meta.get("slot_number", 0)
		if check_slot == slot_number:
			all_metadata[i] = slot_meta_dict
			break

	# Save metadata file
	var json_string: String = JSON.stringify(all_metadata, "\t")
	var file: FileAccess = FileAccess.open(metadata_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
