class_name TileSetAutoGenerator
extends RefCounted

## Utility for auto-generating tile definitions in TileSets based on atlas texture dimensions.
## This allows modders to simply add PNG files to their tileset without manually editing
## the TileSet .tres file to define each tile position.
##
## Called automatically by ModLoader when loading tilesets.
##
## Example output:
##   TileSetAutoGenerator: grass.png (32x128) -> 4 tiles auto-generated
##   TileSetAutoGenerator: water.png (32x128) -> 4 tiles auto-generated
##   TileSetAutoGenerator: lava.png - all 6 tiles already defined, skipping


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
static func _auto_populate_atlas_source(atlas: TileSetAtlasSource, tile_size: int, tileset_name: String) -> int:
	if not atlas.texture:
		return 0

	var texture: Texture2D = atlas.texture
	var texture_path: String = texture.resource_path
	var texture_name: String = texture_path.get_file()

	# Calculate expected tile grid from texture dimensions
	var cols: int = texture.get_width() / tile_size
	var rows: int = texture.get_height() / tile_size
	var expected_tiles: int = cols * rows

	if expected_tiles == 0:
		push_warning("TileSetAutoGenerator: %s has invalid dimensions for %dx%d tiles" % [texture_name, tile_size, tile_size])
		return 0

	# Count existing tiles and find missing positions
	var existing_tiles: int = atlas.get_tiles_count()
	var generated: int = 0

	# Check each grid position
	for y: int in range(rows):
		for x: int in range(cols):
			var coords: Vector2i = Vector2i(x, y)

			# Check if tile already exists at this position
			if not atlas.has_tile(coords):
				# Create the tile
				atlas.create_tile(coords)
				generated += 1

	# Log results
	var prefix: String = "TileSetAutoGenerator"
	if not tileset_name.is_empty():
		prefix = "TileSetAutoGenerator [%s]" % tileset_name

	if generated > 0:
		print("%s: %s (%dx%d) -> %d tile(s) auto-generated" % [prefix, texture_name, texture.get_width(), texture.get_height(), generated])
	elif existing_tiles == expected_tiles:
		# All tiles already defined - only log in verbose mode
		if OS.is_debug_build():
			print("%s: %s - all %d tiles already defined" % [prefix, texture_name, existing_tiles])
	else:
		# Some mismatch - warn about it
		push_warning("%s: %s has %d tiles defined but texture supports %d" % [prefix, texture_name, existing_tiles, expected_tiles])

	return generated


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
