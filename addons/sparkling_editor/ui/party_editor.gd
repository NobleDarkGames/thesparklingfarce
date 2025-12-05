@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Party Editor UI
## Dual-mode editor for:
## 1. Template Parties (PartyData resources - enemy formations, etc.)
## 2. Player Party (Runtime PartyManager state - active player party)

# ============================================================================
# TAB MANAGEMENT
# ============================================================================

var tab_container: TabContainer
var template_parties_panel: VBoxContainer
var player_party_panel: VBoxContainer

# ============================================================================
# TEMPLATE PARTIES TAB (Existing PartyData functionality)
# ============================================================================

# Basic info
var party_name_edit: LineEdit
var description_edit: TextEdit
var max_size_spin: SpinBox

# Party Members
var members_container: VBoxContainer
var members_list: Array[Dictionary] = []  # Track member UI elements

# ============================================================================
# PLAYER PARTY TAB (Save slot party editor)
# ============================================================================

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

# ============================================================================
# SHARED DATA
# ============================================================================

# Available characters for selection (used by both tabs)
var available_characters: Array[CharacterData] = []


func _ready() -> void:
	resource_directory = "res://data/parties/"
	resource_type_name = "Party"
	resource_type_id = "party"
	super._ready()
	_load_available_characters()

	# Listen for character changes from other editor tabs via EditorEventBus
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		event_bus.resource_saved.connect(_on_resource_event)
		event_bus.resource_created.connect(_on_resource_event)
		event_bus.resource_deleted.connect(_on_resource_deleted_event)


## Handle resource saved/created events from EditorEventBus
func _on_resource_event(res_type: String, res_id: String, resource: Resource) -> void:
	# Reload character dropdown when any character is saved or created
	if res_type == "character":
		_load_available_characters()
		_refresh_player_party()
		_refresh_available_characters()


## Handle resource deleted events from EditorEventBus
func _on_resource_deleted_event(res_type: String, res_id: String) -> void:
	# Reload character dropdown when any character is deleted
	if res_type == "character":
		_load_available_characters()
		_refresh_player_party()
		_refresh_available_characters()


# ============================================================================
# UI CREATION (OVERRIDE BASE CLASS)
# ============================================================================

## Override: Create the party editor with dual-mode tabs
func _create_detail_form() -> void:
	# Create TabContainer for dual-mode editing
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(tab_container)

	# Tab 1: Template Parties (existing PartyData functionality)
	_create_template_parties_tab()

	# Tab 2: Player Party (new runtime management)
	_create_player_party_tab()

	# Add the button container at the end (only for template parties)
	template_parties_panel.add_child(button_container)


## Create Template Parties tab (PartyData resources)
func _create_template_parties_tab() -> void:
	template_parties_panel = VBoxContainer.new()
	template_parties_panel.name = "Template Parties"
	tab_container.add_child(template_parties_panel)

	# Section 1: Basic Information
	_add_basic_info_section()

	# Section 2: Party Members
	_add_party_members_section()


## Create Player Party tab (Save slot party editor)
func _create_player_party_tab() -> void:
	player_party_panel = VBoxContainer.new()
	player_party_panel.name = "Player Party"
	tab_container.add_child(player_party_panel)

	# Title
	var title_label: Label = Label.new()
	title_label.text = "Save Slot Party Editor"
	title_label.add_theme_font_size_override("font_size", 16)
	player_party_panel.add_child(title_label)

	var help_label: Label = Label.new()
	help_label.text = "Edit party composition for save slots. Select a slot, modify the party, then save changes."
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 16)
	player_party_panel.add_child(help_label)

	_add_separator_to_panel(player_party_panel)

	# Save slot selector section
	_create_save_slot_selector()

	_add_separator_to_panel(player_party_panel)

	# Main split container
	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.custom_minimum_size = Vector2(0, 400)
	player_party_panel.add_child(hsplit)

	# Left panel: Current party
	_create_current_party_panel(hsplit)

	# Right panel: Available characters
	_create_available_characters_panel(hsplit)

	# Bottom: Party info
	_create_party_info_panel()

	# Initial load
	_refresh_player_party()
	_refresh_available_characters()


## Create save slot selector UI
func _create_save_slot_selector() -> void:
	var selector_container: VBoxContainer = VBoxContainer.new()
	player_party_panel.add_child(selector_container)

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
	current_label.add_theme_font_size_override("font_size", 16)
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
	move_up_button.text = "↑ Move Up"
	move_up_button.pressed.connect(_on_move_up)
	reorder_container.add_child(move_up_button)

	move_down_button = Button.new()
	move_down_button.text = "↓ Move Down"
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
	available_label.add_theme_font_size_override("font_size", 16)
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
	preview_label.add_theme_font_size_override("font_size", 16)
	right_panel.add_child(preview_label)

	character_preview_label = RichTextLabel.new()
	character_preview_label.custom_minimum_size = Vector2(0, 150)
	character_preview_label.bbcode_enabled = true
	character_preview_label.fit_content = true
	right_panel.add_child(character_preview_label)


