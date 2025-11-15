## Unit - Represents a battle unit (player or enemy)
##
## Component-based architecture for tactical RPG units.
## Handles stats, position, turn state, and signals for battle events.
class_name Unit
extends Node2D

# No preload needed - use load() in initialize()

## Signals for battle events
signal moved(from: Vector2i, to: Vector2i)
signal attacked(target: Node2D, damage: int)  # Changed from Unit to Node2D
signal damaged(amount: int)
signal healed(amount: int)
signal died()
signal turn_started()
signal turn_ended()
signal status_effect_added(effect_type: String)
signal status_effect_removed(effect_type: String)

## Source character data
@export var character_data: CharacterData = null

## Runtime stats
var stats: RefCounted = null  # UnitStats instance

## Grid position
var grid_position: Vector2i = Vector2i.ZERO

## Faction: "player", "enemy", "neutral"
var faction: String = "neutral"

## AI behavior (for enemies/neutrals): "aggressive", "defensive", "stationary", "patrol", "support"
var ai_behavior: String = "aggressive"

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
func initialize(p_character_data: CharacterData, p_faction: String = "neutral", p_ai_behavior: String = "aggressive") -> void:
	if p_character_data == null:
		push_error("Unit: Cannot initialize with null CharacterData")
		return

	character_data = p_character_data
	faction = p_faction
	ai_behavior = p_ai_behavior

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
			placeholder_color = Color(0.2, 0.8, 1.0, 1.0)  # Bright cyan
		"enemy":
			placeholder_color = Color(1.0, 0.2, 0.2, 1.0)  # Bright red
		"neutral":
			placeholder_color = Color(1.0, 1.0, 0.2, 1.0)  # Bright yellow

	sprite.color = placeholder_color


## Update health bar display
func _update_health_bar() -> void:
	if not health_bar or not stats:
		return

	health_bar.max_value = stats.max_hp
	health_bar.value = stats.current_hp


## Move unit to new grid position
## Does NOT handle pathfinding - caller must validate path
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

	# Update world position
	position = GridManager.cell_to_world(target_cell)

	# Mark as moved this turn
	has_moved = true

	# Emit signal
	emit_signal("moved", old_position, target_cell)

	print("%s moved from %s to %s" % [character_data.character_name, old_position, target_cell])


## Take damage from attack
func take_damage(damage: int) -> void:
	if stats == null:
		push_error("Unit: Cannot take damage (no stats)")
		return

	# Apply damage
	var died: bool = stats.take_damage(damage)

	# Update health bar
	_update_health_bar()

	# Emit signal
	emit_signal("damaged", damage)

	print("%s takes %d damage (HP: %d/%d)" % [character_data.character_name, damage, stats.current_hp, stats.max_hp])

	# Check if died
	if died:
		_handle_death()


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
	emit_signal("healed", actual_heal)

	print("%s heals %d HP (HP: %d/%d)" % [character_data.character_name, actual_heal, stats.current_hp, stats.max_hp])


## Add status effect
func add_status_effect(effect_type: String, duration: int, power: int = 0) -> void:
	if stats == null:
		return

	stats.add_status_effect(effect_type, duration, power)
	emit_signal("status_effect_added", effect_type)
	print("%s gains status: %s (duration: %d)" % [character_data.character_name, effect_type, duration])


## Remove status effect
func remove_status_effect(effect_type: String) -> void:
	if stats == null:
		return

	stats.remove_status_effect(effect_type)
	emit_signal("status_effect_removed", effect_type)
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

	# Check if died from status effects
	if not still_alive:
		_handle_death()


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
	emit_signal("turn_started")
	print("%s turn started" % character_data.character_name)


## End turn
func end_turn() -> void:
	emit_signal("turn_ended")
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


## Handle unit death
func _handle_death() -> void:
	print("%s has died!" % character_data.character_name)

	# Clear from GridManager
	GridManager.clear_cell_occupied(grid_position)

	# Emit death signal
	emit_signal("died")

	# Visual feedback (fade out)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished

	# Remove from scene (BattleManager will handle cleanup)
	# Don't queue_free here - let BattleManager do it


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
