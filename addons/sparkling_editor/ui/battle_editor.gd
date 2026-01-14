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
var enemies_container: VBoxContainer
var enemies_list: Array[Dictionary] = []  # Track enemy UI elements

# Neutral Forces (collapsible)
var neutrals_section: CollapseSection
var neutrals_container: VBoxContainer
var neutrals_list: Array[Dictionary] = []  # Track neutral UI elements

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

# Rewards
var experience_reward_spin: SpinBox
var gold_reward_spin: SpinBox

# Item rewards
var item_rewards_section: CollapseSection
var item_rewards_container: VBoxContainer
var item_rewards_list: Array[Dictionary] = []  # Track item reward UI elements

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
	form.add_section("Map Configuration")

	map_scene_option = OptionButton.new()
	map_scene_option.item_selected.connect(_on_map_scene_changed)
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
	spawn_hbox.add_child(player_spawn_x_spin)

	player_spawn_y_spin = SpinBox.new()
	player_spawn_y_spin.min_value = 0
	player_spawn_y_spin.max_value = 100
	player_spawn_y_spin.value = 2
	player_spawn_y_spin.tooltip_text = "Y coordinate for party formation center."
	spawn_hbox.add_child(player_spawn_y_spin)

	form.add_labeled_control("Player Spawn (X, Y):", spawn_hbox,
		"Party arranges in formation around this point.")

	form.add_help_text("Party members spawn in formation around this point")
	form.add_separator()


## Section 3: Player Forces
func _add_player_forces_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
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

	enemies_container = VBoxContainer.new()
	enemies_section.add_content_child(enemies_container)

	var add_enemy_button: Button = Button.new()
	add_enemy_button.text = "Add Enemy"
	add_enemy_button.pressed.connect(_on_add_enemy)
	enemies_section.add_content_child(add_enemy_button)

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

	neutrals_container = VBoxContainer.new()
	neutrals_section.add_content_child(neutrals_container)

	var add_neutral_button: Button = Button.new()
	add_neutral_button.text = "Add Neutral Unit"
	add_neutral_button.pressed.connect(_on_add_neutral)
	neutrals_section.add_content_child(add_neutral_button)

	SparklingEditorUtils.add_separator(detail_panel)


## Section 5: Victory Conditions
func _add_victory_conditions_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Victory Conditions"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	detail_panel.add_child(section_label)

	var condition_label: Label = Label.new()
	condition_label.text = "Victory Condition:"
	detail_panel.add_child(condition_label)

	victory_condition_option = OptionButton.new()
	victory_condition_option.tooltip_text = "How the player wins: kill all, kill boss, survive, reach location, or protect an NPC."
	victory_condition_option.add_item("Defeat All Enemies", BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES)
	victory_condition_option.add_item("Defeat Boss", BattleData.VictoryCondition.DEFEAT_BOSS)
	victory_condition_option.add_item("Survive Turns", BattleData.VictoryCondition.SURVIVE_TURNS)
	victory_condition_option.add_item("Reach Location", BattleData.VictoryCondition.REACH_LOCATION)
	victory_condition_option.add_item("Protect Unit", BattleData.VictoryCondition.PROTECT_UNIT)
	victory_condition_option.add_item("Custom", BattleData.VictoryCondition.CUSTOM)
	victory_condition_option.item_selected.connect(_on_victory_condition_changed)
	detail_panel.add_child(victory_condition_option)

	# Container for conditional fields (shown/hidden based on selection)
	victory_conditional_container = VBoxContainer.new()
	detail_panel.add_child(victory_conditional_container)

	SparklingEditorUtils.add_separator(detail_panel)


## Section 6: Defeat Conditions
func _add_defeat_conditions_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Defeat Conditions"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	detail_panel.add_child(section_label)

	var condition_label: Label = Label.new()
	condition_label.text = "Defeat Condition:"
	detail_panel.add_child(condition_label)

	defeat_condition_option = OptionButton.new()
	defeat_condition_option.tooltip_text = "How the player loses: all dead, hero dead, turn limit exceeded, or protected unit dies."
	defeat_condition_option.add_item("All Units Defeated", BattleData.DefeatCondition.ALL_UNITS_DEFEATED)
	defeat_condition_option.add_item("Leader Defeated", BattleData.DefeatCondition.LEADER_DEFEATED)
	defeat_condition_option.add_item("Turn Limit", BattleData.DefeatCondition.TURN_LIMIT)
	defeat_condition_option.add_item("Unit Dies", BattleData.DefeatCondition.UNIT_DIES)
	defeat_condition_option.add_item("Custom", BattleData.DefeatCondition.CUSTOM)
	defeat_condition_option.item_selected.connect(_on_defeat_condition_changed)
	detail_panel.add_child(defeat_condition_option)

	# Container for conditional fields
	defeat_conditional_container = VBoxContainer.new()
	detail_panel.add_child(defeat_conditional_container)

	SparklingEditorUtils.add_separator(detail_panel)