## Create party info panel (bottom)
func _create_party_info_panel() -> void:
	var info_label: Label = Label.new()
	info_label.text = "Party Statistics:"
	info_label.add_theme_font_size_override("font_size", 16)
	player_party_panel.add_child(info_label)

	party_info_label = RichTextLabel.new()
	party_info_label.custom_minimum_size = Vector2(0, 100)
	party_info_label.bbcode_enabled = true
	party_info_label.fit_content = true
	player_party_panel.add_child(party_info_label)


# ============================================================================
# PLAYER PARTY TAB - FUNCTIONALITY
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

	for i in range(current_save_data.party_members.size()):
		var char_save: CharacterSaveData = current_save_data.party_members[i]
		var display_text: String = char_save.fallback_character_name

		# Mark hero
		if char_save.is_hero:
			display_text = "⭐ " + display_text + " (Hero)"

		# Show level and class
		display_text += " - Lv.%d %s" % [char_save.level, char_save.fallback_class_name]

		# Check if character still exists in mods
		var char_data: CharacterData = ModLoader.registry.get_resource(
			"character",
			char_save.character_resource_id
		)
		if not char_data:
			display_text += " [color=yellow]⚠ Missing[/color]"

		player_members_list.add_item(display_text)

	_update_party_info()


## Refresh available characters list
func _refresh_available_characters() -> void:
	if not available_characters_list:
		return

	available_characters_list.clear()

	for character: CharacterData in available_characters:
		var display_text: String = character.character_name

		if character.is_hero:
			display_text += " ⭐"

		if character.character_class:
			display_text += " - " + character.character_class.display_name

		available_characters_list.add_item(display_text)


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
	if char_index < 0 or char_index >= available_characters.size():
		return

	var character: CharacterData = available_characters[char_index]

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
	if index < 0 or index >= available_characters.size():
		return

	var character: CharacterData = available_characters[index]
	_update_character_preview(character)


## Update party member preview when selection changes
func _on_player_member_selected(index: int) -> void:
	# Could show detailed stats here in the future
	pass


## Update character preview panel
func _update_character_preview(character: CharacterData) -> void:
	if not character_preview_label:
		return

	var preview_text: String = "[b]%s[/b]\n" % character.character_name

	if character.is_hero:
		preview_text += "[color=gold]★ HERO CHARACTER[/color]\n"

	preview_text += "Level: %d\n" % character.starting_level

	if character.character_class:
		preview_text += "Class: %s\n" % character.character_class.display_name
		preview_text += "Movement: %d tiles\n" % character.character_class.movement_range

	# Stats
	preview_text += "\n[b]Stats:[/b]\n"
	preview_text += "HP: %d / MP: %d\n" % [character.base_hp, character.base_mp]
	preview_text += "STR: %d / DEF: %d\n" % [character.base_strength, character.base_defense]
	preview_text += "AGI: %d / INT: %d\n" % [character.base_agility, character.base_intelligence]
	preview_text += "LUK: %d\n" % character.base_luck

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
				info_text += "• %s" % mod_info.mod_id
				if "version" in mod_info:
					info_text += " (v%s)" % mod_info.version
				info_text += "\n"

	party_info_label.text = info_text


## Show error message
func _show_error(message: String) -> void:
	push_warning("PartyEditor: " + message)
	# Could show a popup here in the future


# ============================================================================
# SAVE SLOT MANAGEMENT
# ============================================================================

## Slot selection changed
func _on_slot_selected(index: int) -> void:
	# Update current slot number (but don't auto-load for safety)
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
			info_text += "\n[color=yellow]⚠ Mod mismatch detected[/color]"
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
	for i in range(current_save_data.party_members.size()):
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
# TEMPLATE PARTIES TAB - FUNCTIONALITY (Existing PartyData)
# ============================================================================

