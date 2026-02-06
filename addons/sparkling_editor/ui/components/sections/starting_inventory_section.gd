@tool
class_name StartingInventorySection
extends EditorSectionBase

## Starting Inventory section for Character Editor
## Manages items the character carries (not equipped) when recruited

# UI Components
var list_container: VBoxContainer
var add_button: Button

# Current state
var _current_inventory_items: Array[String] = []

# Callback for showing resource picker dialog (provided by parent editor)
var _show_picker_dialog: Callable


func _init(mark_dirty: Callable, get_resource: Callable, show_picker_dialog: Callable = Callable()) -> void:
	super._init(mark_dirty, get_resource)
	_show_picker_dialog = show_picker_dialog


func build_ui(parent: Control) -> void:
	create_collapse_section("Starting Inventory", true)
	parent.add_child(section_root)

	var content: VBoxContainer = get_content_container()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(content)
	form.on_change(mark_dirty)
	form.add_help_text("Items the character carries (not equipped) when recruited")

	# Container for the list of inventory items
	list_container = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 4)
	content.add_child(list_container)

	# Add Item button
	var button_container: HBoxContainer = HBoxContainer.new()
	add_button = Button.new()
	add_button.text = "+ Add Item"
	add_button.tooltip_text = "Add an item to the character's starting inventory"
	add_button.pressed.connect(_on_add_pressed)
	button_container.add_child(add_button)
	content.add_child(button_container)


func load_data() -> void:
	var character: CharacterData = get_resource() as CharacterData
	if not character:
		return

	_current_inventory_items.clear()

	if character and not character.starting_inventory.is_empty():
		for item_id: String in character.starting_inventory:
			_current_inventory_items.append(item_id)

	_refresh_list_display()


func save_data() -> void:
	var character: CharacterData = get_resource() as CharacterData
	if not character:
		return

	var new_inventory: Array[String] = []
	for item_id: String in _current_inventory_items:
		new_inventory.append(item_id)
	character.starting_inventory = new_inventory


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_add_pressed() -> void:
	if _show_picker_dialog.is_valid():
		_show_picker_dialog.call("Add Inventory Item", "item", "Item:", _on_item_selected)


func _on_item_selected(resource: Resource) -> void:
	var item: ItemData = resource as ItemData
	if not item:
		return

	# Extract item_id from resource path (filename without extension)
	var item_id: String = item.resource_path.get_file().get_basename()
	if item_id not in _current_inventory_items:
		_current_inventory_items.append(item_id)
		_refresh_list_display()
		mark_dirty()


func _on_remove_item(item_id: String) -> void:
	_current_inventory_items.erase(item_id)
	_refresh_list_display()
	mark_dirty()


func _refresh_list_display() -> void:
	# Clear existing items
	for child: Node in list_container.get_children():
		child.queue_free()

	if _current_inventory_items.is_empty():
		SparklingEditorUtils.add_empty_placeholder(list_container, "(No items)")
		return

	# Create a row for each item
	for item_id: String in _current_inventory_items:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Try to get item display name from registry
		var display_name: String = item_id
		var item: ItemData = null
		if ModLoader and ModLoader.registry:
			item = ModLoader.registry.get_item(item_id)
			if item:
				display_name = item.item_name if not item.item_name.is_empty() else item_id

		# Item icon (if available)
		if item and item.icon:
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.texture = item.icon
			icon_rect.custom_minimum_size = Vector2(24, 24)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon_rect)

		# Item name label
		var name_label: Label = Label.new()
		name_label.text = display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if item:
			# Add item type to tooltip
			var type_name: String = ItemData.ItemType.keys()[item.item_type]
			name_label.tooltip_text = "%s (%s)" % [item_id, type_name]
		else:
			name_label.tooltip_text = item_id
			name_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))  # Orange for missing
		row.add_child(name_label)

		# Remove button
		var remove_btn: Button = Button.new()
		remove_btn.text = "x"
		remove_btn.tooltip_text = "Remove from inventory"
		remove_btn.custom_minimum_size.x = 24
		remove_btn.pressed.connect(_on_remove_item.bind(item_id))
		row.add_child(remove_btn)

		list_container.add_child(row)
