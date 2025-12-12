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

## Health bar animation
var _health_bar_tween: Tween = null
const HEALTH_BAR_TWEEN_DURATION: float = 0.3

## Grid position
var grid_position: Vector2i = Vector2i.ZERO

## Faction: "player", "enemy", "neutral"
var faction: String = "neutral"

## AI behavior resource (for enemies/neutrals) - data-driven AI configuration
var ai_behavior: AIBehaviorData = null

## Turn state
var has_moved: bool = false
var has_acted: bool = false

## Turn priority (calculated by TurnManager based on AGI)
var turn_priority: float = 0.0

## References to child nodes (set by scene structure)
@onready var sprite: Sprite2D = $Sprite2D
@onready var selection_indicator: ColorRect = $SelectionIndicator
@onready var name_label: Label = $NameLabel
@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	# Update visuals after nodes are ready
	_update_visual()
	_update_health_bar(false)  # No animation on initial setup

	# Update name if character data already set
	if character_data and name_label:
		name_label.text = character_data.character_name


## Initialize unit from CharacterData
func initialize(
	p_character_data: CharacterData,
	p_faction: String = "neutral",
	p_ai_behavior: AIBehaviorData = null
) -> void:
	if p_character_data == null:
		push_error("Unit: Cannot initialize with null CharacterData")
		return

	character_data = p_character_data
	faction = p_faction
	ai_behavior = p_ai_behavior

	# Create stats
	var UnitStatsClass: GDScript = load("res://core/components/unit_stats.gd")
	stats = UnitStatsClass.new()
	stats.owner_unit = self  # Set reference for level-up callbacks
	stats.calculate_from_character(character_data)

	# Set visual (placeholder for now)
	_update_visual()

	# Set name label
	if name_label:
		name_label.text = character_data.character_name

	# Update health bar (no animation on initialization)
	_update_health_bar(false)

	# Hide selection indicator by default
	if selection_indicator:
		selection_indicator.visible = false



## Update sprite based on character data
func _update_visual() -> void:
	# If sprite isn't ready yet, defer until _ready()
	if not is_node_ready():
		return

	if not sprite:
		return

	# Try to load the battle sprite from character data
	if character_data and character_data.battle_sprite:
		sprite.texture = character_data.battle_sprite
		# Apply faction-based modulation for visual faction identification
		match faction:
			"player":
				sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)  # White (no tint)
			"enemy":
				sprite.modulate = Color(1.0, 0.7, 0.7, 1.0)  # Slight red tint
			"neutral":
				sprite.modulate = Color(1.0, 1.0, 0.8, 1.0)  # Slight yellow tint
	else:
		# Fallback: Create a simple colored square texture as placeholder
		sprite.texture = _create_placeholder_texture()
		match faction:
			"player":
				sprite.modulate = COLOR_PLAYER
			"enemy":
				sprite.modulate = COLOR_ENEMY
			"neutral":
				sprite.modulate = COLOR_NEUTRAL


## Create a simple placeholder texture when no sprite is available
func _create_placeholder_texture() -> ImageTexture:
	var img: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


## Update health bar display with optional animation
## animate: If true, smoothly tween to new value; if false, set immediately
func _update_health_bar(animate: bool = true) -> void:
	if not health_bar or not stats:
		return

	health_bar.max_value = stats.get_effective_max_hp()

	# Check if GameJuice is available and animation is enabled
	var should_animate: bool = animate and is_inside_tree()
	if should_animate:
		# Try to check GameJuice setting (may not be available during initialization)
		if Engine.has_singleton("GameJuice") or get_node_or_null("/root/GameJuice"):
			should_animate = GameJuice.animate_stat_bars

	if should_animate:
		# Kill existing health bar tween
		if _health_bar_tween and _health_bar_tween.is_valid():
			_health_bar_tween.kill()

		var duration: float = HEALTH_BAR_TWEEN_DURATION
		# Try to get adjusted duration from GameJuice
		if get_node_or_null("/root/GameJuice"):
			duration = GameJuice.get_adjusted_duration(HEALTH_BAR_TWEEN_DURATION)

		_health_bar_tween = create_tween()
		_health_bar_tween.tween_property(health_bar, "value", float(stats.current_hp), duration)
		_health_bar_tween.set_ease(Tween.EASE_OUT)
		_health_bar_tween.set_trans(Tween.TRANS_CUBIC)
	else:
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

	# Mark as moved this turn
	has_moved = true

	# Animate movement to new position
	var tween: Tween = _animate_movement_to(target_cell)

	# Emit moved signal AFTER animation completes (not before)
	if tween:
		tween.finished.connect(func() -> void: moved.emit(old_position, target_cell))
	else:
		# No animation, emit immediately
		moved.emit(old_position, target_cell)



## Move unit along a pathfinding path, animating through each cell
## Path should include the starting position as first element
func move_along_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		push_warning("Unit: Cannot move along empty path")
		return

	if path.size() == 1:
		# Path only contains current position, no movement needed
		return

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

	# Mark as moved this turn
	has_moved = true

	# Animate movement along the full path
	var tween: Tween = _animate_movement_along_path(path)

	# Emit moved signal AFTER animation completes (not before)
	if tween:
		tween.finished.connect(func() -> void: moved.emit(old_position, end_cell))
	else:
		# No animation, emit immediately
		moved.emit(old_position, end_cell)



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

	# Emit death signal if unit died (let BattleManager handle the visuals)
	if unit_died:
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



