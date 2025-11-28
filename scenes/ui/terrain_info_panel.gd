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
	5: "Sand",
	6: "Bridge",
	7: "Dirt Path",
}

# Terrain effects (placeholder - will be expanded with actual terrain system)
const TERRAIN_EFFECTS: Dictionary = {
	0: "No effect",
	1: "DEF +1",
	2: "DEF +2, AGI -1",
	3: "Impassable (ground)",
	4: "MOV cost reduced",
	5: "MOV +1 cost",
	6: "Crosses water",
	7: "No effect",
}


func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0


## Display terrain information for the given cell.
func show_terrain_info(unit_cell: Vector2i) -> void:
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


## Hide the terrain panel with animation.
func hide_terrain_info() -> void:
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


## Get the terrain type ID at the specified cell.
func _get_terrain_type_at_cell(cell: Vector2i) -> int:
	# TODO: Integrate with GridManager's terrain system when custom data layers are added to tileset
	# For now, return default terrain (0 = Plains)
	# Once terrain_type custom data is added to the tileset, uncomment the code below:
	#
	# if GridManager.tilemap:
	#     var tile_data: TileData = GridManager.tilemap.get_cell_tile_data(cell)
	#     if tile_data:
	#         var terrain_type: Variant = tile_data.get_custom_data("terrain_type")
	#         if terrain_type is int:
	#             return terrain_type

	# Default to Plains until custom data layers are configured
	return 0
