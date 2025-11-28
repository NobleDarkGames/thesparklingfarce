class_name AnimationOffsetRegistry
extends RefCounted

## Registry for animation phase offset types.
## Controls how animated sprites desynchronize their playback to create
## a more natural, less mechanical appearance (classic 16-bit technique).
##
## Default offset types:
## - none: No offset, all animations synchronized
## - random: Full random offset within animation cycle (independent entities)
## - clustered: Slight offset variance (0.2-0.4 of cycle, environmental groups)
## - position_based: Deterministic offset based on world position (save-game friendly)
## - instance_id: Deterministic offset based on instance ID
##
## Mods can register additional types via their mod.json:
## {
##   "custom_types": {
##     "animation_offset_types": ["wave", "cascade"]
##   }
## }

## Enum for built-in offset calculation methods
enum OffsetMethod {
	NONE,           ## No offset applied
	RANDOM,         ## Full random offset (0.0 to 1.0 of cycle)
	CLUSTERED,      ## Clustered offset (0.2 to 0.4 of cycle)
	POSITION_BASED, ## Deterministic based on world position
	INSTANCE_ID,    ## Deterministic based on node instance ID
}

# Default types that are always available
const DEFAULT_OFFSET_TYPES: Array[String] = [
	"none",
	"random",
	"clustered",
	"position_based",
	"instance_id"
]

# Mapping of default types to their enum values
const DEFAULT_TYPE_TO_METHOD: Dictionary = {
	"none": OffsetMethod.NONE,
	"random": OffsetMethod.RANDOM,
	"clustered": OffsetMethod.CLUSTERED,
	"position_based": OffsetMethod.POSITION_BASED,
	"instance_id": OffsetMethod.INSTANCE_ID,
}

# Registered types from mods (mod_id -> Array[String])
var _mod_offset_types: Dictionary = {}

# Cached merged array (rebuilt when mods change)
var _all_offset_types: Array[String] = []
var _cache_dirty: bool = true


## Register animation offset types from a mod
func register_offset_types(mod_id: String, types: Array) -> void:
	var typed_array: Array[String] = []
	for t: Variant in types:
		var type_str: String = str(t).to_lower().strip_edges()
		if not type_str.is_empty():
			typed_array.append(type_str)

	if not typed_array.is_empty():
		_mod_offset_types[mod_id] = typed_array
		_cache_dirty = true
		print("AnimationOffsetRegistry: Registered offset types from '%s': %s" % [mod_id, typed_array])


## Unregister all types from a mod (called when mod is unloaded)
func unregister_mod(mod_id: String) -> void:
	if mod_id in _mod_offset_types:
		_mod_offset_types.erase(mod_id)
		_cache_dirty = true


## Clear all mod registrations (called on full mod reload)
func clear_mod_registrations() -> void:
	_mod_offset_types.clear()
	_cache_dirty = true


## Get all available offset types (defaults + mod-registered)
func get_offset_types() -> Array[String]:
	_rebuild_cache_if_dirty()
	return _all_offset_types.duplicate()


## Check if an offset type is valid
func is_valid_offset_type(offset_type: String) -> bool:
	_rebuild_cache_if_dirty()
	return offset_type.to_lower() in _all_offset_types


## Get the OffsetMethod enum for a given type string
## Returns NONE for unknown types (safe default)
func get_offset_method(offset_type: String) -> OffsetMethod:
	var lower_type: String = offset_type.to_lower()
	if lower_type in DEFAULT_TYPE_TO_METHOD:
		return DEFAULT_TYPE_TO_METHOD[lower_type] as OffsetMethod
	# Custom mod types default to RANDOM behavior
	if is_valid_offset_type(lower_type):
		return OffsetMethod.RANDOM
	return OffsetMethod.NONE


## Get which mod registered an offset type (or "base" for defaults)
func get_offset_type_source(offset_type: String) -> String:
	var lower_type: String = offset_type.to_lower()
	if lower_type in DEFAULT_OFFSET_TYPES:
		return "base"
	for mod_id: String in _mod_offset_types:
		if lower_type in _mod_offset_types[mod_id]:
			return mod_id
	return ""


## Calculate the phase offset value based on the offset method
## Returns a value between 0.0 and 1.0 representing the phase within the animation cycle
static func calculate_offset(method: OffsetMethod, position: Vector2 = Vector2.ZERO, instance_id: int = 0) -> float:
	match method:
		OffsetMethod.NONE:
			return 0.0
		OffsetMethod.RANDOM:
			return randf()
		OffsetMethod.CLUSTERED:
			return randf_range(0.2, 0.4)
		OffsetMethod.POSITION_BASED:
			# Deterministic hash based on position
			var hash_val: float = fmod(position.x * 0.1 + position.y * 0.07, 1.0)
			return absf(hash_val)
		OffsetMethod.INSTANCE_ID:
			# Deterministic based on instance ID
			return fmod(float(instance_id) * 0.001, 1.0)
		_:
			return 0.0


## Rebuild the cached merged array
func _rebuild_cache_if_dirty() -> void:
	if not _cache_dirty:
		return

	# Start with defaults
	_all_offset_types = DEFAULT_OFFSET_TYPES.duplicate()

	# Add mod types (avoiding duplicates)
	for mod_id: String in _mod_offset_types:
		for offset_type: String in _mod_offset_types[mod_id]:
			if offset_type not in _all_offset_types:
				_all_offset_types.append(offset_type)

	_cache_dirty = false
