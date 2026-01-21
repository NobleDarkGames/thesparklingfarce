extends Node

const UnitUtils = preload("res://core/utils/unit_utils.gd")

## PromotionManager - Central system for class promotion mechanics
##
## Autoload singleton responsible for:
## - Checking promotion eligibility based on level and class data
## - Managing standard and special (item-gated) promotion paths
## - Executing promotions with stat preservation and optional bonuses
## - Coordinating with other systems (PartyManager, BattleManager) for persistence
##
## Design Philosophy:
## - SF2-style: Level resets to 1, stats carry over 100%
## - SF3-style: No delayed promotion penalty (promote ASAP is valid)
## - Branching paths via special promotion items

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a unit reaches promotion eligibility.
## UI can use this to display promotion availability indicator.
## @param unit: Unit that can now promote
signal promotion_available(unit: Unit)

## Emitted when promotion process begins (before stat changes).
## @param unit: Unit being promoted
## @param old_class: Previous ClassData
## @param new_class: Target ClassData
signal promotion_started(unit: Unit, old_class: ClassData, new_class: ClassData)

## Emitted when promotion completes successfully.
## @param unit: Unit that was promoted
## @param old_class: Previous ClassData
## @param new_class: New ClassData
## @param stat_changes: Dictionary of changes {stat_name: bonus_amount}
signal promotion_completed(unit: Unit, old_class: ClassData, new_class: ClassData, stat_changes: Dictionary)

## Emitted when promotion is cancelled (user backed out).
## @param unit: Unit that was going to promote
signal promotion_cancelled(unit: Unit)

## Emitted when equipment must be unequipped due to class incompatibility.
## @param unit: Unit losing equipment
## @param items: Array of ItemData that were unequipped
signal equipment_unequipped(unit: Unit, items: Array)


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	pass


# ============================================================================
# ELIGIBILITY CHECKS
# ============================================================================

## Check if a unit can promote.
## Returns true if unit meets level requirement and has a promotion path.
## @param unit: Unit to check
## @return: true if promotion is available
func can_promote(unit: Unit) -> bool:
	if not _validate_unit(unit):
		return false

	var class_data: ClassData = _get_unit_class(unit)
	if not class_data:
		return false

	# Must have at least one promotion path
	if not class_data.can_promote():
		return false

	# Check level requirement
	var required_level: int = _get_promotion_level(class_data)
	return unit.stats.level >= required_level


## Check if a unit has reached promotion level but hasn't promoted yet.
## Used by ExperienceManager to emit promotion_available signal.
## @param unit: Unit to check
## @return: true if just became eligible
func check_promotion_eligibility(unit: Unit) -> bool:
	if can_promote(unit):
		promotion_available.emit(unit)
		return true
	return false


## Get the level required for promotion.
## Uses class-specific level (defaults to 10 if not set).
## @param class_data: ClassData to check
## @return: Required level for promotion
func _get_promotion_level(class_data: ClassData) -> int:
	# ClassData.promotion_level defaults to 10, so just return it
	return class_data.promotion_level if class_data.promotion_level > 0 else 10


# ============================================================================
# PROMOTION PATHS
# ============================================================================

## Get all available promotion paths for a unit.
## Returns all paths where item requirements are met.
## @param unit: Unit to get promotions for
## @return: Array of ClassData options
func get_available_promotions(unit: Unit) -> Array[ClassData]:
	var promotions: Array[ClassData] = []

	if not _validate_unit(unit):
		return promotions

	var class_data: ClassData = _get_unit_class(unit)
	if not class_data:
		return promotions

	# Check each promotion path
	for path: PromotionPath in class_data.get_promotion_path_resources():
		if path.requires_item():
			# Item-gated path - check if player has the required item
			if _has_required_item(unit, path.required_item):
				promotions.append(path.target_class)
		else:
			# No item required - always available
			promotions.append(path.target_class)

	return promotions


## Get all promotion paths with full metadata for UI display.
## Returns paths with availability status for each.
## @param unit: Unit to get promotions for
## @return: Array of Dictionaries with path info and availability
func get_available_promotions_detailed(unit: Unit) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	if not _validate_unit(unit):
		return results

	var class_data: ClassData = _get_unit_class(unit)
	if not class_data:
		return results

	for path: PromotionPath in class_data.get_promotion_path_resources():
		var has_item: bool = true
		if path.requires_item():
			has_item = _has_required_item(unit, path.required_item)

		results.append({
			"path": path,
			"target_class": path.target_class,
			"display_name": path.get_display_name(),
			"required_item": path.required_item,
			"has_required_item": has_item,
			"is_available": has_item
		})

	return results


