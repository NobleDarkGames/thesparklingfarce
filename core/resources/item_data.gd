class_name ItemData
extends Resource

## Represents an item in the game (weapon, armor, or consumable).
## Contains stats modifiers, usability information, and appearance.

enum ItemType {
	WEAPON,
	ARMOR,
	ACCESSORY,  ## Rings, amulets, and other accessories
	CONSUMABLE,
	KEY_ITEM
}

@export var item_name: String = ""
@export var item_type: ItemType = ItemType.WEAPON
@export var icon: Texture2D

@export_group("Equipment Properties")
## For weapons: type like "sword", "axe", "bow"
## For armor: type like "light", "heavy", "robe"
## For rings: "ring"
## For accessories: "accessory"
@export var equipment_type: String = ""

## Which slot this item occupies when equipped
## Uses String to support mod-defined slot types (validated at runtime)
## Default slots: "weapon", "ring_1", "ring_2", "accessory"
@export var equipment_slot: String = "weapon"

@export_group("Curse Properties")
## If true, item cannot be unequipped through normal means once equipped
## Cursed items are typically powerful but lock the slot until uncursed
@export var is_cursed: bool = false

## Item IDs that can remove this curse (e.g., "purify_scroll", "holy_water")
## Empty array means only church service can remove curse
@export var uncurse_items: Array[String] = []

@export_group("Stats Modifiers")
@export var hp_modifier: int = 0
@export var mp_modifier: int = 0
@export var strength_modifier: int = 0
@export var defense_modifier: int = 0
@export var agility_modifier: int = 0
@export var intelligence_modifier: int = 0
@export var luck_modifier: int = 0

@export_group("Weapon Properties")
## For weapons: attack power
@export var attack_power: int = 0
## For weapons: attack range (1 for melee, higher for ranged)
@export var attack_range: int = 1
## Weapon hit rate bonus (percentage)
@export_range(0, 100) var hit_rate: int = 90
## Critical hit rate (percentage)
@export_range(0, 100) var critical_rate: int = 5

@export_group("Consumable Properties")
@export var usable_in_battle: bool = false
@export var usable_on_field: bool = false
## Effect when used (if consumable) - assign an AbilityData resource
@export var effect: Resource

@export_group("Economy")
@export var buy_price: int = 0
@export var sell_price: int = 0

@export_group("Description")
@export_multiline var description: String = ""


## Get stat modifier by name
func get_stat_modifier(stat_name: String) -> int:
	var modifier_key: String = stat_name + "_modifier"
	if modifier_key in self:
		return get(modifier_key)
	return 0


## Check if item has any stat modifiers
func has_stat_modifiers() -> bool:
	return (hp_modifier != 0 or mp_modifier != 0 or
			strength_modifier != 0 or defense_modifier != 0 or
			agility_modifier != 0 or intelligence_modifier != 0 or
			luck_modifier != 0)


## Check if item is equippable
func is_equippable() -> bool:
	return item_type == ItemType.WEAPON or item_type == ItemType.ARMOR


## Check if item is usable
func is_usable() -> bool:
	return item_type == ItemType.CONSUMABLE and (usable_in_battle or usable_on_field)


## Validate that required fields are set
func validate() -> bool:
	if item_name.is_empty():
		push_error("ItemData: item_name is required")
		return false
	if is_equippable() and equipment_type.is_empty():
		push_error("ItemData: equipment_type is required for weapons and armor")
		return false
	if item_type == ItemType.CONSUMABLE and effect == null:
		push_warning("ItemData: consumable item has no effect assigned")
	return true


## Check if this item can have its curse removed by a specific item
func can_uncurse_with(uncurse_item_id: String) -> bool:
	if not is_cursed:
		return false
	return uncurse_item_id in uncurse_items


## Check if this item's curse can only be removed by church service
func requires_church_uncurse() -> bool:
	return is_cursed and uncurse_items.is_empty()


## Get valid slots this item can be equipped to
## Returns array because some item types (rings) can go in multiple slots
func get_valid_slots() -> Array[String]:
	# Check if ModLoader is available (may not be during editor preview)
	if Engine.has_singleton("ModLoader") or ClassDB.class_exists("ModLoader"):
		var mod_loader: Node = Engine.get_singleton("ModLoader") if Engine.has_singleton("ModLoader") else null
		if mod_loader == null:
			mod_loader = Engine.get_main_loop().root.get_node_or_null("ModLoader") if Engine.get_main_loop() else null
		if mod_loader and "equipment_slot_registry" in mod_loader:
			return mod_loader.equipment_slot_registry.get_slots_for_type(equipment_type)
	# Fallback to default slot matching
	return _get_default_valid_slots()


## Fallback slot lookup when ModLoader is not available
func _get_default_valid_slots() -> Array[String]:
	match equipment_type.to_lower():
		"weapon", "sword", "axe", "lance", "bow", "staff", "tome":
			return ["weapon"]
		"ring":
			return ["ring_1", "ring_2"]
		"accessory":
			return ["accessory"]
		_:
			return []


## Validate equipment_slot against current slot registry
## Returns true if the item's equipment_type is accepted by at least one slot
func validate_equipment_slot() -> bool:
	var valid_slots: Array[String] = get_valid_slots()
	if valid_slots.is_empty():
		push_warning("ItemData '%s': equipment_type '%s' not accepted by any slot" % [item_name, equipment_type])
		return false
	return true
