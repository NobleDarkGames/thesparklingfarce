@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Battle Editor UI
## Allows browsing and editing BattleData resources

# Basic info
var battle_name_edit: LineEdit
var battle_description_edit: TextEdit

# Map
var map_scene_label: Label

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

# Battle Flow
var pre_battle_dialogue_option: OptionButton
var victory_dialogue_option: OptionButton
var defeat_dialogue_option: OptionButton

# Environment
var weather_option: OptionButton
var time_of_day_option: OptionButton

# Rewards
var experience_reward_spin: SpinBox
var gold_reward_spin: SpinBox

# AI Behavior options (used in multiple places)
const AI_BEHAVIORS: Array[String] = ["aggressive", "defensive", "patrol", "stationary", "support"]


func _ready() -> void:
	resource_directory = "res://data/battles/"
	resource_type_name = "Battle"
	super._ready()


## Override: Create the battle-specific detail form
func _create_detail_form() -> void:
	# Section 1: Basic Information
	_add_basic_info_section()

	# Section 2: Map Selection
	_add_map_section()

	# Section 3: Enemy Forces
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
	section_label.add_theme_font_size_override("font_size", 14)
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
	battle_description_edit.custom_minimum_size = Vector2(0, 80)
	detail_panel.add_child(battle_description_edit)

	_add_separator()


## Section 2: Map Selection
func _add_map_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Map Configuration"
	section_label.add_theme_font_size_override("font_size", 14)
	detail_panel.add_child(section_label)

	var map_label: Label = Label.new()
	map_label.text = "Map Scene:"
	detail_panel.add_child(map_label)

	map_scene_label = Label.new()
	map_scene_label.text = "Phase 3 - Map scene selection (use Inspector for now)"
	map_scene_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_panel.add_child(map_scene_label)

	_add_separator()


## Section 3: Enemy Forces
func _add_enemy_forces_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Enemy Forces"
	section_label.add_theme_font_size_override("font_size", 14)
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
	section_label.add_theme_font_size_override("font_size", 14)
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
	section_label.add_theme_font_size_override("font_size", 14)
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
	section_label.add_theme_font_size_override("font_size", 14)
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
	section_label.add_theme_font_size_override("font_size", 14)
	detail_panel.add_child(section_label)

	var pre_label: Label = Label.new()
	pre_label.text = "Pre-Battle Dialogue:"
	detail_panel.add_child(pre_label)

	pre_battle_dialogue_option = OptionButton.new()
	detail_panel.add_child(pre_battle_dialogue_option)

	var victory_label: Label = Label.new()
	victory_label.text = "Victory Dialogue:"
	detail_panel.add_child(victory_label)

	victory_dialogue_option = OptionButton.new()
	detail_panel.add_child(victory_dialogue_option)

	var defeat_label: Label = Label.new()
	defeat_label.text = "Defeat Dialogue:"
	detail_panel.add_child(defeat_label)

	defeat_dialogue_option = OptionButton.new()
	detail_panel.add_child(defeat_dialogue_option)

	var turn_note: Label = Label.new()
	turn_note.text = "Turn-based dialogues: Phase 3"
	turn_note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_panel.add_child(turn_note)

	_add_separator()


## Section 8: Environment
func _add_environment_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Environment"
	section_label.add_theme_font_size_override("font_size", 14)
	detail_panel.add_child(section_label)

	var weather_label: Label = Label.new()
	weather_label.text = "Weather:"
	detail_panel.add_child(weather_label)

	weather_option = OptionButton.new()
	weather_option.add_item("None")
	weather_option.add_item("Rain")
	weather_option.add_item("Snow")
	weather_option.add_item("Fog")
	detail_panel.add_child(weather_option)

	var time_label: Label = Label.new()
	time_label.text = "Time of Day:"
	detail_panel.add_child(time_label)

	time_of_day_option = OptionButton.new()
	time_of_day_option.add_item("Day")
	time_of_day_option.add_item("Night")
	time_of_day_option.add_item("Dawn")
	time_of_day_option.add_item("Dusk")
	detail_panel.add_child(time_of_day_option)

	_add_separator()


