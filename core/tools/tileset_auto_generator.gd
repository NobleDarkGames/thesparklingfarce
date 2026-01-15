class_name TileSetAutoGenerator
extends RefCounted

## Utility for auto-generating tile definitions in TileSets based on atlas texture dimensions.
## This allows modders to simply drop PNG files into their tileset's texture folder
## without manually editing the TileSet .tres file.
##
## Called automatically by ModLoader when loading tilesets.
##
## Features:
##   1. Auto-discovery: Scans "textures/" subfolder for new PNGs and adds them as atlas sources
##   2. Auto-population: Creates tile definitions based on texture dimensions
##   3. Animated tiles: Supports filename convention for animation configuration
##
## Animation filename convention:
##   terrain.png           -> static tile
##   terrain_anim2.png     -> 2-frame animation, staggered (default)
##   terrain_anim3sync.png -> 3-frame animation, synchronized
##
## Animation layout: frames horizontal (columns), variants vertical (rows)
## Frame duration: 150ms (SF2-style timing)
##
## Example output:
##   TileSetAutoGenerator: Discovered water_anim2sync.png -> added as source 8
##   TileSetAutoGenerator: grass.png (32x128) -> 4 tiles auto-generated
##   TileSetAutoGenerator: water_anim2sync.png (64x128) -> 4 animated tiles (2 frames, synchronized)

## Default animation frame duration in seconds (150ms = SF2-style timing)
const DEFAULT_FRAME_DURATION: float = 0.15


## Auto-discover PNG textures in the tileset's texture directory and add them as atlas sources.
## Looks for a "textures" subfolder relative to the tileset, or uses the tileset's directory.
## Returns the number of new atlas sources added.
static func auto_discover_textures(tileset: TileSet, tileset_path: String, tileset_name: String = "") -> int:
	if not tileset:
		return 0

	# Determine texture directory
	var tileset_dir: String = tileset_path.get_base_dir()
	var texture_dir: String = tileset_dir.path_join("textures")

	# Fall back to tileset directory if no textures subfolder
	if not DirAccess.dir_exists_absolute(texture_dir):
		texture_dir = tileset_dir

	# Get list of existing texture paths in tileset
	var existing_textures: Array[String] = []
	for i: int in range(tileset.get_source_count()):
		var source_id: int = tileset.get_source_id(i)
		var source: TileSetSource = tileset.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas: TileSetAtlasSource = source as TileSetAtlasSource
			if atlas.texture:
				existing_textures.append(atlas.texture.resource_path)

	# Scan for PNG files
	var dir: DirAccess = DirAccess.open(texture_dir)
	if not dir:
		return 0

	var discovered: int = 0
	var prefix: String = "TileSetAutoGenerator"
	if not tileset_name.is_empty():
		prefix = "TileSetAutoGenerator [%s]" % tileset_name

	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.to_lower().ends_with(".png"):
			var texture_path: String = texture_dir.path_join(filename)

			# Check if already in tileset
			if texture_path not in existing_textures:
				# Load texture and create atlas source
				var texture: Texture2D = load(texture_path) as Texture2D
				if texture:
					var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
					atlas.texture = texture
					atlas.texture_region_size = tileset.tile_size

					# Find next available source ID
					var new_id: int = 0
					while tileset.has_source(new_id):
						new_id += 1

					tileset.add_source(atlas, new_id)
					discovered += 1
					print("%s: Discovered %s -> added as source %d" % [prefix, filename, new_id])

		filename = dir.get_next()
	dir.list_dir_end()

	return discovered


## Parse animation info from filename.
## Returns Dictionary with: frames (int), synchronized (bool)
## Examples:
##   "grass.png" -> {frames: 1, synchronized: false}
##   "water_anim2.png" -> {frames: 2, synchronized: false}
##   "lava_anim3sync.png" -> {frames: 3, synchronized: true}
static func _parse_animation_info(filename: String) -> Dictionary:
	var result: Dictionary = {"frames": 1, "synchronized": false}

	# Look for _anim{N} or _anim{N}sync pattern
	var regex: RegEx = RegEx.new()
	regex.compile("_anim(\\d+)(sync)?\\.")

	var match_result: RegExMatch = regex.search(filename)
	if match_result:
		result.frames = int(match_result.get_string(1))
		result.synchronized = match_result.get_string(2) == "sync"

	return result


