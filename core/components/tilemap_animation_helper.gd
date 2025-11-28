class_name TileMapAnimationHelper
extends RefCounted

## Helper class for configuring TileMap animated tiles with phase offset support.
## Provides utilities to set up Godot 4.2+'s built-in tile animation modes.
##
## Godot supports two animation modes for tiles:
## - TILE_ANIMATION_MODE_DEFAULT: All tiles animate in sync (good for waves, synchronized effects)
## - TILE_ANIMATION_MODE_RANDOM_START_TIMES: Each tile starts at random phase (good for torches, grass)
##
## Usage:
##   var helper := TileMapAnimationHelper.new()
##   helper.set_random_offset_for_tile(tileset, source_id, tile_coords)
##
## Or use the static convenience methods:
##   TileMapAnimationHelper.configure_tile_animation_mode(tileset, source_id, coords, true)

## Animation mode constants (mirrors TileSetAtlasSource enum)
enum TileAnimationMode {
	DEFAULT = 0,           ## All tiles animate in sync
	RANDOM_START_TIMES = 1 ## Each tile instance starts at random phase
}


## Configure animation mode for a specific tile in a TileSetAtlasSource.
## Returns true if successful, false if the source or tile doesn't exist.
static func configure_tile_animation_mode(
	tileset: TileSet,
	source_id: int,
	tile_coords: Vector2i,
	use_random_offset: bool = true
) -> bool:
	if tileset == null:
		push_warning("TileMapAnimationHelper: TileSet is null")
		return false

	if not tileset.has_source(source_id):
		push_warning("TileMapAnimationHelper: Source ID %d not found in TileSet" % source_id)
		return false

	var source: TileSetSource = tileset.get_source(source_id)
	if not source is TileSetAtlasSource:
		push_warning("TileMapAnimationHelper: Source %d is not a TileSetAtlasSource" % source_id)
		return false

	var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource

	if not atlas_source.has_tile(tile_coords):
		push_warning("TileMapAnimationHelper: Tile at %s not found in source %d" % [tile_coords, source_id])
		return false

	# Set the animation mode
	var mode: int = TileAnimationMode.RANDOM_START_TIMES if use_random_offset else TileAnimationMode.DEFAULT
	atlas_source.set_tile_animation_mode(tile_coords, mode)

	return true


## Configure all animated tiles in a TileSetAtlasSource to use random offset.
## Only affects tiles that have animation frames > 1.
## Returns the number of tiles configured.
static func configure_all_animated_tiles(
	tileset: TileSet,
	source_id: int,
	use_random_offset: bool = true
) -> int:
	if tileset == null or not tileset.has_source(source_id):
		return 0

	var source: TileSetSource = tileset.get_source(source_id)
	if not source is TileSetAtlasSource:
		return 0

	var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
	var configured_count: int = 0
	var mode: int = TileAnimationMode.RANDOM_START_TIMES if use_random_offset else TileAnimationMode.DEFAULT

	# Iterate through all tiles in the atlas
	var tiles_count: int = atlas_source.get_tiles_count()
	for i: int in range(tiles_count):
		var tile_coords: Vector2i = atlas_source.get_tile_id(i)

		# Check if this tile has animation frames
		var frame_count: int = atlas_source.get_tile_animation_frames_count(tile_coords)
		if frame_count > 1:
			atlas_source.set_tile_animation_mode(tile_coords, mode)
			configured_count += 1

	return configured_count


## Configure all animated tiles across all sources in a TileSet.
## Useful for batch configuration when loading a tileset.
## Returns total number of tiles configured.
static func configure_tileset_animations(
	tileset: TileSet,
	use_random_offset: bool = true
) -> int:
	if tileset == null:
		return 0

	var total_configured: int = 0
	var source_count: int = tileset.get_source_count()

	for i: int in range(source_count):
		var source_id: int = tileset.get_source_id(i)
		total_configured += configure_all_animated_tiles(tileset, source_id, use_random_offset)

	return total_configured


## Get the current animation mode for a specific tile.
## Returns -1 if the tile or source doesn't exist.
static func get_tile_animation_mode(
	tileset: TileSet,
	source_id: int,
	tile_coords: Vector2i
) -> int:
	if tileset == null or not tileset.has_source(source_id):
		return -1

	var source: TileSetSource = tileset.get_source(source_id)
	if not source is TileSetAtlasSource:
		return -1

	var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource

	if not atlas_source.has_tile(tile_coords):
		return -1

	return atlas_source.get_tile_animation_mode(tile_coords)


## Check if a tile uses random animation offset.
static func tile_has_random_offset(
	tileset: TileSet,
	source_id: int,
	tile_coords: Vector2i
) -> bool:
	return get_tile_animation_mode(tileset, source_id, tile_coords) == TileAnimationMode.RANDOM_START_TIMES


## Recommended animation modes for common tile types.
## Use these as guidelines when setting up tilesets.
const RECOMMENDED_MODES: Dictionary = {
	# Environmental elements - use random offset for natural variation
	"torch": TileAnimationMode.RANDOM_START_TIMES,
	"flame": TileAnimationMode.RANDOM_START_TIMES,
	"candle": TileAnimationMode.RANDOM_START_TIMES,
	"grass": TileAnimationMode.RANDOM_START_TIMES,
	"flower": TileAnimationMode.RANDOM_START_TIMES,
	"tree_leaves": TileAnimationMode.RANDOM_START_TIMES,
	"sparkle": TileAnimationMode.RANDOM_START_TIMES,
	"shimmer": TileAnimationMode.RANDOM_START_TIMES,

	# Water elements - can go either way
	# Synchronized for wave-like patterns, random for small pools/puddles
	"water_wave": TileAnimationMode.DEFAULT,
	"river": TileAnimationMode.DEFAULT,
	"waterfall": TileAnimationMode.RANDOM_START_TIMES,
	"puddle": TileAnimationMode.RANDOM_START_TIMES,
	"fountain": TileAnimationMode.RANDOM_START_TIMES,

	# Mechanical/magical - usually synchronized for intentional effect
	"trap": TileAnimationMode.DEFAULT,
	"portal": TileAnimationMode.DEFAULT,
	"teleporter": TileAnimationMode.DEFAULT,
	"conveyor": TileAnimationMode.DEFAULT,
	"gears": TileAnimationMode.DEFAULT,

	# Ambient effects
	"smoke": TileAnimationMode.RANDOM_START_TIMES,
	"fog": TileAnimationMode.RANDOM_START_TIMES,
	"dust": TileAnimationMode.RANDOM_START_TIMES,
}


## Get the recommended animation mode for a tile type name.
## Returns RANDOM_START_TIMES as default (safer choice for natural feel).
static func get_recommended_mode(tile_type_name: String) -> int:
	var lower_name: String = tile_type_name.to_lower()

	# Check exact match first
	if lower_name in RECOMMENDED_MODES:
		return RECOMMENDED_MODES[lower_name]

	# Check partial matches
	for key: String in RECOMMENDED_MODES.keys():
		if lower_name.contains(key) or key.contains(lower_name):
			return RECOMMENDED_MODES[key]

	# Default to random offset for natural feel
	return TileAnimationMode.RANDOM_START_TIMES