## Section 9: Audio (Placeholders)
func _add_audio_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Audio"
	section_label.add_theme_font_size_override("font_size", 14)
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
	section_label.add_theme_font_size_override("font_size", 14)
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


## Add enemy UI element
func _on_add_enemy() -> void:
	_add_enemy_ui({})


func _add_enemy_ui(enemy_dict: Dictionary) -> void:
	var enemy_panel: PanelContainer = PanelContainer.new()
	var enemy_vbox: VBoxContainer = VBoxContainer.new()
	enemy_panel.add_child(enemy_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	var enemy_title: Label = Label.new()
	enemy_title.text = "Enemy #%d" % (enemies_list.size() + 1)
	enemy_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(enemy_title)

	var remove_button: Button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_enemy.bind(enemy_panel))
	header_hbox.add_child(remove_button)
	enemy_vbox.add_child(header_hbox)

	# Character dropdown
	var char_label: Label = Label.new()
	char_label.text = "Character:"
	enemy_vbox.add_child(char_label)

	var character_option: OptionButton = OptionButton.new()
	enemy_vbox.add_child(character_option)

	# Position
	var pos_label: Label = Label.new()
	pos_label.text = "Position (X, Y):"
	enemy_vbox.add_child(pos_label)

	var pos_hbox: HBoxContainer = HBoxContainer.new()
	var pos_x_spin: SpinBox = SpinBox.new()
	pos_x_spin.min_value = 0
	pos_x_spin.max_value = 100
	pos_hbox.add_child(pos_x_spin)

	var pos_y_spin: SpinBox = SpinBox.new()
	pos_y_spin.min_value = 0
	pos_y_spin.max_value = 100
	pos_hbox.add_child(pos_y_spin)
	enemy_vbox.add_child(pos_hbox)

	# AI Behavior
	var ai_label: Label = Label.new()
	ai_label.text = "AI Behavior:"
	enemy_vbox.add_child(ai_label)

	var ai_option: OptionButton = OptionButton.new()
	for behavior in AI_BEHAVIORS:
		ai_option.add_item(behavior)
	enemy_vbox.add_child(ai_option)

	# Track UI elements
	var enemy_ui: Dictionary = {
		"panel": enemy_panel,
		"character_option": character_option,
		"pos_x_spin": pos_x_spin,
		"pos_y_spin": pos_y_spin,
		"ai_option": ai_option
	}
	enemies_list.append(enemy_ui)

	enemies_container.add_child(enemy_panel)

	# Load character dropdown and set values if provided
	_update_character_dropdown(character_option)

	if 'character' in enemy_dict and enemy_dict.character:
		_select_character_in_dropdown(character_option, enemy_dict.character)
	if 'position' in enemy_dict:
		var pos: Vector2i = enemy_dict.position
		pos_x_spin.value = pos.x
		pos_y_spin.value = pos.y
	if 'ai_behavior' in enemy_dict:
		var ai_index: int = AI_BEHAVIORS.find(enemy_dict.ai_behavior)
		if ai_index >= 0:
			ai_option.selected = ai_index


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


## Add neutral UI element
func _on_add_neutral() -> void:
	_add_neutral_ui({})


