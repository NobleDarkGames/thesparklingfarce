@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## New Game Config Editor UI
## Allows modders to create and edit NewGameConfigData resources
## which define the starting state for new games (party, gold, items, flags, etc.)

# =============================================================================
# IDENTITY FIELDS
# =============================================================================

var config_id_edit: LineEdit
var config_name_edit: LineEdit
var description_edit: TextEdit
var is_default_check: CheckBox

# =============================================================================
# CAMPAIGN SELECTION
# =============================================================================

var campaign_option: OptionButton
var location_label_edit: LineEdit

# =============================================================================
# ECONOMY
# =============================================================================

var starting_gold_spin: SpinBox

# =============================================================================
# DEPOT ITEMS
# =============================================================================

var depot_items_container: VBoxContainer
var depot_items_list: Array[Dictionary] = []  # Track item UI elements

# =============================================================================
# STARTING PARTY
# =============================================================================

var party_option: OptionButton
var party_help_label: Label
var party_preview_container: VBoxContainer

# =============================================================================
# CARAVAN STATE
# =============================================================================

var caravan_unlocked_check: CheckBox

# =============================================================================
# STORY FLAGS
# =============================================================================

var story_flags_container: VBoxContainer
var story_flags_list: Array[Dictionary] = []  # Track flag UI elements

# =============================================================================
# CACHED DATA
# =============================================================================

var available_campaigns: Array[Resource] = []
var available_parties: Array[Resource] = []
var available_items: Array[Resource] = []

# =============================================================================
# PHASE 7: ACTIVE DEFAULT TRACKING
# =============================================================================

# Track which config is the active default (highest priority mod)
var active_default_config_id: String = ""
var active_default_source_mod: String = ""

# =============================================================================
# PHASE 7.4: PREVIEW CONFIGURATION PANEL
# =============================================================================

var preview_panel: PanelContainer
var preview_container: VBoxContainer
var preview_toggle_button: Button
var preview_expanded: bool = false


func _ready() -> void:
	resource_type_name = "New Game Config"
	resource_type_id = "new_game_config"
	# Declare dependencies BEFORE super._ready() so base class can auto-subscribe
	resource_dependencies = ["campaign", "party", "item"]
	super._ready()
	_load_available_resources()
	_load_active_default_info()


## Override: Called when dependent resource types change (via base class)
func _on_dependencies_changed(changed_type: String) -> void:
	match changed_type:
		"campaign":
			_load_available_campaigns()
		"party":
			_load_available_parties()
			_update_preview_panel()
		"item":
			_load_available_items()
	# Refresh active default info when any dependency changes
	_load_active_default_info()
	_apply_filter()  # Refresh list to update badges


# =============================================================================
# UI CREATION (OVERRIDE BASE CLASS)
# =============================================================================

## Override: Create the new game config editor form
func _create_detail_form() -> void:
	# Phase 7.4: Preview Configuration Panel at the top
	_add_preview_configuration_panel()

	# Section 1: Identity
	_add_identity_section()

	# Section 2: Campaign Selection
	_add_campaign_section()

	# Section 3: Economy
	_add_economy_section()

	# Section 4: Starting Party
	_add_party_section()

	# Section 5: Caravan State
	_add_caravan_section()

	# Section 6: Depot Items
	_add_depot_items_section()

	# Section 7: Story Flags
	_add_story_flags_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