## Section 7: Battle Flow & Dialogue
func _add_battle_flow_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
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


## Section 8: Audio (Placeholders)
func _add_audio_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Audio")
	form.add_help_text("Audio settings (BGM, Victory, Defeat music): Coming soon")
	form.add_separator()


## Section 10: Rewards
func _add_rewards_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Rewards")

	experience_reward_spin = form.add_number_field("Experience Reward:", 0, 10000, 0,
		"Bonus XP for completing this battle. Divided among surviving party members.", 10)

	gold_reward_spin = form.add_number_field("Gold Reward:", 0, 10000, 0,
		"Gold received upon victory. Added to party funds.", 10)

	form.add_help_text("Items granted to the player's depot after victory. Use Add Item button to add rewards.")

	# Item rewards (collapsible section)
	item_rewards_section = CollapseSection.new()
	item_rewards_section.title = "Item Rewards"
	item_rewards_section.start_collapsed = true
	detail_panel.add_child(item_rewards_section)

	var item_help_label: Label = Label.new()
	item_help_label.text = "Add item rewards that will be granted to the player's depot after victory"
	item_help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	item_rewards_section.add_content_child(item_help_label)

	item_rewards_container = VBoxContainer.new()
	item_rewards_container.add_theme_constant_override("separation", 4)
	item_rewards_section.add_content_child(item_rewards_container)

	var add_item_button: Button = Button.new()
	add_item_button.text = "Add Item Reward"
	add_item_button.pressed.connect(_on_add_item_reward)
	item_rewards_section.add_content_child(add_item_button)

	form.add_separator()


## Called when map scene selection changes
func _on_map_scene_changed(_index: int) -> void:
	# Map preview removed - coordinates are entered manually
	pass


## Add enemy UI element
func _on_add_enemy() -> void:
	_add_enemy_ui({})


func _add_enemy_ui(enemy_dict: Dictionary) -> void:
	var enemy_index: int = enemies_list.size()
	var enemy_panel: PanelContainer = PanelContainer.new()
	var enemy_vbox: VBoxContainer = VBoxContainer.new()
	enemy_panel.add_child(enemy_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	var enemy_title: Label = Label.new()
	enemy_title.text = "Enemy #%d" % (enemy_index + 1)
	enemy_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(enemy_title)

	var remove_button: Button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_enemy.bind(enemy_panel))
	header_hbox.add_child(remove_button)
	enemy_vbox.add_child(header_hbox)

	# Character picker - uses ResourcePicker for cross-mod support
	var character_picker: ResourcePicker = ResourcePicker.new()
	character_picker.resource_type = "character"
	character_picker.label_text = "Character:"
	character_picker.label_min_width = 80
	character_picker.allow_none = true
	character_picker.tooltip_text = "The CharacterData template for this enemy unit. Defines stats, class, appearance."
	enemy_vbox.add_child(character_picker)

	# Position with Place button
	var pos_label: Label = Label.new()
	pos_label.text = "Position (X, Y):"
	enemy_vbox.add_child(pos_label)

	var pos_hbox: HBoxContainer = HBoxContainer.new()
	var pos_x_spin: SpinBox = SpinBox.new()
	pos_x_spin.min_value = 0
	pos_x_spin.max_value = 100
	pos_x_spin.value_changed.connect(_on_enemy_position_changed.bind(enemy_index))
	pos_hbox.add_child(pos_x_spin)

	var pos_y_spin: SpinBox = SpinBox.new()
	pos_y_spin.min_value = 0
	pos_y_spin.max_value = 100
	pos_y_spin.value_changed.connect(_on_enemy_position_changed.bind(enemy_index))
	pos_hbox.add_child(pos_y_spin)

	enemy_vbox.add_child(pos_hbox)

	# AI Behavior
	var ai_label: Label = Label.new()
	ai_label.text = "AI Behavior:"
	ai_label.tooltip_text = "How this enemy makes decisions. Affects targeting, positioning, ability usage."
	enemy_vbox.add_child(ai_label)

	var ai_option: OptionButton = OptionButton.new()
	ai_option.tooltip_text = "AI brain controlling this enemy. Aggressive rushes, Cautious holds position, Support heals allies."
	enemy_vbox.add_child(ai_option)

	# Track UI elements
	var enemy_ui: Dictionary = {
		"panel": enemy_panel,
		"character_picker": character_picker,
		"pos_x_spin": pos_x_spin,
		"pos_y_spin": pos_y_spin,
		"ai_option": ai_option
	}
	enemies_list.append(enemy_ui)

	enemies_container.add_child(enemy_panel)

	# Load AI dropdown and set values if provided
	_update_ai_dropdown(ai_option)

	if 'character' in enemy_dict and enemy_dict.character:
		character_picker.select_resource(enemy_dict.character)
	if 'position' in enemy_dict:
		var pos: Vector2i = enemy_dict.position
		pos_x_spin.value = pos.x
		pos_y_spin.value = pos.y
	if 'ai_behavior' in enemy_dict and enemy_dict.ai_behavior:
		_select_ai_in_dropdown(ai_option, enemy_dict.ai_behavior)