## Check if unit has a specific required item.
## @param unit: Unit to check (for future unit-specific inventory)
## @param required_item: ItemData to check for
## @return: true if item is available
func _has_required_item(_unit: Unit, required_item: ItemData) -> bool:
	if not required_item:
		return true

	# Check party inventory for the required item
	var hero_save: CharacterSaveData = GameState.get_hero_save_data()
	if hero_save and hero_save.inventory:
		for item_slot: String in hero_save.inventory:
			if item_slot == required_item.resource_path:
				return true
	
	# Item not found in inventory - promotion not allowed
	return false


## Check if unit has the required item for a specific promotion path.
## @param unit: Unit to check inventory
## @param target_class: The target ClassData of the promotion path
## @return: true if item is available (or no item required)
func has_item_for_promotion(unit: Unit, target_class: ClassData) -> bool:
	var class_data: ClassData = _get_unit_class(unit)
	if not class_data:
		return false

	var path: PromotionPath = class_data.get_promotion_path_for_class(target_class)
	if not path:
		return false

	if not path.requires_item():
		return true

	return _has_required_item(unit, path.required_item)


## DEPRECATED: Use has_item_for_promotion instead.
## Kept for backward compatibility.
func has_item_for_special_promotion(unit: Unit, class_data: ClassData = null) -> bool:
	var unit_class: ClassData = class_data if class_data else _get_unit_class(unit)
	if not unit_class:
		return false

	for path: PromotionPath in unit_class.get_promotion_path_resources():
		if path.requires_item() and _has_required_item(unit, path.required_item):
			return true
	return false


## Check if class has any item-gated promotion paths.
## @param class_data: ClassData to check
## @return: true if any path requires an item
func _has_special_promotion(class_data: ClassData) -> bool:
	return class_data.has_special_promotion()


# ============================================================================
# PROMOTION EXECUTION
# ============================================================================

## Execute a promotion for a unit.
## Preserves all stats, resets level to 1, applies bonuses.
## @param unit: Unit to promote
## @param target_class: ClassData to promote to
## @return: Dictionary of stat changes applied
func execute_promotion(unit: Unit, target_class: ClassData) -> Dictionary:
	var stat_changes: Dictionary = {}

	if not _validate_unit(unit):
		push_error("PromotionManager: Invalid unit for promotion")
		return stat_changes

	if not target_class:
		push_error("PromotionManager: Target class is null")
		return stat_changes

	var old_class: ClassData = _get_unit_class(unit)
	if not old_class:
		push_error("PromotionManager: Unit has no current class")
		return stat_changes

	# Validate promotion is legal
	var available: Array[ClassData] = get_available_promotions(unit)
	if target_class not in available:
		push_error("PromotionManager: Target class is not a valid promotion option")
		return stat_changes

	# Emit started signal
	promotion_started.emit(unit, old_class, target_class)

	# Check and handle equipment compatibility
	var unequipped: Array = _check_equipment_compatibility(unit, target_class)
	if not unequipped.is_empty():
		equipment_unequipped.emit(unit, unequipped)

	# Consume promotion item if applicable
	var promotion_path: PromotionPath = old_class.get_promotion_path_for_class(target_class)
	if promotion_path and promotion_path.requires_item():
		_consume_promotion_item(unit, old_class, promotion_path)

	# Store cumulative level before reset
	var cumulative_before: int = _get_cumulative_level(unit)
	var current_level: int = unit.stats.level

	# Apply promotion stat bonuses from the target class
	stat_changes = _calculate_promotion_bonuses(target_class)
	_apply_stat_bonuses(unit, stat_changes)

	# Update class reference
	_set_unit_class(unit, target_class)

	# Reset level to 1 (SF2-style)
	if _should_reset_level(target_class):
		unit.stats.level = 1
		stat_changes["level_reset"] = true

		# Also update CharacterSaveData level
		var save_data: CharacterSaveData = _get_unit_save_data(unit)
		if save_data:
			save_data.level = 1

	# Update cumulative level tracking
	_set_cumulative_level(unit, cumulative_before + current_level)

	# Increment promotion count
	_increment_promotion_count(unit)

	# Update unit visuals if sprite changes
	if unit.has_method("_update_visual"):
		unit._update_visual()

	# Emit completion signal
	promotion_completed.emit(unit, old_class, target_class, stat_changes)

	# Also emit ExperienceManager signal for compatibility
	ExperienceManager.unit_promoted.emit(unit, old_class, target_class)

	return stat_changes