## Override: Load config data from resource into UI
func _load_resource_data() -> void:
	var config: NewGameConfigData = current_resource as NewGameConfigData
	if not config:
		return

	# Identity
	config_id_edit.text = config.config_id
	config_name_edit.text = config.config_name
	description_edit.text = config.config_description
	is_default_check.button_pressed = config.is_default

	# Campaign
	_select_campaign(config.starting_campaign_id)
	location_label_edit.text = config.starting_location_label

	# Economy
	starting_gold_spin.value = config.starting_gold

	# Starting Party
	_select_party(config.starting_party_id)

	# Caravan State
	caravan_unlocked_check.button_pressed = config.caravan_unlocked

	# Depot Items
	_clear_depot_items_ui()
	for item_id: String in config.starting_depot_items:
		_add_depot_item_ui(item_id)

	# Story Flags
	_clear_story_flags_ui()
	for flag_name: String in config.starting_story_flags.keys():
		var flag_value: bool = config.starting_story_flags[flag_name]
		_add_story_flag_ui(flag_name, flag_value)


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var config: NewGameConfigData = current_resource as NewGameConfigData
	if not config:
		return

	# Identity
	config.config_id = config_id_edit.text.strip_edges()
	config.config_name = config_name_edit.text.strip_edges()
	config.config_description = description_edit.text
	config.is_default = is_default_check.button_pressed

	# Campaign
	config.starting_campaign_id = _get_selected_campaign_id()
	config.starting_location_label = location_label_edit.text.strip_edges()

	# Economy
	config.starting_gold = int(starting_gold_spin.value)

	# Starting Party
	config.starting_party_id = _get_selected_party_id()

	# Caravan State
	config.caravan_unlocked = caravan_unlocked_check.button_pressed

	# Depot Items
	config.starting_depot_items.clear()
	for item_ui: Dictionary in depot_items_list:
		var item_id: String = _get_item_id_from_option(item_ui.item_option)
		if not item_id.is_empty():
			config.starting_depot_items.append(item_id)

	# Story Flags
	config.starting_story_flags.clear()
	for flag_ui: Dictionary in story_flags_list:
		var flag_name: String = flag_ui.name_edit.text.strip_edges()
		if not flag_name.is_empty():
			config.starting_story_flags[flag_name] = flag_ui.value_check.button_pressed


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	if config_id_edit.text.strip_edges().is_empty():
		errors.append("Config ID cannot be empty")

	if config_name_edit.text.strip_edges().is_empty():
		errors.append("Config Name cannot be empty")

	# Validate ID format (lowercase, underscores, no spaces)
	var config_id: String = config_id_edit.text.strip_edges()
	var id_regex: RegEx = RegEx.new()
	id_regex.compile("^[a-z][a-z0-9_]*$")
	if not config_id.is_empty() and not id_regex.search(config_id):
		errors.append("Config ID must start with a letter and contain only lowercase letters, numbers, and underscores")

	# Warn about multiple defaults in the same mod
	if is_default_check.button_pressed:
		var other_defaults: Array[String] = _find_other_defaults_in_active_mod()
		if not other_defaults.is_empty():
			warnings.append("Warning: Other configs are also marked as default: " + ", ".join(other_defaults))

	# Warn about broken references
	var broken_refs: Array[String] = _check_broken_references()
	warnings.append_array(broken_refs)

	# Combine errors and warnings for display (errors prevent save, warnings don't)
	var all_messages: Array[String] = errors.duplicate()
	all_messages.append_array(warnings)

	return {
		"valid": errors.is_empty(),
		"errors": all_messages
	}


## Override: Create a new config with defaults
func _create_new_resource() -> Resource:
	var config: NewGameConfigData = NewGameConfigData.new()
	config.config_id = "new_config"
	config.config_name = "New Configuration"
	config.config_description = ""
	config.is_default = false
	config.starting_campaign_id = ""
	config.starting_location_label = "Prologue"
	config.starting_gold = 0
	config.starting_depot_items = []
	config.starting_story_flags = {}
	config.starting_party_id = ""
	return config


## Override: Get display name from resource
## Includes validation warning indicator if references are broken
## Phase 7.3: Shows [ACTIVE DEFAULT] for the config that will actually be used
func _get_resource_display_name(resource: Resource) -> String:
	var config: NewGameConfigData = resource as NewGameConfigData
	if config:
		var warning_indicator: String = ""

		# Check for broken references without triggering full validation
		if _has_broken_references_quick(config):
			warning_indicator = " (!)"

		# Phase 7.3: Determine badge based on active default status
		var badge: String = ""
		if config.is_default:
			if config.config_id == active_default_config_id:
				badge = " [ACTIVE DEFAULT]"
			else:
				badge = " [DEFAULT]"

		return config.config_name + badge + warning_indicator
	return "Unnamed Config"


## Quick check for broken references (used for list display)
## Returns true if any referenced resource doesn't exist
func _has_broken_references_quick(config: NewGameConfigData) -> bool:
	if not ModLoader or not ModLoader.registry:
		return false

	# Check campaign reference
	if not config.starting_campaign_id.is_empty():
		if not ModLoader.registry.has_resource("campaign", config.starting_campaign_id):
			return true

	# Check party reference
	if not config.starting_party_id.is_empty():
		if not ModLoader.registry.has_resource("party", config.starting_party_id):
			return true

	# Check depot items
	for item_id: String in config.starting_depot_items:
		if not ModLoader.registry.has_resource("item", item_id):
			return true

	return false


## Override: Update resource properties when copying
## This ensures the config_name and config_id are updated for copies
func _update_resource_id_for_copy(resource: Resource, original_name: String) -> void:
	var config: NewGameConfigData = resource as NewGameConfigData
	if config:
		# Add copy suffix to display name
		if not config.config_name.ends_with(" (Copy)"):
			config.config_name = config.config_name + " (Copy)"
		# Generate unique ID for the copy
		var timestamp: int = Time.get_unix_time_from_system()
		config.config_id = config.config_id + "_copy_%d" % timestamp
		# Copies should not be default
		config.is_default = false


