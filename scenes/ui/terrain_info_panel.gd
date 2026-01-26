## TerrainInfoPanel - Displays terrain information for the active unit's cell
##
## Shows terrain name and effects in a small panel at the top-left of the screen.
## Appears when a unit's turn starts.
## Now uses the TerrainData system via GridManager for real terrain effects.
class_name TerrainInfoPanel
extends PanelContainer

@onready var terrain_name_label: Label = %TerrainNameLabel
@onready var terrain_effect_label: Label = %TerrainEffectLabel

## Animation settings
const SLIDE_OFFSET: float = 15.0
const ANIMATION_DURATION: float = 0.2

var _current_tween: Tween = null
var _original_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0
	# Store original position once ready
	call_deferred("_store_original_position")


func _store_original_position() -> void:
	_original_position = position


## Display terrain information for the given cell (with animation).
## Use update_terrain_info() for rapid updates during movement.
func show_terrain_info(unit_cell: Vector2i) -> void:
	UIUtils.kill_tween(_current_tween)
	_current_tween = null

	# Get terrain data from GridManager
	var terrain: TerrainData = GridManager.get_terrain_at_cell(unit_cell)

	# Update labels
	terrain_name_label.text = terrain.display_name
	terrain_effect_label.text = _format_terrain_effects(terrain)

	# If already visible, skip animation (just update text)
	if visible and modulate.a > 0.9:
		return

	# Setup for animation - slide down from above
	visible = true
	modulate.a = 0.0
	position = _original_position - Vector2(0, SLIDE_OFFSET)

	# Animate in with slide + fade
	var duration: float = GameJuice.get_adjusted_duration(ANIMATION_DURATION)
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(self, "modulate:a", 1.0, duration)
	_current_tween.tween_property(self, "position", _original_position, duration)


## Update terrain info without animation (for rapid updates during movement)
func update_terrain_info(unit_cell: Vector2i) -> void:
	var terrain: TerrainData = GridManager.get_terrain_at_cell(unit_cell)
	terrain_name_label.text = terrain.display_name
	terrain_effect_label.text = _format_terrain_effects(terrain)


## Hide the terrain panel with animation.
func hide_terrain_info() -> void:
	UIUtils.kill_tween(_current_tween)
	_current_tween = null

	# If already hidden, don't animate
	if not visible:
		return

	var duration: float = GameJuice.get_adjusted_duration(ANIMATION_DURATION * 0.7)
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_current_tween.tween_property(self, "modulate:a", 0.0, duration)
	_current_tween.tween_property(self, "position:y", _original_position.y - SLIDE_OFFSET, duration)
	_current_tween.chain().tween_callback(func() -> void:
		visible = false
		position = _original_position
	)


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