## Preview promotion stat changes without applying.
## Useful for UI to show what will happen before confirming.
## @param unit: Unit to preview promotion for
## @param target_class: ClassData to preview
## @return: Dictionary describing the promotion effects
func preview_promotion(unit: Unit, target_class: ClassData) -> Dictionary:
	var preview: Dictionary = {
		"valid": false,
		"old_class_name": "",
		"new_class_name": "",
		"stat_bonuses": {},
		"equipment_conflicts": [],
		"level_reset": _should_reset_level(target_class),
		"is_special_promotion": false
	}

	if not _validate_unit(unit):
		return preview

	var old_class: ClassData = _get_unit_class(unit)
	if not old_class:
		return preview

	# Basic info
	preview["valid"] = target_class in get_available_promotions(unit)
	preview["old_class_name"] = old_class.display_name
	preview["new_class_name"] = target_class.display_name
	preview["stat_bonuses"] = _calculate_promotion_bonuses(target_class)
	preview["is_special_promotion"] = _is_item_gated_promotion(old_class, target_class)

	# Equipment compatibility check
	preview["equipment_conflicts"] = _get_equipment_conflicts(unit, target_class)

	return preview


# ============================================================================
# EQUIPMENT COMPATIBILITY
# ============================================================================

## Check equipment compatibility and unequip incompatible items.
## @param unit: Unit being promoted
## @param new_class: Target class
## @return: Array of items that were unequipped
func _check_equipment_compatibility(unit: Unit, new_class: ClassData) -> Array:
	var unequipped: Array = []

	# Get save data for unequipping
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if not save_data:
		return unequipped

	# Get conflicts and equipped items mapping
	var conflicts: Array = _get_equipment_conflicts(unit, new_class)
	var equipped_dict: Dictionary = EquipmentManager.get_equipped_items(save_data)

	# Unequip each conflicting item
	for item: ItemData in conflicts:
		# Find the slot this item is in
		for slot_id: String in equipped_dict.keys():
			var equipped_item: ItemData = equipped_dict[slot_id] as ItemData
			if equipped_item == item:
				# Unequip - item goes to inventory
				var result: Dictionary = EquipmentManager.unequip_item(save_data, slot_id, unit)
				if result.get("success", false):
					unequipped.append(item)
				break

	return unequipped


## Get list of equipped items incompatible with new class.
## @param unit: Unit to check
## @param new_class: Target class
## @return: Array of conflicting ItemData
func _get_equipment_conflicts(unit: Unit, new_class: ClassData) -> Array:
	var conflicts: Array = []
	
	# Get unit's equipped items
	var equipped_items: Array[ItemData] = _get_unit_equipped_items(unit)
	
	for item: ItemData in equipped_items:
		# Check weapon compatibility
		if item.item_type == ItemData.ItemType.WEAPON:
			if not new_class.can_equip_weapon(item.equipment_type):
				conflicts.append(item)
		# Check armor compatibility (if/when armor system is implemented)
		# elif item.item_type == ItemData.ItemType.ARMOR:
		#     if not new_class.can_equip_armor(item.armor_type):
		#         conflicts.append(item)
	
	return conflicts


## Get all equipped items from a unit.
## @param unit: Unit to query
## @return: Array of equipped ItemData
func _get_unit_equipped_items(unit: Unit) -> Array[ItemData]:
	var items: Array[ItemData] = []
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if not save_data:
		return items

	var equipped_dict: Dictionary = EquipmentManager.get_equipped_items(save_data)
	for item: Variant in equipped_dict.values():
		if item is ItemData:
			items.append(item)
	return items


# ============================================================================
# STAT BONUSES
# ============================================================================

## Calculate promotion stat bonuses from the target class.
## Promotion bonuses come from the TARGET class (the class being promoted to),
## applied instantly on promotion.
## @param target_class: The ClassData being promoted to
## @return: Dictionary of stat bonuses {stat_name: bonus_value}
func _calculate_promotion_bonuses(target_class: ClassData) -> Dictionary:
	var bonuses: Dictionary = {}

	if not target_class:
		return bonuses

	# Read promotion bonus properties from the target class
	var bonus_stats: Array[String] = ["hp", "mp", "strength", "defense", "agility", "intelligence", "luck"]

	for stat: String in bonus_stats:
		var property_key: String = "promotion_bonus_" + stat
		if property_key in target_class:
			var bonus: int = target_class.get(property_key)
			if bonus > 0:
				bonuses[stat] = bonus

	return bonuses