# =============================================================================
# UI SECTIONS
# =============================================================================

## Section 1: Identity
func _add_identity_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Identity"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	# Config ID
	var id_container: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Config ID:"
	id_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	id_label.tooltip_text = "Unique identifier (e.g., 'standard', 'hard_mode', 'demo')"
	id_container.add_child(id_label)

	config_id_edit = LineEdit.new()
	config_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_id_edit.placeholder_text = "e.g., standard, hard_mode"
	config_id_edit.text_changed.connect(_on_field_changed)
	id_container.add_child(config_id_edit)
	detail_panel.add_child(id_container)

	# Config Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Display Name:"
	name_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	name_label.tooltip_text = "Human-readable name shown in the new game UI"
	name_container.add_child(name_label)

	config_name_edit = LineEdit.new()
	config_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_name_edit.placeholder_text = "Standard Game"
	config_name_edit.text_changed.connect(_on_field_changed)
	name_container.add_child(config_name_edit)
	detail_panel.add_child(name_container)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	detail_panel.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size = Vector2(0, 60)
	description_edit.placeholder_text = "Describe what makes this configuration special..."
	description_edit.text_changed.connect(_on_field_changed)
	detail_panel.add_child(description_edit)

	# Is Default checkbox
	is_default_check = CheckBox.new()
	is_default_check.text = "Default Configuration (used when starting a new game)"
	is_default_check.tooltip_text = "Only one config per mod should be marked as default"
	is_default_check.toggled.connect(_on_default_toggled)
	detail_panel.add_child(is_default_check)

	_add_separator()


## Section 2: Campaign Selection
func _add_campaign_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Campaign"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	# Campaign selector
	var campaign_container: HBoxContainer = HBoxContainer.new()
	var campaign_label: Label = Label.new()
	campaign_label.text = "Starting Campaign:"
	campaign_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	campaign_label.tooltip_text = "Which campaign to start. Leave as 'Auto' to use the highest-priority mod's campaign."
	campaign_container.add_child(campaign_label)

	campaign_option = OptionButton.new()
	campaign_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_option.item_selected.connect(_on_campaign_selected)
	campaign_container.add_child(campaign_option)
	detail_panel.add_child(campaign_container)

	# Location label
	var location_container: HBoxContainer = HBoxContainer.new()
	var location_label: Label = Label.new()
	location_label.text = "Location Label:"
	location_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	location_label.tooltip_text = "Display text for save slot (e.g., 'Prologue', 'Chapter 1')"
	location_container.add_child(location_label)

	location_label_edit = LineEdit.new()
	location_label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location_label_edit.placeholder_text = "Prologue"
	location_label_edit.text_changed.connect(_on_field_changed)
	location_container.add_child(location_label_edit)
	detail_panel.add_child(location_container)

	var help_label: Label = Label.new()
	help_label.text = "Location label is cosmetic - shown in save slots. Actual location is determined by campaign."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(help_label)

	_add_separator()


## Section 3: Economy
func _add_economy_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Economy"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	# Starting Gold
	var gold_container: HBoxContainer = HBoxContainer.new()
	var gold_label: Label = Label.new()
	gold_label.text = "Starting Gold:"
	gold_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	gold_label.tooltip_text = "Gold the party starts with. SF2 authentic default is 0."
	gold_container.add_child(gold_label)

	starting_gold_spin = SpinBox.new()
	starting_gold_spin.min_value = 0
	starting_gold_spin.max_value = 99999
	starting_gold_spin.value = 0
	starting_gold_spin.value_changed.connect(_on_spin_changed)
	gold_container.add_child(starting_gold_spin)

	var gold_help: Label = Label.new()
	gold_help.text = "(SF2 default: 0)"
	gold_help.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	gold_help.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	gold_container.add_child(gold_help)

	detail_panel.add_child(gold_container)

	_add_separator()


## Section 4: Starting Party
func _add_party_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Starting Party"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	# Party selector
	var party_container: HBoxContainer = HBoxContainer.new()
	var party_label: Label = Label.new()
	party_label.text = "Party Template:"
	party_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	party_label.tooltip_text = "Select a PartyData template or auto-detect from character flags"
	party_container.add_child(party_label)

	party_option = OptionButton.new()
	party_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_option.item_selected.connect(_on_party_selected)
	party_container.add_child(party_option)
	detail_panel.add_child(party_container)

	# Help label explaining party resolution
	party_help_label = Label.new()
	party_help_label.text = "Select a PartyData template, or use 'Auto-detect' to use is_hero + is_default_party_member flags."
	party_help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	party_help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	party_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(party_help_label)

	# Party preview (shows computed party members)
	party_preview_container = VBoxContainer.new()
	detail_panel.add_child(party_preview_container)

	_add_separator()


