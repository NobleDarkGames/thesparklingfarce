@tool
class_name StatusEffectRegistry
extends RefCounted

## Registry for status effect definitions from mods
##
## Manages StatusEffectData resources loaded from mods/*/data/status_effects/
## Provides lookup and validation for the status effect system.
##
## Usage:
##   var effect: StatusEffectData = ModLoader.status_effect_registry.get_effect("poison")
##   if effect and effect.damage_per_turn > 0:
##       # Apply damage...

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when registrations change (for editor refresh)
signal registrations_changed()

# =============================================================================
# DATA STORAGE
# =============================================================================

## Registered status effects: {effect_id: StatusEffectData}
var _effects: Dictionary = {}

## Track which mod registered each effect
var _effect_sources: Dictionary = {}  # {effect_id: mod_id}

# =============================================================================
# REGISTRATION API
# =============================================================================

## Register a status effect from a mod
## @param effect: The StatusEffectData resource
## @param mod_id: The mod registering this effect
func register_effect(effect: StatusEffectData, mod_id: String) -> void:
	if not effect:
		push_error("StatusEffectRegistry: Cannot register null effect")
		return

	var id_lower: String = effect.effect_id.to_lower().strip_edges()
	if id_lower.is_empty():
		push_error("StatusEffectRegistry: Effect has empty effect_id from mod '%s'" % mod_id)
		return

	# Validate the effect
	if not effect.validate():
		push_warning("StatusEffectRegistry: Effect '%s' from mod '%s' failed validation" % [id_lower, mod_id])
		# Still register it - validation is advisory

	# Check for override
	if id_lower in _effects:
		var existing_mod: String = _effect_sources.get(id_lower, "unknown")
		push_warning("StatusEffectRegistry: Mod '%s' overrides status effect '%s' (was from '%s')" % [
			mod_id, id_lower, existing_mod
		])

	_effects[id_lower] = effect
	_effect_sources[id_lower] = mod_id


## Register multiple effects from a mod (called by ModLoader during discovery)
## @param effects: Array of StatusEffectData resources
## @param mod_id: The mod registering these effects
func register_effects(effects: Array, mod_id: String) -> void:
	for effect: Variant in effects:
		if effect is StatusEffectData:
			register_effect(effect as StatusEffectData, mod_id)
	registrations_changed.emit()


# =============================================================================
# LOOKUP API
# =============================================================================

## Get a status effect by ID
## Returns null if not found
func get_effect(effect_id: String) -> StatusEffectData:
	var id_lower: String = effect_id.to_lower()
	if id_lower in _effects:
		return _effects[id_lower]
	return null


## Check if an effect is registered
func has_effect(effect_id: String) -> bool:
	return effect_id.to_lower() in _effects


## Get all registered effect IDs
func get_all_effect_ids() -> Array[String]:
	var result: Array[String] = []
	for effect_id: String in _effects.keys():
		result.append(effect_id)
	result.sort()
	return result


## Get all registered effects
func get_all_effects() -> Array[StatusEffectData]:
	var result: Array[StatusEffectData] = []
	for effect: StatusEffectData in _effects.values():
		result.append(effect)
	return result


## Get which mod provides an effect
func get_source_mod(effect_id: String) -> String:
	var id_lower: String = effect_id.to_lower()
	if id_lower in _effect_sources:
		return _effect_sources[id_lower]
	return ""


## Get the display name for an effect (with fallback)
func get_display_name(effect_id: String) -> String:
	var effect: StatusEffectData = get_effect(effect_id)
	if effect:
		if not effect.display_name.is_empty():
			return effect.display_name
		return effect_id.capitalize()
	return effect_id.capitalize()


# =============================================================================
# UTILITY API
# =============================================================================

## Clear all registrations (called on mod reload)
func clear_mod_registrations() -> void:
	_effects.clear()
	_effect_sources.clear()
	registrations_changed.emit()


## Get registration counts for debugging
func get_stats() -> Dictionary:
	return {
		"effect_count": _effects.size()
	}


## Get all effects that skip turns (for UI filtering)
func get_skip_turn_effects() -> Array[StatusEffectData]:
	var result: Array[StatusEffectData] = []
	for effect: StatusEffectData in _effects.values():
		if effect.skips_turn:
			result.append(effect)
	return result


## Get all effects that modify actions (for UI filtering)
func get_action_modifier_effects() -> Array[StatusEffectData]:
	var result: Array[StatusEffectData] = []
	for effect: StatusEffectData in _effects.values():
		if effect.action_modifier != StatusEffectData.ActionModifier.NONE:
			result.append(effect)
	return result


## Get all buff effects (positive stat modifiers)
func get_buff_effects() -> Array[StatusEffectData]:
	var result: Array[StatusEffectData] = []
	for effect: StatusEffectData in _effects.values():
		var is_buff: bool = false
		for value: Variant in effect.stat_modifiers.values():
			var int_value: int = 0
			if value is int:
				int_value = value
			elif value is float:
				int_value = int(value)
			if int_value > 0:
				is_buff = true
				break
		if is_buff:
			result.append(effect)
	return result


## Get all debuff effects (negative stat modifiers or damage over time)
func get_debuff_effects() -> Array[StatusEffectData]:
	var result: Array[StatusEffectData] = []
	for effect: StatusEffectData in _effects.values():
		var is_debuff: bool = effect.damage_per_turn > 0
		if not is_debuff:
			for value: Variant in effect.stat_modifiers.values():
				var int_value: int = 0
				if value is int:
					int_value = value
				elif value is float:
					int_value = int(value)
				if int_value < 0:
					is_debuff = true
					break
		if is_debuff:
			result.append(effect)
	return result
