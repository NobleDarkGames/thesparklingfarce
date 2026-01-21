@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Battle Editor UI
## Allows browsing and editing BattleData resources
##
## Features a visual map preview panel that shows:
## - The battle map with tiles rendered
## - Player spawn point (blue marker)
## - Enemy positions (red markers with index numbers)
## - Neutral positions (yellow markers)
## - Click-to-place functionality for positioning units visually

# Basic info
var battle_name_edit: LineEdit
var battle_description_edit: TextEdit

# Map
var map_scene_option: OptionButton
var player_spawn_x_spin: SpinBox
var player_spawn_y_spin: SpinBox


# Player Forces - now using ResourcePicker for cross-mod support
var player_party_picker: ResourcePicker

# Enemy Forces (collapsible)
var enemies_section: CollapseSection
var enemies_list: DynamicRowList

# Neutral Forces (collapsible)
var neutrals_section: CollapseSection
var neutrals_list: DynamicRowList

# Victory Conditions
var victory_condition_option: OptionButton
var victory_conditional_container: VBoxContainer
var victory_boss_index_spin: SpinBox
var victory_protect_index_spin: SpinBox
var victory_turn_count_spin: SpinBox
var victory_target_x_spin: SpinBox
var victory_target_y_spin: SpinBox

# Defeat Conditions
var defeat_condition_option: OptionButton
var defeat_conditional_container: VBoxContainer
var defeat_protect_index_spin: SpinBox
var defeat_turn_limit_spin: SpinBox

# Battle Flow - now using ResourcePicker for cross-mod support
var pre_battle_dialogue_picker: ResourcePicker
var victory_dialogue_picker: ResourcePicker
var defeat_dialogue_picker: ResourcePicker

# Audio
var music_id_option: OptionButton
var victory_music_option: OptionButton
var defeat_music_option: OptionButton

# Rewards
var experience_reward_spin: SpinBox
var gold_reward_spin: SpinBox

# Item rewards
var item_rewards_section: CollapseSection
var item_rewards_list: DynamicRowList

# AI Behavior - no local cache, query registry directly

# Flag to prevent signal feedback loops during UI updates
var _updating_ui: bool = false


func _ready() -> void:
	resource_type_id = "battle"
	resource_type_name = "Battle"
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()

	# Declare dependencies BEFORE calling super._ready() so base class sets up tracking
	# Note: ResourcePickers for character, party, dialogue, item auto-refresh via EditorEventBus
	# This declaration is for completeness and documents the editor's dependencies
	# ai_behavior is included so enemy AI dropdowns refresh when new behaviors are created
	resource_dependencies = ["character", "party", "dialogue", "item", "ai_behavior"]

	super._ready()


## Called when a dependent resource type changes
func _on_dependencies_changed(_changed_type: String) -> void:
	# No local cache to clear - dropdowns query registry directly when populated
	pass


## Override: Create the battle-specific detail form
func _create_detail_form() -> void:
	# Section 1: Basic Information
	_add_basic_info_section()

	# Section 2: Map Selection
	_add_map_section()

	# Section 3: Player Forces
	_add_player_forces_section()

	# Section 4: Enemy Forces
	_add_enemy_forces_section()

	# Section 4: Neutral Forces
	_add_neutral_forces_section()

	# Section 5: Victory Conditions
	_add_victory_conditions_section()

	# Section 6: Defeat Conditions
	_add_defeat_conditions_section()

	# Section 7: Battle Flow & Dialogue
	_add_battle_flow_section()

	# Section 8: Audio (placeholders)
	_add_audio_section()

	# Section 10: Rewards
	_add_rewards_section()

	# Add the button container at the end
	_add_button_container_to_detail_panel()


## Section 1: Basic Information
func _add_basic_info_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Basic Information")

	battle_name_edit = form.add_text_field("Battle Name:", "Enter battle name",
		"Display name shown when battle begins. E.g., 'Battle of Guardiana'.")
	battle_name_edit.max_length = 64

	battle_description_edit = form.add_text_area("Description:", 120,
		"Notes for modders describing the battle scenario, objectives, and story context.")

	form.add_separator()


## Section 2: Map Selection
func _add_map_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Map Configuration")

	map_scene_option = OptionButton.new()
	map_scene_option.item_selected.connect(_on_map_scene_changed)
	map_scene_option.item_selected.connect(func(_idx: int) -> void: _mark_dirty())
	form.add_labeled_control("Map Scene:", map_scene_option,
		"The tilemap scene where combat takes place. Maps are in mods/*/maps/.")

	form.add_help_text("Maps are loaded from mods/*/maps/ directories")

	# Player Spawn Point (custom HBox for X, Y)
	var spawn_hbox: HBoxContainer = HBoxContainer.new()
	player_spawn_x_spin = SpinBox.new()
	player_spawn_x_spin.min_value = 0
	player_spawn_x_spin.max_value = 100
	player_spawn_x_spin.value = 2
	player_spawn_x_spin.tooltip_text = "X coordinate for party formation center."
	player_spawn_x_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	spawn_hbox.add_child(player_spawn_x_spin)

	player_spawn_y_spin = SpinBox.new()
	player_spawn_y_spin.min_value = 0
	player_spawn_y_spin.max_value = 100
	player_spawn_y_spin.value = 2
	player_spawn_y_spin.tooltip_text = "Y coordinate for party formation center."
	player_spawn_y_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	spawn_hbox.add_child(player_spawn_y_spin)

	form.add_labeled_control("Player Spawn (X, Y):", spawn_hbox,
		"Party arranges in formation around this point.")

	form.add_help_text("Party members spawn in formation around this point")
	form.add_separator()