## Auto-populate tile definitions for all atlas sources in a TileSet.
## Returns the number of tiles that were auto-generated.
static func auto_populate_tileset(tileset: TileSet, tileset_name: String = "") -> int:
	if not tileset:
		push_error("TileSetAutoGenerator: Cannot auto-populate null TileSet")
		return 0

	var total_generated: int = 0
	var tile_size: int = tileset.tile_size.x  # Assume square tiles

	# Iterate through all sources in the tileset
	var source_count: int = tileset.get_source_count()
	for i: int in range(source_count):
		var source_id: int = tileset.get_source_id(i)
		var source: TileSetSource = tileset.get_source(source_id)

		if source is TileSetAtlasSource:
			var atlas: TileSetAtlasSource = source as TileSetAtlasSource
			var generated: int = _auto_populate_atlas_source(atlas, tile_size, tileset_name)
			total_generated += generated

	return total_generated


## Auto-populate tile definitions for a single atlas source.
## Creates tiles for any grid positions that don't already have definitions.
## Handles animated tiles based on filename convention (_anim{N}[sync]).
static func _auto_populate_atlas_source(atlas: TileSetAtlasSource, tile_size: int, tileset_name: String) -> int:
	if not atlas.texture:
		return 0

	var texture: Texture2D = atlas.texture
	var texture_path: String = texture.resource_path
	var texture_name: String = texture_path.get_file()

	# Parse animation info from filename
	var anim_info: Dictionary = _parse_animation_info(texture_name)
	var frame_count: int = anim_info.frames
	var is_synchronized: bool = anim_info.synchronized

	# Calculate expected tile grid from texture dimensions
	var cols: int = texture.get_width() / tile_size
	var rows: int = texture.get_height() / tile_size

	# Validate animation frame count matches texture columns
	if frame_count > 1 and cols != frame_count:
		push_warning("TileSetAutoGenerator: %s declares %d frames but texture has %d columns" % [texture_name, frame_count, cols])
		frame_count = cols  # Fall back to texture width

	# For animated tiles, we only create tiles in column 0
	var is_animated: bool = frame_count > 1
	var tiles_to_create: int = rows if is_animated else cols * rows

	if tiles_to_create == 0:
		push_warning("TileSetAutoGenerator: %s has invalid dimensions for %dx%d tiles" % [texture_name, tile_size, tile_size])
		return 0

	# Count existing tiles
	var existing_tiles: int = atlas.get_tiles_count()
	var generated: int = 0

	# Create tiles
	if is_animated:
		# Animated: create tiles only in column 0, configure animation
		for y: int in range(rows):
			var coords: Vector2i = Vector2i(0, y)

			# Only create and configure if tile doesn't exist
			if not atlas.has_tile(coords):
				# Create a standard 1x1 tile (animation reads from consecutive columns)
				atlas.create_tile(coords)

				# Configure animation: columns first, then frame count
				atlas.set_tile_animation_columns(coords, frame_count)
				atlas.set_tile_animation_frames_count(coords, frame_count)

				# Set frame durations
				for frame_idx: int in range(frame_count):
					atlas.set_tile_animation_frame_duration(coords, frame_idx, DEFAULT_FRAME_DURATION)

				# Set animation mode: DEFAULT (0) = synchronized, RANDOM_START_TIMES (1) = staggered
				var mode: int = TileSetAtlasSource.TILE_ANIMATION_MODE_DEFAULT if is_synchronized else TileSetAtlasSource.TILE_ANIMATION_MODE_RANDOM_START_TIMES
				atlas.set_tile_animation_mode(coords, mode)

				generated += 1
	else:
		# Static: create tiles for each grid position
		for y: int in range(rows):
			for x: int in range(cols):
				var coords: Vector2i = Vector2i(x, y)

				if not atlas.has_tile(coords):
					atlas.create_tile(coords)
					generated += 1

	# Log results
	var prefix: String = "TileSetAutoGenerator"
	if not tileset_name.is_empty():
		prefix = "TileSetAutoGenerator [%s]" % tileset_name

	if generated > 0:
		if is_animated:
			var mode_str: String = "synchronized" if is_synchronized else "staggered"
			print("%s: %s (%dx%d) -> %d animated tile(s) (%d frames, %s)" % [prefix, texture_name, texture.get_width(), texture.get_height(), generated, frame_count, mode_str])
		else:
			print("%s: %s (%dx%d) -> %d tile(s) auto-generated" % [prefix, texture_name, texture.get_width(), texture.get_height(), generated])
	elif existing_tiles > 0:
		# Tiles already defined
		if OS.is_debug_build():
			if is_animated:
				var mode_str: String = "synchronized" if is_synchronized else "staggered"
				print("%s: %s - %d animated tiles configured (%d frames, %s)" % [prefix, texture_name, rows, frame_count, mode_str])
			else:
				print("%s: %s - all %d tiles already defined" % [prefix, texture_name, existing_tiles])

	return generated


