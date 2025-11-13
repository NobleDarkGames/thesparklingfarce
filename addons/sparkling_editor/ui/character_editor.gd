@tool
extends Control

## Character Editor UI
## Allows browsing and editing CharacterData resources

var character_list: ItemList
var character_detail: VBoxContainer
var current_character: CharacterData

var name_edit: LineEdit
var class_option: OptionButton
var level_spin: SpinBox
var bio_edit: TextEdit

# Stat editors
var hp_spin: SpinBox
var mp_spin: SpinBox
var str_spin: SpinBox
var def_spin: SpinBox
var agi_spin: SpinBox
var int_spin: SpinBox
var luk_spin: SpinBox

# Growth rate editors
var hp_growth_slider: HSlider
var mp_growth_slider: HSlider
var str_growth_slider: HSlider
var def_growth_slider: HSlider
var agi_growth_slider: HSlider
var int_growth_slider: HSlider
var luk_growth_slider: HSlider

var available_classes: Array[ClassData] = []


func _ready() -> void:
	_setup_ui()
	_load_available_classes()
	_refresh_character_list()


func _setup_ui() -> void:
	# Use size flags for proper editor panel expansion (no anchors needed)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hsplit)

	# Left side: Character list
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 250

	var list_label: Label = Label.new()
	list_label.text = "Characters"
	list_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(list_label)

	var help_label: Label = Label.new()
	help_label.text = "Use Tools > Create New Character\nto get started"
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 11)
	left_panel.add_child(help_label)

	character_list = ItemList.new()
	character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_list.custom_minimum_size = Vector2(200, 200)
	character_list.item_selected.connect(_on_character_selected)
	left_panel.add_child(character_list)

	var create_button: Button = Button.new()
	create_button.text = "Create New Character"
	create_button.pressed.connect(_on_create_new_character)
	left_panel.add_child(create_button)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh List"
	refresh_button.pressed.connect(_refresh_character_list)
	left_panel.add_child(refresh_button)

	hsplit.add_child(left_panel)

	# Right side: Character details
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(400, 0)

	character_detail = VBoxContainer.new()
	character_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var detail_label: Label = Label.new()
	detail_label.text = "Character Details"
	detail_label.add_theme_font_size_override("font_size", 18)
	character_detail.add_child(detail_label)

	# Basic info section
	_add_basic_info_section()

	# Stats section
	_add_stats_section()

	# Growth rates section
	_add_growth_rates_section()

	# Button container for Save and Delete
	var button_container: HBoxContainer = HBoxContainer.new()

	var save_button: Button = Button.new()
	save_button.text = "Save Changes"
	save_button.pressed.connect(_save_current_character)
	button_container.add_child(save_button)

	var delete_button: Button = Button.new()
	delete_button.text = "Delete Character"
	delete_button.pressed.connect(_delete_current_character)
	button_container.add_child(delete_button)

	character_detail.add_child(button_container)

	scroll.add_child(character_detail)
	hsplit.add_child(scroll)


func _add_basic_info_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	# Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 120
	name_container.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(name_edit)
	section.add_child(name_container)

	# Class
	var class_container: HBoxContainer = HBoxContainer.new()
	var class_label: Label = Label.new()
	class_label.text = "Class:"
	class_label.custom_minimum_size.x = 120
	class_container.add_child(class_label)

	class_option = OptionButton.new()
	class_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_container.add_child(class_option)
	section.add_child(class_container)

	# Starting Level
	var level_container: HBoxContainer = HBoxContainer.new()
	var level_label: Label = Label.new()
	level_label.text = "Starting Level:"
	level_label.custom_minimum_size.x = 120
	level_container.add_child(level_label)

	level_spin = SpinBox.new()
	level_spin.min_value = 1
	level_spin.max_value = 99
	level_spin.value = 1
	level_container.add_child(level_spin)
	section.add_child(level_container)

	# Biography
	var bio_label: Label = Label.new()
	bio_label.text = "Biography:"
	section.add_child(bio_label)

	bio_edit = TextEdit.new()
	bio_edit.custom_minimum_size.y = 100
	section.add_child(bio_edit)

	character_detail.add_child(section)


func _add_stats_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Base Stats"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	hp_spin = _create_stat_editor("HP:", section)
	mp_spin = _create_stat_editor("MP:", section)
	str_spin = _create_stat_editor("Strength:", section)
	def_spin = _create_stat_editor("Defense:", section)
	agi_spin = _create_stat_editor("Agility:", section)
	int_spin = _create_stat_editor("Intelligence:", section)
	luk_spin = _create_stat_editor("Luck:", section)

	character_detail.add_child(section)


func _add_growth_rates_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Growth Rates (%)"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	hp_growth_slider = _create_growth_editor("HP Growth:", section)
	mp_growth_slider = _create_growth_editor("MP Growth:", section)
	str_growth_slider = _create_growth_editor("STR Growth:", section)
	def_growth_slider = _create_growth_editor("DEF Growth:", section)
	agi_growth_slider = _create_growth_editor("AGI Growth:", section)
	int_growth_slider = _create_growth_editor("INT Growth:", section)
	luk_growth_slider = _create_growth_editor("LUK Growth:", section)

	character_detail.add_child(section)


func _create_stat_editor(label_text: String, parent: VBoxContainer) -> SpinBox:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	container.add_child(label)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = 1
	spin.max_value = 999
	spin.value = 10
	container.add_child(spin)

	parent.add_child(container)
	return spin


func _create_growth_editor(label_text: String, parent: VBoxContainer) -> HSlider:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	container.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = 50
	slider.step = 5
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(slider)

	var value_label: Label = Label.new()
	value_label.text = "50%"
	value_label.custom_minimum_size.x = 50
	slider.value_changed.connect(func(value: float) -> void: value_label.text = str(int(value)) + "%")
	container.add_child(value_label)

	parent.add_child(container)
	return slider