## Section 5: Caravan State
func _add_caravan_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Caravan"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	# Caravan unlocked checkbox
	caravan_unlocked_check = CheckBox.new()
	caravan_unlocked_check.text = "Caravan Unlocked at Start"
	caravan_unlocked_check.tooltip_text = "If checked, the Caravan is available from the beginning. In SF2, the Caravan is acquired early in the game."
	caravan_unlocked_check.toggled.connect(_on_caravan_toggled)
	detail_panel.add_child(caravan_unlocked_check)

	var help_label: Label = Label.new()
	help_label.text = "Controls whether the Caravan (party storage, shops access) is available. Uncheck for authentic SF2 experience where the Caravan is unlocked through story progression."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(help_label)

	_add_separator()


## Section 6: Depot Items
func _add_depot_items_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Starting Depot Items"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Items placed in the Caravan depot at game start. Duplicates allowed for stacking."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(help_label)

	depot_items_container = VBoxContainer.new()
	detail_panel.add_child(depot_items_container)

	var add_item_button: Button = Button.new()
	add_item_button.text = "+ Add Depot Item"
	add_item_button.pressed.connect(_on_add_depot_item)
	detail_panel.add_child(add_item_button)

	_add_separator()


## Section 6: Story Flags
func _add_story_flags_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Starting Story Flags"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Story flags to set at game start. These supplement (and override) the campaign's initial_flags."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(help_label)

	story_flags_container = VBoxContainer.new()
	detail_panel.add_child(story_flags_container)

	var add_flag_button: Button = Button.new()
	add_flag_button.text = "+ Add Story Flag"
	add_flag_button.pressed.connect(_on_add_story_flag)
	detail_panel.add_child(add_flag_button)

	_add_separator()


## Add a visual separator
func _add_separator() -> void:
	var separator: HSeparator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 10)
	detail_panel.add_child(separator)


# =============================================================================
# RESOURCE LOADING
# =============================================================================

func _load_available_resources() -> void:
	_load_available_campaigns()
	_load_available_parties()
	_load_available_items()


func _load_available_campaigns() -> void:
	available_campaigns.clear()
	if ModLoader and ModLoader.registry:
		available_campaigns = ModLoader.registry.get_all_resources("campaign")
	_populate_campaign_dropdown()


func _load_available_parties() -> void:
	available_parties.clear()
	if ModLoader and ModLoader.registry:
		available_parties = ModLoader.registry.get_all_resources("party")
	_populate_party_dropdown()


func _load_available_items() -> void:
	available_items.clear()
	if ModLoader and ModLoader.registry:
		available_items = ModLoader.registry.get_all_resources("item")
	# Update existing item dropdowns
	for item_ui: Dictionary in depot_items_list:
		_populate_item_dropdown(item_ui.item_option)


# =============================================================================
# CAMPAIGN DROPDOWN
# =============================================================================

func _populate_campaign_dropdown() -> void:
	if not campaign_option:
		return

	campaign_option.clear()
	campaign_option.add_item("(Auto - highest priority mod's campaign)", -1)
	campaign_option.set_item_metadata(0, "")

	var idx: int = 1
	for campaign: CampaignData in available_campaigns:
		if not campaign:
			continue
		var display_name: String = campaign.campaign_name if not campaign.campaign_name.is_empty() else campaign.resource_path.get_file().get_basename()
		campaign_option.add_item(display_name)
		campaign_option.set_item_metadata(idx, campaign.campaign_id if not campaign.campaign_id.is_empty() else campaign.resource_path.get_file().get_basename())
		idx += 1


func _select_campaign(campaign_id: String) -> void:
	if campaign_id.is_empty():
		campaign_option.select(0)
		return

	for i: int in range(campaign_option.item_count):
		if campaign_option.get_item_metadata(i) == campaign_id:
			campaign_option.select(i)
			return

	# Campaign not found - default to auto
	campaign_option.select(0)


func _get_selected_campaign_id() -> String:
	var selected: int = campaign_option.selected
	if selected <= 0:
		return ""
	return campaign_option.get_item_metadata(selected)


# =============================================================================
# PARTY DROPDOWN
# =============================================================================

