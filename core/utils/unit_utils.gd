class_name UnitUtils
extends RefCounted

## Utility functions for safely accessing unit properties
## These helpers avoid UNSAFE_METHOD_ACCESS warnings by using call() internally


## Get a unit's display name safely
## Works with any object that has a get_display_name() method
static func get_display_name(unit: Variant, fallback: String = "Unknown") -> String:
	if unit == null:
		return fallback
	if unit is Object and unit.has_method("get_display_name"):
		var result: Variant = unit.call("get_display_name")
		return str(result) if result != null else fallback
	return fallback


## Get a unit's grid position safely
static func get_grid_position(unit: Variant, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	if unit == null:
		return fallback
	if unit is Object and "grid_position" in unit:
		var pos: Variant = unit.get("grid_position")
		if pos is Vector2i:
			return pos
	return fallback


## Check if a unit is alive safely
static func is_alive(unit: Variant) -> bool:
	if unit == null:
		return false
	if unit is Object and "is_alive" in unit:
		var alive: Variant = unit.get("is_alive")
		if alive is bool:
			return alive
	return false


## Get a unit's character data safely
static func get_character_data(unit: Variant) -> Variant:
	if unit == null:
		return null
	if unit is Object and "character_data" in unit:
		return unit.get("character_data")
	return null
