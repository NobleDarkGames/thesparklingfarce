class_name TerrainRegistry
extends RefCounted

## Registry for terrain types.
## Allows mods to define custom terrain types with full override support.
##
## Following Commander Claudius's guidance: MINIMAL fallback only.
## Default terrain values belong in mod .tres files, not hardcoded here.
## The registry only provides a plains fallback for missing terrain types.
##
## Mods register terrain via TerrainData .tres files in mods/*/data/terrain/

# Minimal fallback terrain data (only used when terrain_type not found)
# This is intentionally sparse - full definitions belong in mod .tres files
const FALLBACK_TERRAIN_ID: String = "plains"
const FALLBACK_DISPLAY_NAME: String = "Plains"

# Registered TerrainData resources: terrain_id -> TerrainData
var _terrain_data: Dictionary = {}

# Source tracking: terrain_id -> mod_id
var _terrain_sources: Dictionary = {}

# Cached fallback terrain (lazy-created)
var _fallback_terrain: Resource = null


## Register a TerrainData resource from a mod
func register_terrain(terrain: Resource, mod_id: String) -> void:
	if not terrain:
		push_warning("TerrainRegistry: Cannot register null terrain")
		return

	# Verify it's a TerrainData resource
	if not terrain is TerrainData:
		push_warning("TerrainRegistry: Resource is not a TerrainData")
		return

	var terrain_data: TerrainData = terrain as TerrainData

	if terrain_data.terrain_id.is_empty():
		push_warning("TerrainRegistry: Cannot register terrain with empty terrain_id")
		return

	_terrain_data[terrain_data.terrain_id] = terrain_data
	_terrain_sources[terrain_data.terrain_id] = mod_id


## Get TerrainData by ID (returns fallback plains if not found)
func get_terrain(terrain_id: String) -> TerrainData:
	if terrain_id in _terrain_data:
		return _terrain_data[terrain_id]

	# Fallback to plains with warning
	push_warning("TerrainRegistry: Unknown terrain '%s', using plains fallback" % terrain_id)
	return _get_fallback_terrain()


## Check if terrain type exists
func has_terrain(terrain_id: String) -> bool:
	return terrain_id in _terrain_data


## Get all registered terrain IDs
func get_all_terrain_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _terrain_data.keys():
		ids.append(id)
	return ids


## Get which mod registered a terrain (or empty string if not found)
func get_terrain_source(terrain_id: String) -> String:
	if terrain_id in _terrain_sources:
		return _terrain_sources[terrain_id]
	return ""


## Get all registered TerrainData resources
func get_all_terrain() -> Array[TerrainData]:
	var result: Array[TerrainData] = []
	for terrain: TerrainData in _terrain_data.values():
		result.append(terrain)
	return result


## Clear all mod registrations (called on mod reload)
func clear_mod_registrations() -> void:
	_terrain_data.clear()
	_terrain_sources.clear()
	# Don't clear fallback - it's a static safety net


## Get or create the fallback plains terrain
## This is a minimal safety net, not a full terrain definition
func _get_fallback_terrain() -> TerrainData:
	if _fallback_terrain == null:
		_fallback_terrain = TerrainData.new()
		_fallback_terrain.terrain_id = FALLBACK_TERRAIN_ID
		_fallback_terrain.display_name = FALLBACK_DISPLAY_NAME
		_fallback_terrain.movement_cost_walking = 1
		_fallback_terrain.movement_cost_floating = 1
		_fallback_terrain.movement_cost_flying = 1
		_fallback_terrain.defense_bonus = 0
		_fallback_terrain.evasion_bonus = 0
		_fallback_terrain.damage_per_turn = 0
	return _fallback_terrain