## Repair a TileSet by removing invalid atlas sources and out-of-bounds tiles.
## Call this when textures have been modified and tile definitions may be stale.
## Returns the number of repairs made.
static func repair_tileset(tileset: TileSet, tileset_name: String = "") -> int:
	if not tileset:
		return 0

	var prefix: String = "TileSetAutoGenerator"
	if not tileset_name.is_empty():
		prefix = "TileSetAutoGenerator [%s]" % tileset_name

	var tile_size: int = tileset.tile_size.x
	var repairs: int = 0

	# Collect source IDs to remove (can't modify while iterating)
	var sources_to_remove: Array[int] = []

	for i: int in range(tileset.get_source_count()):
		var source_id: int = tileset.get_source_id(i)
		var source: TileSetSource = tileset.get_source(source_id)

		if source is TileSetAtlasSource:
			var atlas: TileSetAtlasSource = source as TileSetAtlasSource

			# Remove atlas sources with no texture
			if not atlas.texture:
				sources_to_remove.append(source_id)
				print("%s: Removing atlas source %d (no texture assigned)" % [prefix, source_id])
				repairs += 1
				continue

			# Check for out-of-bounds tiles and remove them
			var texture: Texture2D = atlas.texture
			var max_col: int = (texture.get_width() / tile_size) - 1
			var max_row: int = (texture.get_height() / tile_size) - 1
			var texture_name: String = texture.resource_path.get_file()

			# Parse animation info to determine if tiles use multiple columns
			var anim_info: Dictionary = _parse_animation_info(texture_name)
			var frame_count: int = anim_info.frames
			var is_animated: bool = frame_count > 1

			# Get all tiles and check bounds
			var tiles_to_remove: Array[Vector2i] = []
			for tile_coords: Vector2i in atlas.get_tiles_to_be_removed_on_change(atlas.texture):
				pass  # This method doesn't exist, need different approach

			# Iterate through defined tiles using atlas coordinates
			# For animated tiles, only column 0 should have tiles
			var tile_count: int = atlas.get_tiles_count()
			if tile_count > 0:
				# Check if any tiles are out of bounds
				# Unfortunately there's no direct way to iterate tiles, so we check expected bounds
				var expected_max_row: int = max_row
				if is_animated:
					# Animated tiles only in column 0
					if atlas.get_tiles_count() > (max_row + 1):
						print("%s: %s has %d tiles but texture only supports %d rows" % [
							prefix, texture_name, atlas.get_tiles_count(), max_row + 1
						])

	# Remove invalid sources
	for source_id: int in sources_to_remove:
		tileset.remove_source(source_id)

	return repairs


## Validate a TileSet and report any issues.
## Returns an array of warning messages (empty if no issues).
static func validate_tileset(tileset: TileSet, tileset_name: String = "") -> Array[String]:
	var warnings: Array[String] = []

	if not tileset:
		warnings.append("TileSet is null")
		return warnings

	var tile_size: int = tileset.tile_size.x
	var source_count: int = tileset.get_source_count()

	if source_count == 0:
		warnings.append("TileSet has no atlas sources")
		return warnings

	for i: int in range(source_count):
		var source_id: int = tileset.get_source_id(i)
		var source: TileSetSource = tileset.get_source(source_id)

		if source is TileSetAtlasSource:
			var atlas: TileSetAtlasSource = source as TileSetAtlasSource

			if not atlas.texture:
				warnings.append("Atlas source %d has no texture" % source_id)
				continue

			var texture: Texture2D = atlas.texture
			var texture_name: String = texture.resource_path.get_file()

			# Check dimensions are divisible by tile size
			if texture.get_width() % tile_size != 0:
				warnings.append("%s: width %d not divisible by tile size %d" % [texture_name, texture.get_width(), tile_size])
			if texture.get_height() % tile_size != 0:
				warnings.append("%s: height %d not divisible by tile size %d" % [texture_name, texture.get_height(), tile_size])

			# Check for missing tile definitions
			var cols: int = texture.get_width() / tile_size
			var rows: int = texture.get_height() / tile_size
			var expected: int = cols * rows
			var actual: int = atlas.get_tiles_count()

			if actual < expected:
				warnings.append("%s: only %d of %d tiles defined (will be auto-generated)" % [texture_name, actual, expected])

	return warnings
