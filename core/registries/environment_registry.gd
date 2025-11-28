class_name EnvironmentRegistry
extends RefCounted

## Registry for environmental settings (weather and time of day).
## Allows mods to extend available options beyond the defaults.
##
## Default weather types: none, rain, snow, fog
## Default time of day: day, night, dawn, dusk
##
## Mods can register additional types via their mod.json:
## {
##   "environment_types": {
##     "weather_types": ["blizzard", "sandstorm", "aurora"],
##     "time_of_day": ["midnight", "noon", "twilight"]
##   }
## }

# Default types that are always available
const DEFAULT_WEATHER_TYPES: Array[String] = ["none", "rain", "snow", "fog"]
const DEFAULT_TIME_OF_DAY: Array[String] = ["day", "night", "dawn", "dusk"]

# Registered types from mods (mod_id -> Array[String])
var _mod_weather_types: Dictionary = {}
var _mod_time_of_day: Dictionary = {}

# Cached merged arrays (rebuilt when mods change)
var _all_weather_types: Array[String] = []
var _all_time_of_day: Array[String] = []
var _cache_dirty: bool = true


## Register weather types from a mod
func register_weather_types(mod_id: String, types: Array) -> void:
	var typed_array: Array[String] = []
	for t: Variant in types:
		var type_str: String = str(t).to_lower().strip_edges()
		if not type_str.is_empty():
			typed_array.append(type_str)

	if not typed_array.is_empty():
		_mod_weather_types[mod_id] = typed_array
		_cache_dirty = true
		print("EnvironmentRegistry: Registered weather types from '%s': %s" % [mod_id, typed_array])


## Register time of day options from a mod
func register_time_of_day(mod_id: String, times: Array) -> void:
	var typed_array: Array[String] = []
	for t: Variant in times:
		var type_str: String = str(t).to_lower().strip_edges()
		if not type_str.is_empty():
			typed_array.append(type_str)

	if not typed_array.is_empty():
		_mod_time_of_day[mod_id] = typed_array
		_cache_dirty = true
		print("EnvironmentRegistry: Registered time of day from '%s': %s" % [mod_id, typed_array])


## Unregister all types from a mod (called when mod is unloaded)
func unregister_mod(mod_id: String) -> void:
	var changed: bool = false
	if mod_id in _mod_weather_types:
		_mod_weather_types.erase(mod_id)
		changed = true
	if mod_id in _mod_time_of_day:
		_mod_time_of_day.erase(mod_id)
		changed = true
	if changed:
		_cache_dirty = true


## Clear all mod registrations (called on full mod reload)
func clear_mod_registrations() -> void:
	_mod_weather_types.clear()
	_mod_time_of_day.clear()
	_cache_dirty = true


## Get all available weather types (defaults + mod-registered)
func get_weather_types() -> Array[String]:
	_rebuild_cache_if_dirty()
	return _all_weather_types.duplicate()


## Get all available time of day options (defaults + mod-registered)
func get_time_of_day_options() -> Array[String]:
	_rebuild_cache_if_dirty()
	return _all_time_of_day.duplicate()


## Check if a weather type is valid
func is_valid_weather_type(weather_type: String) -> bool:
	_rebuild_cache_if_dirty()
	return weather_type.to_lower() in _all_weather_types


## Check if a time of day is valid
func is_valid_time_of_day(time: String) -> bool:
	_rebuild_cache_if_dirty()
	return time.to_lower() in _all_time_of_day


## Get which mod registered a weather type (or "base" for defaults)
func get_weather_type_source(weather_type: String) -> String:
	var lower_type: String = weather_type.to_lower()
	if lower_type in DEFAULT_WEATHER_TYPES:
		return "base"
	for mod_id: String in _mod_weather_types:
		if lower_type in _mod_weather_types[mod_id]:
			return mod_id
	return ""


## Get which mod registered a time of day (or "base" for defaults)
func get_time_of_day_source(time: String) -> String:
	var lower_type: String = time.to_lower()
	if lower_type in DEFAULT_TIME_OF_DAY:
		return "base"
	for mod_id: String in _mod_time_of_day:
		if lower_type in _mod_time_of_day[mod_id]:
			return mod_id
	return ""


## Rebuild the cached merged arrays
func _rebuild_cache_if_dirty() -> void:
	if not _cache_dirty:
		return

	# Start with defaults
	_all_weather_types = DEFAULT_WEATHER_TYPES.duplicate()
	_all_time_of_day = DEFAULT_TIME_OF_DAY.duplicate()

	# Add mod types (avoiding duplicates)
	for mod_id: String in _mod_weather_types:
		for weather_type: String in _mod_weather_types[mod_id]:
			if weather_type not in _all_weather_types:
				_all_weather_types.append(weather_type)

	for mod_id: String in _mod_time_of_day:
		for time: String in _mod_time_of_day[mod_id]:
			if time not in _all_time_of_day:
				_all_time_of_day.append(time)

	_cache_dirty = false