func _on_remove_enemy(panel: PanelContainer) -> void:
	# Find and remove from list
	for i: int in range(enemies_list.size()):
		if enemies_list[i].panel == panel:
			enemies_list.remove_at(i)
			break

	# Remove from UI
	enemies_container.remove_child(panel)
	panel.queue_free()

	# Update numbering
	for i: int in range(enemies_list.size()):
		var title_label: Label = enemies_list[i].panel.get_child(0).get_child(0).get_child(0)
		title_label.text = "Enemy #%d" % (i + 1)



## Called when enemy position spinboxes change
func _on_enemy_position_changed(_value: float, _index: int) -> void:
	# Map preview removed - no action needed
	pass


## Add neutral UI element
func _on_add_neutral() -> void:
	_add_neutral_ui({})


func _add_neutral_ui(neutral_dict: Dictionary) -> void:
	var neutral_index: int = neutrals_list.size()
	var neutral_panel: PanelContainer = PanelContainer.new()
	var neutral_vbox: VBoxContainer = VBoxContainer.new()
	neutral_panel.add_child(neutral_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	var neutral_title: Label = Label.new()
	neutral_title.text = "Neutral #%d" % (neutral_index + 1)
	neutral_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(neutral_title)

	var remove_button: Button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_neutral.bind(neutral_panel))
	header_hbox.add_child(remove_button)
	neutral_vbox.add_child(header_hbox)

	# Character picker - uses ResourcePicker for cross-mod support
	var character_picker: ResourcePicker = ResourcePicker.new()
	character_picker.resource_type = "character"
	character_picker.label_text = "Character:"
	character_picker.label_min_width = 80
	character_picker.allow_none = true
	character_picker.tooltip_text = "The CharacterData template for this neutral unit. Usually an NPC to protect or escort."
	neutral_vbox.add_child(character_picker)

	# Position with Place button
	var pos_label: Label = Label.new()
	pos_label.text = "Position (X, Y):"
	pos_label.tooltip_text = "Starting coordinates on the battle map grid."
	neutral_vbox.add_child(pos_label)

	var pos_hbox: HBoxContainer = HBoxContainer.new()
	var pos_x_spin: SpinBox = SpinBox.new()
	pos_x_spin.min_value = 0
	pos_x_spin.max_value = 100
	pos_x_spin.value_changed.connect(_on_neutral_position_changed.bind(neutral_index))
	pos_hbox.add_child(pos_x_spin)

	var pos_y_spin: SpinBox = SpinBox.new()
	pos_y_spin.min_value = 0
	pos_y_spin.max_value = 100
	pos_y_spin.value_changed.connect(_on_neutral_position_changed.bind(neutral_index))
	pos_hbox.add_child(pos_y_spin)

	neutral_vbox.add_child(pos_hbox)

	# AI Behavior
	var ai_label: Label = Label.new()
	ai_label.text = "AI Behavior:"
	ai_label.tooltip_text = "How this neutral NPC behaves. Can flee, fight enemies, or stay in place."
	neutral_vbox.add_child(ai_label)

	var ai_option: OptionButton = OptionButton.new()
	ai_option.tooltip_text = "AI brain for neutral units. Defensive stays in place, Support heals nearby allies."
	neutral_vbox.add_child(ai_option)

	# Track UI elements
	var neutral_ui: Dictionary = {
		"panel": neutral_panel,
		"character_picker": character_picker,
		"pos_x_spin": pos_x_spin,
		"pos_y_spin": pos_y_spin,
		"ai_option": ai_option
	}
	neutrals_list.append(neutral_ui)

	neutrals_container.add_child(neutral_panel)

	# Load AI dropdown and set values if provided
	_update_ai_dropdown(ai_option)

	if 'character' in neutral_dict and neutral_dict.character:
		character_picker.select_resource(neutral_dict.character)
	if 'position' in neutral_dict:
		var pos: Vector2i = neutral_dict.position
		pos_x_spin.value = pos.x
		pos_y_spin.value = pos.y
	if 'ai_behavior' in neutral_dict and neutral_dict.ai_behavior:
		_select_ai_in_dropdown(ai_option, neutral_dict.ai_behavior)



