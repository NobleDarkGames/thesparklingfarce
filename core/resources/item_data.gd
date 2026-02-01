class_name ItemData
extends Resource

## Represents an item in the game (weapon, accessory, or consumable).
## Contains stats modifiers, usability information, and appearance.
## Note: Shining Force 2 did not have armor slots - equipment was weapon + rings only.

enum ItemType {
	WEAPON,
	ACCESSORY,  ## Rings, amulets, and other accessories (SF2-authentic)
	CONSUMABLE,
	KEY_ITEM
}

@export var item_name: String = ""
@export var item_type: ItemType = ItemType.WEAPON
@export var icon: Texture2D

@export_group("Equipment Properties")
## For weapons: type like "sword", "axe", "bow"
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
## For weapons: minimum attack range (1 for melee, 2+ for bows with dead zone)
## A bow with min_attack_range=2 CANNOT hit adjacent enemies (dead zone)
@export var min_attack_range: int = 1
## For weapons: maximum attack range (1 for melee, higher for ranged)
@export var max_attack_range: int = 1
## Weapon hit rate bonus (percentage)
@export_range(0, 100) var hit_rate: int = 90
## Critical hit rate (percentage)
@export_range(0, 100) var critical_rate: int = 5

@export_group("Consumable Properties")
@export var usable_in_battle: bool = false
@export var usable_on_field: bool = false
## Effect when used (if consumable) - AbilityData defining the ability triggered on use
@export var effect: AbilityData

@export_group("Economy")
@export var buy_price: int = 0
@export var sell_price: int = 0

@export_group("Description")
@export_multiline var description: String = ""

@export_group("Combat Modifiers")
## If true, this weapon negates flying units' enhanced dodge rate (12% -> 3%)
## Used for bows, crossbows, and other anti-air weapons
@export var reduces_flying_dodge: bool = false

## Damage multipliers against target movement types
## Keys: MovementType enum values (0=WALKING, 1=FLYING, 2=FLOATING) or custom type strings
## Values: float multiplier (1.25 = +25% damage)
@export var movement_type_bonuses: Dictionary = {}

## Damage multipliers against unit tags (e.g., "undead", "beast", "armored")
## Keys: tag strings, Values: float multiplier
@export var unit_tag_bonuses: Dictionary = {}

@export_group("Item Management")
## Whether this item can be dropped/discarded by the player
## Set to false for plot-critical or special items
@export var can_be_dropped: bool = true

## Whether to show confirmation dialog when dropping
## Defaults to true for safety; set false for common consumables if desired
@export var confirm_on_drop: bool = true

## Whether this item is a crafting material (mithril, dragon scale, etc.)
## Crafting materials can be combined at crafter NPCs to create equipment
@export var is_crafting_material: bool = false


## Get stat modifier by name
func get_stat_modifier(stat_name: String) -> int:
	var modifier_key: String = stat_name + "_modifier"
	if modifier_key in self:
		var value: Variant = get(modifier_key)
		if value is int:
			return value
		elif value is float:
			var float_val: float = value
			return int(float_val)
	return 0


## Check if item has any stat modifiers
func has_stat_modifiers() -> bool:
	return (hp_modifier != 0 or mp_modifier != 0 or
			strength_modifier != 0 or defense_modifier != 0 or
			agility_modifier != 0 or intelligence_modifier != 0 or
			luck_modifier != 0)


## Check if item is equippable
func is_equippable() -> bool:
	return item_type == ItemType.WEAPON or item_type == ItemType.ACCESSORY


## Check if item is usable (in any context)
func is_usable() -> bool:
	return item_type == ItemType.CONSUMABLE and (usable_in_battle or usable_on_field)


## Check if item is usable on the field (exploration mode)
func is_usable_on_field() -> bool:
	return item_type == ItemType.CONSUMABLE and usable_on_field


## Check if item is usable in battle
func is_usable_in_battle() -> bool:
	return item_type == ItemType.CONSUMABLE and usable_in_battle


## Validate that required fields are set
func validate() -> bool:
	if item_name.is_empty():
		push_error("ItemData: item_name is required")
		return false
	if is_equippable() and equipment_type.is_empty():
		push_error("ItemData: equipment_type is required for weapons and accessories")
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


## Check if a given distance is within this weapon's attack range
## Uses min_attack_range and max_attack_range to support dead zones
## Example: Bow with min=2, max=3 returns false for distance=1
func is_distance_in_range(distance: int) -> bool:
	return distance >= min_attack_range and distance <= max_attack_range


## Get formatted range string for UI display
## Returns "1" for melee, "2-4" for ranged with min/max
func get_range_display() -> String:
	if min_attack_range == max_attack_range:
		return str(max_attack_range)
	return "%d-%d" % [min_attack_range, max_attack_range]


## Check if this weapon has a dead zone (cannot hit adjacent enemies)
## Returns true if min_attack_range > 1
func has_dead_zone() -> bool:
	return min_attack_range > 1


## Get valid slots this item can be equipped to
## Returns array because some item types (rings) can go in multiple slots
func get_valid_slots() -> Array[String]:
	# Check if ModLoader is available (may not be during editor preview)
	if Engine.has_singleton("ModLoader") or ClassDB.class_exists("ModLoader"):
		var mod_loader: Node = Engine.get_singleton("ModLoader") if Engine.has_singleton("ModLoader") else null
		if mod_loader == null:
			var main_loop: MainLoop = Engine.get_main_loop()
			if main_loop is SceneTree:
				var scene_tree: SceneTree = main_loop as SceneTree
				mod_loader = scene_tree.root.get_node_or_null("ModLoader")
		if mod_loader and "equipment_slot_registry" in mod_loader:
			var registry: Object = mod_loader.get("equipment_slot_registry")
			if registry and registry.has_method("get_slots_for_type"):
				var result: Variant = registry.call("get_slots_for_type", equipment_type)
				if result is Array:
					var result_array: Array = result
					var typed_result: Array[String] = []
					for slot: Variant in result_array:
						if slot is String:
							typed_result.append(slot)
					return typed_result
	# Fallback to default slot matching
	return _get_default_valid_slots()


## Fallback slot lookup when ModLoader is not available
## Matches EquipmentTypeRegistry.init_defaults() weapon subtypes
func _get_default_valid_slots() -> Array[String]:
	match equipment_type.to_lower():
		"weapon", "sword", "axe", "spear", "bow", "staff", "knife":
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