## Override: Load party data from resource into UI
func _load_resource_data() -> void:
	var party: PartyData = current_resource as PartyData
	if not party:
		return

	party_name_edit.text = party.party_name
	description_edit.text = party.description
	max_size_spin.value = party.max_size

	# Clear and rebuild members list
	_clear_members_ui()
	for member_dict: Dictionary in party.members:
		_add_member_ui(member_dict)


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var party: PartyData = current_resource as PartyData
	if not party:
		return

	# Update basic info
	party.party_name = party_name_edit.text
	party.description = description_edit.text
	party.max_size = int(max_size_spin.value)

	# Update members array from UI
	party.members.clear()
	for member_ui: Dictionary in members_list:
		var character_idx: int = member_ui.character_option.selected - 1
		if character_idx < 0 or character_idx >= available_characters.size():
			continue  # Skip if no character selected

		var member_dict: Dictionary = {
			"character": available_characters[character_idx],
			"formation_offset": Vector2i(
				int(member_ui.offset_x_spin.value),
				int(member_ui.offset_y_spin.value)
			)
		}
		party.members.append(member_dict)


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var errors: Array[String] = []

	if party_name_edit.text.strip_edges().is_empty():
		errors.append("Party name cannot be empty")

	# Validate that at least one member is selected
	var has_valid_member: bool = false
	for member_ui: Dictionary in members_list:
		if member_ui.character_option.selected > 0:
			has_valid_member = true
			break

	if not has_valid_member:
		errors.append("Party must have at least one member")

	return {
		"valid": errors.is_empty(),
		"errors": errors
	}


## Override: Create a new party with defaults
func _create_new_resource() -> Resource:
	var party: PartyData = PartyData.new()
	party.party_name = "New Party"
	party.description = ""
	party.max_size = 8
	party.members = []
	return party


## Override: Get display name from resource
func _get_resource_display_name(resource: Resource) -> String:
	var party: PartyData = resource as PartyData
	if party:
		var member_count: int = party.get_member_count()
		return "%s (%d/%d)" % [party.party_name, member_count, party.max_size]
	return "Unnamed Party"


## Section 1: Basic Information
func _add_basic_info_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 16)
	template_parties_panel.add_child(section_label)

	var name_label: Label = Label.new()
	name_label.text = "Party Name:"
	template_parties_panel.add_child(name_label)

	party_name_edit = LineEdit.new()
	party_name_edit.placeholder_text = "Enter party name"
	template_parties_panel.add_child(party_name_edit)

	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	template_parties_panel.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size = Vector2(0, 60)
	template_parties_panel.add_child(description_edit)

	var max_size_label: Label = Label.new()
	max_size_label.text = "Maximum Party Size:"
	template_parties_panel.add_child(max_size_label)

	max_size_spin = SpinBox.new()
	max_size_spin.min_value = 1
	max_size_spin.max_value = 12
	max_size_spin.value = 8
	template_parties_panel.add_child(max_size_spin)

	_add_separator_to_panel(template_parties_panel)


## Section 2: Party Members
func _add_party_members_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Party Members"
	section_label.add_theme_font_size_override("font_size", 16)
	template_parties_panel.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Add characters to this party. Formation offsets determine spawn positions."
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 16)
	template_parties_panel.add_child(help_label)

	members_container = VBoxContainer.new()
	template_parties_panel.add_child(members_container)

	var add_member_button: Button = Button.new()
	add_member_button.text = "+ Add Member"
	add_member_button.pressed.connect(_on_add_member)
	template_parties_panel.add_child(add_member_button)

	_add_separator_to_panel(template_parties_panel)


## Load all available characters from ALL loaded mods
func _load_available_characters() -> void:
	available_characters.clear()

	# Get ALL characters from ModRegistry (not just active mod!)
	if ModLoader and ModLoader.registry:
		var all_characters: Array[Resource] = ModLoader.registry.get_all_resources("character")

		# Convert to typed array
		for resource: Resource in all_characters:
			var char_data: CharacterData = resource as CharacterData
			if char_data:
				available_characters.append(char_data)
	else:
		push_warning("PartyEditor: ModLoader or registry not available")

	# Update all character dropdowns if we have any members (Template Parties tab)
	for member_ui: Dictionary in members_list:
		_populate_character_dropdown(member_ui.character_option)

	# Update available characters list (Player Party tab)
	_refresh_available_characters()


## Populate a character dropdown with available characters
func _populate_character_dropdown(option_button: OptionButton) -> void:
	option_button.clear()
	option_button.add_item("(Select Character)", -1)

	for character: CharacterData in available_characters:
		option_button.add_item(character.character_name)


## Add a new member UI element
func _on_add_member() -> void:
	_add_member_ui({})