func _on_remove_neutral(panel: PanelContainer) -> void:
	# Find and remove from list
	for i: int in range(neutrals_list.size()):
		if neutrals_list[i].panel == panel:
			neutrals_list.remove_at(i)
			break

	# Remove from UI
	neutrals_container.remove_child(panel)
	panel.queue_free()

	# Update numbering
	for i: int in range(neutrals_list.size()):
		var title_label: Label = neutrals_list[i].panel.get_child(0).get_child(0).get_child(0)
		title_label.text = "Neutral #%d" % (i + 1)


## Called when neutral position spinboxes change
func _on_neutral_position_changed(_value: float, _index: int) -> void:
	# Map preview removed - no action needed
	pass


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

	# Clear existing enemies/neutrals UI
	_clear_enemies_ui()
	_clear_neutrals_ui()

	# Load enemies
	for enemy_dict in battle.enemies:
		_add_enemy_ui(enemy_dict)

	# Load neutrals
	for neutral_dict in battle.neutrals:
		_add_neutral_ui(neutral_dict)

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

	# Rewards
	experience_reward_spin.value = battle.experience_reward
	gold_reward_spin.value = battle.gold_reward

	# Load item rewards (convert from ItemData array to our UI format)
	_clear_item_rewards_ui()
	_load_item_rewards_from_array(battle.item_rewards)

	_updating_ui = false


## Clear enemies UI
func _clear_enemies_ui() -> void:
	for enemy_ui in enemies_list:
		enemies_container.remove_child(enemy_ui.panel)
		enemy_ui.panel.queue_free()
	enemies_list.clear()


## Clear neutrals UI
func _clear_neutrals_ui() -> void:
	for neutral_ui in neutrals_list:
		neutrals_container.remove_child(neutral_ui.panel)
		neutral_ui.panel.queue_free()
	neutrals_list.clear()


## =============================================================================
## ITEM REWARDS UI
## =============================================================================

## Add item reward UI element
func _on_add_item_reward() -> void:
	_add_item_reward_ui()


func _add_item_reward_ui(item_data: ItemData = null, quantity: int = 1) -> void:
	var entry_container: HBoxContainer = HBoxContainer.new()
	entry_container.add_theme_constant_override("separation", 4)

	# Item picker - use ResourcePicker for cross-mod support
	var item_picker: ResourcePicker = ResourcePicker.new()
	item_picker.resource_type = "item"
	item_picker.allow_none = true
	item_picker.none_text = "(Select Item)"
	item_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_container.add_child(item_picker)

	# Quantity label and spinner
	var qty_label: Label = Label.new()
	qty_label.text = "x"
	entry_container.add_child(qty_label)

	var qty_spin: SpinBox = SpinBox.new()
	qty_spin.min_value = 1
	qty_spin.max_value = 99
	qty_spin.value = quantity
	qty_spin.custom_minimum_size.x = 60
	qty_spin.tooltip_text = "Quantity of this item to grant"
	entry_container.add_child(qty_spin)

	# Remove button
	var remove_btn: Button = Button.new()
	remove_btn.text = "X"
	remove_btn.tooltip_text = "Remove this item reward"
	remove_btn.custom_minimum_size.x = 30
	remove_btn.pressed.connect(_on_remove_item_reward.bind(entry_container))
	entry_container.add_child(remove_btn)

	item_rewards_container.add_child(entry_container)

	# Track UI elements
	var item_reward_ui: Dictionary = {
		"container": entry_container,
		"item_picker": item_picker,
		"quantity_spin": qty_spin
	}
	item_rewards_list.append(item_reward_ui)

	# Set item if provided
	if item_data:
		item_picker.select_resource(item_data)


