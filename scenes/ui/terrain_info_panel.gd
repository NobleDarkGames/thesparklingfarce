## TerrainInfoPanel - Displays terrain information for the active unit's cell
##
## Shows terrain name and effects in a small panel at the top-left of the screen.
## Appears when a unit's turn starts.
## Now uses the TerrainData system via GridManager for real terrain effects.
class_name TerrainInfoPanel
extends PanelContainer

@onready var terrain_name_label: Label = %TerrainNameLabel
@onready var terrain_effect_label: Label = %TerrainEffectLabel

var _current_tween: Tween = null


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

	# Get terrain data from GridManager
	var terrain: TerrainData = GridManager.get_terrain_at_cell(unit_cell)

	# Update labels
	terrain_name_label.text = terrain.display_name
	terrain_effect_label.text = _format_terrain_effects(terrain)

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


## Format terrain effects into a readable string
func _format_terrain_effects(terrain: TerrainData) -> String:
	var effects: Array[String] = []

	# Defense bonus
	if terrain.defense_bonus > 0:
		effects.append("DEF +%d" % terrain.defense_bonus)

	# Evasion bonus
	if terrain.evasion_bonus > 0:
		effects.append("EVA +%d%%" % terrain.evasion_bonus)

	# Damage per turn
	if terrain.damage_per_turn > 0:
		effects.append("DMG %d/turn" % terrain.damage_per_turn)

	# Healing per turn (shows even though deferred - players can see what terrain will do)
	if terrain.healing_per_turn > 0:
		effects.append("HEAL %d/turn" % terrain.healing_per_turn)

	# Movement cost for ground units (only show if not standard cost 1)
	if terrain.movement_cost_walking > 1:
		effects.append("MOV x%d" % terrain.movement_cost_walking)

	# Impassable indicators
	if terrain.impassable_walking and terrain.impassable_floating and terrain.impassable_flying:
		effects.append("Impassable")
	elif terrain.impassable_walking and terrain.impassable_floating:
		effects.append("Ground/Float: Blocked")
	elif terrain.impassable_walking:
		effects.append("Ground: Blocked")

	if effects.is_empty():
		return "No effect"

	return ", ".join(effects)