## Section 3: Player Forces
func _add_player_forces_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Player Forces")

	# Use ResourcePicker for cross-mod party selection
	player_party_picker = ResourcePicker.new()
	player_party_picker.resource_type = "party"
	player_party_picker.label_text = "Player Party:"
	player_party_picker.label_min_width = 120
	player_party_picker.none_text = "(Use PartyManager)"
	player_party_picker.allow_none = true
	form.add_labeled_control("", player_party_picker,
		"Override party for this battle. Leave empty to use player's current party.")

	form.add_help_text("If not set, uses PartyManager's current party")
	form.add_separator()


## Section 4: Enemy Forces (collapsible)
func _add_enemy_forces_section() -> void:
	enemies_section = CollapseSection.new()
	enemies_section.title = "Enemy Forces"
	enemies_section.start_collapsed = false
	detail_panel.add_child(enemies_section)

	var help_label: Label = Label.new()
	help_label.text = "Configure enemy units, positions, and AI behaviors"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	enemies_section.add_content_child(help_label)

	# Use DynamicRowList for enemy management
	enemies_list = DynamicRowList.new()
	enemies_list.add_button_text = "Add Enemy"
	enemies_list.add_button_tooltip = "Add a new enemy unit to this battle."
	enemies_list.use_scroll_container = true
	enemies_list.scroll_min_height = 150
	enemies_list.show_row_numbers = true
	enemies_list.row_number_prefix = "Enemy"
	enemies_list.row_factory = _create_enemy_row
	enemies_list.data_extractor = _extract_enemy_data
	enemies_list.data_changed.connect(_on_enemy_data_changed)
	enemies_section.add_content_child(enemies_list)

	SparklingEditorUtils.add_separator(detail_panel)


## Section 4: Neutral Forces (collapsible)
func _add_neutral_forces_section() -> void:
	neutrals_section = CollapseSection.new()
	neutrals_section.title = "Neutral/NPC Forces"
	neutrals_section.start_collapsed = true  # Start collapsed since less commonly used
	detail_panel.add_child(neutrals_section)

	var help_label: Label = Label.new()
	help_label.text = "Configure neutral units (for PROTECT_UNIT objectives)"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	neutrals_section.add_content_child(help_label)

	# Use DynamicRowList for neutral unit management
	neutrals_list = DynamicRowList.new()
	neutrals_list.add_button_text = "Add Neutral Unit"
	neutrals_list.add_button_tooltip = "Add a neutral/NPC unit (for PROTECT_UNIT objectives)."
	neutrals_list.use_scroll_container = true
	neutrals_list.scroll_min_height = 120
	neutrals_list.show_row_numbers = true
	neutrals_list.row_number_prefix = "Neutral"
	neutrals_list.row_factory = _create_neutral_row
	neutrals_list.data_extractor = _extract_neutral_data
	neutrals_list.data_changed.connect(_on_neutral_data_changed)
	neutrals_section.add_content_child(neutrals_list)

	SparklingEditorUtils.add_separator(detail_panel)


## Section 5: Victory Conditions
func _add_victory_conditions_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Victory Conditions")

	victory_condition_option = OptionButton.new()
	victory_condition_option.add_item("Defeat All Enemies", BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES)
	victory_condition_option.add_item("Defeat Boss", BattleData.VictoryCondition.DEFEAT_BOSS)
	victory_condition_option.add_item("Survive Turns", BattleData.VictoryCondition.SURVIVE_TURNS)
	victory_condition_option.add_item("Reach Location", BattleData.VictoryCondition.REACH_LOCATION)
	victory_condition_option.add_item("Protect Unit", BattleData.VictoryCondition.PROTECT_UNIT)
	victory_condition_option.add_item("Custom", BattleData.VictoryCondition.CUSTOM)
	victory_condition_option.item_selected.connect(_on_victory_condition_changed)
	form.add_labeled_control("Victory Condition:", victory_condition_option,
		"How the player wins: kill all, kill boss, survive, reach location, or protect an NPC.")

	# Container for conditional fields (shown/hidden based on selection)
	victory_conditional_container = VBoxContainer.new()
	form.get_container().add_child(victory_conditional_container)

	form.add_separator()


## Section 6: Defeat Conditions
func _add_defeat_conditions_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Defeat Conditions")

	defeat_condition_option = OptionButton.new()
	defeat_condition_option.add_item("All Units Defeated", BattleData.DefeatCondition.ALL_UNITS_DEFEATED)
	defeat_condition_option.add_item("Leader Defeated", BattleData.DefeatCondition.LEADER_DEFEATED)
	defeat_condition_option.add_item("Turn Limit", BattleData.DefeatCondition.TURN_LIMIT)
	defeat_condition_option.add_item("Unit Dies", BattleData.DefeatCondition.UNIT_DIES)
	defeat_condition_option.add_item("Custom", BattleData.DefeatCondition.CUSTOM)
	defeat_condition_option.item_selected.connect(_on_defeat_condition_changed)
	form.add_labeled_control("Defeat Condition:", defeat_condition_option,
		"How the player loses: all dead, hero dead, turn limit exceeded, or protected unit dies.")

	# Container for conditional fields
	defeat_conditional_container = VBoxContainer.new()
	form.get_container().add_child(defeat_conditional_container)

	form.add_separator()


