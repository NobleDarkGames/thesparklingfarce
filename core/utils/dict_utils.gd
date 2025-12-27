class_name DictUtils
extends RefCounted
## Type-safe dictionary access utilities
##
## GDScript's Dictionary.get() returns Variant, which requires casting.
## Using `as Type` causes UNSAFE_CAST warnings. These helpers provide
## type-checked access that returns the default value if the type doesn't match.
##
## Usage:
##   var name: String = DictUtils.get_string(data, "name", "Unknown")
##   var count: int = DictUtils.get_int(data, "count", 0)
##
## When to use:
## - JSON data from external files
## - Dictionary parameters from signals/callbacks
## - Any Dictionary where values are Variant
##
## When NOT to use:
## - Typed dictionaries (Dictionary[String, MyType]) - use direct access
## - Known internal data structures - consider typed dictionaries instead


## Get a String value from a dictionary with type checking
## Returns default if key is missing or value is not a String
static func get_string(dict: Dictionary, key: String, default: String = "") -> String:
	var value: Variant = dict.get(key, default)
	return value if value is String else default


## Get an int value from a dictionary with type checking
## Returns default if key is missing or value is not an int
static func get_int(dict: Dictionary, key: String, default: int = 0) -> int:
	var value: Variant = dict.get(key, default)
	return value if value is int else default


## Get a float value from a dictionary with type checking
## Returns default if key is missing or value is not a float
## Note: Also accepts int and converts to float for convenience
static func get_float(dict: Dictionary, key: String, default: float = 0.0) -> float:
	var value: Variant = dict.get(key, default)
	if value is float:
		return value
	if value is int:
		return float(value)
	return default


## Get a bool value from a dictionary with type checking
## Returns default if key is missing or value is not a bool
static func get_bool(dict: Dictionary, key: String, default: bool = false) -> bool:
	var value: Variant = dict.get(key, default)
	return value if value is bool else default


## Get an Array value from a dictionary with type checking
## Returns default if key is missing or value is not an Array
static func get_array(dict: Dictionary, key: String, default: Array = []) -> Array:
	var value: Variant = dict.get(key, default)
	return value if value is Array else default


## Get a Dictionary value from a dictionary with type checking
## Returns default if key is missing or value is not a Dictionary
static func get_dict(dict: Dictionary, key: String, default: Dictionary = {}) -> Dictionary:
	var value: Variant = dict.get(key, default)
	return value if value is Dictionary else default


## Get a Vector2 value from a dictionary with type checking
## Returns default if key is missing or value is not a Vector2
static func get_vector2(dict: Dictionary, key: String, default: Vector2 = Vector2.ZERO) -> Vector2:
	var value: Variant = dict.get(key, default)
	return value if value is Vector2 else default


## Get a Vector2i value from a dictionary with type checking
## Returns default if key is missing or value is not a Vector2i
static func get_vector2i(dict: Dictionary, key: String, default: Vector2i = Vector2i.ZERO) -> Vector2i:
	var value: Variant = dict.get(key, default)
	return value if value is Vector2i else default
