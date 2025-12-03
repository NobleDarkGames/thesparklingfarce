extends Node

## EquipmentManager - Autoload singleton for equipment operations
##
## Handles equip/unequip operations, curse mechanics, and class restrictions.
## Emits signals for mod reactivity and provides custom validation hooks.
##
## Usage:
##   EquipmentManager.equip_item(save_data, "weapon", "bronze_sword")
##   EquipmentManager.can_equip(save_data, "weapon", "steel_axe")


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when an item is successfully equipped
signal item_equipped(character_uid: String, slot_id: String, item_id: String, old_item_id: String)

## Emitted when an item is unequipped (includes moving to inventory)
signal item_unequipped(character_uid: String, slot_id: String, item_id: String)

## Emitted when a curse is applied (cursed item equipped)
signal curse_applied(character_uid: String, slot_id: String, item_id: String)

## Emitted when a curse is removed
signal curse_removed(character_uid: String, slot_id: String, item_id: String)

## Emitted before equip for custom mod validation
## Mods connect to this and can set result.can_equip = false with a reason
signal custom_equip_validation(context: Dictionary, result: Dictionary)

## Emitted before equip (can be cancelled by setting context.cancel = true)
signal pre_equip(context: Dictionary)

## Emitted after successful equip
signal post_equip(context: Dictionary)


# =============================================================================
# PUBLIC API - EQUIP/UNEQUIP
# =============================================================================

## Equip an item to a character's slot
## Returns: {success: bool, error: String, unequipped_item_id: String}
##
## @param save_data: CharacterSaveData to modify
## @param slot_id: Target slot (e.g., "weapon", "ring_1")
## @param item_id: Item ID to equip (empty string to unequip)
## @param unit: Optional Unit node to refresh equipment cache
func equip_item(
	save_data: CharacterSaveData,
	slot_id: String,
	item_id: String,
	unit: Node2D = null
) -> Dictionary:
	if not save_data:
		return {success = false, error = "Invalid save data", unequipped_item_id = ""}

	# Build context for signals
	var context: Dictionary = {
		"save_data": save_data,
		"slot_id": slot_id,
		"item_id": item_id,
		"unit": unit,
		"cancel": false,
		"cancel_reason": ""
	}

	# Emit pre_equip - mods can cancel
	pre_equip.emit(context)
	if context.cancel:
		return {success = false, error = context.cancel_reason, unequipped_item_id = ""}

	# If item_id is empty, this is an unequip operation
	if item_id.is_empty():
		return _unequip_slot(save_data, slot_id, unit)

	# Validate the equip operation
	var validation: Dictionary = can_equip(save_data, slot_id, item_id)
	if not validation.can_equip:
		return {success = false, error = validation.reason, unequipped_item_id = ""}

	# Get the old item in this slot (if any)
	var old_item_id: String = get_equipped_item_id(save_data, slot_id)
	var old_item_data: ItemData = _get_item_data(old_item_id) if not old_item_id.is_empty() else null

	# Check if old item is cursed and not broken
	if old_item_data and old_item_data.is_cursed:
		var old_entry: Dictionary = _get_equipped_entry(save_data, slot_id)
		if not old_entry.get("curse_broken", false):
			return {success = false, error = "Cannot replace cursed item", unequipped_item_id = ""}

	# Perform the equip
	var mod_id: String = _get_item_mod_id(item_id)
	var new_entry: Dictionary = {
		"slot": slot_id,
		"mod_id": mod_id,
		"item_id": item_id,
		"curse_broken": false
	}

	# Update or add the equipped item entry
	var found: bool = false
	for i in range(save_data.equipped_items.size()):
		if save_data.equipped_items[i].get("slot", "") == slot_id:
			save_data.equipped_items[i] = new_entry
			found = true
			break

	if not found:
		save_data.equipped_items.append(new_entry)

	# Refresh unit cache if provided
	if unit and unit.has_method("refresh_equipment_cache"):
		unit.refresh_equipment_cache()

	# Emit signals
	item_equipped.emit(
		save_data.character_resource_id,
		slot_id,
		item_id,
		old_item_id
	)
	context.old_item_id = old_item_id
	post_equip.emit(context)

	# Check for curse
	var new_item: ItemData = _get_item_data(item_id)
	if new_item and new_item.is_cursed:
		curse_applied.emit(save_data.character_resource_id, slot_id, item_id)

	return {success = true, error = "", unequipped_item_id = old_item_id}


## Unequip an item from a slot (convenience wrapper)
## Returns: {success: bool, error: String, unequipped_item_id: String}
func unequip_item(
	save_data: CharacterSaveData,
	slot_id: String,
	unit: Node2D = null
) -> Dictionary:
	return _unequip_slot(save_data, slot_id, unit)


