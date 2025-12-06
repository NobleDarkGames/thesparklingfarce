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

# Map Preview Component
var map_preview: BattleMapPreview
var place_spawn_button: Button
var preview_update_pending: bool = false

# Player Forces - now using ResourcePicker for cross-mod support
var player_party_picker: ResourcePicker

# Enemy Forces
var enemies_container: VBoxContainer
var enemies_list: Array[Dictionary] = []  # Track enemy UI elements

# Neutral Forces
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

# Environment
var weather_option: OptionButton
var time_of_day_option: OptionButton

# Rewards
var experience_reward_spin: SpinBox
var gold_reward_spin: SpinBox

# AI Behavior tracking
var available_ai_brains: Array[AIBrain] = []  # Track loaded AI brain instances


func _ready() -> void:
	resource_type_id = "battle"
	resource_type_name = "Battle"
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()
	super._ready()


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

	# Section 8: Environment
	_add_environment_section()

	# Section 9: Audio (placeholders)
	_add_audio_section()

	# Section 10: Rewards
	_add_rewards_section()

	# Add the button container at the end
	detail_panel.add_child(button_container)


## Section 1: Basic Information
func _add_basic_info_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var name_label: Label = Label.new()
	name_label.text = "Battle Name:"
	detail_panel.add_child(name_label)

	battle_name_edit = LineEdit.new()
	battle_name_edit.placeholder_text = "Enter battle name"
	detail_panel.add_child(battle_name_edit)

	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	detail_panel.add_child(desc_label)

	battle_description_edit = TextEdit.new()
	battle_description_edit.custom_minimum_size = Vector2(0, 120)
	detail_panel.add_child(battle_description_edit)

	_add_separator()


## Section 2: Map Selection
func _add_map_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Map Configuration"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var map_label: Label = Label.new()
	map_label.text = "Map Scene:"
	detail_panel.add_child(map_label)

	map_scene_option = OptionButton.new()
	map_scene_option.item_selected.connect(_on_map_scene_changed)
	detail_panel.add_child(map_scene_option)

	var map_note: Label = Label.new()
	map_note.text = "Maps are loaded from mods/*/maps/ directories"
	map_note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	map_note.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(map_note)

	# Player Spawn Point with place button
	var spawn_label: Label = Label.new()
	spawn_label.text = "Player Spawn Point (X, Y):"
	detail_panel.add_child(spawn_label)

	var spawn_hbox: HBoxContainer = HBoxContainer.new()
	player_spawn_x_spin = SpinBox.new()
	player_spawn_x_spin.min_value = 0
	player_spawn_x_spin.max_value = 100
	player_spawn_x_spin.value = 2
	player_spawn_x_spin.value_changed.connect(_on_spawn_position_changed)
	spawn_hbox.add_child(player_spawn_x_spin)

	player_spawn_y_spin = SpinBox.new()
	player_spawn_y_spin.min_value = 0
	player_spawn_y_spin.max_value = 100
	player_spawn_y_spin.value = 2
	player_spawn_y_spin.value_changed.connect(_on_spawn_position_changed)
	spawn_hbox.add_child(player_spawn_y_spin)

	place_spawn_button = Button.new()
	place_spawn_button.text = "Place on Map"
	place_spawn_button.tooltip_text = "Click on the map preview to set spawn point"
	place_spawn_button.pressed.connect(_on_place_spawn_pressed)
	spawn_hbox.add_child(place_spawn_button)

	detail_panel.add_child(spawn_hbox)

	var spawn_note: Label = Label.new()
	spawn_note.text = "Party members spawn in formation around this point"
	spawn_note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	spawn_note.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(spawn_note)

	# Map Preview Panel
	_add_map_preview_panel()

	_add_separator()


## Section 3: Player Forces
func _add_player_forces_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Player Forces"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	# Use ResourcePicker for cross-mod party selection
	player_party_picker = ResourcePicker.new()
	player_party_picker.resource_type = "party"
	player_party_picker.label_text = "Player Party:"
	player_party_picker.label_min_width = 120
	player_party_picker.none_text = "(Use PartyManager)"
	player_party_picker.allow_none = true
	detail_panel.add_child(player_party_picker)

	var party_note: Label = Label.new()
	party_note.text = "If not set, uses PartyManager's current party"
	party_note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	party_note.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(party_note)

	_add_separator()