## Apply stat bonuses to unit.
## @param unit: Unit to modify
## @param bonuses: Dictionary of stat bonuses
func _apply_stat_bonuses(unit: Unit, bonuses: Dictionary) -> void:
	if not unit.stats:
		return

	for stat_name: String in bonuses.keys():
		var bonus_variant: Variant = bonuses[stat_name]
		# MED-006: Handle float case in bonus conversion
		var bonus: int = 0
		if bonus_variant is int:
			bonus = bonus_variant
		elif bonus_variant is float:
			bonus = int(bonus_variant)

		match stat_name:
			"hp":
				unit.stats.max_hp += bonus
				unit.stats.current_hp += bonus
			"mp":
				unit.stats.max_mp += bonus
				unit.stats.current_mp += bonus
			"strength":
				unit.stats.strength += bonus
			"defense":
				unit.stats.defense += bonus
			"agility":
				unit.stats.agility += bonus
			"intelligence":
				unit.stats.intelligence += bonus
			"luck":
				unit.stats.luck += bonus


# ============================================================================
# HELPER METHODS
# ============================================================================

## Validate unit is valid for promotion operations.
func _validate_unit(unit: Unit) -> bool:
	if unit == null:
		return false
	if unit.stats == null:
		return false
	if unit.character_data == null:
		return false
	return true


## Get unit's current class.
## Checks CharacterSaveData first (for promoted characters), then falls back to CharacterData.
func _get_unit_class(unit: Unit) -> ClassData:
	if not unit.character_data:
		return null

	# Try to get from save data first (handles promoted characters)
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if save_data:
		var current_class: ClassData = save_data.get_current_class(unit.character_data)
		if current_class:
			return current_class

	# Fallback to CharacterData's class (unpromoted or no save data)
	return unit.character_data.character_class


## Set unit's class via CharacterSaveData (does NOT mutate CharacterData template).
## @param unit: The unit being promoted
## @param new_class: The ClassData to set
func _set_unit_class(unit: Unit, new_class: ClassData) -> void:
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if not save_data:
		push_error("PromotionManager: Cannot set class - no CharacterSaveData for unit '%s'" % UnitUtils.get_display_name(unit))
		return

	save_data.set_current_class(new_class)

	# Also update the Unit's stats to reference the new class
	if unit.stats:
		unit.stats.class_data = new_class


## Get CharacterSaveData for a unit from PartyManager.
## @param unit: The unit to get save data for
## @return: CharacterSaveData or null if not found
func _get_unit_save_data(unit: Unit) -> CharacterSaveData:
	if not unit.character_data:
		return null

	var character_uid: String = unit.character_data.character_uid
	if character_uid.is_empty():
		push_warning("PromotionManager: Unit '%s' has no character_uid" % UnitUtils.get_display_name(unit))
		return null

	return PartyManager.get_member_save_data(character_uid)


## Check if a promotion path requires an item.
## @param old_class: The class being promoted from
## @param target_class: The target ClassData
## @return: true if the path requires an item
func _is_item_gated_promotion(old_class: ClassData, target_class: ClassData) -> bool:
	if not old_class:
		return false

	var path: PromotionPath = old_class.get_promotion_path_for_class(target_class)
	if not path:
		return false

	return path.requires_item()


## DEPRECATED: Use _is_item_gated_promotion instead.
func _is_special_promotion(old_class: ClassData, target_class: ClassData) -> bool:
	return _is_item_gated_promotion(old_class, target_class)


## Consume the promotion item from inventory.
## @param unit: Unit being promoted (for future unit-specific inventory)
## @param class_data: The class being promoted from
## @param path: The PromotionPath being taken
func _consume_promotion_item(_unit: Unit, class_data: ClassData, path: PromotionPath) -> void:
	# Check if class says to consume item (defaults to true)
	if not class_data.consume_promotion_item:
		return

	if not path or not path.required_item:
		return

	if PartyManager.has_method("remove_item"):
		PartyManager.remove_item(path.required_item)


## Check if level should reset on promotion.
## Uses the target class's setting (defaults to true for SF2 behavior).
func _should_reset_level(target_class: ClassData) -> bool:
	if target_class:
		return target_class.promotion_resets_level
	return true  # Default SF2 behavior


## Get cumulative level from unit's save data.
func _get_cumulative_level(unit: Unit) -> int:
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if save_data:
		return save_data.cumulative_level
	return unit.stats.level if unit.stats else 1


## Set cumulative level in unit's save data.
func _set_cumulative_level(unit: Unit, total: int) -> void:
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if save_data:
		save_data.cumulative_level = total


## Increment promotion count for unit.
func _increment_promotion_count(unit: Unit) -> void:
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if save_data:
		save_data.promotion_count += 1
		save_data.is_promoted = true
