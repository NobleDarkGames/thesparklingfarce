## TerrainInfoPanel - Displays terrain information for the active unit's cell
##
## Shows terrain name and effects in a small panel at the top-left of the screen.
## Appears when a unit's turn starts.
class_name TerrainInfoPanel
extends PanelContainer

@onready var terrain_name_label: Label = %TerrainNameLabel
@onready var terrain_effect_label: Label = %TerrainEffectLabel

var _current_tween: Tween = null

# Terrain type to name mapping
const TERRAIN_NAMES: Dictionary = {
	0: "Plains",
	1: "Forest",
	2: "Mountain",
	3: "Water",
	4: "Road",
}

# Terrain effects (placeholder - will be expanded with actual terrain system)
const TERRAIN_EFFECTS: Dictionary = {
	0: "No effect",
	1: "DEF +1",
	2: "DEF +2, AGI -1",
	3: "Impassable (ground)",
	4: "MOV cost reduced",
}


func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0


func show_terrain_info(unit_cell: Vector2i) -> void:
	"""Display terrain information for the given cell."""
	# Kill any existing tween to prevent conflicts
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

	# Get terrain type from TileMapLayer
	var terrain_type: int = _get_terrain_type_at_cell(unit_cell)

	# Update labels
	terrain_name_label.text = TERRAIN_NAMES.get(terrain_type, "Unknown")
	terrain_effect_label.text = TERRAIN_EFFECTS.get(terrain_type, "No data")

	# Force visible and animate in
	visible = true
	modulate.a = 0.0
	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 1.0, 0.2)


func hide_terrain_info() -> void:
	"""Hide the terrain panel with animation."""
	# Kill any existing tween to prevent conflicts
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

	# If already hidden, don't animate
	if not visible:
		return

	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_current_tween.tween_callback(func() -> void: visible = false)


func _get_terrain_type_at_cell(cell: Vector2i) -> int:
	"""Get the terrain type ID at the specified cell."""
	# For now, return default terrain (0 = Plains)
	# TODO: Integrate with GridManager's terrain system when custom data is added
	if GridManager.tilemap:
		var tile_data: TileData = GridManager.tilemap.get_cell_tile_data(cell)
		if tile_data and tile_data.get_custom_data_layer_count() > 0:
			# Try to get terrain_type from custom data
			# This will work when we add custom data layers to the tileset
			if tile_data.has_custom_data("terrain_type"):
				return tile_data.get_custom_data("terrain_type")

	# Default to Plains if no terrain data available
	return 0
