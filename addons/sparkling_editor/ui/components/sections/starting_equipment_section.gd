@tool
class_name StartingEquipmentSection
extends EditorSectionBase

## Starting Equipment section for Character Editor
## Manages equipment the character starts with when recruited

# UI Components
var equipment_pickers: Dictionary = {}  # {slot_id: ResourcePicker}
var equipment_warning_labels: Dictionary = {}  # {slot_id: Label}


func build_ui(parent: Control) -> void:
	create_collapse_section("Starting Equipment", false)
	parent.add_child(section_root)

	var content: VBoxContainer = get_content_container()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(content)
	form.on_change(mark_dirty)
	form.add_help_text("Equipment the character starts with when recruited")

	# Get available equipment slots from registry
	var slots: Array[Dictionary] = _get_equipment_slots()

	equipment_pickers.clear()
	equipment_warning_labels.clear()

	for slot: Dictionary in slots:
		var slot_id: String = DictUtils.get_string(slot, "id", "")
		var display_name: String = DictUtils.get_string(slot, "display_name", slot_id.capitalize())
		var accepts_types: Array = DictUtils.get_array(slot, "accepts_types", [])

		# Create a container for each slot
		var slot_container: VBoxContainer = VBoxContainer.new()

		# Create the picker
		var picker: ResourcePicker = ResourcePicker.new()
		picker.resource_type = "item"
		picker.label_text = display_name + ":"
		picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
		picker.allow_none = true
		picker.none_text = "(Empty)"

		# Filter items to only show compatible types for this slot
		picker.filter_function = _create_equipment_filter(accepts_types)
		picker.resource_selected.connect(_on_equipment_selected.bind(slot_id))
		slot_container.add_child(picker)
		equipment_pickers[slot_id] = picker

		# Add warning label (hidden by default)
		var warning: Label = Label.new()
		warning.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		warning.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
		warning.visible = false
		slot_container.add_child(warning)
		equipment_warning_labels[slot_id] = warning

		content.add_child(slot_container)


func load_data() -> void:
	var character: CharacterData = get_resource() as CharacterData

	# Clear all pickers first
	for slot_id: String in equipment_pickers.keys():
		var picker: ResourcePicker = equipment_pickers[slot_id]
		picker.select_none()
		_clear_equipment_warning(slot_id)

	if not character or character.starting_equipment.is_empty():
		return

	# Map items to their slots
	for item: ItemData in character.starting_equipment:
		if not item:
			continue

		var slot_id: String = item.equipment_slot
		if slot_id.is_empty():
			# Try to infer slot from equipment type
			slot_id = _infer_slot_from_type(item.equipment_type)

		if slot_id in equipment_pickers:
			var picker: ResourcePicker = equipment_pickers[slot_id]
			picker.select_resource(item)

			# Validate class restrictions
			_validate_equipment_for_class(slot_id, item, character)


func save_data() -> void:
	var character: CharacterData = get_resource() as CharacterData
	if not character:
		return

	# Create a new array to avoid read-only state from duplicated resources
	var new_equipment: Array[ItemData] = []

	for slot_id: String in equipment_pickers.keys():
		var picker: ResourcePicker = equipment_pickers[slot_id]
		var item: ItemData = picker.get_selected_resource() as ItemData
		if item:
			new_equipment.append(item)

	character.starting_equipment = new_equipment


# =============================================================================
# HELPER METHODS
# =============================================================================

## Get equipment slots from registry with fallback
func _get_equipment_slots() -> Array[Dictionary]:
	if ModLoader and ModLoader.equipment_slot_registry:
		return ModLoader.equipment_slot_registry.get_slots()
	# Fallback to default SF-style slots
	return [
		{"id": "weapon", "display_name": "Weapon", "accepts_types": ["weapon:*"]},
		{"id": "ring_1", "display_name": "Ring 1", "accepts_types": ["accessory:*"]},
		{"id": "ring_2", "display_name": "Ring 2", "accepts_types": ["accessory:*"]},
		{"id": "accessory", "display_name": "Accessory", "accepts_types": ["accessory:*"]}
	]


## Create an equipment filter function that properly captures types by value
func _create_equipment_filter(types: Array) -> Callable:
	return func(resource: Resource) -> bool:
		var item: ItemData = resource as ItemData
		if not item:
			return false
		var eq_type: String = item.equipment_type.to_lower()
		# Use EquipmentTypeRegistry for wildcard matching
		if ModLoader and ModLoader.equipment_type_registry:
			for accept_type: Variant in types:
				if ModLoader.equipment_type_registry.matches_accept_type(eq_type, str(accept_type)):
					return true
			return false
		# Fallback: direct match only
		return eq_type in types


## Infer equipment slot from equipment type
func _infer_slot_from_type(equipment_type: String) -> String:
	var lower_type: String = equipment_type.to_lower()
	# Check registry for category-based inference
	if ModLoader and ModLoader.equipment_type_registry:
		var category: String = ModLoader.equipment_type_registry.get_category(lower_type)
		if category == "weapon":
			return "weapon"
		elif category == "accessory":
			if lower_type == "ring":
				return "ring_1"
			return "accessory"
	# Fallback matching
	match lower_type:
		"sword", "axe", "spear", "bow", "staff", "knife":
			return "weapon"
		"ring":
			return "ring_1"
		"accessory":
			return "accessory"
		_:
			return "weapon"


## Validate that equipment can be used by the character's class
func _validate_equipment_for_class(slot_id: String, item: ItemData, character: CharacterData) -> void:
	_clear_equipment_warning(slot_id)

	if not item or not character:
		return

	var class_data: ClassData = character.character_class
	if not class_data:
		return

	# Check weapon type restrictions
	if item.item_type == ItemData.ItemType.WEAPON:
		if not class_data.equippable_weapon_types.is_empty():
			var item_weapon_type: String = item.equipment_type.to_lower()
			var can_equip: bool = false
			for allowed_type: String in class_data.equippable_weapon_types:
				if allowed_type.to_lower() == item_weapon_type:
					can_equip = true
					break
			if not can_equip:
				_show_equipment_warning(
					slot_id,
					"Warning: %s cannot equip %s weapons" % [class_data.display_name, item.equipment_type]
				)
				return

	# Check if item is cursed
	if item.is_cursed:
		_show_equipment_warning(slot_id, "Note: This is a cursed item")


## Show a warning message for an equipment slot
func _show_equipment_warning(slot_id: String, message: String) -> void:
	if slot_id in equipment_warning_labels:
		var label: Label = equipment_warning_labels[slot_id]
		label.text = message
		label.visible = true


## Clear the warning for an equipment slot
func _clear_equipment_warning(slot_id: String) -> void:
	if slot_id in equipment_warning_labels:
		var label: Label = equipment_warning_labels[slot_id]
		label.text = ""
		label.visible = false


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_equipment_selected(metadata: Dictionary, slot_id: String) -> void:
	var item: ItemData = metadata.get("resource", null) as ItemData

	if item:
		var character: CharacterData = get_resource() as CharacterData
		if character:
			_validate_equipment_for_class(slot_id, item, character)
	else:
		_clear_equipment_warning(slot_id)

	mark_dirty()