## Internal unequip implementation
func _unequip_slot(
	save_data: CharacterSaveData,
	slot_id: String,
	unit: Node2D = null
) -> Dictionary:
	var old_item_id: String = get_equipped_item_id(save_data, slot_id)

	if old_item_id.is_empty():
		return {success = true, error = "", unequipped_item_id = ""}

	# Check if item is cursed
	var old_item: ItemData = _get_item_data(old_item_id)
	if old_item and old_item.is_cursed:
		var old_entry: Dictionary = _get_equipped_entry(save_data, slot_id)
		if not old_entry.get("curse_broken", false):
			return {success = false, error = "Cannot unequip cursed item", unequipped_item_id = ""}

	# Remove the entry from equipped_items
	for i in range(save_data.equipped_items.size() - 1, -1, -1):
		if save_data.equipped_items[i].get("slot", "") == slot_id:
			save_data.equipped_items.remove_at(i)
			break

	# Refresh unit cache if provided
	if unit and unit.has_method("refresh_equipment_cache"):
		unit.refresh_equipment_cache()

	# Emit signal
	item_unequipped.emit(save_data.character_resource_id, slot_id, old_item_id)

	return {success = true, error = "", unequipped_item_id = old_item_id}


# =============================================================================
# PUBLIC API - VALIDATION
# =============================================================================

## Check if a character can equip an item in a specific slot
## Returns: {can_equip: bool, reason: String}
func can_equip(
	save_data: CharacterSaveData,
	slot_id: String,
	item_id: String
) -> Dictionary:
	var result: Dictionary = {can_equip = true, reason = ""}

	# Check if slot is valid
	if not ModLoader.equipment_slot_registry.is_valid_slot(slot_id):
		result.can_equip = false
		result.reason = "Invalid equipment slot"
		return result

	# Get item data
	var item: ItemData = _get_item_data(item_id)
	if not item:
		result.can_equip = false
		result.reason = "Item not found"
		return result

	# Check if item is equippable
	if not item.is_equippable():
		result.can_equip = false
		result.reason = "Item cannot be equipped"
		return result

	# Check slot accepts this item type
	if not ModLoader.equipment_slot_registry.slot_accepts_type(slot_id, item.equipment_type):
		result.can_equip = false
		result.reason = "Item type not compatible with slot"
		return result

	# Check class restrictions
	var class_result: Dictionary = _check_class_restrictions(save_data, item)
	if not class_result.can_equip:
		return class_result

	# Check if current slot item is cursed
	var current_item_id: String = get_equipped_item_id(save_data, slot_id)
	if not current_item_id.is_empty():
		var current_item: ItemData = _get_item_data(current_item_id)
		if current_item and current_item.is_cursed:
			var entry: Dictionary = _get_equipped_entry(save_data, slot_id)
			if not entry.get("curse_broken", false):
				result.can_equip = false
				result.reason = "Slot contains cursed item"
				return result

	# Custom validation hook - mods can add level requirements, quest prereqs, etc.
	var context: Dictionary = {
		"save_data": save_data,
		"slot_id": slot_id,
		"item_id": item_id,
		"item_data": item
	}
	custom_equip_validation.emit(context, result)

	return result


## Check class equipment restrictions
func _check_class_restrictions(save_data: CharacterSaveData, item: ItemData) -> Dictionary:
	var result: Dictionary = {can_equip = true, reason = ""}

	# Get current class data
	var class_data: ClassData = _get_current_class(save_data)
	if not class_data:
		# No class restrictions if class can't be found
		return result

	# Check weapon type restrictions
	if item.item_type == ItemData.ItemType.WEAPON:
		if not class_data.equippable_weapon_types.is_empty():
			var item_weapon_type: String = item.equipment_type.to_lower()
			var can_equip_weapon: bool = false
			for allowed_type: String in class_data.equippable_weapon_types:
				if allowed_type.to_lower() == item_weapon_type:
					can_equip_weapon = true
					break
			if not can_equip_weapon:
				result.can_equip = false
				result.reason = "%s cannot equip %s weapons" % [class_data.display_name, item.equipment_type]
				return result

	return result


# =============================================================================
# PUBLIC API - CURSE MECHANICS
# =============================================================================