## Section 4: Enemy Forces
func _add_enemy_forces_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Enemy Forces"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Configure enemy units, positions, and AI behaviors"
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_panel.add_child(help_label)

	enemies_container = VBoxContainer.new()
	detail_panel.add_child(enemies_container)

	var add_enemy_button: Button = Button.new()
	add_enemy_button.text = "Add Enemy"
	add_enemy_button.pressed.connect(_on_add_enemy)
	detail_panel.add_child(add_enemy_button)

	_add_separator()


## Section 4: Neutral Forces
func _add_neutral_forces_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Neutral/NPC Forces"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Configure neutral units (for PROTECT_UNIT objectives)"
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_panel.add_child(help_label)

	neutrals_container = VBoxContainer.new()
	detail_panel.add_child(neutrals_container)

	var add_neutral_button: Button = Button.new()
	add_neutral_button.text = "Add Neutral Unit"
	add_neutral_button.pressed.connect(_on_add_neutral)
	detail_panel.add_child(add_neutral_button)

	_add_separator()


## Section 5: Victory Conditions
func _add_victory_conditions_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Victory Conditions"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var condition_label: Label = Label.new()
	condition_label.text = "Victory Condition:"
	detail_panel.add_child(condition_label)

	victory_condition_option = OptionButton.new()
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

	_add_separator()


## Section 6: Defeat Conditions
func _add_defeat_conditions_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Defeat Conditions"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var condition_label: Label = Label.new()
	condition_label.text = "Defeat Condition:"
	detail_panel.add_child(condition_label)

	defeat_condition_option = OptionButton.new()
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

	_add_separator()


## Section 7: Battle Flow & Dialogue
func _add_battle_flow_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Battle Flow & Dialogue"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	# Use ResourcePicker for cross-mod dialogue selection
	pre_battle_dialogue_picker = ResourcePicker.new()
	pre_battle_dialogue_picker.resource_type = "dialogue"
	pre_battle_dialogue_picker.label_text = "Pre-Battle Dialogue:"
	pre_battle_dialogue_picker.label_min_width = 140
	pre_battle_dialogue_picker.allow_none = true
	detail_panel.add_child(pre_battle_dialogue_picker)

	victory_dialogue_picker = ResourcePicker.new()
	victory_dialogue_picker.resource_type = "dialogue"
	victory_dialogue_picker.label_text = "Victory Dialogue:"
	victory_dialogue_picker.label_min_width = 140
	victory_dialogue_picker.allow_none = true
	detail_panel.add_child(victory_dialogue_picker)

	defeat_dialogue_picker = ResourcePicker.new()
	defeat_dialogue_picker.resource_type = "dialogue"
	defeat_dialogue_picker.label_text = "Defeat Dialogue:"
	defeat_dialogue_picker.label_min_width = 140
	defeat_dialogue_picker.allow_none = true
	detail_panel.add_child(defeat_dialogue_picker)

	var turn_note: Label = Label.new()
	turn_note.text = "Turn-based dialogues: Phase 3"
	turn_note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_panel.add_child(turn_note)

	_add_separator()


## Section 8: Environment
func _add_environment_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Environment"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var weather_label: Label = Label.new()
	weather_label.text = "Weather:"
	detail_panel.add_child(weather_label)

	weather_option = OptionButton.new()
	# Populate from registry
	var weather_types: Array[String] = _get_weather_types_from_registry()
	for weather_type: String in weather_types:
		weather_option.add_item(weather_type.capitalize())
	detail_panel.add_child(weather_option)

	var time_label: Label = Label.new()
	time_label.text = "Time of Day:"
	detail_panel.add_child(time_label)

	time_of_day_option = OptionButton.new()
	# Populate from registry
	var time_options: Array[String] = _get_time_of_day_from_registry()
	for time_option: String in time_options:
		time_of_day_option.add_item(time_option.capitalize())
	detail_panel.add_child(time_of_day_option)

	_add_separator()


