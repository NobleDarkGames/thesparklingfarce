class_name EquipmentSlotRegistry
extends RefCounted

## Data-driven equipment slot registry
## Allows mods to define custom slot layouts via mod.json
##
## Default SF-style layout: weapon, ring_1, ring_2, accessory
## Total conversion mods can replace with: helmet, armor, main_hand, off_hand, etc.
##
## Slot format: {id: String, display_name: String, accepts_types: Array[String]}
##
## ARCHITECTURE NOTE (TODO): The current system requires slots to explicitly list all
## accepted equipment subtypes (sword, axe, etc.). A planned improvement is to add an
## EquipmentTypeRegistry that maps subtypes to categories (sword -> weapon category),
## allowing slots to accept categories instead. This would let modders register new
## weapon types without modifying slot definitions. See design discussion in
## docs/design/inventory-equipment-analysis.md for the full plan.

const DEFAULT_SLOTS: Array[Dictionary] = [
	{"id": "weapon", "display_name": "Weapon", "accepts_types": ["weapon", "sword", "axe", "lance", "spear", "bow", "staff", "tome", "knife", "dagger"]},
	{"id": "ring_1", "display_name": "Ring 1", "accepts_types": ["ring"]},
	{"id": "ring_2", "display_name": "Ring 2", "accepts_types": ["ring"]},
	{"id": "accessory", "display_name": "Accessory", "accepts_types": ["accessory"]}
]

var _slots: Array[Dictionary] = []
var _slot_source_mod: String = ""


## Register a complete slot layout from a mod
## Higher priority mods completely replace lower priority layouts
func register_slot_layout(mod_id: String, slots: Array) -> void:
	var typed_slots: Array[Dictionary] = []
	for slot: Variant in slots:
		if slot is Dictionary:
			var slot_dict: Dictionary = slot as Dictionary
			# Validate required fields
			if "id" in slot_dict and "display_name" in slot_dict:
				var validated: Dictionary = {
					"id": str(slot_dict.get("id", "")).to_lower(),
					"display_name": str(slot_dict.get("display_name", "")),
					"accepts_types": []
				}
				# Parse accepts_types array
				if "accepts_types" in slot_dict and slot_dict.accepts_types is Array:
					var types_array: Array[String] = []
					for t: Variant in slot_dict.accepts_types:
						types_array.append(str(t).to_lower())
					validated.accepts_types = types_array
				typed_slots.append(validated)

	if not typed_slots.is_empty():
		_slots = typed_slots
		_slot_source_mod = mod_id


## Get the active slot layout (defaults if none registered)
func get_slots() -> Array[Dictionary]:
	if _slots.is_empty():
		return DEFAULT_SLOTS.duplicate(true)
	return _slots.duplicate(true)


## Get slot count
func get_slot_count() -> int:
	return get_slots().size()


## Get slot by ID
## Returns empty Dictionary if not found
func get_slot(slot_id: String) -> Dictionary:
	var lower_id: String = slot_id.to_lower()
	for slot: Dictionary in get_slots():
		if slot.get("id", "") == lower_id:
			return slot.duplicate()
	return {}


## Check if a slot ID is valid
func is_valid_slot(slot_id: String) -> bool:
	return not get_slot(slot_id).is_empty()


## Check if an item type can go in a slot
func slot_accepts_type(slot_id: String, item_type: String) -> bool:
	var slot: Dictionary = get_slot(slot_id)
	if slot.is_empty():
		return false
	var accepts: Array = slot.get("accepts_types", [])
	return item_type.to_lower() in accepts


## Get display name for a slot
func get_slot_display_name(slot_id: String) -> String:
	var slot: Dictionary = get_slot(slot_id)
	if slot.is_empty():
		return slot_id.capitalize()
	return slot.get("display_name", slot_id.capitalize())


## Get all slot IDs
func get_slot_ids() -> Array[String]:
	var ids: Array[String] = []
	for slot: Dictionary in get_slots():
		if "id" in slot:
			ids.append(slot.id)
	return ids


## Get slots that accept a specific item type (for UI dropdowns)
## Returns array of slot IDs
func get_slots_for_type(item_type: String) -> Array[String]:
	var matching: Array[String] = []
	var lower_type: String = item_type.to_lower()
	for slot: Dictionary in get_slots():
		var accepts: Array = slot.get("accepts_types", [])
		if lower_type in accepts:
			matching.append(slot.get("id", ""))
	return matching


## Get which mod provided the current slot layout
func get_source_mod() -> String:
	if _slot_source_mod.is_empty():
		return "base"
	return _slot_source_mod


## Clear mod registrations (called on full mod reload)
func clear_mod_registrations() -> void:
	_slots.clear()
	_slot_source_mod = ""