## Section 7: Battle Flow & Dialogue
func _add_battle_flow_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Battle Flow & Dialogue")

	# Use ResourcePicker for cross-mod dialogue selection
	pre_battle_dialogue_picker = ResourcePicker.new()
	pre_battle_dialogue_picker.resource_type = "dialogue"
	pre_battle_dialogue_picker.label_text = "Pre-Battle Dialogue:"
	pre_battle_dialogue_picker.label_min_width = 140
	pre_battle_dialogue_picker.allow_none = true
	pre_battle_dialogue_picker.tooltip_text = "Cutscene that plays before combat begins. Sets up story context."
	form.add_labeled_control("", pre_battle_dialogue_picker)

	victory_dialogue_picker = ResourcePicker.new()
	victory_dialogue_picker.resource_type = "dialogue"
	victory_dialogue_picker.label_text = "Victory Dialogue:"
	victory_dialogue_picker.label_min_width = 140
	victory_dialogue_picker.allow_none = true
	victory_dialogue_picker.tooltip_text = "Cutscene that plays when player wins. Rewards, story progression."
	form.add_labeled_control("", victory_dialogue_picker)

	defeat_dialogue_picker = ResourcePicker.new()
	defeat_dialogue_picker.resource_type = "dialogue"
	defeat_dialogue_picker.label_text = "Defeat Dialogue:"
	defeat_dialogue_picker.label_min_width = 140
	defeat_dialogue_picker.allow_none = true
	defeat_dialogue_picker.tooltip_text = "Cutscene that plays when player loses. Usually offers retry or game over."
	form.add_labeled_control("", defeat_dialogue_picker)

	form.add_help_text("Turn-based dialogues: Coming soon")
	form.add_separator()


## Section 8: Audio
func _add_audio_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Audio")

	# Battle Music dropdown
	music_id_option = OptionButton.new()
	music_id_option.item_selected.connect(func(_idx: int) -> void: _mark_dirty())
	form.add_labeled_control("Battle Music:", music_id_option,
		"Music track to play during battle. Empty uses default based on battle type.")

	# Victory Fanfare dropdown
	victory_music_option = OptionButton.new()
	victory_music_option.item_selected.connect(func(_idx: int) -> void: _mark_dirty())
	form.add_labeled_control("Victory Fanfare:", victory_music_option,
		"Sound effect or short music played when battle is won.")

	# Defeat Jingle dropdown
	defeat_music_option = OptionButton.new()
	defeat_music_option.item_selected.connect(func(_idx: int) -> void: _mark_dirty())
	form.add_labeled_control("Defeat Jingle:", defeat_music_option,
		"Sound effect or short music played when battle is lost.")

	form.add_help_text("Music files are loaded from mods/*/assets/audio/music/. Layers (_layer1, _l2) are automatic.")
	form.add_separator()


## Section 10: Rewards
func _add_rewards_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Rewards")

	experience_reward_spin = form.add_number_field("Experience Reward:", 0, 10000, 0,
		"Bonus XP for completing this battle. Divided among surviving party members.", 10)

	gold_reward_spin = form.add_number_field("Gold Reward:", 0, 10000, 0,
		"Gold received upon victory. Added to party funds.", 10)

	form.add_help_text("Items granted to the player's depot after victory.")

	# Item rewards (collapsible section)
	item_rewards_section = CollapseSection.new()
	item_rewards_section.title = "Item Rewards"
	item_rewards_section.start_collapsed = true
	detail_panel.add_child(item_rewards_section)

	var item_help_label: Label = Label.new()
	item_help_label.text = "Add item rewards that will be granted to the player's depot after victory"
	item_help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	item_rewards_section.add_content_child(item_help_label)

	# Use DynamicRowList for item rewards
	item_rewards_list = DynamicRowList.new()
	item_rewards_list.add_button_text = "Add Item Reward"
	item_rewards_list.add_button_tooltip = "Add an item reward for battle victory."
	item_rewards_list.use_scroll_container = false
	item_rewards_list.row_factory = _create_item_reward_row
	item_rewards_list.data_extractor = _extract_item_reward_data
	item_rewards_list.data_changed.connect(_on_item_reward_data_changed)
	item_rewards_section.add_content_child(item_rewards_list)

	form.add_separator()


## Called when map scene selection changes (placeholder for future map preview)
func _on_map_scene_changed(_index: int) -> void:
	pass


## =============================================================================
## UNIT ROW - Shared Factory/Extractor for Enemy and Neutral Units
## =============================================================================

## Shared row factory for enemy and neutral units (they have identical structure)
## @param data: Dictionary with character, position, ai_behavior
## @param row: HBoxContainer to populate
## @param character_tooltip: Tooltip for the character picker
## @param ai_tooltip: Tooltip for the AI dropdown
func _create_unit_row(data: Dictionary, row: HBoxContainer, character_tooltip: String, ai_tooltip: String) -> void:
	var character: CharacterData = data.get("character") as CharacterData
	var position: Vector2i = data.get("position", Vector2i.ZERO)
	var ai_behavior: AIBehaviorData = data.get("ai_behavior") as AIBehaviorData

	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(content_vbox)

	# Character picker
	var character_picker: ResourcePicker = ResourcePicker.new()
	character_picker.name = "CharacterPicker"
	character_picker.resource_type = "character"
	character_picker.label_text = "Character:"
	character_picker.label_min_width = 80
	character_picker.allow_none = true
	character_picker.tooltip_text = character_tooltip
	content_vbox.add_child(character_picker)

	# Position row
	var pos_hbox: HBoxContainer = HBoxContainer.new()
	pos_hbox.add_theme_constant_override("separation", 4)
	content_vbox.add_child(pos_hbox)

	var pos_label: Label = Label.new()
	pos_label.text = "Position:"
	pos_label.custom_minimum_size.x = 80
	pos_hbox.add_child(pos_label)

	var pos_x_spin: SpinBox = SpinBox.new()
	pos_x_spin.name = "PosXSpin"
	pos_x_spin.min_value = 0
	pos_x_spin.max_value = 100
	pos_x_spin.value = position.x
	pos_x_spin.custom_minimum_size.x = 60
	pos_x_spin.tooltip_text = "X coordinate on battle map"
	pos_hbox.add_child(pos_x_spin)

	var pos_y_spin: SpinBox = SpinBox.new()
	pos_y_spin.name = "PosYSpin"
	pos_y_spin.min_value = 0
	pos_y_spin.max_value = 100
	pos_y_spin.value = position.y
	pos_y_spin.custom_minimum_size.x = 60
	pos_y_spin.tooltip_text = "Y coordinate on battle map"
	pos_hbox.add_child(pos_y_spin)

	# AI Behavior row
	var ai_hbox: HBoxContainer = HBoxContainer.new()
	ai_hbox.add_theme_constant_override("separation", 4)
	content_vbox.add_child(ai_hbox)

	var ai_label: Label = Label.new()
	ai_label.text = "AI:"
	ai_label.custom_minimum_size.x = 80
	ai_hbox.add_child(ai_label)

	var ai_option: OptionButton = OptionButton.new()
	ai_option.name = "AIOption"
	ai_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_option.tooltip_text = ai_tooltip
	ai_hbox.add_child(ai_option)

	# Populate AI dropdown and set values (deferred to ensure picker is ready)
	_update_ai_dropdown(ai_option)
	if character:
		character_picker.call_deferred("select_resource", character)
	if ai_behavior:
		call_deferred("_select_ai_in_dropdown", ai_option, ai_behavior)


