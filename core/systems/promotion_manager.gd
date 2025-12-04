extends Node

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
signal promotion_available(unit: Node2D)

## Emitted when promotion process begins (before stat changes).
## @param unit: Unit being promoted
## @param old_class: Previous ClassData
## @param new_class: Target ClassData
signal promotion_started(unit: Node2D, old_class: Resource, new_class: Resource)

## Emitted when promotion completes successfully.
## @param unit: Unit that was promoted
## @param old_class: Previous ClassData
## @param new_class: New ClassData
## @param stat_changes: Dictionary of changes {stat_name: bonus_amount}
signal promotion_completed(unit: Node2D, old_class: Resource, new_class: Resource, stat_changes: Dictionary)

## Emitted when promotion is cancelled (user backed out).
## @param unit: Unit that was going to promote
signal promotion_cancelled(unit: Node2D)

## Emitted when equipment must be unequipped due to class incompatibility.
## @param unit: Unit losing equipment
## @param items: Array of ItemData that were unequipped
signal equipment_unequipped(unit: Node2D, items: Array)


# ============================================================================
# CONFIGURATION
# ============================================================================

## Reference to ExperienceConfig for promotion bonuses.
## Set automatically from ExperienceManager.
var _experience_config: ExperienceConfig = null


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get config from ExperienceManager when available
	call_deferred("_connect_to_experience_manager")


func _connect_to_experience_manager() -> void:
	if ExperienceManager and ExperienceManager.config:
		_experience_config = ExperienceManager.config


# ============================================================================
# ELIGIBILITY CHECKS
# ============================================================================

## Check if a unit can promote.
## Returns true if unit meets level requirement and has a promotion path.
## @param unit: Unit to check
## @return: true if promotion is available
func can_promote(unit: Node2D) -> bool:
	if not _validate_unit(unit):
		return false

	var class_data: ClassData = _get_unit_class(unit)
	if not class_data:
		return false

	# Must have at least one promotion path
	if not class_data.promotion_class:
		return false

	# Check level requirement
	var required_level: int = _get_promotion_level(class_data)
	return unit.stats.level >= required_level


## Check if a unit has reached promotion level but hasn't promoted yet.
## Used by ExperienceManager to emit promotion_available signal.
## @param unit: Unit to check
## @return: true if just became eligible
func check_promotion_eligibility(unit: Node2D) -> bool:
	if can_promote(unit):
		promotion_available.emit(unit)
		return true
	return false


## Get the level required for promotion.
## Uses class-specific level if set, otherwise falls back to config default.
## @param class_data: ClassData to check
## @return: Required level for promotion
func _get_promotion_level(class_data: ClassData) -> int:
	if class_data.promotion_level > 0:
		return class_data.promotion_level

	# Fallback to global config
	if _experience_config and "promotion_level" in _experience_config:
		return _experience_config.promotion_level

	# Default if no config
	return 10


# ============================================================================
# PROMOTION PATHS
# ============================================================================

## Get all available promotion paths for a unit.
## Returns standard promotion plus special promotion if item requirements are met.
## @param unit: Unit to get promotions for
## @return: Array of ClassData options
func get_available_promotions(unit: Node2D) -> Array[ClassData]:
	var promotions: Array[ClassData] = []

	if not _validate_unit(unit):
		return promotions

	var class_data: ClassData = _get_unit_class(unit)
	if not class_data:
		return promotions

	# Standard promotion path
	if class_data.promotion_class:
		promotions.append(class_data.promotion_class)

	# Special promotion path (requires item)
	if _has_special_promotion(class_data):
		if has_item_for_special_promotion(unit, class_data):
			promotions.append(class_data.special_promotion_class)

	return promotions


## Check if unit has the required item for special promotion.
## @param unit: Unit to check inventory
## @param class_data: ClassData with special promotion requirements
## @return: true if item is available
func has_item_for_special_promotion(unit: Node2D, class_data: ClassData = null) -> bool:
	if class_data == null:
		class_data = _get_unit_class(unit)

	if not class_data:
		return false

	if not _has_special_promotion(class_data):
		return false

	var required_item: Resource = class_data.special_promotion_item
	if not required_item:
		# Special promotion exists but no item required
		return true

	# TODO: Check party inventory for the item when inventory system is implemented
	# For now, check if PartyManager has the item
	if PartyManager.has_method("has_item"):
		return PartyManager.has_item(required_item)

	# Fallback: assume item is available (for testing)
	push_warning("PromotionManager: Inventory system not implemented, assuming special promotion item available")
	return true