func _add_neutral_ui(neutral_dict: Dictionary) -> void:
	var neutral_panel: PanelContainer = PanelContainer.new()
	var neutral_vbox: VBoxContainer = VBoxContainer.new()
	neutral_panel.add_child(neutral_vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	var neutral_title: Label = Label.new()
	neutral_title.text = "Neutral #%d" % (neutrals_list.size() + 1)
	neutral_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(neutral_title)

	var remove_button: Button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_neutral.bind(neutral_panel))
	header_hbox.add_child(remove_button)
	neutral_vbox.add_child(header_hbox)

	# Character dropdown
	var char_label: Label = Label.new()
	char_label.text = "Character:"
	neutral_vbox.add_child(char_label)

	var character_option: OptionButton = OptionButton.new()
	neutral_vbox.add_child(character_option)

	# Position
	var pos_label: Label = Label.new()
	pos_label.text = "Position (X, Y):"
	neutral_vbox.add_child(pos_label)

	var pos_hbox: HBoxContainer = HBoxContainer.new()
	var pos_x_spin: SpinBox = SpinBox.new()
	pos_x_spin.min_value = 0
	pos_x_spin.max_value = 100
	pos_hbox.add_child(pos_x_spin)

	var pos_y_spin: SpinBox = SpinBox.new()
	pos_y_spin.min_value = 0
	pos_y_spin.max_value = 100
	pos_hbox.add_child(pos_y_spin)
	neutral_vbox.add_child(pos_hbox)

	# AI Behavior
	var ai_label: Label = Label.new()
	ai_label.text = "AI Behavior:"
	neutral_vbox.add_child(ai_label)

	var ai_option: OptionButton = OptionButton.new()
	for behavior in AI_BEHAVIORS:
		ai_option.add_item(behavior)
	neutral_vbox.add_child(ai_option)

	# Track UI elements
	var neutral_ui: Dictionary = {
		"panel": neutral_panel,
		"character_option": character_option,
		"pos_x_spin": pos_x_spin,
		"pos_y_spin": pos_y_spin,
		"ai_option": ai_option
	}
	neutrals_list.append(neutral_ui)

	neutrals_container.add_child(neutral_panel)

	# Load character dropdown and set values if provided
	_update_character_dropdown(character_option)

	if 'character' in neutral_dict and neutral_dict.character:
		_select_character_in_dropdown(character_option, neutral_dict.character)
	if 'position' in neutral_dict:
		var pos: Vector2i = neutral_dict.position
		pos_x_spin.value = pos.x
		pos_y_spin.value = pos.y
	if 'ai_behavior' in neutral_dict:
		var ai_index: int = AI_BEHAVIORS.find(neutral_dict.ai_behavior)
		if ai_index >= 0:
			ai_option.selected = ai_index


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


## Update character dropdown with available characters
func _update_character_dropdown(option: OptionButton) -> void:
	option.clear()
	option.add_item("(None)", -1)

	var dir: DirAccess = DirAccess.open("res://data/characters/")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		var index: int = 0
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path: String = "res://data/characters/" + file_name
				var character: CharacterData = load(full_path)
				if character:
					option.add_item(character.character_name, index)
					option.set_item_metadata(index + 1, character)
					index += 1
			file_name = dir.get_next()
		dir.list_dir_end()


## Select a character in the dropdown
func _select_character_in_dropdown(option: OptionButton, character: CharacterData) -> void:
	for i in range(option.item_count):
		var metadata: Variant = option.get_item_metadata(i)
		if metadata == character:
			option.selected = i
			return


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

	# Dialogues
	_update_dialogue_dropdowns()
	_select_dialogue_in_dropdown(pre_battle_dialogue_option, battle.pre_battle_dialogue)
	_select_dialogue_in_dropdown(victory_dialogue_option, battle.victory_dialogue)
	_select_dialogue_in_dropdown(defeat_dialogue_option, battle.defeat_dialogue)

	# Environment
	var weather_index: int = ["none", "rain", "snow", "fog"].find(battle.weather)
	if weather_index >= 0:
		weather_option.selected = weather_index

	var time_index: int = ["day", "night", "dawn", "dusk"].find(battle.time_of_day)
	if time_index >= 0:
		time_of_day_option.selected = time_index

	# Rewards
	experience_reward_spin.value = battle.experience_reward
	gold_reward_spin.value = battle.gold_reward


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