## Shared data extractor for enemy and neutral rows (identical structure)
func _extract_unit_data(row: HBoxContainer) -> Dictionary:
	var content_vbox: VBoxContainer = row.get_node_or_null("ContentVBox") as VBoxContainer
	if not content_vbox:
		return {}

	var character_picker: ResourcePicker = content_vbox.get_node_or_null("CharacterPicker") as ResourcePicker

	# Find spinboxes and AI option by searching through nested HBoxContainers
	var pos_x_spin: SpinBox = null
	var pos_y_spin: SpinBox = null
	var ai_option: OptionButton = null

	for child: Node in content_vbox.get_children():
		if child is HBoxContainer:
			for subchild: Node in child.get_children():
				if subchild.name == "PosXSpin":
					pos_x_spin = subchild as SpinBox
				elif subchild.name == "PosYSpin":
					pos_y_spin = subchild as SpinBox
				elif subchild.name == "AIOption":
					ai_option = subchild as OptionButton

	var character: CharacterData = character_picker.get_selected_resource() as CharacterData if character_picker else null
	var ai_behavior: AIBehaviorData = null
	if ai_option and ai_option.selected > 0:
		ai_behavior = ai_option.get_item_metadata(ai_option.selected) as AIBehaviorData

	return {
		"character": character,
		"position": Vector2i(int(pos_x_spin.value) if pos_x_spin else 0, int(pos_y_spin.value) if pos_y_spin else 0),
		"ai_behavior": ai_behavior
	}


## Row factory for enemies - delegates to shared unit row factory
func _create_enemy_row(data: Dictionary, row: HBoxContainer) -> void:
	_create_unit_row(data, row,
		"The CharacterData template for this enemy unit. Defines stats, class, appearance.",
		"AI brain controlling this enemy. Aggressive rushes, Cautious holds position, Support heals allies.")


## Data extractor for enemies - delegates to shared extractor
func _extract_enemy_data(row: HBoxContainer) -> Dictionary:
	return _extract_unit_data(row)


## Called when enemy data changes via DynamicRowList
func _on_enemy_data_changed() -> void:
	if not _updating_ui:
		_mark_dirty()


## Row factory for neutrals - delegates to shared unit row factory
func _create_neutral_row(data: Dictionary, row: HBoxContainer) -> void:
	_create_unit_row(data, row,
		"The CharacterData template for this neutral unit. Usually an NPC to protect or escort.",
		"AI brain for neutral units. Defensive stays in place, Support heals nearby allies.")


## Data extractor for neutrals - delegates to shared extractor
func _extract_neutral_data(row: HBoxContainer) -> Dictionary:
	return _extract_unit_data(row)


## Called when neutral data changes via DynamicRowList
func _on_neutral_data_changed() -> void:
	if not _updating_ui:
		_mark_dirty()


## Update an audio dropdown with tracks from MusicDiscovery
## @param option: OptionButton to populate
## @param is_music: true for music tracks, false for SFX
func _update_audio_dropdown(option: OptionButton, is_music: bool) -> void:
	option.clear()
	option.add_item("(Use Default)", -1)

	var tracks: Array[Dictionary] = MusicDiscovery.get_available_music_with_labels() if is_music else MusicDiscovery.get_available_sfx_with_labels()
	for i: int in range(tracks.size()):
		var track: Dictionary = tracks[i]
		option.add_item("[%s] %s" % [track.mod, track.display_name])
		option.set_item_metadata(i + 1, track.id)


## Convenience wrapper for music dropdowns
func _update_music_dropdown(option: OptionButton) -> void:
	_update_audio_dropdown(option, true)


## Convenience wrapper for SFX dropdowns
func _update_sfx_dropdown(option: OptionButton) -> void:
	_update_audio_dropdown(option, false)


## Select a music/sfx track in dropdown by ID
func _select_audio_in_dropdown(option: OptionButton, audio_id: String) -> void:
	if audio_id.is_empty():
		option.selected = 0
		return

	for i: int in range(option.item_count):
		var metadata: Variant = option.get_item_metadata(i)
		if metadata == audio_id:
			option.selected = i
			return

	# ID not found - might be custom, add it
	var item_index: int = option.item_count
	option.add_item("[custom] %s" % audio_id, item_index - 1)
	option.set_item_metadata(item_index, audio_id)
	option.selected = item_index