## Attempt to remove a curse using a specified method
## Methods: "church", "item", or custom mod-defined methods
##
## @param save_data: Character with cursed equipment
## @param slot_id: Slot containing cursed item
## @param method: Uncurse method ("church", "item", or custom)
## @param context: Additional context (e.g., {item_id: "purify_scroll"} for item method)
## Returns: {success: bool, error: String}
func attempt_uncurse(
	save_data: CharacterSaveData,
	slot_id: String,
	method: String,
	context: Dictionary = {}
) -> Dictionary:
	var item_id: String = get_equipped_item_id(save_data, slot_id)
	if item_id.is_empty():
		return {success = false, error = "No item in slot"}

	var item: ItemData = _get_item_data(item_id)
	if not item:
		return {success = false, error = "Item not found"}

	if not item.is_cursed:
		return {success = false, error = "Item is not cursed"}

	var entry: Dictionary = _get_equipped_entry(save_data, slot_id)
	if entry.get("curse_broken", false):
		return {success = false, error = "Curse already broken"}

	# Validate uncurse method
	match method:
		"church":
			# Church can always uncurse
			pass
		"item":
			# Check if the specified item can uncurse this curse
			var uncurse_item_id: String = context.get("item_id", "")
			if uncurse_item_id.is_empty():
				return {success = false, error = "No uncurse item specified"}
			if not item.can_uncurse_with(uncurse_item_id):
				return {success = false, error = "Item cannot remove this curse"}
		_:
			# Allow custom methods - mods can handle via signals
			pass

	# Mark curse as broken
	for i in range(save_data.equipped_items.size()):
		if save_data.equipped_items[i].get("slot", "") == slot_id:
			save_data.equipped_items[i]["curse_broken"] = true
			break

	# Emit signal
	curse_removed.emit(save_data.character_resource_id, slot_id, item_id)

	return {success = true, error = ""}


## Check if a slot contains a cursed item that hasn't been broken
func is_slot_cursed(save_data: CharacterSaveData, slot_id: String) -> bool:
	var item_id: String = get_equipped_item_id(save_data, slot_id)
	if item_id.is_empty():
		return false

	var item: ItemData = _get_item_data(item_id)
	if not item or not item.is_cursed:
		return false

	var entry: Dictionary = _get_equipped_entry(save_data, slot_id)
	return not entry.get("curse_broken", false)


# =============================================================================
# PUBLIC API - QUERIES
# =============================================================================

## Get the item ID equipped in a specific slot
func get_equipped_item_id(save_data: CharacterSaveData, slot_id: String) -> String:
	var entry: Dictionary = _get_equipped_entry(save_data, slot_id)
	return entry.get("item_id", "")


## Get all equipped items as ItemData references
## Returns: {slot_id: ItemData or null}
func get_equipped_items(save_data: CharacterSaveData) -> Dictionary:
	var items: Dictionary = {}
	for entry: Dictionary in save_data.equipped_items:
		var slot: String = entry.get("slot", "")
		var item_id: String = entry.get("item_id", "")
		if not slot.is_empty() and not item_id.is_empty():
			items[slot] = _get_item_data(item_id)
	return items


## Calculate total stat bonus from all equipped items
func get_total_equipment_bonus(save_data: CharacterSaveData, stat_name: String) -> int:
	var total: int = 0
	for entry: Dictionary in save_data.equipped_items:
		var item_id: String = entry.get("item_id", "")
		if not item_id.is_empty():
			var item: ItemData = _get_item_data(item_id)
			if item:
				total += item.get_stat_modifier(stat_name)
	return total


## Get equipped weapon data (for combat calculations)
func get_equipped_weapon(save_data: CharacterSaveData) -> ItemData:
	var weapon_id: String = get_equipped_item_id(save_data, "weapon")
	if weapon_id.is_empty():
		return null
	return _get_item_data(weapon_id)


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

## Get the equipped item entry for a slot
func _get_equipped_entry(save_data: CharacterSaveData, slot_id: String) -> Dictionary:
	for entry: Dictionary in save_data.equipped_items:
		if entry.get("slot", "") == slot_id:
			return entry
	return {}


## Get ItemData from registry
func _get_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	return ModLoader.registry.get_resource("item", item_id) as ItemData


## Get current class data for a character
func _get_current_class(save_data: CharacterSaveData) -> ClassData:
	# Try to get from current_class fields (post-promotion)
	if not save_data.current_class_resource_id.is_empty():
		return ModLoader.registry.get_resource("class", save_data.current_class_resource_id) as ClassData

	# Fall back to base character's class
	var character: CharacterData = ModLoader.registry.get_resource(
		"character",
		save_data.character_resource_id
	) as CharacterData
	if character:
		return character.character_class

	return null


## Get mod ID for an item (tries to find it in registry)
func _get_item_mod_id(item_id: String) -> String:
	# For now, return empty string - ModRegistry tracks this internally
	# The proper way would be to query the registry, but equipped_items
	# format already includes mod_id from the original registration
	return ""