## Update dialogue dropdowns with available dialogues
func _update_dialogue_dropdowns() -> void:
	for option in [pre_battle_dialogue_option, victory_dialogue_option, defeat_dialogue_option]:
		option.clear()
		option.add_item("(None)", -1)

		var dir: DirAccess = DirAccess.open("res://data/dialogues/")
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			var index: int = 0
			while file_name != "":
				if file_name.ends_with(".tres"):
					var full_path: String = "res://data/dialogues/" + file_name
					var dialogue: DialogueData = load(full_path)
					if dialogue:
						option.add_item(dialogue.dialogue_title, index)
						option.set_item_metadata(index + 1, dialogue)
						index += 1
				file_name = dir.get_next()
			dir.list_dir_end()


## Select a dialogue in dropdown
func _select_dialogue_in_dropdown(option: OptionButton, dialogue: DialogueData) -> void:
	if not dialogue:
		option.selected = 0
		return

	for i in range(option.item_count):
		var metadata: Variant = option.get_item_metadata(i)
		if metadata == dialogue:
			option.selected = i
			return


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var battle: BattleData = current_resource as BattleData
	if not battle:
		return

	# Basic info
	battle.battle_name = battle_name_edit.text
	battle.battle_description = battle_description_edit.text

	# Enemies
	var new_enemies: Array[Dictionary] = []
	for enemy_ui in enemies_list:
		var char_index: int = enemy_ui.character_option.selected
		var character: CharacterData = null
		if char_index > 0:
			character = enemy_ui.character_option.get_item_metadata(char_index)

		var enemy_dict: Dictionary = {
			"character": character,
			"position": Vector2i(int(enemy_ui.pos_x_spin.value), int(enemy_ui.pos_y_spin.value)),
			"ai_behavior": AI_BEHAVIORS[enemy_ui.ai_option.selected]
		}
		new_enemies.append(enemy_dict)
	battle.enemies = new_enemies

	# Neutrals
	var new_neutrals: Array[Dictionary] = []
	for neutral_ui in neutrals_list:
		var char_index: int = neutral_ui.character_option.selected
		var character: CharacterData = null
		if char_index > 0:
			character = neutral_ui.character_option.get_item_metadata(char_index)

		var neutral_dict: Dictionary = {
			"character": character,
			"position": Vector2i(int(neutral_ui.pos_x_spin.value), int(neutral_ui.pos_y_spin.value)),
			"ai_behavior": AI_BEHAVIORS[neutral_ui.ai_option.selected]
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

	# Dialogues
	var pre_index: int = pre_battle_dialogue_option.selected
	if pre_index > 0:
		battle.pre_battle_dialogue = pre_battle_dialogue_option.get_item_metadata(pre_index)
	else:
		battle.pre_battle_dialogue = null

	var victory_index: int = victory_dialogue_option.selected
	if victory_index > 0:
		battle.victory_dialogue = victory_dialogue_option.get_item_metadata(victory_index)
	else:
		battle.victory_dialogue = null

	var defeat_index: int = defeat_dialogue_option.selected
	if defeat_index > 0:
		battle.defeat_dialogue = defeat_dialogue_option.get_item_metadata(defeat_index)
	else:
		battle.defeat_dialogue = null

	# Environment
	var weather_items: Array[String] = ["none", "rain", "snow", "fog"]
	battle.weather = weather_items[weather_option.selected]

	var time_items: Array[String] = ["day", "night", "dawn", "dusk"]
	battle.time_of_day = time_items[time_of_day_option.selected]

	# Rewards
	battle.experience_reward = int(experience_reward_spin.value)
	battle.gold_reward = int(gold_reward_spin.value)


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var battle: BattleData = current_resource as BattleData
	if not battle:
		return {valid = false, errors = ["Invalid resource type"]}

	# Save first to get current UI values
	_save_resource_data()

	# Use BattleData's built-in validation
	if not battle.validate():
		return {valid = false, errors = ["See console for validation errors"]}

	return {valid = true, errors = []}


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