## Get weather types from ModLoader's environment registry (with fallback)
func _get_weather_types_from_registry() -> Array[String]:
	if ModLoader and ModLoader.environment_registry:
		return ModLoader.environment_registry.get_weather_types()
	# Fallback to defaults if registry not available
	return ["none", "rain", "snow", "fog"]


## Get time of day options from ModLoader's environment registry (with fallback)
func _get_time_of_day_from_registry() -> Array[String]:
	if ModLoader and ModLoader.environment_registry:
		return ModLoader.environment_registry.get_time_of_day_options()
	# Fallback to defaults if registry not available
	return ["day", "night", "dawn", "dusk"]


## Section 9: Audio (Placeholders)
func _add_audio_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Audio"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var audio_note: Label = Label.new()
	audio_note.text = "Phase 3 - Audio integration (BGM, Victory, Defeat music)"
	audio_note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_panel.add_child(audio_note)

	_add_separator()


## Section 10: Rewards
func _add_rewards_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Rewards"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var exp_label: Label = Label.new()
	exp_label.text = "Experience Reward:"
	detail_panel.add_child(exp_label)

	experience_reward_spin = SpinBox.new()
	experience_reward_spin.min_value = 0
	experience_reward_spin.max_value = 10000
	experience_reward_spin.step = 10
	detail_panel.add_child(experience_reward_spin)

	var gold_label: Label = Label.new()
	gold_label.text = "Gold Reward:"
	detail_panel.add_child(gold_label)

	gold_reward_spin = SpinBox.new()
	gold_reward_spin.min_value = 0
	gold_reward_spin.max_value = 10000
	gold_reward_spin.step = 10
	detail_panel.add_child(gold_reward_spin)

	var items_note: Label = Label.new()
	items_note.text = "Item rewards: Phase 3 - Multiple item selection"
	items_note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_panel.add_child(items_note)

	_add_separator()


## Helper: Add visual separator
func _add_separator() -> void:
	var separator: HSeparator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 10)
	detail_panel.add_child(separator)


## Add the map preview panel with battle map visualization
func _add_map_preview_panel() -> void:
	var preview_container: VBoxContainer = VBoxContainer.new()

	var preview_header: HBoxContainer = HBoxContainer.new()
	preview_header.add_theme_constant_override("separation", 8)

	var preview_label: Label = Label.new()
	preview_label.text = "Battle Map Preview"
	preview_label.add_theme_font_size_override("font_size", 16)
	preview_header.add_child(preview_label)

	var help_icon: Label = Label.new()
	help_icon.text = "(Click markers for info, use Place buttons to position)"
	help_icon.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	help_icon.add_theme_font_size_override("font_size", 16)
	preview_header.add_child(help_icon)

	preview_container.add_child(preview_header)

	# Create the BattleMapPreview component
	map_preview = BattleMapPreview.new()
	map_preview.custom_minimum_size = Vector2(350, 250)
	map_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_preview.position_clicked.connect(_on_preview_position_clicked)
	preview_container.add_child(map_preview)

	# Legend
	var legend_hbox: HBoxContainer = HBoxContainer.new()
	legend_hbox.add_theme_constant_override("separation", 16)

	var spawn_legend: Label = Label.new()
	spawn_legend.text = "[P] Player Spawn"
	spawn_legend.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	spawn_legend.add_theme_font_size_override("font_size", 16)
	legend_hbox.add_child(spawn_legend)

	var enemy_legend: Label = Label.new()
	enemy_legend.text = "[1,2...] Enemies"
	enemy_legend.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	enemy_legend.add_theme_font_size_override("font_size", 16)
	legend_hbox.add_child(enemy_legend)

	var neutral_legend: Label = Label.new()
	neutral_legend.text = "[N1...] Neutrals"
	neutral_legend.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	neutral_legend.add_theme_font_size_override("font_size", 16)
	legend_hbox.add_child(neutral_legend)

	preview_container.add_child(legend_hbox)

	detail_panel.add_child(preview_container)


## Called when map scene selection changes
func _on_map_scene_changed(index: int) -> void:
	if not map_preview:
		return

	if index <= 0:
		map_preview.clear_map()
		return

	var map_path: String = map_scene_option.get_item_metadata(index)
	if map_path and not map_path.is_empty():
		map_preview.set_map_scene_path(map_path)
		_schedule_preview_update()