## Remove item reward entry
func _on_remove_item_reward(container: HBoxContainer) -> void:
	# Find and remove from list
	for i in range(item_rewards_list.size()):
		if item_rewards_list[i].container == container:
			item_rewards_list.remove_at(i)
			break

	# Remove from UI
	item_rewards_container.remove_child(container)
	container.queue_free()


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

	# Create UI entries with correct quantities
	for path: String in item_counts.keys():
		var entry: Dictionary = item_counts[path]
		_add_item_reward_ui(entry.item, entry.count)


## Collect item rewards as ItemData array (for BattleData)
func _collect_item_rewards_as_itemdata() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item_ui in item_rewards_list:
		var item: ItemData = item_ui.item_picker.get_selected_resource() as ItemData
		if item:
			# BattleData stores ItemData directly with quantity managed by duplicates
			var quantity: int = int(item_ui.quantity_spin.value)
			for i: int in range(quantity):
				result.append(item)
	return result


## Clear item rewards UI
func _clear_item_rewards_ui() -> void:
	for item_ui in item_rewards_list:
		item_rewards_container.remove_child(item_ui.container)
		item_ui.container.queue_free()
	item_rewards_list.clear()


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

	# Enemies - use ResourcePicker for character selection
	var new_enemies: Array[Dictionary] = []
	for enemy_ui in enemies_list:
		var character: CharacterData = enemy_ui.character_picker.get_selected_resource() as CharacterData

		var ai_index: int = enemy_ui.ai_option.selected
		var ai_behavior: AIBehaviorData = null
		if ai_index > 0:
			ai_behavior = enemy_ui.ai_option.get_item_metadata(ai_index)

		var enemy_dict: Dictionary = {
			"character": character,
			"position": Vector2i(int(enemy_ui.pos_x_spin.value), int(enemy_ui.pos_y_spin.value)),
			"ai_behavior": ai_behavior
		}
		new_enemies.append(enemy_dict)
	battle.enemies = new_enemies

	# Neutrals - use ResourcePicker for character selection
	var new_neutrals: Array[Dictionary] = []
	for neutral_ui in neutrals_list:
		var character: CharacterData = neutral_ui.character_picker.get_selected_resource() as CharacterData

		var ai_index: int = neutral_ui.ai_option.selected
		var ai_behavior: AIBehaviorData = null
		if ai_index > 0:
			ai_behavior = neutral_ui.ai_option.get_item_metadata(ai_index)

		var neutral_dict: Dictionary = {
			"character": character,
			"position": Vector2i(int(neutral_ui.pos_x_spin.value), int(neutral_ui.pos_y_spin.value)),
			"ai_behavior": ai_behavior
		}
		new_neutrals.append(neutral_dict)
	battle.neutrals = new_neutrals

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


## Collect validation error messages by reading directly from UI controls
## This validates UI state before _save_resource_data() is called
func _collect_battle_validation_errors_from_ui() -> Array[String]:
	var errors: Array[String] = []

	# Basic validation - read from UI controls
	var ui_battle_name: String = battle_name_edit.text.strip_edges() if battle_name_edit else ""
	if ui_battle_name.is_empty():
		errors.append("Battle name is required")

	# Map scene validation - check UI dropdown
	var map_index: int = map_scene_option.selected if map_scene_option else -1
	if map_index <= 0:
		errors.append("Map scene is required")

	# Enemy validation - read from enemies_list UI elements
	for i: int in range(enemies_list.size()):
		var enemy_ui: Dictionary = enemies_list[i]
		var character: CharacterData = enemy_ui.character_picker.get_selected_resource() as CharacterData
		if character == null:
			errors.append("Enemy %d: Missing character" % (i + 1))
		# Position is always present in UI (spinboxes have defaults)
		var ai_index: int = enemy_ui.ai_option.selected
		if ai_index <= 0:
			errors.append("Enemy %d: Missing AI behavior" % (i + 1))

	# Neutral validation - read from neutrals_list UI elements
	for i: int in range(neutrals_list.size()):
		var neutral_ui: Dictionary = neutrals_list[i]
		var character: CharacterData = neutral_ui.character_picker.get_selected_resource() as CharacterData
		if character == null:
			errors.append("Neutral %d: Missing character" % (i + 1))
		# Position is always present in UI (spinboxes have defaults)
		var ai_index: int = neutral_ui.ai_option.selected
		if ai_index <= 0:
			errors.append("Neutral %d: Missing AI behavior" % (i + 1))

	# Victory condition validation - read from UI
	var victory_condition: BattleData.VictoryCondition = victory_condition_option.get_item_id(victory_condition_option.selected)
	var enemy_count: int = enemies_list.size()
	var neutral_count: int = neutrals_list.size()

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

	# Defeat condition validation - read from UI
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