## Get selected audio ID from dropdown (empty string if default selected)
func _get_selected_audio_id(option: OptionButton) -> String:
	var index: int = option.selected
	if index <= 0:
		return ""
	var metadata: Variant = option.get_item_metadata(index)
	return metadata if metadata is String else ""


## Update AI dropdown with available AI behaviors - queries registry directly
func _update_ai_dropdown(option: OptionButton) -> void:
	option.clear()
	option.add_item("(None)", -1)

	# Query registry fresh each time - no local cache
	if ModLoader and ModLoader.registry:
		var behaviors: Array[Resource] = ModLoader.registry.get_all_resources("ai_behavior")
		var index: int = 0
		for ai_behavior: AIBehaviorData in behaviors:
			if ai_behavior:
				var behavior_id: String = ai_behavior.behavior_id if not ai_behavior.behavior_id.is_empty() else ai_behavior.resource_path.get_file().get_basename()
				var display_name: String = ai_behavior.display_name if ai_behavior.display_name else behavior_id.capitalize()
				var label: String = SparklingEditorUtils.get_display_with_mod_by_id("ai_behavior", behavior_id, display_name)
				option.add_item(label, index)
				option.set_item_metadata(index + 1, ai_behavior)
				index += 1


## Select an AI behavior in the dropdown
func _select_ai_in_dropdown(option: OptionButton, ai_behavior: AIBehaviorData) -> void:
	if not ai_behavior:
		option.selected = 0
		return

	for i in range(option.item_count):
		var metadata: Variant = option.get_item_metadata(i)
		if metadata and metadata is AIBehaviorData:
			# Match by resource path for reliable comparison
			if metadata.resource_path == ai_behavior.resource_path:
				option.selected = i
				return


## Update map dropdown with available map scenes from mod directories
func _update_map_dropdown() -> void:
	map_scene_option.clear()
	map_scene_option.add_item("(No map selected)", -1)

	# Scan all mod directories for maps
	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		push_warning("Battle Editor: Could not open mods directory")
		return

	var index: int = 0
	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var maps_path: String = "res://mods/%s/maps/" % mod_name
			var maps_dir: DirAccess = DirAccess.open(maps_path)

			if maps_dir:
				_scan_maps_directory(maps_dir, maps_path, mod_name, index)
				index = map_scene_option.item_count - 1  # Update index based on items added

		mod_name = mods_dir.get_next()
	mods_dir.list_dir_end()


## Recursively scan a maps directory for .tscn files
func _scan_maps_directory(dir: DirAccess, base_path: String, mod_name: String, start_index: int) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recurse into subdirectories
			var sub_path: String = base_path.path_join(file_name)
			var sub_dir: DirAccess = DirAccess.open(sub_path)
			if sub_dir:
				_scan_maps_directory(sub_dir, sub_path, mod_name, start_index)
		elif file_name.ends_with(".tscn"):
			var full_path: String = base_path.path_join(file_name)
			var map_scene: PackedScene = load(full_path)
			if map_scene:
				# Display as "mod_name: filename"
				var display_name: String = "[%s] %s" % [mod_name, file_name]
				map_scene_option.add_item(display_name)
				var item_index: int = map_scene_option.item_count - 1
				map_scene_option.set_item_metadata(item_index, full_path)

		file_name = dir.get_next()
	dir.list_dir_end()


## Select a map in the dropdown by PackedScene
func _select_map_in_dropdown(map_scene: PackedScene) -> void:
	if not map_scene:
		map_scene_option.selected = 0
		return

	var target_path: String = map_scene.resource_path
	for i in range(map_scene_option.item_count):
		var metadata: Variant = map_scene_option.get_item_metadata(i)
		if metadata == target_path:
			map_scene_option.selected = i
			return

	# Map not found in dropdown - might be from a path not in maps/
	# Add it as a custom entry
	var display_name: String = "[custom] %s" % target_path.get_file()
	var item_index: int = map_scene_option.item_count
	map_scene_option.add_item(display_name, item_index - 1)
	map_scene_option.set_item_metadata(item_index, target_path)
	map_scene_option.selected = item_index


## Victory condition changed - update conditional UI
func _on_victory_condition_changed(index: int) -> void:
	# Clear conditional container
	for child: Node in victory_conditional_container.get_children():
		victory_conditional_container.remove_child(child)
		child.queue_free()

	var condition: BattleData.VictoryCondition = victory_condition_option.get_item_id(index)

	match condition:
		BattleData.VictoryCondition.DEFEAT_BOSS:
			var label: Label = Label.new()
			label.text = "Boss Enemy Index (0-based):"
			victory_conditional_container.add_child(label)

			victory_boss_index_spin = SpinBox.new()
			victory_boss_index_spin.min_value = -1
			victory_boss_index_spin.max_value = 99
			victory_boss_index_spin.value = -1
			victory_conditional_container.add_child(victory_boss_index_spin)

		BattleData.VictoryCondition.SURVIVE_TURNS:
			var label: Label = Label.new()
			label.text = "Number of Turns:"
			victory_conditional_container.add_child(label)

			victory_turn_count_spin = SpinBox.new()
			victory_turn_count_spin.min_value = 1
			victory_turn_count_spin.max_value = 99
			victory_conditional_container.add_child(victory_turn_count_spin)

		BattleData.VictoryCondition.REACH_LOCATION:
			var label: Label = Label.new()
			label.text = "Target Position (X, Y):"
			victory_conditional_container.add_child(label)

			var hbox: HBoxContainer = HBoxContainer.new()
			victory_target_x_spin = SpinBox.new()
			victory_target_x_spin.min_value = 0
			victory_target_x_spin.max_value = 100
			hbox.add_child(victory_target_x_spin)

			victory_target_y_spin = SpinBox.new()
			victory_target_y_spin.min_value = 0
			victory_target_y_spin.max_value = 100
			hbox.add_child(victory_target_y_spin)
			victory_conditional_container.add_child(hbox)

		BattleData.VictoryCondition.PROTECT_UNIT:
			var label: Label = Label.new()
			label.text = "Neutral Unit Index (0-based):"
			victory_conditional_container.add_child(label)

			victory_protect_index_spin = SpinBox.new()
			victory_protect_index_spin.min_value = -1
			victory_protect_index_spin.max_value = 99
			victory_protect_index_spin.value = -1
			victory_conditional_container.add_child(victory_protect_index_spin)

		BattleData.VictoryCondition.CUSTOM:
			var label: Label = Label.new()
			label.text = "Custom victory scripts: Coming soon"
			label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			label.add_theme_font_size_override("font_size", 12)
			victory_conditional_container.add_child(label)