func _populate_party_dropdown() -> void:
	if not party_option:
		return

	party_option.clear()
	party_option.add_item("(Auto-detect from character flags)", -1)
	party_option.set_item_metadata(0, "")

	var idx: int = 1
	for party: PartyData in available_parties:
		if not party:
			continue
		var display_name: String = party.party_name if not party.party_name.is_empty() else party.resource_path.get_file().get_basename()
		if party.has_method("get_member_count"):
			display_name = "%s (%d members)" % [display_name, party.get_member_count()]
		party_option.add_item(display_name)
		party_option.set_item_metadata(idx, party.resource_path.get_file().get_basename())
		idx += 1


func _select_party(party_id: String) -> void:
	if party_id.is_empty():
		party_option.select(0)
		_update_party_help(true)
		return

	for i: int in range(party_option.item_count):
		if party_option.get_item_metadata(i) == party_id:
			party_option.select(i)
			_update_party_help(false)
			return

	# Party not found - default to auto
	party_option.select(0)
	_update_party_help(true)


func _get_selected_party_id() -> String:
	var selected: int = party_option.selected
	if selected <= 0:
		return ""
	return party_option.get_item_metadata(selected)


func _update_party_help(is_auto: bool) -> void:
	if is_auto:
		party_help_label.text = "Auto-detect mode: Party will be built from characters with is_hero=true and is_default_party_member=true flags."
	else:
		party_help_label.text = "Using explicit PartyData template. This completely replaces the default party resolution."
	_update_party_preview(is_auto)


## Update the party preview to show computed members
func _update_party_preview(is_auto: bool) -> void:
	if not party_preview_container:
		return

	# Clear existing preview
	for child: Node in party_preview_container.get_children():
		child.queue_free()

	var members: Array = []
	var preview_title: String = ""

	if is_auto:
		# Get the auto-detected party from ModLoader
		if ModLoader:
			var default_party: Array = ModLoader.get_default_party()
			for character: Resource in default_party:
				if character and "character_name" in character:
					var is_hero: bool = character.is_hero if "is_hero" in character else false
					members.append({
						"name": character.character_name,
						"is_hero": is_hero
					})
		preview_title = "Auto-detected Party:"
	else:
		# Get the selected party template
		var party_id: String = _get_selected_party_id()
		if not party_id.is_empty():
			for resource: Resource in available_parties:
				var res_id: String = resource.resource_path.get_file().get_basename()
				if res_id == party_id:
					# PartyData has member_ids array
					if "member_ids" in resource:
						for member_id: String in resource.member_ids:
							var char_data: CharacterData = null
							if ModLoader and ModLoader.registry:
								char_data = ModLoader.registry.get_character(member_id)
							if char_data and "character_name" in char_data:
								var is_hero: bool = char_data.is_hero if "is_hero" in char_data else false
								members.append({
									"name": char_data.character_name,
									"is_hero": is_hero
								})
							else:
								members.append({"name": member_id, "is_hero": false})
					break
		preview_title = "Party Template Members:"

	# Build preview UI
	if members.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No party members found"
		empty_label.add_theme_color_override("font_color", SparklingEditorUtils.get_warning_color())
		empty_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
		party_preview_container.add_child(empty_label)
	else:
		var title_label: Label = Label.new()
		title_label.text = preview_title
		title_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
		party_preview_container.add_child(title_label)

		var members_hbox: HBoxContainer = HBoxContainer.new()
		members_hbox.add_theme_constant_override("separation", 10)

		for i: int in range(members.size()):
			var member: Dictionary = members[i]
			var member_label: Label = Label.new()
			var prefix: String = "[Hero] " if member.is_hero else ""
			member_label.text = prefix + member.name
			if member.is_hero:
				member_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))  # Gold for hero
			else:
				member_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
			member_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
			members_hbox.add_child(member_label)

			# Add separator between members (except last)
			if i < members.size() - 1:
				var sep: Label = Label.new()
				sep.text = "|"
				sep.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
				sep.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
				members_hbox.add_child(sep)

		party_preview_container.add_child(members_hbox)


# =============================================================================
# DEPOT ITEMS UI
# =============================================================================

func _on_add_depot_item() -> void:
	_add_depot_item_ui("")
	_mark_dirty()


func _add_depot_item_ui(item_id: String) -> void:
	var item_hbox: HBoxContainer = HBoxContainer.new()

	var item_option: OptionButton = OptionButton.new()
	item_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_item_dropdown(item_option)
	_select_item_in_dropdown(item_option, item_id)
	item_option.item_selected.connect(_on_depot_item_selected)
	item_hbox.add_child(item_option)

	var remove_button: Button = Button.new()
	remove_button.text = "X"
	remove_button.tooltip_text = "Remove this item"
	item_hbox.add_child(remove_button)

	var item_ui: Dictionary = {
		"container": item_hbox,
		"item_option": item_option,
		"remove_button": remove_button
	}

	remove_button.pressed.connect(_on_remove_depot_item.bind(item_ui))

	depot_items_list.append(item_ui)
	depot_items_container.add_child(item_hbox)


