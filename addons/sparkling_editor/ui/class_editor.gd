@tool
extends Control

## Class Editor UI
## Allows browsing and editing ClassData resources

var class_list: ItemList
var class_detail: VBoxContainer
var current_class: ClassData

var name_edit: LineEdit
var movement_type_option: OptionButton
var movement_range_spin: SpinBox
var promotion_level_spin: SpinBox
var promotion_class_option: OptionButton

var weapon_types_container: VBoxContainer
var armor_types_container: VBoxContainer

var available_classes: Array[ClassData] = []


func _ready() -> void:
	_setup_ui()
	_refresh_class_list()


func _setup_ui() -> void:
	# Use size flags for proper editor panel expansion (no anchors needed)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hsplit)

	# Left side: Class list
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 250

	var list_label: Label = Label.new()
	list_label.text = "Classes"
	list_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(list_label)

	var help_label: Label = Label.new()
	help_label.text = "Use Tools > Create New Class\nto get started"
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 11)
	left_panel.add_child(help_label)

	class_list = ItemList.new()
	class_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	class_list.custom_minimum_size = Vector2(200, 200)
	class_list.item_selected.connect(_on_class_selected)
	left_panel.add_child(class_list)

	var create_button: Button = Button.new()
	create_button.text = "Create New Class"
	create_button.pressed.connect(_on_create_new_class)
	left_panel.add_child(create_button)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh List"
	refresh_button.pressed.connect(_refresh_class_list)
	left_panel.add_child(refresh_button)

	hsplit.add_child(left_panel)

	# Right side: Class details
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	class_detail = VBoxContainer.new()
	class_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var detail_label: Label = Label.new()
	detail_label.text = "Class Details"
	detail_label.add_theme_font_size_override("font_size", 18)
	class_detail.add_child(detail_label)

	# Basic info section
	_add_basic_info_section()

	# Movement section
	_add_movement_section()

	# Equipment section
	_add_equipment_section()

	# Promotion section
	_add_promotion_section()

	# Save button
	var save_button: Button = Button.new()
	save_button.text = "Save Changes"
	save_button.pressed.connect(_save_current_class)
	class_detail.add_child(save_button)

	scroll.add_child(class_detail)
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
	name_label.text = "Class Name:"
	name_label.custom_minimum_size.x = 150
	name_container.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(name_edit)
	section.add_child(name_container)

	class_detail.add_child(section)


func _add_movement_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Movement"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	# Movement Type
	var type_container: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Movement Type:"
	type_label.custom_minimum_size.x = 150
	type_container.add_child(type_label)

	movement_type_option = OptionButton.new()
	movement_type_option.add_item("Walking", ClassData.MovementType.WALKING)
	movement_type_option.add_item("Flying", ClassData.MovementType.FLYING)
	movement_type_option.add_item("Floating", ClassData.MovementType.FLOATING)
	type_container.add_child(movement_type_option)
	section.add_child(type_container)

	# Movement Range
	var range_container: HBoxContainer = HBoxContainer.new()
	var range_label: Label = Label.new()
	range_label.text = "Movement Range:"
	range_label.custom_minimum_size.x = 150
	range_container.add_child(range_label)

	movement_range_spin = SpinBox.new()
	movement_range_spin.min_value = 1
	movement_range_spin.max_value = 20
	movement_range_spin.value = 4
	range_container.add_child(movement_range_spin)
	section.add_child(range_container)

	class_detail.add_child(section)


func _add_equipment_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Equipment Restrictions"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	# Weapon Types
	var weapon_label: Label = Label.new()
	weapon_label.text = "Equippable Weapon Types:"
	section.add_child(weapon_label)

	weapon_types_container = VBoxContainer.new()
	_add_equipment_type_checkboxes(weapon_types_container, ["sword", "axe", "lance", "bow", "staff", "tome"])
	section.add_child(weapon_types_container)

	# Armor Types
	var armor_label: Label = Label.new()
	armor_label.text = "Equippable Armor Types:"
	section.add_child(armor_label)

	armor_types_container = VBoxContainer.new()
	_add_equipment_type_checkboxes(armor_types_container, ["light", "heavy", "robe", "shield"])
	section.add_child(armor_types_container)

	class_detail.add_child(section)


func _add_equipment_type_checkboxes(parent: VBoxContainer, types: Array) -> void:
	for type_name in types:
		var checkbox: CheckBox = CheckBox.new()
		checkbox.text = type_name.capitalize()
		checkbox.set_meta("equipment_type", type_name)
		parent.add_child(checkbox)


func _add_promotion_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Class Promotion"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	# Promotion Level
	var level_container: HBoxContainer = HBoxContainer.new()
	var level_label: Label = Label.new()
	level_label.text = "Promotion Level:"
	level_label.custom_minimum_size.x = 150
	level_container.add_child(level_label)

	promotion_level_spin = SpinBox.new()
	promotion_level_spin.min_value = 1
	promotion_level_spin.max_value = 99
	promotion_level_spin.value = 10
	level_container.add_child(promotion_level_spin)
	section.add_child(level_container)

	# Promotion Class
	var class_container: HBoxContainer = HBoxContainer.new()
	var class_label: Label = Label.new()
	class_label.text = "Promotes To:"
	class_label.custom_minimum_size.x = 150
	class_container.add_child(class_label)

	promotion_class_option = OptionButton.new()
	promotion_class_option.add_item("(None)", 0)
	class_container.add_child(promotion_class_option)
	section.add_child(class_container)

	class_detail.add_child(section)