## Add a member UI row (for existing or new member)
func _add_member_ui(member_dict: Dictionary) -> void:
	var member_panel: PanelContainer = PanelContainer.new()
	var member_vbox: VBoxContainer = VBoxContainer.new()
	member_panel.add_child(member_vbox)

	# Character selector
	var char_label: Label = Label.new()
	char_label.text = "Character:"
	member_vbox.add_child(char_label)

	var character_option: OptionButton = OptionButton.new()
	_populate_character_dropdown(character_option)

	# Select the current character if present
	if "character" in member_dict and member_dict.character:
		for i: int in range(available_characters.size()):
			if available_characters[i] == member_dict.character:
				character_option.select(i + 1)
				break

	member_vbox.add_child(character_option)

	# Formation offset
	var offset_label: Label = Label.new()
	offset_label.text = "Formation Offset (X, Y):"
	member_vbox.add_child(offset_label)

	var offset_hbox: HBoxContainer = HBoxContainer.new()
	member_vbox.add_child(offset_hbox)

	var offset_x_spin: SpinBox = SpinBox.new()
	offset_x_spin.min_value = -5
	offset_x_spin.max_value = 10
	offset_x_spin.value = 0
	offset_hbox.add_child(offset_x_spin)

	var offset_y_spin: SpinBox = SpinBox.new()
	offset_y_spin.min_value = -5
	offset_y_spin.max_value = 10
	offset_y_spin.value = 0
	offset_hbox.add_child(offset_y_spin)

	# Set current formation offset if present
	if "formation_offset" in member_dict:
		var offset: Vector2i = member_dict.formation_offset
		offset_x_spin.value = offset.x
		offset_y_spin.value = offset.y

	# Remove button
	var remove_button: Button = Button.new()
	remove_button.text = "Remove Member"
	member_vbox.add_child(remove_button)

	# Store UI references
	var member_ui: Dictionary = {
		"panel": member_panel,
		"character_option": character_option,
		"offset_x_spin": offset_x_spin,
		"offset_y_spin": offset_y_spin,
		"remove_button": remove_button
	}

	# Connect remove button
	remove_button.pressed.connect(_on_remove_member.bind(member_ui))

	members_list.append(member_ui)
	members_container.add_child(member_panel)


## Remove a member from the UI
func _on_remove_member(member_ui: Dictionary) -> void:
	var index: int = members_list.find(member_ui)
	if index >= 0:
		members_list.remove_at(index)
		member_ui.panel.queue_free()


## Clear all member UI elements
func _clear_members_ui() -> void:
	for member_ui: Dictionary in members_list:
		member_ui.panel.queue_free()
	members_list.clear()


## Add a visual separator
func _add_separator_to_panel(panel: Control) -> void:
	var separator: HSeparator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 10)
	panel.add_child(separator)


# ============================================================================
# DIRECT FILE ACCESS (for editor tool mode - SaveManager doesn't work in editor)
# ============================================================================

const SAVE_DIRECTORY: String = "user://saves/"
const SLOT_FILE_PATTERN: String = "slot_%d.sav"
const METADATA_FILE: String = "slots.meta"


## Check if slot is occupied (direct file access for editor)
func _editor_is_slot_occupied(slot_number: int) -> bool:
	var file_path: String = SAVE_DIRECTORY.path_join(SLOT_FILE_PATTERN % slot_number)
	return FileAccess.file_exists(file_path)


## Load save data from slot (direct file access for editor)
func _editor_load_from_slot(slot_number: int) -> SaveData:
	var file_path: String = SAVE_DIRECTORY.path_join(SLOT_FILE_PATTERN % slot_number)

	if not FileAccess.file_exists(file_path):
		push_warning("PartyEditor: Slot %d file does not exist" % slot_number)
		return null

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("PartyEditor: Failed to open slot %d for reading" % slot_number)
		return null

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("PartyEditor: Failed to parse JSON from slot %d: %s" % [slot_number, json.get_error_message()])
		return null

	var save_dict: Dictionary = json.data
	var save_data: SaveData = SaveData.new()
	save_data.deserialize_from_dict(save_dict)

	if not save_data.validate():
		push_error("PartyEditor: Loaded SaveData from slot %d failed validation" % slot_number)
		return null

	return save_data


## Save data to slot (direct file access for editor)
func _editor_save_to_slot(slot_number: int, save_data: SaveData) -> bool:
	if not save_data:
		push_error("PartyEditor: Cannot save null SaveData")
		return false

	if not save_data.validate():
		push_error("PartyEditor: SaveData validation failed")
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
		push_error("PartyEditor: Failed to open slot %d for writing" % slot_number)
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

	for meta_dict: Dictionary in json.data:
		if meta_dict.get("slot_number", 0) == slot_number:
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
				for i in range(metadata_array.size()):
					var meta_dict: Dictionary = metadata_array[i]
					all_metadata.append(meta_dict)
			file.close()

	# Find or create metadata for this slot
	var slot_meta_dict: Dictionary = {}
	var found: bool = false
	for i in range(all_metadata.size()):
		if all_metadata[i].get("slot_number", 0) == slot_number:
			slot_meta_dict = all_metadata[i]
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
	for i in range(all_metadata.size()):
		if all_metadata[i].get("slot_number", 0) == slot_number:
			all_metadata[i] = slot_meta_dict
			break

	# Save metadata file
	var json_string: String = JSON.stringify(all_metadata, "\t")
	var file: FileAccess = FileAccess.open(metadata_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
