extends Control

## Test scene for InventoryPanel
##
## Creates mock CharacterSaveData with items for testing equip/unequip flow.
## Run this scene directly to verify inventory UI works standalone.

@onready var inventory_panel: InventoryPanel = %InventoryPanel
@onready var status_label: Label = %StatusLabel
@onready var character_buttons: HBoxContainer = %CharacterButtons

var _test_characters: Array[CharacterSaveData] = []
var _current_index: int = 0


func _ready() -> void:
	# Wait for ModLoader to be ready
	if not ModLoader.is_node_ready():
		await ModLoader.ready

	# Create test characters
	_create_test_data()

	# Connect panel signals
	inventory_panel.equipment_changed.connect(_on_equipment_changed)
	inventory_panel.operation_failed.connect(_on_operation_failed)
	inventory_panel.cursed_item_blocked.connect(_on_cursed_blocked)

	# Create character selection buttons
	_create_character_buttons()

	# Show first character
	if not _test_characters.is_empty():
		_show_character(0)

	_update_status("Ready. Click items to equip/unequip.")


func _create_test_data() -> void:
	# Try to load real character data, or create mock data
	var characters_to_load: Array[String] = ["max", "maggie", "warrioso"]

	for char_id: String in characters_to_load:
		var char_data: CharacterData = ModLoader.registry.get_character(char_id)
		if char_data:
			var save_data: CharacterSaveData = CharacterSaveData.new()
			save_data.populate_from_character_data(char_data)
			_test_characters.append(save_data)
		else:
			print("Could not load character: ", char_id)

	# If no characters loaded, create minimal test data
	if _test_characters.is_empty():
		_test_characters.append(_create_mock_save_data("Test Hero", 1))

	# Add some test items to inventories
	_add_test_items()


func _create_mock_save_data(name: String, level: int) -> CharacterSaveData:
	var save_data: CharacterSaveData = CharacterSaveData.new()
	save_data.character_mod_id = "_sandbox"
	save_data.character_resource_id = "test_" + name.to_lower().replace(" ", "_")
	save_data.fallback_character_name = name
	save_data.fallback_class_name = "Warrior"
	save_data.level = level
	save_data.current_hp = 25
	save_data.max_hp = 25
	save_data.current_mp = 10
	save_data.max_mp = 10
	save_data.strength = 8
	save_data.defense = 7
	save_data.agility = 6
	save_data.intelligence = 5
	save_data.luck = 5
	return save_data


func _add_test_items() -> void:
	# Add specific test items to first character (includes cursed blade)
	if _test_characters.size() > 0:
		var first_char: CharacterSaveData = _test_characters[0]
		# Clear starting inventory to add our test items
		first_char.inventory.clear()
		first_char.inventory.append("cursed_blade")  # Cursed sword for testing
		first_char.inventory.append("power_ring")    # Ring for testing ring slots
		first_char.inventory.append("example_sword") # Normal sword

	# Add different items to second character
	if _test_characters.size() > 1:
		var second_char: CharacterSaveData = _test_characters[1]
		second_char.inventory.clear()
		second_char.inventory.append("item_1764949671")  # Basic Sword from sandbox
		second_char.inventory.append("power_ring")

	# Third character gets generic items from registry
	if _test_characters.size() > 2:
		var third_char: CharacterSaveData = _test_characters[2]
		third_char.inventory.clear()
		var all_items: Array[Resource] = ModLoader.registry.get_all_resources("item")
		var items_added: int = 0
		for item: ItemData in all_items:
			if items_added >= 3:
				break
			if item and item.is_equippable():
				third_char.inventory.append(_get_item_id_from_path(item.resource_path))
				items_added += 1

	print("Test data created: ", _test_characters.size(), " characters")
	for save_data: CharacterSaveData in _test_characters:
		print("  - ", save_data.fallback_character_name, ": ", save_data.inventory.size(), " items, ", save_data.equipped_items.size(), " equipped")


func _get_item_id_from_path(path: String) -> String:
	# Extract filename without extension
	var filename: String = path.get_file()
	return filename.get_basename()


func _create_character_buttons() -> void:
	# Clear existing buttons
	for child: Node in character_buttons.get_children():
		child.queue_free()

	# Create button for each test character
	for i: int in range(_test_characters.size()):
		var save_data: CharacterSaveData = _test_characters[i]
		var button: Button = Button.new()
		button.text = save_data.fallback_character_name
		button.custom_minimum_size = Vector2(80, 40)
		button.add_theme_font_size_override("font_size", 16)

		# Style the button with SF-authentic look
		var normal_style: StyleBoxFlat = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.2, 0.25, 0.9)
		normal_style.border_width_bottom = 2
		normal_style.border_width_left = 2
		normal_style.border_width_right = 2
		normal_style.border_width_top = 2
		normal_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
		normal_style.corner_radius_top_left = 2
		normal_style.corner_radius_top_right = 2
		normal_style.corner_radius_bottom_left = 2
		normal_style.corner_radius_bottom_right = 2
		button.add_theme_stylebox_override("normal", normal_style)

		var hover_style: StyleBoxFlat = normal_style.duplicate()
		hover_style.bg_color = Color(0.25, 0.25, 0.3, 0.9)
		hover_style.border_color = Color(0.6, 0.6, 0.7, 1.0)
		button.add_theme_stylebox_override("hover", hover_style)

		var pressed_style: StyleBoxFlat = normal_style.duplicate()
		pressed_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
		pressed_style.border_color = Color(1.0, 1.0, 0.3, 1.0)
		button.add_theme_stylebox_override("pressed", pressed_style)

		button.pressed.connect(_show_character.bind(i))
		character_buttons.add_child(button)


func _show_character(index: int) -> void:
	if index < 0 or index >= _test_characters.size():
		return

	_current_index = index
	var save_data: CharacterSaveData = _test_characters[index]
	inventory_panel.set_character(save_data)
	_update_status("Showing: " + save_data.fallback_character_name)


func _on_equipment_changed(slot_id: String, old_item: String, new_item: String) -> void:
	var msg: String = "Equipment changed in %s: %s -> %s" % [slot_id, old_item, new_item]
	_update_status(msg)
	print(msg)


func _on_operation_failed(message: String) -> void:
	_update_status("FAILED: " + message)
	print("Operation failed: ", message)


func _on_cursed_blocked(slot_id: String, item_id: String) -> void:
	_update_status("CURSED: Cannot unequip " + item_id)
	print("Cursed item blocked: ", slot_id, " -> ", item_id)


func _update_status(text: String) -> void:
	if status_label:
		status_label.text = text


func _input(event: InputEvent) -> void:
	# Quick character switching with number keys
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
			var index: int = key_event.keycode - KEY_1
			if index < _test_characters.size():
				_show_character(index)
