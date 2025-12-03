class_name EquipmentSlot
extends RefCounted

## Convenience constants for default SF-style equipment slot IDs
##
## Use these for base game code. Note that total conversion mods
## may define entirely different slot IDs via EquipmentSlotRegistry.
##
## Always validate against ModLoader.equipment_slot_registry for
## mod-safe code that needs to work with custom slot layouts.

## Default slot IDs (SF-style layout)
const WEAPON: String = "weapon"
const RING_1: String = "ring_1"
const RING_2: String = "ring_2"
const ACCESSORY: String = "accessory"


## Check if slot ID matches a ring slot in default layout
static func is_default_ring_slot(slot_id: String) -> bool:
	return slot_id == RING_1 or slot_id == RING_2


## Check if slot ID is a default slot
static func is_default_slot(slot_id: String) -> bool:
	return slot_id == WEAPON or slot_id == RING_1 or slot_id == RING_2 or slot_id == ACCESSORY


## Get all default slot IDs
static func get_default_slot_ids() -> Array[String]:
	return [WEAPON, RING_1, RING_2, ACCESSORY]
