class_name UnitUtils
extends RefCounted

## Utility functions for safely accessing unit properties
## These helpers avoid UNSAFE_METHOD_ACCESS warnings by using call() internally


## Get a unit's display name safely
## Works with any object that has a get_display_name() method
static func get_display_name(unit: Variant, fallback: String = "Unknown") -> String:
	if unit == null or (unit is Object and not is_instance_valid(unit)):
		return fallback
	if unit is Object:
		var obj: Object = unit
		if obj.has_method("get_display_name"):
			var result: Variant = obj.call("get_display_name")
			return str(result) if result != null else fallback
	return fallback


## Get a unit's grid position safely
static func get_grid_position(unit: Variant, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	if unit == null or (unit is Object and not is_instance_valid(unit)):
		return fallback
	if unit is Object:
		var obj: Object = unit
		if "grid_position" in obj:
			var pos: Variant = obj.get("grid_position")
			if pos is Vector2i:
				return pos
	return fallback


## Check if a unit is alive safely
static func is_alive(unit: Variant) -> bool:
	if unit == null or (unit is Object and not is_instance_valid(unit)):
		return false
	if unit is Object:
		var obj: Object = unit
		if "is_alive" in obj:
			var alive: Variant = obj.get("is_alive")
			if alive is bool:
				return alive
	return false


## Get a unit's character data safely
static func get_character_data(unit: Variant) -> Variant:
	if unit == null or (unit is Object and not is_instance_valid(unit)):
		return null
	if unit is Object:
		var obj: Object = unit
		if "character_data" in obj:
			return obj.get("character_data")
	return null