func _refresh_class_list() -> void:
	print("[ClassEditor] Refreshing class list...")
	class_list.clear()
	available_classes.clear()

	var dir: DirAccess = DirAccess.open("res://data/classes/")
	if dir:
		print("[ClassEditor] Directory opened successfully")
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		var file_count: int = 0
		while file_name != "":
			print("[ClassEditor] Found file: ", file_name)
			if file_name.ends_with(".tres"):
				var full_path: String = "res://data/classes/" + file_name
				print("[ClassEditor] Loading class from: ", full_path)
				var class_data: ClassData = load(full_path)
				if class_data:
					print("[ClassEditor] Loaded class: ", class_data.display_name)
					class_list.add_item(class_data.display_name)
					class_list.set_item_metadata(class_list.item_count - 1, full_path)
					available_classes.append(class_data)
					file_count += 1
				else:
					print("[ClassEditor] Failed to load class from: ", full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		print("[ClassEditor] Total classes loaded: ", file_count)
	else:
		print("[ClassEditor] Failed to open directory: res://data/classes/")

	# Update promotion class dropdown
	_update_promotion_options()


func _update_promotion_options() -> void:
	promotion_class_option.clear()
	promotion_class_option.add_item("(None)", 0)

	for i in range(available_classes.size()):
		promotion_class_option.add_item(available_classes[i].display_name, i + 1)


func _on_class_selected(index: int) -> void:
	var path: String = class_list.get_item_metadata(index)
	current_class = load(path)
	_load_class_data()


func _load_class_data() -> void:
	if not current_class:
		return

	name_edit.text = current_class.display_name
	movement_type_option.selected = current_class.movement_type
	movement_range_spin.value = current_class.movement_range
	promotion_level_spin.value = current_class.promotion_level

	# Set promotion class
	if current_class.promotion_class:
		for i in range(available_classes.size()):
			if available_classes[i] == current_class.promotion_class:
				promotion_class_option.selected = i + 1
				break
	else:
		promotion_class_option.selected = 0

	# Set weapon types
	for child in weapon_types_container.get_children():
		if child is CheckBox:
			var type_name: String = child.get_meta("equipment_type")
			child.button_pressed = type_name in current_class.equippable_weapon_types

	# Set armor types
	for child in armor_types_container.get_children():
		if child is CheckBox:
			var type_name: String = child.get_meta("equipment_type")
			child.button_pressed = type_name in current_class.equippable_armor_types


func _save_current_class() -> void:
	if not current_class:
		push_warning("No class selected")
		return

	# Update class data from UI
	current_class.display_name = name_edit.text
	current_class.movement_type = movement_type_option.selected
	current_class.movement_range = int(movement_range_spin.value)
	current_class.promotion_level = int(promotion_level_spin.value)

	# Update promotion class
	var promo_index: int = promotion_class_option.selected - 1
	if promo_index >= 0 and promo_index < available_classes.size():
		current_class.promotion_class = available_classes[promo_index]
	else:
		current_class.promotion_class = null

	# Update weapon types
	current_class.equippable_weapon_types.clear()
	for child in weapon_types_container.get_children():
		if child is CheckBox and child.button_pressed:
			var type_name: String = child.get_meta("equipment_type")
			current_class.equippable_weapon_types.append(type_name)

	# Update armor types
	current_class.equippable_armor_types.clear()
	for child in armor_types_container.get_children():
		if child is CheckBox and child.button_pressed:
			var type_name: String = child.get_meta("equipment_type")
			current_class.equippable_armor_types.append(type_name)

	# Save to file
	var path: String = class_list.get_item_metadata(class_list.get_selected_items()[0])
	var err: Error = ResourceSaver.save(current_class, path)
	if err == OK:
		print("Class saved successfully")
		_refresh_class_list()
	else:
		push_error("Failed to save class: " + str(err))


func _on_create_new_class() -> void:
	# Create a new class
	var new_class: ClassData = ClassData.new()
	new_class.display_name = "New Class"
	new_class.movement_range = 4

	# Generate unique filename
	var timestamp: int = Time.get_unix_time_from_system()
	var filename: String = "class_%d.tres" % timestamp
	var full_path: String = "res://data/classes/" + filename

	# Save the resource
	var err: Error = ResourceSaver.save(new_class, full_path)
	if err == OK:
		print("Created new class at ", full_path)
		# Force Godot to rescan filesystem and reload the resource
		EditorInterface.get_resource_filesystem().scan()
		# Wait a frame for the scan to complete, then refresh
		await get_tree().process_frame
		_refresh_class_list()
	else:
		push_error("Failed to create class: " + str(err))