## Defeat condition changed - update conditional UI
func _on_defeat_condition_changed(index: int) -> void:
	# Clear conditional container
	for child: Node in defeat_conditional_container.get_children():
		defeat_conditional_container.remove_child(child)
		child.queue_free()

	var condition: BattleData.DefeatCondition = defeat_condition_option.get_item_id(index)

	match condition:
		BattleData.DefeatCondition.TURN_LIMIT:
			var label: Label = Label.new()
			label.text = "Turn Limit:"
			defeat_conditional_container.add_child(label)

			defeat_turn_limit_spin = SpinBox.new()
			defeat_turn_limit_spin.min_value = 1
			defeat_turn_limit_spin.max_value = 99
			defeat_conditional_container.add_child(defeat_turn_limit_spin)

		BattleData.DefeatCondition.UNIT_DIES:
			var label: Label = Label.new()
			label.text = "Neutral Unit Index (0-based):"
			defeat_conditional_container.add_child(label)

			defeat_protect_index_spin = SpinBox.new()
			defeat_protect_index_spin.min_value = -1
			defeat_protect_index_spin.max_value = 99
			defeat_protect_index_spin.value = -1
			defeat_conditional_container.add_child(defeat_protect_index_spin)

		BattleData.DefeatCondition.CUSTOM:
			var label: Label = Label.new()
			label.text = "Custom defeat scripts: Coming soon"
			label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			label.add_theme_font_size_override("font_size", 12)
			defeat_conditional_container.add_child(label)


## Override: Load battle data from resource into UI
func _load_resource_data() -> void:
	var battle: BattleData = current_resource as BattleData
	if not battle:
		return

	_updating_ui = true

	# Basic info
	battle_name_edit.text = battle.battle_name
	battle_description_edit.text = battle.battle_description

	# Map scene
	_update_map_dropdown()
	_select_map_in_dropdown(battle.map_scene)

	# Player spawn point
	player_spawn_x_spin.value = battle.player_spawn_point.x
	player_spawn_y_spin.value = battle.player_spawn_point.y

	# Player party - use ResourcePicker
	if battle.player_party:
		player_party_picker.select_resource(battle.player_party)
	else:
		player_party_picker.select_none()

	# Load enemies into DynamicRowList
	enemies_list.load_data(battle.enemies)

	# Load neutrals into DynamicRowList
	neutrals_list.load_data(battle.neutrals)

	# Victory condition
	victory_condition_option.selected = battle.victory_condition
	_on_victory_condition_changed(battle.victory_condition)

	# Set victory conditional values
	match battle.victory_condition:
		BattleData.VictoryCondition.DEFEAT_BOSS:
			if victory_boss_index_spin:
				victory_boss_index_spin.value = battle.victory_boss_index
		BattleData.VictoryCondition.SURVIVE_TURNS:
			if victory_turn_count_spin:
				victory_turn_count_spin.value = battle.victory_turn_count
		BattleData.VictoryCondition.REACH_LOCATION:
			if victory_target_x_spin and victory_target_y_spin:
				victory_target_x_spin.value = battle.victory_target_position.x
				victory_target_y_spin.value = battle.victory_target_position.y
		BattleData.VictoryCondition.PROTECT_UNIT:
			if victory_protect_index_spin:
				victory_protect_index_spin.value = battle.victory_protect_index

	# Defeat condition
	defeat_condition_option.selected = battle.defeat_condition
	_on_defeat_condition_changed(battle.defeat_condition)

	# Set defeat conditional values
	match battle.defeat_condition:
		BattleData.DefeatCondition.TURN_LIMIT:
			if defeat_turn_limit_spin:
				defeat_turn_limit_spin.value = battle.defeat_turn_limit
		BattleData.DefeatCondition.UNIT_DIES:
			if defeat_protect_index_spin:
				defeat_protect_index_spin.value = battle.defeat_protect_index

	# Dialogues - use ResourcePickers
	if battle.pre_battle_dialogue:
		pre_battle_dialogue_picker.select_resource(battle.pre_battle_dialogue)
	else:
		pre_battle_dialogue_picker.select_none()

	if battle.victory_dialogue:
		victory_dialogue_picker.select_resource(battle.victory_dialogue)
	else:
		victory_dialogue_picker.select_none()

	if battle.defeat_dialogue:
		defeat_dialogue_picker.select_resource(battle.defeat_dialogue)
	else:
		defeat_dialogue_picker.select_none()

	# Audio settings
	_update_music_dropdown(music_id_option)
	_update_sfx_dropdown(victory_music_option)
	_update_sfx_dropdown(defeat_music_option)
	_select_audio_in_dropdown(music_id_option, battle.music_id)
	_select_audio_in_dropdown(victory_music_option, battle.victory_music_id)
	_select_audio_in_dropdown(defeat_music_option, battle.defeat_music_id)

	# Rewards
	experience_reward_spin.value = battle.experience_reward
	gold_reward_spin.value = battle.gold_reward

	# Load item rewards (convert from ItemData array to DynamicRowList format)
	_load_item_rewards_from_array(battle.item_rewards)

	_updating_ui = false