## Called when spawn position spinboxes change
func _on_spawn_position_changed(_value: float) -> void:
	_schedule_preview_update()


## Called when "Place on Map" button for spawn is pressed
func _on_place_spawn_pressed() -> void:
	if map_preview:
		map_preview.start_placement("player_spawn")
		place_spawn_button.text = "Click Map..."
		place_spawn_button.disabled = true


## Called when a position is clicked on the map preview
func _on_preview_position_clicked(mode: String, index: int, grid_position: Vector2i) -> void:
	match mode:
		"player_spawn":
			player_spawn_x_spin.value = grid_position.x
			player_spawn_y_spin.value = grid_position.y
			place_spawn_button.text = "Place on Map"
			place_spawn_button.disabled = false

		"enemy":
			if index >= 0 and index < enemies_list.size():
				var enemy_ui: Dictionary = enemies_list[index]
				enemy_ui.pos_x_spin.value = grid_position.x
				enemy_ui.pos_y_spin.value = grid_position.y
				# Reset the place button
				if "place_button" in enemy_ui:
					enemy_ui.place_button.text = "Place"
					enemy_ui.place_button.disabled = false

		"neutral":
			if index >= 0 and index < neutrals_list.size():
				var neutral_ui: Dictionary = neutrals_list[index]
				neutral_ui.pos_x_spin.value = grid_position.x
				neutral_ui.pos_y_spin.value = grid_position.y
				# Reset the place button
				if "place_button" in neutral_ui:
					neutral_ui.place_button.text = "Place"
					neutral_ui.place_button.disabled = false

	_schedule_preview_update()


## Schedule a preview marker update (debounced)
func _schedule_preview_update() -> void:
	if preview_update_pending:
		return

	preview_update_pending = true

	# Use call_deferred to batch updates
	call_deferred("_update_preview_markers")


