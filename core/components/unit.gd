## Unit - Represents a battle unit (player or enemy)
##
## Component-based architecture for tactical RPG units.
## Handles stats, position, turn state, and signals for battle events.
class_name Unit
extends Node2D

# No preload needed - use load() in initialize()

# Faction visual colors (placeholder until sprites are implemented)
const COLOR_PLAYER: Color = Color(0.2, 0.8, 1.0, 1.0)  # Bright cyan
const COLOR_ENEMY: Color = Color(1.0, 0.2, 0.2, 1.0)  # Bright red
const COLOR_NEUTRAL: Color = Color(1.0, 1.0, 0.2, 1.0)  # Bright yellow

## Signals for battle events
signal moved(from: Vector2i, to: Vector2i)
signal attacked(target: Node2D, damage: int)  # Changed from Unit to Node2D
signal damaged(amount: int)
signal healed(amount: int)
signal died()
signal turn_began()
signal turn_finished()
signal status_effect_applied(effect_type: String)
signal status_effect_cleared(effect_type: String)

## Source character data
@export var character_data: CharacterData = null

## Runtime stats
var stats: RefCounted = null  # UnitStats instance

## Movement animation settings
var movement_speed: float = 200.0  # Pixels per second
var _movement_tween: Tween = null

## Grid position
var grid_position: Vector2i = Vector2i.ZERO

## Faction: "player", "enemy", "neutral"
var faction: String = "neutral"

## AI brain resource (for enemies/neutrals) - NEW SYSTEM
var ai_brain: Resource = null  # AIBrain instance

## Turn state
var has_moved: bool = false
var has_acted: bool = false

## Turn priority (calculated by TurnManager based on AGI)
var turn_priority: float = 0.0

## References to child nodes (set by scene structure)
@onready var sprite: ColorRect = $Sprite2D
@onready var selection_indicator: ColorRect = $SelectionIndicator
@onready var name_label: Label = $NameLabel
@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	# Update visuals after nodes are ready
	_update_visual()
	_update_health_bar()


## Initialize unit from CharacterData
func initialize(
	p_character_data: CharacterData,
	p_faction: String = "neutral",
	p_ai_brain: Resource = null
) -> void:
	if p_character_data == null:
		push_error("Unit: Cannot initialize with null CharacterData")
		return

	character_data = p_character_data
	faction = p_faction
	ai_brain = p_ai_brain

	# Create stats
	var UnitStatsClass: GDScript = load("res://core/components/unit_stats.gd")
	stats = UnitStatsClass.new()
	stats.calculate_from_character(character_data)

	# Set visual (placeholder for now)
	_update_visual()

	# Set name label
	if name_label:
		name_label.text = character_data.character_name

	# Update health bar
	_update_health_bar()

	# Hide selection indicator by default
	if selection_indicator:
		selection_indicator.visible = false

	print("Unit initialized: %s (Lv%d %s)" % [character_data.character_name, stats.level, faction])


## Update sprite based on character data
func _update_visual() -> void:
	# If sprite isn't ready yet, defer until _ready()
	if not is_node_ready():
		return

	if not sprite:
		return

	# For now, use ColorRect with faction colors (no sprites yet)
	var placeholder_color: Color = Color.GRAY
	match faction:
		"player":
			placeholder_color = COLOR_PLAYER
		"enemy":
			placeholder_color = COLOR_ENEMY
		"neutral":
			placeholder_color = COLOR_NEUTRAL

	sprite.color = placeholder_color


## Update health bar display
func _update_health_bar() -> void:
	if not health_bar or not stats:
		return

	health_bar.max_value = stats.max_hp
	health_bar.value = stats.current_hp