func _load_available_classes() -> void:
	available_classes.clear()
	class_option.clear()
	class_option.add_item("(None)", 0)

	var dir: DirAccess = DirAccess.open("res://data/classes/")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var class_data: ClassData = load("res://data/classes/" + file_name)
				if class_data:
					available_classes.append(class_data)
					class_option.add_item(class_data.display_name, available_classes.size())
			file_name = dir.get_next()
		dir.list_dir_end()


func _refresh_character_list() -> void:
	character_list.clear()

	var dir: DirAccess = DirAccess.open("res://data/characters/")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var character: CharacterData = load("res://data/characters/" + file_name)
				if character:
					character_list.add_item(character.character_name)
					character_list.set_item_metadata(character_list.item_count - 1, "res://data/characters/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()


func _on_character_selected(index: int) -> void:
	var path: String = character_list.get_item_metadata(index)
	# Load and duplicate to make it editable (load() returns read-only cached resource)
	var loaded_character: CharacterData = load(path)
	current_character = loaded_character.duplicate(true)
	# Keep the original path so we can save to the same location
	current_character.take_over_path(path)
	_load_character_data()


func _load_character_data() -> void:
	if not current_character:
		return

	name_edit.text = current_character.character_name
	level_spin.value = current_character.starting_level
	bio_edit.text = current_character.biography

	# Set class
	if current_character.character_class:
		for i in range(available_classes.size()):
			if available_classes[i] == current_character.character_class:
				class_option.selected = i + 1
				break

	# Set stats
	hp_spin.value = current_character.base_hp
	mp_spin.value = current_character.base_mp
	str_spin.value = current_character.base_strength
	def_spin.value = current_character.base_defense
	agi_spin.value = current_character.base_agility
	int_spin.value = current_character.base_intelligence
	luk_spin.value = current_character.base_luck

	# Set growth rates
	hp_growth_slider.value = current_character.hp_growth
	mp_growth_slider.value = current_character.mp_growth
	str_growth_slider.value = current_character.strength_growth
	def_growth_slider.value = current_character.defense_growth
	agi_growth_slider.value = current_character.agility_growth
	int_growth_slider.value = current_character.intelligence_growth
	luk_growth_slider.value = current_character.luck_growth


func _save_current_character() -> void:
	if not current_character:
		push_warning("No character selected")
		return

	# Update character data from UI
	current_character.character_name = name_edit.text
	current_character.starting_level = int(level_spin.value)
	current_character.biography = bio_edit.text

	# Update class
	var class_index: int = class_option.selected - 1
	if class_index >= 0 and class_index < available_classes.size():
		current_character.character_class = available_classes[class_index]
	else:
		current_character.character_class = null

	# Update stats
	current_character.base_hp = int(hp_spin.value)
	current_character.base_mp = int(mp_spin.value)
	current_character.base_strength = int(str_spin.value)
	current_character.base_defense = int(def_spin.value)
	current_character.base_agility = int(agi_spin.value)
	current_character.base_intelligence = int(int_spin.value)
	current_character.base_luck = int(luk_spin.value)

	# Update growth rates
	current_character.hp_growth = int(hp_growth_slider.value)
	current_character.mp_growth = int(mp_growth_slider.value)
	current_character.strength_growth = int(str_growth_slider.value)
	current_character.defense_growth = int(def_growth_slider.value)
	current_character.agility_growth = int(agi_growth_slider.value)
	current_character.intelligence_growth = int(int_growth_slider.value)
	current_character.luck_growth = int(luk_growth_slider.value)

	# Save to file
	var path: String = character_list.get_item_metadata(character_list.get_selected_items()[0])
	var err: Error = ResourceSaver.save(current_character, path)
	if err != OK:
		push_error("Failed to save character: " + str(err))


func _on_create_new_character() -> void:
	# Create a new character
	var new_character: CharacterData = CharacterData.new()
	new_character.character_name = "New Character"
	new_character.starting_level = 1
	new_character.base_hp = 20
	new_character.base_mp = 10

	# Generate unique filename
	var timestamp: int = Time.get_unix_time_from_system()
	var filename: String = "character_%d.tres" % timestamp
	var full_path: String = "res://data/characters/" + filename

	# Save the resource
	var err: Error = ResourceSaver.save(new_character, full_path)
	if err == OK:
		# Force Godot to rescan filesystem and reload the resource
		EditorInterface.get_resource_filesystem().scan()
		# Wait a frame for the scan to complete, then refresh
		await get_tree().process_frame
		_refresh_character_list()
	else:
		push_error("Failed to create character: " + str(err))


func _delete_current_character() -> void:
	if not current_character:
		return

	# Check if this character is referenced in battles/dialogues
	var references: Array[String] = _check_character_references(current_character)
	if references.size() > 0:
		push_error("Cannot delete character '%s': Referenced by %d resource(s)" % [current_character.character_name, references.size()])
		return

	# Get the file path
	var selected_items: PackedInt32Array = character_list.get_selected_items()
	if selected_items.size() == 0:
		return

	var path: String = character_list.get_item_metadata(selected_items[0])

	# Delete the file
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir:
		var err: Error = dir.remove(path)
		if err == OK:
			current_character = null
			_refresh_character_list()
		else:
			push_error("Failed to delete character file: " + str(err))
	else:
		push_error("Failed to access directory for deletion")


func _check_character_references(character_to_check: CharacterData) -> Array[String]:
	var references: Array[String] = []

	# TODO: In Phase 2+, check battles and dialogues for references to this character
	# For now, allow deletion

	return references
