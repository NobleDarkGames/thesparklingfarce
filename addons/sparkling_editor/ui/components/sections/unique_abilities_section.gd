@tool
class_name UniqueAbilitiesSection
extends EditorSectionBase

## Unique Abilities section for Character Editor
## Manages character-specific abilities that bypass class restrictions

# UI Components
var abilities_container: VBoxContainer
var add_button: Button

# Current state
var _current_unique_abilities: Array[Dictionary] = []

# Callback for showing resource picker dialog (provided by parent editor)
var _show_picker_dialog: Callable

# Callback for showing error messages
var _show_error_message: Callable


func _init(mark_dirty: Callable, get_resource: Callable, show_picker_dialog: Callable = Callable(), show_error_message: Callable = Callable()) -> void:
	super._init(mark_dirty, get_resource)
	_show_picker_dialog = show_picker_dialog
	_show_error_message = show_error_message


func build_ui(parent: Control) -> void:
	create_collapse_section("Unique Abilities", true)
	parent.add_child(section_root)

	var content: VBoxContainer = get_content_container()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(content)
	form.on_change(mark_dirty)
	form.add_help_text("Character-specific abilities that bypass class restrictions")

	# Container for the list of unique abilities
	abilities_container = VBoxContainer.new()
	abilities_container.add_theme_constant_override("separation", 4)
	content.add_child(abilities_container)

	# Add Unique Ability button
	var button_container: HBoxContainer = HBoxContainer.new()
	add_button = Button.new()
	add_button.text = "+ Add Unique Ability"
	add_button.tooltip_text = "Add a character-specific ability that bypasses class restrictions"
	add_button.pressed.connect(_on_add_pressed)
	button_container.add_child(add_button)
	content.add_child(button_container)


func load_data() -> void:
	var character: CharacterData = get_resource() as CharacterData
	if not character:
		return

	_current_unique_abilities.clear()

	if character and not character.unique_abilities.is_empty():
		for ability: AbilityData in character.unique_abilities:
			if ability:
				_current_unique_abilities.append({"ability": ability})

	_refresh_display()


func save_data() -> void:
	var character: CharacterData = get_resource() as CharacterData
	if not character:
		return

	var new_unique_abilities: Array[AbilityData] = []
	for ability_dict: Dictionary in _current_unique_abilities:
		var ability: AbilityData = ability_dict.get("ability", null) as AbilityData
		if ability:
			new_unique_abilities.append(ability)
	character.unique_abilities = new_unique_abilities


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_add_pressed() -> void:
	if _show_picker_dialog.is_valid():
		_show_picker_dialog.call("Add Unique Ability", "ability", "Ability:", _on_ability_selected)


func _on_ability_selected(resource: Resource) -> void:
	var ability: AbilityData = resource as AbilityData
	if not ability:
		return

	# Check if already added
	for existing_dict: Dictionary in _current_unique_abilities:
		var existing_ability: AbilityData = existing_dict.get("ability", null) as AbilityData
		if existing_ability and existing_ability.ability_id == ability.ability_id:
			if _show_error_message.is_valid():
				_show_error_message.call("Ability already added")
			return

	# Add the ability
	_current_unique_abilities.append({"ability": ability})
	_refresh_display()
	mark_dirty()


func _on_remove_ability(ability_dict: Dictionary) -> void:
	_current_unique_abilities.erase(ability_dict)
	_refresh_display()
	mark_dirty()


func _refresh_display() -> void:
	# Clear existing rows
	for child: Node in abilities_container.get_children():
		child.queue_free()

	if _current_unique_abilities.is_empty():
		SparklingEditorUtils.add_empty_placeholder(abilities_container, "(No unique abilities)")
		return

	# Create a row for each ability
	for ability_dict: Dictionary in _current_unique_abilities:
		var ability: AbilityData = ability_dict.get("ability", null) as AbilityData
		if not ability:
			continue

		var row: HBoxContainer = HBoxContainer.new()

		# Ability name
		var name_label: Label = Label.new()
		name_label.text = ability.display_name if ability.display_name else ability.ability_id.capitalize()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.tooltip_text = ability.ability_id
		row.add_child(name_label)

		# Remove button
		var remove_btn: Button = Button.new()
		remove_btn.text = "x"
		remove_btn.tooltip_text = "Remove unique ability"
		remove_btn.custom_minimum_size.x = 24
		remove_btn.pressed.connect(_on_remove_ability.bind(ability_dict))
		row.add_child(remove_btn)

		abilities_container.add_child(row)