func _on_remove_depot_item(item_ui: Dictionary) -> void:
	var index: int = depot_items_list.find(item_ui)
	if index >= 0:
		depot_items_list.remove_at(index)
		item_ui.container.queue_free()
		_mark_dirty()


func _clear_depot_items_ui() -> void:
	for item_ui: Dictionary in depot_items_list:
		item_ui.container.queue_free()
	depot_items_list.clear()


func _populate_item_dropdown(option: OptionButton) -> void:
	var current_selection: String = ""
	if option.selected >= 0 and option.selected < option.item_count:
		current_selection = option.get_item_metadata(option.selected)

	option.clear()
	option.add_item("(Select Item)", -1)
	option.set_item_metadata(0, "")

	var idx: int = 1
	for resource: Resource in available_items:
		var display_name: String = _get_item_display_name(resource)
		option.add_item(display_name)
		option.set_item_metadata(idx, _get_item_id(resource))
		idx += 1

	# Restore selection if possible
	if not current_selection.is_empty():
		_select_item_in_dropdown(option, current_selection)


func _get_item_display_name(resource: Resource) -> String:
	if "item_name" in resource:
		return resource.item_name
	return resource.resource_path.get_file().get_basename()


func _get_item_id(resource: Resource) -> String:
	# ItemData uses the filename as the ID
	return resource.resource_path.get_file().get_basename()


func _select_item_in_dropdown(option: OptionButton, item_id: String) -> void:
	if item_id.is_empty():
		option.select(0)
		return

	for i: int in range(option.item_count):
		if option.get_item_metadata(i) == item_id:
			option.select(i)
			return

	# Item not found - default to none
	option.select(0)


func _get_item_id_from_option(option: OptionButton) -> String:
	var selected: int = option.selected
	if selected <= 0:
		return ""
	var metadata: Variant = option.get_item_metadata(selected)
	if metadata is String:
		return metadata
	return ""


# =============================================================================
# STORY FLAGS UI
# =============================================================================

func _on_add_story_flag() -> void:
	_add_story_flag_ui("", true)
	_mark_dirty()


func _add_story_flag_ui(flag_name: String, flag_value: bool) -> void:
	var flag_hbox: HBoxContainer = HBoxContainer.new()

	var name_edit: LineEdit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.placeholder_text = "flag_name"
	name_edit.text = flag_name
	name_edit.text_changed.connect(_on_field_changed)
	flag_hbox.add_child(name_edit)

	var value_check: CheckBox = CheckBox.new()
	value_check.text = "true"
	value_check.button_pressed = flag_value
	value_check.toggled.connect(_on_flag_toggled)
	flag_hbox.add_child(value_check)

	var remove_button: Button = Button.new()
	remove_button.text = "X"
	remove_button.tooltip_text = "Remove this flag"
	flag_hbox.add_child(remove_button)

	var flag_ui: Dictionary = {
		"container": flag_hbox,
		"name_edit": name_edit,
		"value_check": value_check,
		"remove_button": remove_button
	}

	remove_button.pressed.connect(_on_remove_story_flag.bind(flag_ui))

	story_flags_list.append(flag_ui)
	story_flags_container.add_child(flag_hbox)


func _on_remove_story_flag(flag_ui: Dictionary) -> void:
	var index: int = story_flags_list.find(flag_ui)
	if index >= 0:
		story_flags_list.remove_at(index)
		flag_ui.container.queue_free()
		_mark_dirty()


func _clear_story_flags_ui() -> void:
	for flag_ui: Dictionary in story_flags_list:
		flag_ui.container.queue_free()
	story_flags_list.clear()


# =============================================================================
# EVENT HANDLERS (for dirty tracking)
# =============================================================================

func _on_field_changed(_new_value: Variant = null) -> void:
	_mark_dirty()


func _on_spin_changed(_new_value: float) -> void:
	_mark_dirty()


func _on_default_toggled(_pressed: bool) -> void:
	_mark_dirty()


func _on_campaign_selected(_index: int) -> void:
	_mark_dirty()


func _on_party_selected(index: int) -> void:
	var is_auto: bool = (index <= 0)
	_update_party_help(is_auto)
	_mark_dirty()


func _on_depot_item_selected(_index: int) -> void:
	_mark_dirty()


func _on_flag_toggled(_pressed: bool) -> void:
	_mark_dirty()


func _on_caravan_toggled(_pressed: bool) -> void:
	_mark_dirty()