## =============================================================================
## ITEM REWARDS - DynamicRowList Factory/Extractor Pattern
## =============================================================================

## Row factory for item rewards - creates the UI for an item reward row
func _create_item_reward_row(data: Dictionary, row: HBoxContainer) -> void:
	var item: ItemData = data.get("item") as ItemData
	var quantity: int = data.get("quantity", 1)

	# Item picker - use ResourcePicker for cross-mod support
	var item_picker: ResourcePicker = ResourcePicker.new()
	item_picker.name = "ItemPicker"
	item_picker.resource_type = "item"
	item_picker.allow_none = true
	item_picker.none_text = "(Select Item)"
	item_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(item_picker)

	# Quantity label and spinner
	var qty_label: Label = Label.new()
	qty_label.text = "x"
	row.add_child(qty_label)

	var qty_spin: SpinBox = SpinBox.new()
	qty_spin.name = "QuantitySpin"
	qty_spin.min_value = 1
	qty_spin.max_value = 99
	qty_spin.value = quantity
	qty_spin.custom_minimum_size.x = 60
	qty_spin.tooltip_text = "Quantity of this item to grant"
	row.add_child(qty_spin)

	# Set item if provided (deferred to ensure picker is ready)
	if item:
		item_picker.call_deferred("select_resource", item)


## Data extractor for item rewards - extracts data from an item reward row
func _extract_item_reward_data(row: HBoxContainer) -> Dictionary:
	var item_picker: ResourcePicker = row.get_node_or_null("ItemPicker") as ResourcePicker
	var qty_spin: SpinBox = row.get_node_or_null("QuantitySpin") as SpinBox

	if not item_picker:
		return {}

	var item: ItemData = item_picker.get_selected_resource() as ItemData
	if not item:
		return {}  # Skip rows with no item selected

	return {
		"item": item,
		"quantity": int(qty_spin.value) if qty_spin else 1
	}


## Called when item reward data changes via DynamicRowList
func _on_item_reward_data_changed() -> void:
	if not _updating_ui:
		_mark_dirty()


## Load item rewards from ItemData array
## BattleData stores quantity via duplicates, so we count them and consolidate
func _load_item_rewards_from_array(items: Array[ItemData]) -> void:
	# Count duplicates by resource path to consolidate quantity
	var item_counts: Dictionary = {}  # resource_path -> {item: ItemData, count: int}
	for item: ItemData in items:
		if item:
			var path: String = item.resource_path
			if path in item_counts:
				item_counts[path].count += 1
			else:
				item_counts[path] = {item = item, count = 1}

	# Build data array for DynamicRowList
	var reward_data: Array[Dictionary] = []
	for path: String in item_counts.keys():
		var entry: Dictionary = item_counts[path]
		reward_data.append({
			"item": entry.item,
			"quantity": entry.count
		})

	# Load into DynamicRowList
	item_rewards_list.load_data(reward_data)


## Collect item rewards as ItemData array (for BattleData)
func _collect_item_rewards_as_itemdata() -> Array[ItemData]:
	var result: Array[ItemData] = []
	var all_data: Array[Dictionary] = item_rewards_list.get_all_data()
	for entry: Dictionary in all_data:
		var item: ItemData = entry.get("item") as ItemData
		if item:
			# BattleData stores ItemData directly with quantity managed by duplicates
			var quantity: int = entry.get("quantity", 1)
			for i: int in range(quantity):
				result.append(item)
	return result


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var battle: BattleData = current_resource as BattleData
	if not battle:
		return

	# Basic info
	battle.battle_name = battle_name_edit.text
	battle.battle_description = battle_description_edit.text

	# Map scene
	var map_index: int = map_scene_option.selected
	if map_index > 0:
		var map_path: String = map_scene_option.get_item_metadata(map_index)
		if map_path:
			battle.map_scene = load(map_path)
	else:
		battle.map_scene = null

	# Player spawn point
	battle.player_spawn_point = Vector2i(int(player_spawn_x_spin.value), int(player_spawn_y_spin.value))

	# Player party - use ResourcePicker
	battle.player_party = player_party_picker.get_selected_resource() as PartyData

	# Enemies and neutrals - collect directly from DynamicRowList
	battle.enemies = enemies_list.get_all_data()
	battle.neutrals = neutrals_list.get_all_data()

	# Victory condition
	battle.victory_condition = victory_condition_option.get_item_id(victory_condition_option.selected)
	match battle.victory_condition:
		BattleData.VictoryCondition.DEFEAT_BOSS:
			if victory_boss_index_spin:
				battle.victory_boss_index = int(victory_boss_index_spin.value)
		BattleData.VictoryCondition.SURVIVE_TURNS:
			if victory_turn_count_spin:
				battle.victory_turn_count = int(victory_turn_count_spin.value)
		BattleData.VictoryCondition.REACH_LOCATION:
			if victory_target_x_spin and victory_target_y_spin:
				battle.victory_target_position = Vector2i(int(victory_target_x_spin.value), int(victory_target_y_spin.value))
		BattleData.VictoryCondition.PROTECT_UNIT:
			if victory_protect_index_spin:
				battle.victory_protect_index = int(victory_protect_index_spin.value)

	# Defeat condition
	battle.defeat_condition = defeat_condition_option.get_item_id(defeat_condition_option.selected)
	match battle.defeat_condition:
		BattleData.DefeatCondition.TURN_LIMIT:
			if defeat_turn_limit_spin:
				battle.defeat_turn_limit = int(defeat_turn_limit_spin.value)
		BattleData.DefeatCondition.UNIT_DIES:
			if defeat_protect_index_spin:
				battle.defeat_protect_index = int(defeat_protect_index_spin.value)

	# Dialogues - use ResourcePickers
	battle.pre_battle_dialogue = pre_battle_dialogue_picker.get_selected_resource() as DialogueData
	battle.victory_dialogue = victory_dialogue_picker.get_selected_resource() as DialogueData
	battle.defeat_dialogue = defeat_dialogue_picker.get_selected_resource() as DialogueData

	# Audio settings
	battle.music_id = _get_selected_audio_id(music_id_option)
	battle.victory_music_id = _get_selected_audio_id(victory_music_option)
	battle.defeat_music_id = _get_selected_audio_id(defeat_music_option)

	# Rewards
	battle.experience_reward = int(experience_reward_spin.value)
	battle.gold_reward = int(gold_reward_spin.value)

	# Item rewards (convert from our UI format to ItemData array)
	battle.item_rewards = _collect_item_rewards_as_itemdata()