## Update all preview markers based on current UI values
func _update_preview_markers() -> void:
	preview_update_pending = false

	if not map_preview:
		return

	# Update player spawn
	var spawn_pos: Vector2i = Vector2i(
		int(player_spawn_x_spin.value),
		int(player_spawn_y_spin.value)
	)
	map_preview.set_player_spawn(spawn_pos)

	# Update enemy markers
	var enemy_positions: Array[Dictionary] = []
	for i in range(enemies_list.size()):
		var enemy_ui: Dictionary = enemies_list[i]
		enemy_positions.append({
			"position": Vector2i(
				int(enemy_ui.pos_x_spin.value),
				int(enemy_ui.pos_y_spin.value)
			)
		})
	map_preview.set_enemy_positions(enemy_positions)

	# Update neutral markers
	var neutral_positions: Array[Dictionary] = []
	for i in range(neutrals_list.size()):
		var neutral_ui: Dictionary = neutrals_list[i]
		neutral_positions.append({
			"position": Vector2i(
				int(neutral_ui.pos_x_spin.value),
				int(neutral_ui.pos_y_spin.value)
			)
		})
	map_preview.set_neutral_positions(neutral_positions)


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

	var place_button: Button = Button.new()
	place_button.text = "Place"
	place_button.tooltip_text = "Click on the map preview to position this enemy"
	place_button.pressed.connect(_on_place_enemy_pressed.bind(enemy_index))
	pos_hbox.add_child(place_button)

	enemy_vbox.add_child(pos_hbox)

	# AI Behavior
	var ai_label: Label = Label.new()
	ai_label.text = "AI Behavior:"
	enemy_vbox.add_child(ai_label)

	var ai_option: OptionButton = OptionButton.new()
	enemy_vbox.add_child(ai_option)

	# Track UI elements - now stores ResourcePicker and place_button
	var enemy_ui: Dictionary = {
		"panel": enemy_panel,
		"character_picker": character_picker,
		"pos_x_spin": pos_x_spin,
		"pos_y_spin": pos_y_spin,
		"place_button": place_button,
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
	if 'ai_brain' in enemy_dict and enemy_dict.ai_brain:
		_select_ai_in_dropdown(ai_option, enemy_dict.ai_brain)

	# Update preview after adding enemy
	_schedule_preview_update()


func _on_remove_enemy(panel: PanelContainer) -> void:
	# Find and remove from list
	for i in range(enemies_list.size()):
		if enemies_list[i].panel == panel:
			enemies_list.remove_at(i)
			break

	# Remove from UI
	enemies_container.remove_child(panel)
	panel.queue_free()

	# Update numbering
	for i in range(enemies_list.size()):
		var title_label: Label = enemies_list[i].panel.get_child(0).get_child(0).get_child(0)
		title_label.text = "Enemy #%d" % (i + 1)

	# Update preview after removing enemy
	_schedule_preview_update()


## Called when enemy position spinboxes change
func _on_enemy_position_changed(_value: float, _index: int) -> void:
	_schedule_preview_update()


## Called when "Place" button for an enemy is pressed
func _on_place_enemy_pressed(index: int) -> void:
	if map_preview and index < enemies_list.size():
		map_preview.start_placement("enemy", index)
		var enemy_ui: Dictionary = enemies_list[index]
		if "place_button" in enemy_ui:
			enemy_ui.place_button.text = "Click..."
			enemy_ui.place_button.disabled = true


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
	neutral_vbox.add_child(character_picker)

	# Position with Place button
	var pos_label: Label = Label.new()
	pos_label.text = "Position (X, Y):"
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

	var place_button: Button = Button.new()
	place_button.text = "Place"
	place_button.tooltip_text = "Click on the map preview to position this neutral"
	place_button.pressed.connect(_on_place_neutral_pressed.bind(neutral_index))
	pos_hbox.add_child(place_button)

	neutral_vbox.add_child(pos_hbox)

	# AI Behavior
	var ai_label: Label = Label.new()
	ai_label.text = "AI Behavior:"
	neutral_vbox.add_child(ai_label)

	var ai_option: OptionButton = OptionButton.new()
	neutral_vbox.add_child(ai_option)

	# Track UI elements - now stores ResourcePicker and place_button
	var neutral_ui: Dictionary = {
		"panel": neutral_panel,
		"character_picker": character_picker,
		"pos_x_spin": pos_x_spin,
		"pos_y_spin": pos_y_spin,
		"place_button": place_button,
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
	if 'ai_brain' in neutral_dict and neutral_dict.ai_brain:
		_select_ai_in_dropdown(ai_option, neutral_dict.ai_brain)

	# Update preview after adding neutral
	_schedule_preview_update()


func _on_remove_neutral(panel: PanelContainer) -> void:
	# Find and remove from list
	for i in range(neutrals_list.size()):
		if neutrals_list[i].panel == panel:
			neutrals_list.remove_at(i)
			break

	# Remove from UI
	neutrals_container.remove_child(panel)
	panel.queue_free()

	# Update numbering
	for i in range(neutrals_list.size()):
		var title_label: Label = neutrals_list[i].panel.get_child(0).get_child(0).get_child(0)
		title_label.text = "Neutral #%d" % (i + 1)

	# Update preview after removing neutral
	_schedule_preview_update()


## Called when neutral position spinboxes change
func _on_neutral_position_changed(_value: float, _index: int) -> void:
	_schedule_preview_update()


## Called when "Place" button for a neutral is pressed
func _on_place_neutral_pressed(index: int) -> void:
	if map_preview and index < neutrals_list.size():
		map_preview.start_placement("neutral", index)
		var neutral_ui: Dictionary = neutrals_list[index]
		if "place_button" in neutral_ui:
			neutral_ui.place_button.text = "Click..."
			neutral_ui.place_button.disabled = true


## Load available AI brains from the AI Brain Registry
func _load_available_ai_brains() -> void:
	available_ai_brains.clear()

	# Use the AI Brain Registry for discovery (supports mod.json declarations + auto-discovery)
	if ModLoader and ModLoader.ai_brain_registry:
		var brain_instances: Array[Resource] = ModLoader.ai_brain_registry.get_all_brain_instances()
		for instance: Resource in brain_instances:
			var ai_brain: AIBrain = instance as AIBrain
			if ai_brain:
				available_ai_brains.append(ai_brain)


## Update AI dropdown with available AI brains
func _update_ai_dropdown(option: OptionButton) -> void:
	option.clear()
	option.add_item("(None)", -1)

	# Load AI brains if not already loaded
	if available_ai_brains.is_empty():
		_load_available_ai_brains()

	# Populate dropdown using registry metadata for display names
	var index: int = 0
	for ai_brain: AIBrain in available_ai_brains:
		var display_name: String = ""
		# Try to get display name from registry
		if ModLoader and ModLoader.ai_brain_registry:
			var brain_path: String = ai_brain.get_script().get_path()
			var brains: Array[Dictionary] = ModLoader.ai_brain_registry.get_all_brains()
			for info: Dictionary in brains:
				if info.get("path", "") == brain_path:
					display_name = info.get("display_name", "")
					break
		# Fallback to extracting from filename
		if display_name.is_empty():
			display_name = ai_brain.get_script().get_path().get_file().get_basename().replace("ai_", "").capitalize()
		option.add_item(display_name, index)
		option.set_item_metadata(index + 1, ai_brain)
		index += 1


## Select an AI brain in the dropdown
func _select_ai_in_dropdown(option: OptionButton, ai_brain: AIBrain) -> void:
	if not ai_brain:
		option.selected = 0
		return

	for i in range(option.item_count):
		var metadata: Variant = option.get_item_metadata(i)
		if metadata and metadata.get_script() == ai_brain.get_script():
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
				var item_index: int = map_scene_option.item_count
				map_scene_option.add_item(display_name, item_index - 1)
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
	for child in victory_conditional_container.get_children():
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
			label.text = "Phase 3 - Custom victory script"
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			victory_conditional_container.add_child(label)


## Defeat condition changed - update conditional UI
func _on_defeat_condition_changed(index: int) -> void:
	# Clear conditional container
	for child in defeat_conditional_container.get_children():
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
			label.text = "Phase 3 - Custom defeat script"
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			defeat_conditional_container.add_child(label)


## Override: Load battle data from resource into UI
func _load_resource_data() -> void:
	var battle: BattleData = current_resource as BattleData
	if not battle:
		return

	# Basic info
	battle_name_edit.text = battle.battle_name
	battle_description_edit.text = battle.battle_description

	# Map scene
	_update_map_dropdown()
	_select_map_in_dropdown(battle.map_scene)

	# Update map preview with the selected map
	if map_preview:
		if battle.map_scene:
			map_preview.set_map_scene(battle.map_scene)
		else:
			map_preview.clear_map()

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

	# Environment - use registry for lookups
	var weather_types: Array[String] = _get_weather_types_from_registry()
	var weather_index: int = weather_types.find(battle.weather)
	if weather_index >= 0:
		weather_option.selected = weather_index

	var time_options: Array[String] = _get_time_of_day_from_registry()
	var time_index: int = time_options.find(battle.time_of_day)
	if time_index >= 0:
		time_of_day_option.selected = time_index

	# Rewards
	experience_reward_spin.value = battle.experience_reward
	gold_reward_spin.value = battle.gold_reward

	# Update map preview markers after loading all data
	_schedule_preview_update()


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
		var ai_brain: AIBrain = null
		if ai_index > 0:
			ai_brain = enemy_ui.ai_option.get_item_metadata(ai_index)

		var enemy_dict: Dictionary = {
			"character": character,
			"position": Vector2i(int(enemy_ui.pos_x_spin.value), int(enemy_ui.pos_y_spin.value)),
			"ai_brain": ai_brain
		}
		new_enemies.append(enemy_dict)
	battle.enemies = new_enemies

	# Neutrals - use ResourcePicker for character selection
	var new_neutrals: Array[Dictionary] = []
	for neutral_ui in neutrals_list:
		var character: CharacterData = neutral_ui.character_picker.get_selected_resource() as CharacterData

		var ai_index: int = neutral_ui.ai_option.selected
		var ai_brain: AIBrain = null
		if ai_index > 0:
			ai_brain = neutral_ui.ai_option.get_item_metadata(ai_index)

		var neutral_dict: Dictionary = {
			"character": character,
			"position": Vector2i(int(neutral_ui.pos_x_spin.value), int(neutral_ui.pos_y_spin.value)),
			"ai_brain": ai_brain
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

	# Environment - use registry for lookups
	var weather_items: Array[String] = _get_weather_types_from_registry()
	if weather_option.selected >= 0 and weather_option.selected < weather_items.size():
		battle.weather = weather_items[weather_option.selected]

	var time_items: Array[String] = _get_time_of_day_from_registry()
	if time_of_day_option.selected >= 0 and time_of_day_option.selected < time_items.size():
		battle.time_of_day = time_items[time_of_day_option.selected]

	# Rewards
	battle.experience_reward = int(experience_reward_spin.value)
	battle.gold_reward = int(gold_reward_spin.value)


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var battle: BattleData = current_resource as BattleData
	if not battle:
		return {"valid": false, "errors": ["Invalid resource type"]}

	# Save first to get current UI values
	_save_resource_data()

	# Collect validation errors instead of just checking boolean
	var errors: Array[String] = _collect_battle_validation_errors(battle)
	if not errors.is_empty():
		return {"valid": false, "errors": errors}

	return {"valid": true, "errors": []}


## Collect actual validation error messages from BattleData
## This duplicates BattleData.validate() logic but returns actual error strings
func _collect_battle_validation_errors(battle: BattleData) -> Array[String]:
	var errors: Array[String] = []

	# Basic validation
	if battle.battle_name.is_empty():
		errors.append("Battle name is required")
	if battle.map_scene == null:
		errors.append("Map scene is required")

	# Enemy validation
	for i: int in range(battle.enemies.size()):
		var enemy: Dictionary = battle.enemies[i]
		if not 'character' in enemy or enemy.character == null:
			errors.append("Enemy %d: Missing character" % (i + 1))
		if not 'position' in enemy:
			errors.append("Enemy %d: Missing position" % (i + 1))
		if not 'ai_brain' in enemy or enemy.ai_brain == null:
			errors.append("Enemy %d: Missing AI brain" % (i + 1))

	# Neutral validation
	for i: int in range(battle.neutrals.size()):
		var neutral: Dictionary = battle.neutrals[i]
		if not 'character' in neutral or neutral.character == null:
			errors.append("Neutral %d: Missing character" % (i + 1))
		if not 'position' in neutral:
			errors.append("Neutral %d: Missing position" % (i + 1))
		if not 'ai_brain' in neutral or neutral.ai_brain == null:
			errors.append("Neutral %d: Missing AI brain" % (i + 1))

	# Victory condition validation
	match battle.victory_condition:
		BattleData.VictoryCondition.DEFEAT_BOSS:
			if battle.victory_boss_index < 0 or battle.victory_boss_index >= battle.enemies.size():
				errors.append("Victory condition: Invalid boss index %d (have %d enemies)" % [battle.victory_boss_index, battle.enemies.size()])
		BattleData.VictoryCondition.SURVIVE_TURNS:
			if battle.victory_turn_count <= 0:
				errors.append("Victory condition: Turn count must be greater than 0")
		BattleData.VictoryCondition.PROTECT_UNIT:
			if battle.victory_protect_index < 0 or battle.victory_protect_index >= battle.neutrals.size():
				errors.append("Victory condition: Invalid protect unit index %d (have %d neutrals)" % [battle.victory_protect_index, battle.neutrals.size()])

	# Defeat condition validation
	match battle.defeat_condition:
		BattleData.DefeatCondition.TURN_LIMIT:
			if battle.defeat_turn_limit <= 0:
				errors.append("Defeat condition: Turn limit must be greater than 0")
		BattleData.DefeatCondition.UNIT_DIES:
			if battle.defeat_protect_index < 0 or battle.defeat_protect_index >= battle.neutrals.size():
				errors.append("Defeat condition: Invalid protect unit index %d (have %d neutrals)" % [battle.defeat_protect_index, battle.neutrals.size()])

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
	battle.weather = "none"
	battle.time_of_day = "day"
	return battle


## Override: Get the display name from a resource
func _get_resource_display_name(resource: Resource) -> String:
	var battle: BattleData = resource as BattleData
	if battle:
		return battle.battle_name
	return "Unnamed Battle"