## Move unit to new grid position (direct movement, no path following)
## Does NOT handle pathfinding - caller must validate path
## NOTE: Prefer move_along_path() for visible path following
func move_to(target_cell: Vector2i) -> void:
	if not GridManager.is_within_bounds(target_cell):
		push_error("Unit: Cannot move to %s (out of bounds)" % target_cell)
		return

	if GridManager.is_cell_occupied(target_cell):
		push_error("Unit: Cannot move to %s (occupied)" % target_cell)
		return

	var old_position: Vector2i = grid_position

	# Update GridManager occupation
	GridManager.move_unit(self, old_position, target_cell)

	# Update internal position
	grid_position = target_cell

	# Animate movement to new position
	_animate_movement_to(target_cell)

	# Mark as moved this turn
	has_moved = true

	# Emit signal
	moved.emit(old_position, target_cell)

	print("%s moved from %s to %s" % [character_data.character_name, old_position, target_cell])


## Move unit along a pathfinding path, animating through each cell
## Path should include the starting position as first element
func move_along_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		push_warning("Unit: Cannot move along empty path")
		return

	if path.size() == 1:
		# Path only contains current position, no movement needed
		return

	var start_cell: Vector2i = path[0]
	var end_cell: Vector2i = path[path.size() - 1]

	# Validate end position
	if not GridManager.is_within_bounds(end_cell):
		push_error("Unit: Cannot move to %s (out of bounds)" % end_cell)
		return

	if GridManager.is_cell_occupied(end_cell):
		push_error("Unit: Cannot move to %s (occupied)" % end_cell)
		return

	var old_position: Vector2i = grid_position

	# Update GridManager occupation (only at start and end)
	GridManager.move_unit(self, old_position, end_cell)

	# Update internal position to final destination
	grid_position = end_cell

	# Animate movement along the full path
	_animate_movement_along_path(path)

	# Mark as moved this turn
	has_moved = true

	# Emit signal
	moved.emit(old_position, end_cell)

	print("%s moved from %s to %s along %d-cell path" % [character_data.character_name, old_position, end_cell, path.size()])


## Animate smooth movement to target cell
func _animate_movement_to(target_cell: Vector2i) -> Tween:
	# Kill any existing movement tween
	if _movement_tween and _movement_tween.is_valid():
		_movement_tween.kill()
		_movement_tween = null

	# Get target world position
	var target_position: Vector2 = GridManager.cell_to_world(target_cell)

	# Calculate distance and duration
	var distance: float = position.distance_to(target_position)
	var duration: float = distance / movement_speed

	print("DEBUG [TO REMOVE]: %s animating movement over %.2fs (distance: %.1f)" % [character_data.character_name, duration, distance])  # DEBUG: TO REMOVE

	# Create tween for smooth movement
	_movement_tween = create_tween()
	_movement_tween.set_trans(Tween.TRANS_LINEAR)
	_movement_tween.set_ease(Tween.EASE_IN_OUT)

	# Animate position
	_movement_tween.tween_property(self, "position", target_position, duration)

	return _movement_tween


## Animate movement along a path, stepping through each cell
func _animate_movement_along_path(path: Array[Vector2i]) -> Tween:
	# Kill any existing movement tween
	if _movement_tween and _movement_tween.is_valid():
		_movement_tween.kill()
		_movement_tween = null

	# Create tween for the entire path
	_movement_tween = create_tween()
	_movement_tween.set_trans(Tween.TRANS_LINEAR)
	_movement_tween.set_ease(Tween.EASE_IN_OUT)

	# Animate through each cell in the path (skip first cell as it's the current position)
	for i in range(1, path.size()):
		var cell: Vector2i = path[i]
		var target_position: Vector2 = GridManager.cell_to_world(cell)

		# Calculate duration for this step based on distance
		var current_pos: Vector2 = GridManager.cell_to_world(path[i - 1]) if i > 0 else position
		var distance: float = current_pos.distance_to(target_position)
		var duration: float = distance / movement_speed

		# Chain the movement to this cell
		_movement_tween.tween_property(self, "position", target_position, duration)

	print("DEBUG [TO REMOVE]: %s animating along %d-cell path" % [character_data.character_name, path.size()])

	return _movement_tween