## Add status effect
func add_status_effect(effect_type: String, duration: int, power: int = 0) -> void:
	if stats == null:
		return

	stats.add_status_effect(effect_type, duration, power)
	status_effect_applied.emit(effect_type)


## Remove status effect
func remove_status_effect(effect_type: String) -> void:
	if stats == null:
		return

	stats.remove_status_effect(effect_type)
	status_effect_cleared.emit(effect_type)


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
	# Restore normal brightness when turn starts
	_set_acted_visual(false)
	turn_began.emit()


## End turn
func end_turn() -> void:
	turn_finished.emit()
	# Dim the unit to show they've acted this round
	_set_acted_visual(true)


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


## Set visual feedback for acted/waiting state
## When dimmed=true, unit appears darker to show they've completed their turn
func _set_acted_visual(dimmed: bool) -> void:
	if not sprite:
		return

	if dimmed:
		# Dim to ~60% brightness to show unit has acted
		sprite.modulate = sprite.modulate * Color(0.6, 0.6, 0.6, 1.0)
	else:
		# Restore based on faction (from _update_visual logic)
		if character_data and character_data.battle_sprite:
			match faction:
				"player":
					sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
				"enemy":
					sprite.modulate = Color(1.0, 0.7, 0.7, 1.0)
				"neutral":
					sprite.modulate = Color(1.0, 1.0, 0.8, 1.0)
		else:
			match faction:
				"player":
					sprite.modulate = COLOR_PLAYER
				"enemy":
					sprite.modulate = COLOR_ENEMY
				"neutral":
					sprite.modulate = COLOR_NEUTRAL


## Reset all units to undimmed state (call at round start)
func reset_acted_visual() -> void:
	_set_acted_visual(false)


## Get unit display name (for UI)
func get_display_name() -> String:
	if character_data:
		return character_data.character_name
	return "Unknown Unit"


## Get the unit's current class (respects promotion state)
## This should be used instead of directly accessing character_data.character_class
## as it handles promoted characters correctly.
## @return: ClassData for current class, or null if not available
func get_current_class() -> ClassData:
	# First check stats.class_data which is set from CharacterSaveData during init
	if stats and stats.class_data:
		return stats.class_data

	# Fallback to character_data template (for unpromoted characters or enemies)
	if character_data and character_data.character_class:
		return character_data.character_class

	return null


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


## Wait for any active movement animation to complete
## Use this instead of accessing _movement_tween directly
func await_movement_completion() -> void:
	if _movement_tween and _movement_tween.is_valid():
		await _movement_tween.finished


## Check if unit is currently animating movement
## Use this instead of accessing _movement_tween directly
func is_moving() -> bool:
	return _movement_tween != null and _movement_tween.is_valid()


## Refresh the equipment cache from CharacterSaveData
## Called when equipment changes (equip/unequip) to update combat stats
## Requires a CharacterSaveData reference - typically from PartyManager
func refresh_equipment_cache() -> void:
	if stats == null:
		push_warning("Unit: Cannot refresh equipment cache - no stats")
		return

	# Try to get save data from PartyManager
	if not character_data:
		push_warning("Unit: Cannot refresh equipment cache - no character_data")
		return

	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_data.character_uid)
	if not save_data:
		# Fall back to checking if we have a reference stored
		push_warning("Unit: Cannot refresh equipment cache - no save data found for '%s'" % character_data.character_name)
		return

	stats.load_equipment_from_save(save_data)


## Initialize unit from CharacterSaveData (for battle)
## This preserves persistent stats and equipment from saved state
func initialize_from_save_data(
	p_character_data: CharacterData,
	p_save_data: CharacterSaveData,
	p_faction: String = "neutral",
	p_ai_behavior: AIBehaviorData = null
) -> void:
	if p_character_data == null or p_save_data == null:
		push_error("Unit: Cannot initialize with null CharacterData or SaveData")
		return

	character_data = p_character_data
	faction = p_faction
	ai_behavior = p_ai_behavior

	# Create stats
	var UnitStatsClass: GDScript = load("res://core/components/unit_stats.gd")
	stats = UnitStatsClass.new()
	stats.owner_unit = self

	# Load base stats from save data instead of character data
	stats.level = p_save_data.level
	stats.current_xp = p_save_data.current_xp
	stats.max_hp = p_save_data.max_hp
	stats.current_hp = p_save_data.current_hp
	stats.max_mp = p_save_data.max_mp
	stats.current_mp = p_save_data.current_mp
	stats.strength = p_save_data.strength
	stats.defense = p_save_data.defense
	stats.agility = p_save_data.agility
	stats.intelligence = p_save_data.intelligence
	stats.luck = p_save_data.luck

	# Store character and class references
	stats.character_data = p_character_data
	# Get class from save data (handles promoted characters) with fallback to template
	stats.class_data = p_save_data.get_current_class(p_character_data)

	# Load equipment from save data
	stats.load_equipment_from_save(p_save_data)

	# Set visual (placeholder for now)
	_update_visual()

	# Set name label
	if name_label:
		name_label.text = character_data.character_name

	# Update health bar (no animation on initialization)
	_update_health_bar(false)

	# Hide selection indicator by default
	if selection_indicator:
		selection_indicator.visible = false