## Check if class has a special promotion path defined.
## @param class_data: ClassData to check
## @return: true if special_promotion_class is set
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
func execute_promotion(unit: Node2D, target_class: ClassData) -> Dictionary:
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

	# Consume special promotion item if applicable
	if _is_special_promotion(old_class, target_class):
		_consume_promotion_item(unit, old_class)

	# Store cumulative level before reset
	var cumulative_before: int = _get_cumulative_level(unit)
	var current_level: int = unit.stats.level

	# Apply promotion stat bonuses
	stat_changes = _calculate_promotion_bonuses()
	_apply_stat_bonuses(unit, stat_changes)

	# Update class reference
	_set_unit_class(unit, target_class)

	# Reset level to 1 (SF2-style)
	if _should_reset_level():
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
func preview_promotion(unit: Node2D, target_class: ClassData) -> Dictionary:
	var preview: Dictionary = {
		"valid": false,
		"old_class_name": "",
		"new_class_name": "",
		"stat_bonuses": {},
		"equipment_conflicts": [],
		"level_reset": _should_reset_level(),
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
	preview["stat_bonuses"] = _calculate_promotion_bonuses()
	preview["is_special_promotion"] = _is_special_promotion(old_class, target_class)

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
func _check_equipment_compatibility(unit: Node2D, new_class: ClassData) -> Array:
	var unequipped: Array = []

	# TODO: Implement when equipment system is complete
	# For now, return empty array
	var conflicts: Array = _get_equipment_conflicts(unit, new_class)

	for i in range(conflicts.size()):
		var item: Resource = conflicts[i]
		# Unequip item and move to inventory
		# PartyManager.unequip_item(unit, item)
		# PartyManager.add_to_inventory(item)
		unequipped.append(item)

	return unequipped


## Get list of equipped items incompatible with new class.
## @param unit: Unit to check
## @param new_class: Target class
## @return: Array of conflicting ItemData
func _get_equipment_conflicts(unit: Node2D, new_class: ClassData) -> Array:
	var conflicts: Array = []

	# TODO: Implement when equipment system is complete
	# Check each equipped item against new class restrictions
	# if unit.has_method("get_equipped_items"):
	#     for item in unit.get_equipped_items():
	#         if item.item_type == ItemData.ItemType.WEAPON:
	#             if not new_class.can_equip_weapon(item.equipment_type):
	#                 conflicts.append(item)
	#         elif item.item_type == ItemData.ItemType.ARMOR:
	#             if not new_class.can_equip_armor(item.equipment_type):
	#                 conflicts.append(item)

	return conflicts


# ============================================================================
# STAT BONUSES
# ============================================================================

## Calculate promotion stat bonuses from config.
## @return: Dictionary of stat bonuses {stat_name: bonus_value}
func _calculate_promotion_bonuses() -> Dictionary:
	var bonuses: Dictionary = {}

	if not _experience_config:
		return bonuses

	# Check for promotion bonus properties in config
	var bonus_stats: Array[String] = ["hp", "mp", "strength", "defense", "agility", "intelligence", "luck"]

	for stat in bonus_stats:
		var config_key: String = "promotion_bonus_" + stat
		if config_key in _experience_config:
			var bonus: int = _experience_config.get(config_key)
			if bonus > 0:
				bonuses[stat] = bonus

	return bonuses


## Apply stat bonuses to unit.
## @param unit: Unit to modify
## @param bonuses: Dictionary of stat bonuses
func _apply_stat_bonuses(unit: Node2D, bonuses: Dictionary) -> void:
	if not unit.stats:
		return

	for stat_name: String in bonuses.keys():
		var bonus: int = bonuses[stat_name]

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
func _validate_unit(unit: Node2D) -> bool:
	if unit == null:
		return false
	if unit.stats == null:
		return false
	if unit.character_data == null:
		return false
	return true


## Get unit's current class.
## Checks CharacterSaveData first (for promoted characters), then falls back to CharacterData.
func _get_unit_class(unit: Node2D) -> ClassData:
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
func _set_unit_class(unit: Node2D, new_class: ClassData) -> void:
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if not save_data:
		push_error("PromotionManager: Cannot set class - no CharacterSaveData for unit '%s'" % unit.get_display_name())
		return

	save_data.set_current_class(new_class)

	# Also update the Unit's stats to reference the new class
	if unit.stats:
		unit.stats.class_data = new_class


## Get CharacterSaveData for a unit from PartyManager.
## @param unit: The unit to get save data for
## @return: CharacterSaveData or null if not found
func _get_unit_save_data(unit: Node2D) -> CharacterSaveData:
	if not unit.character_data:
		return null

	var character_uid: String = unit.character_data.character_uid
	if character_uid.is_empty():
		push_warning("PromotionManager: Unit '%s' has no character_uid" % unit.get_display_name())
		return null

	return PartyManager.get_member_save_data(character_uid)


## Check if promotion is to special class (not standard path).
func _is_special_promotion(old_class: ClassData, target_class: ClassData) -> bool:
	if not old_class:
		return false
	if not _has_special_promotion(old_class):
		return false
	return target_class == old_class.special_promotion_class


## Consume the special promotion item from inventory.
func _consume_promotion_item(unit: Node2D, class_data: ClassData) -> void:
	if not _experience_config:
		return

	# Check if config says to consume item
	var consume: bool = true
	if "consume_promotion_item" in _experience_config:
		consume = _experience_config.consume_promotion_item

	if not consume:
		return

	var item: Resource = class_data.special_promotion_item
	if item and PartyManager.has_method("remove_item"):
		PartyManager.remove_item(item)


## Check if level should reset on promotion.
func _should_reset_level() -> bool:
	if _experience_config and "promotion_resets_level" in _experience_config:
		return _experience_config.promotion_resets_level
	return true  # Default SF2 behavior


## Get cumulative level from unit's save data.
func _get_cumulative_level(unit: Node2D) -> int:
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if save_data:
		return save_data.cumulative_level

	# Fallback: return current level if no save data
	if unit.stats:
		return unit.stats.level
	return 1


## Set cumulative level in unit's save data.
func _set_cumulative_level(unit: Node2D, total: int) -> void:
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if save_data:
		save_data.cumulative_level = total


## Increment promotion count for unit.
func _increment_promotion_count(unit: Node2D) -> void:
	var save_data: CharacterSaveData = _get_unit_save_data(unit)
	if save_data:
		save_data.promotion_count += 1
		save_data.is_promoted = true