# =============================================================================
# VALIDATION HELPERS
# =============================================================================

## Find other default configs in the active mod (excluding current resource)
func _find_other_defaults_in_active_mod() -> Array[String]:
	var other_defaults: Array[String] = []

	if not ModLoader or not ModLoader.registry:
		return other_defaults

	var active_mod: ModManifest = ModLoader.get_active_mod()
	if not active_mod:
		return other_defaults

	var active_mod_folder: String = active_mod.mod_directory.get_file()
	var current_config_id: String = config_id_edit.text.strip_edges() if config_id_edit else ""

	# Scan the active mod's new_game_configs directory
	var config_dir: String = active_mod.get_data_directory().path_join("new_game_configs")
	var dir: DirAccess = DirAccess.open(config_dir)
	if not dir:
		return other_defaults

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path: String = config_dir.path_join(file_name)
			var resource: Resource = load(full_path)
			if resource and resource is NewGameConfigData:
				var config: NewGameConfigData = resource as NewGameConfigData
				# Skip the current config being edited
				if config.config_id != current_config_id and config.is_default:
					other_defaults.append(config.config_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	return other_defaults


## Check for references to resources that no longer exist
func _check_broken_references() -> Array[String]:
	var warnings: Array[String] = []

	if not ModLoader or not ModLoader.registry:
		return warnings

	# Check campaign reference
	var campaign_id: String = _get_selected_campaign_id()
	if not campaign_id.is_empty():
		if not ModLoader.registry.has_resource("campaign", campaign_id):
			warnings.append("Warning: Campaign '%s' not found" % campaign_id)

	# Check party reference
	var party_id: String = _get_selected_party_id()
	if not party_id.is_empty():
		if not ModLoader.registry.has_resource("party", party_id):
			warnings.append("Warning: Party '%s' not found" % party_id)

	# Check depot item references
	for item_ui: Dictionary in depot_items_list:
		var item_id: String = _get_item_id_from_option(item_ui.item_option)
		if not item_id.is_empty():
			if not ModLoader.registry.has_resource("item", item_id):
				warnings.append("Warning: Item '%s' not found" % item_id)

	return warnings


# =============================================================================
# PHASE 7: ACTIVE DEFAULT TRACKING & PREVIEW PANEL
# =============================================================================

## Load information about which config is the active default
func _load_active_default_info() -> void:
	active_default_config_id = ""
	active_default_source_mod = ""

	if not ModLoader or not ModLoader.registry:
		return

	# Get all NewGameConfigData resources
	var all_configs: Array[Resource] = ModLoader.registry.get_all_resources("new_game_config")

	# Track the highest priority default config
	var highest_priority: int = -1

	for ngc: NewGameConfigData in all_configs:
		if not ngc:
			continue

		if not ngc.is_default:
			continue

		# Get the source mod and its priority
		var source_mod: String = ModLoader.registry.get_resource_source(ngc.config_id)
		var mod_manifest: ModManifest = ModLoader.get_mod(source_mod) if source_mod else null
		var priority: int = mod_manifest.load_priority if mod_manifest else 0

		if priority > highest_priority:
			highest_priority = priority
			active_default_config_id = ngc.config_id
			active_default_source_mod = source_mod


## Phase 7.4: Add Preview Configuration Panel
func _add_preview_configuration_panel() -> void:
	# Collapsible panel header
	var header_container: HBoxContainer = HBoxContainer.new()
	detail_panel.add_child(header_container)

	preview_toggle_button = Button.new()
	preview_toggle_button.text = "Show Effective Configuration Preview"
	preview_toggle_button.toggle_mode = true
	preview_toggle_button.button_pressed = false
	preview_toggle_button.tooltip_text = "Shows which config will actually be used at game start (considering mod priorities)"
	preview_toggle_button.pressed.connect(_on_preview_toggle)
	header_container.add_child(preview_toggle_button)

	# The collapsible preview panel
	preview_panel = PanelContainer.new()
	preview_panel.visible = false

	# Apply info panel style
	var info_style: StyleBoxFlat = SparklingEditorUtils.create_info_panel_style()
	preview_panel.add_theme_stylebox_override("panel", info_style)

	preview_container = VBoxContainer.new()
	preview_panel.add_child(preview_container)
	detail_panel.add_child(preview_panel)

	_add_separator()


## Handle preview panel toggle
func _on_preview_toggle() -> void:
	preview_expanded = preview_toggle_button.button_pressed
	preview_panel.visible = preview_expanded

	if preview_expanded:
		preview_toggle_button.text = "Hide Effective Configuration Preview"
		_update_preview_panel()
	else:
		preview_toggle_button.text = "Show Effective Configuration Preview"


## Update the preview panel content
func _update_preview_panel() -> void:
	if not preview_container or not preview_expanded:
		return

	# Clear existing content
	for child: Node in preview_container.get_children():
		child.queue_free()

	# Title
	var title_label: Label = Label.new()
	title_label.text = "Effective New Game Configuration"
	title_label.add_theme_font_size_override("font_size", 14)
	preview_container.add_child(title_label)

	# Find the active default config
	var active_config: NewGameConfigData = _get_active_default_config()

	if not active_config:
		var no_config_label: Label = Label.new()
		no_config_label.text = "No default configuration found. The game will use auto-detection for party."
		no_config_label.add_theme_color_override("font_color", SparklingEditorUtils.get_warning_color())
		no_config_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_container.add_child(no_config_label)
		return

	# Config source info
	var source_label: Label = Label.new()
	source_label.text = "Active Config: %s (from mod: %s)" % [active_config.config_name, active_default_source_mod]
	source_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	preview_container.add_child(source_label)

	# Check if current config is being overridden
	if current_resource is NewGameConfigData:
		var current_config: NewGameConfigData = current_resource as NewGameConfigData
		if current_config.is_default and current_config.config_id != active_default_config_id:
			var override_warning: Label = Label.new()
			override_warning.text = "Note: This config is marked as default but is overridden by a higher-priority mod."
			override_warning.add_theme_color_override("font_color", SparklingEditorUtils.get_warning_color())
			override_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			preview_container.add_child(override_warning)

	# Starting Party Preview
	_add_preview_separator()
	var party_header: Label = Label.new()
	party_header.text = "Starting Party:"
	party_header.add_theme_font_size_override("font_size", 12)
	preview_container.add_child(party_header)

	var party_preview: Label = Label.new()
	if active_config.starting_party_id.is_empty():
		party_preview.text = "(Auto-detect from character flags)"
		# Show auto-detected party members
		var members: Array = _get_auto_detected_party_members()
		if not members.is_empty():
			party_preview.text += "\n  Members: " + ", ".join(members)
	else:
		party_preview.text = "Template: " + active_config.starting_party_id
		# Show party template members
		var members: Array = _get_party_template_members(active_config.starting_party_id)
		if not members.is_empty():
			party_preview.text += "\n  Members: " + ", ".join(members)
		elif ModLoader and ModLoader.registry:
			if not ModLoader.registry.has_resource("party", active_config.starting_party_id):
				party_preview.text += " (NOT FOUND!)"
				party_preview.add_theme_color_override("font_color", SparklingEditorUtils.get_error_color())
	party_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_container.add_child(party_preview)

	# Economy Preview
	_add_preview_separator()
	var economy_label: Label = Label.new()
	economy_label.text = "Starting Gold: %d" % active_config.starting_gold
	preview_container.add_child(economy_label)

	var depot_label: Label = Label.new()
	depot_label.text = "Depot Items: %d items" % active_config.starting_depot_items.size()
	preview_container.add_child(depot_label)

	# Caravan Status
	var caravan_label: Label = Label.new()
	caravan_label.text = "Caravan: %s" % ("Unlocked" if active_config.caravan_unlocked else "Locked")
	preview_container.add_child(caravan_label)


## Add a small separator to the preview panel
func _add_preview_separator() -> void:
	var sep: HSeparator = HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 5)
	preview_container.add_child(sep)


## Get the active default NewGameConfigData
func _get_active_default_config() -> NewGameConfigData:
	if active_default_config_id.is_empty():
		return null

	if not ModLoader or not ModLoader.registry:
		return null

	return ModLoader.registry.get_new_game_config(active_default_config_id)


## Get auto-detected party member names
func _get_auto_detected_party_members() -> Array:
	var members: Array = []

	if not ModLoader:
		return members

	var default_party: Array = ModLoader.get_default_party()
	for character: Resource in default_party:
		if character and "character_name" in character:
			var name: String = character.character_name
			if "is_hero" in character and character.is_hero:
				name = "[Hero] " + name
			members.append(name)

	return members


## Get party template member names
func _get_party_template_members(party_id: String) -> Array:
	var members: Array = []

	if not ModLoader or not ModLoader.registry:
		return members

	var party_data: PartyData = ModLoader.registry.get_party(party_id)
	if not party_data:
		return members
	for member_dict: Dictionary in party_data.members:
		if "character" in member_dict and member_dict.character:
			var char_data: CharacterData = member_dict.character as CharacterData
			if char_data:
				var name: String = char_data.character_name
				if char_data.is_hero:
					name = "[Hero] " + name
				members.append(name)

	return members