## Override: Validate resource before saving
## Reads directly from UI state - does NOT call _save_resource_data() first
func _validate_resource() -> Dictionary:
	var battle: BattleData = current_resource as BattleData
	if not battle:
		return {"valid": false, "errors": ["Invalid resource type"]}

	# Collect validation errors from UI state directly
	var errors: Array[String] = _collect_battle_validation_errors_from_ui()
	if not errors.is_empty():
		return {"valid": false, "errors": errors}

	return {"valid": true, "errors": []}


## Validate unit data entries (shared for enemies and neutrals)
func _validate_unit_entries(unit_data: Array[Dictionary], unit_type: String) -> Array[String]:
	var errors: Array[String] = []
	for i: int in range(unit_data.size()):
		var entry: Dictionary = unit_data[i]
		if entry.get("character") == null:
			errors.append("%s %d: Missing character" % [unit_type, i + 1])
		if entry.get("ai_behavior") == null:
			errors.append("%s %d: Missing AI behavior" % [unit_type, i + 1])
	return errors


## Collect validation error messages by reading directly from UI controls
func _collect_battle_validation_errors_from_ui() -> Array[String]:
	var errors: Array[String] = []

	# Basic validation
	if battle_name_edit.text.strip_edges().is_empty():
		errors.append("Battle name is required")

	if map_scene_option.selected <= 0:
		errors.append("Map scene is required")

	# Unit validation
	var enemy_data: Array[Dictionary] = enemies_list.get_all_data()
	var neutral_data: Array[Dictionary] = neutrals_list.get_all_data()
	errors.append_array(_validate_unit_entries(enemy_data, "Enemy"))
	errors.append_array(_validate_unit_entries(neutral_data, "Neutral"))

	# Victory condition validation
	var victory_condition: BattleData.VictoryCondition = victory_condition_option.get_item_id(victory_condition_option.selected)
	var enemy_count: int = enemy_data.size()
	var neutral_count: int = neutral_data.size()

	match victory_condition:
		BattleData.VictoryCondition.DEFEAT_BOSS:
			var boss_index: int = int(victory_boss_index_spin.value) if victory_boss_index_spin else -1
			if boss_index < 0 or boss_index >= enemy_count:
				errors.append("Victory condition: Invalid boss index %d (have %d enemies)" % [boss_index, enemy_count])
		BattleData.VictoryCondition.SURVIVE_TURNS:
			var turn_count: int = int(victory_turn_count_spin.value) if victory_turn_count_spin else 0
			if turn_count <= 0:
				errors.append("Victory condition: Turn count must be greater than 0")
		BattleData.VictoryCondition.PROTECT_UNIT:
			var protect_index: int = int(victory_protect_index_spin.value) if victory_protect_index_spin else -1
			if protect_index < 0 or protect_index >= neutral_count:
				errors.append("Victory condition: Invalid protect unit index %d (have %d neutrals)" % [protect_index, neutral_count])

	# Defeat condition validation
	var defeat_condition: BattleData.DefeatCondition = defeat_condition_option.get_item_id(defeat_condition_option.selected)

	match defeat_condition:
		BattleData.DefeatCondition.TURN_LIMIT:
			var turn_limit: int = int(defeat_turn_limit_spin.value) if defeat_turn_limit_spin else 0
			if turn_limit <= 0:
				errors.append("Defeat condition: Turn limit must be greater than 0")
		BattleData.DefeatCondition.UNIT_DIES:
			var protect_index: int = int(defeat_protect_index_spin.value) if defeat_protect_index_spin else -1
			if protect_index < 0 or protect_index >= neutral_count:
				errors.append("Defeat condition: Invalid protect unit index %d (have %d neutrals)" % [protect_index, neutral_count])

	return errors


## Override: Check for references before deletion
func _check_resource_references(resource_to_check: Resource) -> Array[String]:
	# Battles are top-level scenarios, nothing references them
	return []


## Override: Create a new resource with defaults
func _create_new_resource() -> Resource:
	var battle: BattleData = BattleData.new()
	battle.battle_name = "New Battle"
	battle.battle_description = "Enter battle description"
	battle.victory_condition = BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES
	battle.defeat_condition = BattleData.DefeatCondition.LEADER_DEFEATED
	return battle


## Override: Get the display name from a resource
func _get_resource_display_name(resource: Resource) -> String:
	var battle: BattleData = resource as BattleData
	if battle:
		return battle.battle_name
	return "Unnamed Battle"
