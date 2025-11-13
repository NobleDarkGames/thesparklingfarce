class_name ItemData
extends Resource

## Represents an item in the game (weapon, armor, or consumable).
## Contains stats modifiers, usability information, and appearance.

enum ItemType {
	WEAPON,
	ARMOR,
	CONSUMABLE,
	KEY_ITEM
}

@export var item_name: String = ""
@export var item_type: ItemType = ItemType.WEAPON
@export var icon: Texture2D

@export_group("Equipment Properties")
## For weapons: type like "sword", "axe", "bow"
## For armor: type like "light", "heavy", "robe"
@export var equipment_type: String = ""
## Durability/uses (-1 for unlimited)
@export var durability: int = -1

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
