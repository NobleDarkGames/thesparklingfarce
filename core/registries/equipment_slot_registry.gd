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
## accepts_types supports category wildcards via EquipmentTypeRegistry:
##   - "weapon:*" matches ANY subtype in the "weapon" category (sword, axe, bow, etc.)
##   - "sword" matches ONLY the literal "sword" subtype
##   - Category wildcards require EquipmentTypeRegistry to be populated from mod.json

const DEFAULT_SLOTS: Array[Dictionary] = [
	{"id": "weapon", "display_name": "Weapon", "accepts_types": ["weapon:*"]},
	{"id": "ring_1", "display_name": "Ring 1", "accepts_types": ["accessory:*"]},
	{"id": "ring_2", "display_name": "Ring 2", "accepts_types": ["accessory:*"]},
	{"id": "accessory", "display_name": "Accessory", "accepts_types": ["accessory:*"]}
]

var _slots: Array[Dictionary] = []
var _slot_source_mod: String = ""

## O(1) lookup cache: {slot_id: Dictionary}
var _slot_by_id: Dictionary = {}

## Emitted when registrations change (for editor refresh)
signal registrations_changed()


## Register a complete slot layout from a mod
## Higher priority mods completely replace lower priority layouts
func register_slot_layout(mod_id: String, slots: Array) -> void:
	var typed_slots: Array[Dictionary] = []
	for slot: Variant in slots:
		if slot is Dictionary:
			var slot_dict: Dictionary = slot
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
		_rebuild_slot_cache()
		registrations_changed.emit()


## Get the active slot layout (defaults if none registered)
func get_slots() -> Array[Dictionary]:
	if _slots.is_empty():
		return DEFAULT_SLOTS.duplicate(true)
	return _slots.duplicate(true)


## Get slot count (O(1) - no deep copy)
func get_slot_count() -> int:
	if _slots.is_empty():
		return DEFAULT_SLOTS.size()
	return _slots.size()


## Get slot by ID (O(1) lookup via cache)
## Returns empty Dictionary if not found
func get_slot(slot_id: String) -> Dictionary:
	var lower_id: String = slot_id.to_lower()
	# Use cache if slots are registered
	if not _slots.is_empty():
		if lower_id in _slot_by_id:
			var slot: Dictionary = _slot_by_id[lower_id]
			return slot.duplicate()
		return {}
	# Fall back to defaults
	for slot: Dictionary in DEFAULT_SLOTS:
		if slot.get("id", "") == lower_id:
			return slot.duplicate()
	return {}


## Check if a slot ID is valid (O(1) lookup)
func is_valid_slot(slot_id: String) -> bool:
	var lower_id: String = slot_id.to_lower()
	if not _slots.is_empty():
		return lower_id in _slot_by_id
	# Check defaults
	for slot: Dictionary in DEFAULT_SLOTS:
		if slot.get("id", "") == lower_id:
			return true
	return false


## Check if an item type can go in a slot (O(1) slot lookup)
## Supports category wildcards via EquipmentTypeRegistry (e.g., "weapon:*" matches any weapon subtype)
func slot_accepts_type(slot_id: String, item_type: String) -> bool:
	var lower_id: String = slot_id.to_lower()
	var slot: Dictionary = {}
	# Use cache for O(1) lookup
	if not _slots.is_empty():
		if lower_id in _slot_by_id:
			slot = _slot_by_id[lower_id]
	else:
		for default_slot: Dictionary in DEFAULT_SLOTS:
			if default_slot.get("id", "") == lower_id:
				slot = default_slot
				break
	if slot.is_empty():
		return false

	var accepts: Array = slot.get("accepts_types", [])
	var lower_type: String = item_type.to_lower()

	# Check each accept entry (may include wildcards like "weapon:*")
	for accept_entry: Variant in accepts:
		var accept_str: String = str(accept_entry).to_lower()

		# Try to use EquipmentTypeRegistry for wildcard matching
		if ModLoader and ModLoader.equipment_type_registry:
			if ModLoader.equipment_type_registry.matches_accept_type(lower_type, accept_str):
				return true
		else:
			# Fallback: direct match only (no wildcard support)
			if lower_type == accept_str:
				return true

	return false


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
			var slot_id: String = slot.get("id", "")
			ids.append(slot_id)
	return ids


## Get slots that accept a specific item type (for UI dropdowns)
## Returns array of slot IDs
func get_slots_for_type(item_type: String) -> Array[String]:
	var matching: Array[String] = []
	var lower_type: String = item_type.to_lower()
	for slot: Dictionary in get_slots():
		if slot_accepts_type(slot.get("id", ""), lower_type):
			matching.append(slot.get("id", ""))
	return matching


## Get which mod provided the current slot layout
func get_source_mod() -> String:
	if _slot_source_mod.is_empty():
		return "base"
	return _slot_source_mod


## Unregister slot layout from a specific mod
func unregister_mod(mod_id: String) -> void:
	if _slot_source_mod == mod_id:
		_slots.clear()
		_slot_by_id.clear()
		_slot_source_mod = ""
		registrations_changed.emit()


## Clear mod registrations (called on full mod reload)
func clear_mod_registrations() -> void:
	_slots.clear()
	_slot_by_id.clear()
	_slot_source_mod = ""
	registrations_changed.emit()


## Get registration stats for debugging
func get_stats() -> Dictionary:
	return {
		"slot_count": get_slot_count(),
		"slot_ids": get_slot_ids(),
		"source_mod": get_source_mod()
	}


## Rebuild the slot lookup cache
func _rebuild_slot_cache() -> void:
	_slot_by_id.clear()
	for slot: Dictionary in _slots:
		var slot_id: String = slot.get("id", "")
		if not slot_id.is_empty():
			_slot_by_id[slot_id] = slot