## Take damage from attack
func take_damage(damage: int) -> void:
	if stats == null:
		push_error("Unit: Cannot take damage (no stats)")
		return

	# Apply damage
	var unit_died: bool = stats.take_damage(damage)

	# Update health bar
	_update_health_bar()

	# Emit signal
	damaged.emit(damage)

	print("%s takes %d damage (HP: %d/%d)" % [character_data.character_name, damage, stats.current_hp, stats.max_hp])

	# Emit death signal if unit died (let BattleManager handle the visuals)
	if unit_died:
		print("%s has died!" % character_data.character_name)
		GridManager.clear_cell_occupied(grid_position)
		died.emit()


## Heal HP
func heal(amount: int) -> void:
	if stats == null:
		return

	var old_hp: int = stats.current_hp
	stats.heal(amount)
	var actual_heal: int = stats.current_hp - old_hp

	# Update health bar
	_update_health_bar()

	# Emit signal
	healed.emit(actual_heal)

	print("%s heals %d HP (HP: %d/%d)" % [character_data.character_name, actual_heal, stats.current_hp, stats.max_hp])


## Add status effect
func add_status_effect(effect_type: String, duration: int, power: int = 0) -> void:
	if stats == null:
		return

	stats.add_status_effect(effect_type, duration, power)
	status_effect_applied.emit(effect_type)
	print("%s gains status: %s (duration: %d)" % [character_data.character_name, effect_type, duration])


## Remove status effect
func remove_status_effect(effect_type: String) -> void:
	if stats == null:
		return

	stats.remove_status_effect(effect_type)
	status_effect_cleared.emit(effect_type)
	print("%s loses status: %s" % [character_data.character_name, effect_type])


## Check if unit has status effect
func has_status_effect(effect_type: String) -> bool:
	if stats == null:
		return false
	return stats.has_status_effect(effect_type)


## Process status effects (call at end of turn)
func process_status_effects() -> void:
	if stats == null:
		return

	var still_alive: bool = stats.process_status_effects()

	# Update health bar
	_update_health_bar()

	# Emit death signal if died from status effects (let BattleManager handle the visuals)
	if not still_alive:
		print("%s has died from status effects!" % character_data.character_name)
		GridManager.clear_cell_occupied(grid_position)
		died.emit()


## Check if unit is alive
func is_alive() -> bool:
	return stats != null and stats.is_alive()


## Check if unit is dead
func is_dead() -> bool:
	return not is_alive()


## Start turn (reset turn flags)
func start_turn() -> void:
	has_moved = false
	has_acted = false
	turn_began.emit()
	print("%s turn started" % character_data.character_name)


## End turn
func end_turn() -> void:
	turn_finished.emit()
	print("%s turn ended" % character_data.character_name)


## Check if unit can still act this turn
func can_act() -> bool:
	return not has_acted and is_alive()


## Check if unit can still move this turn
func can_move() -> bool:
	return not has_moved and is_alive()


## Mark unit as having acted
func mark_acted() -> void:
	has_acted = true


## Show selection indicator
func show_selection() -> void:
	if selection_indicator:
		selection_indicator.visible = true


## Hide selection indicator
func hide_selection() -> void:
	if selection_indicator:
		selection_indicator.visible = false


## Handle unit death (DEPRECATED - death visuals now handled by BattleManager)
## This method is kept for backwards compatibility but no longer creates tweens
func _handle_death() -> void:
	print("%s has died!" % character_data.character_name)
	GridManager.clear_cell_occupied(grid_position)
	died.emit()
	# Note: BattleManager is responsible for death visuals and cleanup


## Get unit display name (for UI)
func get_display_name() -> String:
	if character_data:
		return character_data.character_name
	return "Unknown Unit"


## Get unit stats summary for debug
func get_stats_summary() -> String:
	if stats:
		return stats.get_stats_string()
	return "No stats"


## Check if unit is player-controlled
func is_player_unit() -> bool:
	return faction == "player"


## Check if unit is enemy
func is_enemy_unit() -> bool:
	return faction == "enemy"


## Check if unit is neutral
func is_neutral_unit() -> bool:
	return faction == "neutral"
