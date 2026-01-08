## Unit - Represents a battle unit (player or enemy)
##
## Component-based architecture for tactical RPG units.
## Handles stats, position, turn state, and signals for battle events.
class_name Unit
extends Node2D

const FacingUtils = preload("res://core/utils/facing_utils.gd")
const UnitStatsScript: GDScript = preload("res://core/components/unit_stats.gd")
const UIColors = preload("res://core/utils/ui_colors.gd")
const DEBUG_MODE: bool = false

# Faction tint colors for character sprites
const TINT_PLAYER: Color = Color(1.0, 1.0, 1.0, 1.0)  # No tint
const TINT_ENEMY: Color = Color(1.0, 0.7, 0.7, 1.0)  # Slight red tint
const TINT_NEUTRAL: Color = Color(1.0, 1.0, 0.8, 1.0)  # Slight yellow tint

## Signals for battle events
signal moved(from: Vector2i, to: Vector2i)
signal cell_entered(cell: Vector2i)  ## Emitted when unit reaches each cell during path movement
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
var stats: UnitStats = null

## Movement animation settings
var movement_speed: float = 200.0  # Pixels per second
var _movement_tween: Tween = null

## Health bar animation
var _health_bar_tween: Tween = null
@export var health_bar_tween_duration: float = 0.3

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

## Current facing direction (for sprite animations)
## Valid values: "down", "up", "left", "right"
var facing_direction: String = "down"

## References to child nodes (set by scene structure)
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
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
	stats = UnitStatsScript.new()
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



## Update sprite based on character data (SF2-authentic: same sprite for map and battle)
func _update_visual() -> void:
	# If sprite isn't ready yet, defer until _ready()
	if not is_node_ready():
		return

	if not sprite:
		return

	# Try to load sprite_frames from character data
	if character_data and character_data.sprite_frames:
		sprite.sprite_frames = character_data.sprite_frames
		# SF2-authentic: walk animation plays continuously (even when stationary)
		if character_data.sprite_frames.has_animation("walk_down"):
			sprite.animation = "walk_down"
			sprite.play()
		sprite.modulate = _get_faction_modulate(true)
	else:
		# Fallback: Create placeholder sprite_frames with colored square
		sprite.sprite_frames = _create_placeholder_sprite_frames()
		sprite.animation = "walk_down"
		sprite.play()
		sprite.modulate = _get_faction_modulate(false)


## Path to default character spritesheet in core assets
const DEFAULT_SPRITESHEET_PATH: String = "res://core/assets/defaults/sprites/default_character_spritesheet.png"
const DEFAULT_FRAME_SIZE: Vector2i = Vector2i(32, 32)


## Create placeholder SpriteFrames using the core default spritesheet
## Spritesheet format: 64x128 (2 columns × 4 rows of 32x32 frames)
## Rows: down, left, right, up (standard 4-direction layout)
func _create_placeholder_sprite_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()

	# Remove default animation if present
	if frames.has_animation("default"):
		frames.remove_animation("default")

	# Try to load the default spritesheet
	var spritesheet: Texture2D = load(DEFAULT_SPRITESHEET_PATH)
	if not spritesheet:
		# Ultimate fallback: create a simple colored square
		push_warning("Unit: Could not load default spritesheet at %s" % DEFAULT_SPRITESHEET_PATH)
		return _create_emergency_placeholder_frames()

	# Create atlas textures for each frame
	# Row 0: down (frames 0, 1), Row 1: left, Row 2: right, Row 3: up
	# SF2-authentic: only walk animations (no separate idle)
	var directions: Array[String] = ["walk_down", "walk_left", "walk_right", "walk_up"]

	for row: int in range(4):
		var anim_name: String = directions[row]
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 4.0)

		for col: int in range(2):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = spritesheet
			atlas.region = Rect2(
				col * DEFAULT_FRAME_SIZE.x,
				row * DEFAULT_FRAME_SIZE.y,
				DEFAULT_FRAME_SIZE.x,
				DEFAULT_FRAME_SIZE.y
			)
			frames.add_frame(anim_name, atlas)

	return frames


## Emergency fallback if even the default spritesheet can't be loaded
func _create_emergency_placeholder_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	# Create a simple colored square texture
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var texture: ImageTexture = ImageTexture.create_from_image(img)

	frames.add_animation("walk_down")
	frames.set_animation_loop("walk_down", true)
	frames.set_animation_speed("walk_down", 1.0)
	frames.add_frame("walk_down", texture)
	return frames


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
		var game_juice: Node = get_node_or_null("/root/GameJuice")
		if game_juice:
			should_animate = game_juice.animate_stat_bars

	if should_animate:
		# Kill existing health bar tween
		if _health_bar_tween and _health_bar_tween.is_valid():
			_health_bar_tween.kill()

		var duration: float = health_bar_tween_duration
		# Try to get adjusted duration from GameJuice
		if get_node_or_null("/root/GameJuice"):
			duration = GameJuice.get_adjusted_duration(health_bar_tween_duration)

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

	# Update facing direction based on movement
	_update_facing_from_movement(grid_position, target_cell)

	# Play walk animation
	_play_directional_animation()

	# Create tween for smooth movement
	_movement_tween = create_tween()
	_movement_tween.set_trans(Tween.TRANS_LINEAR)
	_movement_tween.set_ease(Tween.EASE_IN_OUT)

	# Animate position
	_movement_tween.tween_property(self, "position", target_position, duration)

	# Return to idle when movement completes
	_movement_tween.tween_callback(_play_directional_animation)

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

	# Track previous direction to detect direction changes
	var prev_direction: String = ""

	# Animate through each cell in the path (skip first cell as it's the current position)
	for i: int in range(1, path.size()):
		var prev_cell: Vector2i = path[i - 1]
		var cell: Vector2i = path[i]
		var target_position: Vector2 = GridManager.cell_to_world(cell)

		# Calculate direction for this step
		var step_direction: String = _direction_to_string(cell - prev_cell)

		# Update facing and animation when direction changes (or on first step)
		if step_direction != prev_direction:
			var new_dir: String = step_direction  # Capture for lambda
			_movement_tween.tween_callback(func() -> void:
				facing_direction = new_dir
				_play_directional_animation()
			)
			prev_direction = step_direction

		# Calculate duration for this step based on distance
		var current_pos: Vector2 = GridManager.cell_to_world(prev_cell)
		var distance: float = current_pos.distance_to(target_position)
		var duration: float = distance / movement_speed

		# Chain the movement to this cell
		_movement_tween.tween_property(self, "position", target_position, duration)

		# Emit cell_entered when reaching this cell (for terrain panel updates, etc.)
		var entered_cell: Vector2i = cell  # Capture for lambda
		_movement_tween.tween_callback(func() -> void: cell_entered.emit(entered_cell))

	# Return to idle when movement completes
	_movement_tween.tween_callback(_play_directional_animation)

	return _movement_tween


## Take damage from attack
## Checks status effects for removed_on_damage using registry (data-driven)
func take_damage(damage: int) -> void:
	if stats == null:
		push_error("Unit: Cannot take damage (no stats)")
		return

	# Check for status effects that should be removed on damage
	if damage > 0:
		_check_effects_removed_on_damage()

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


## Check all status effects for removed_on_damage flag
## Uses data-driven StatusEffectData with legacy fallback
func _check_effects_removed_on_damage() -> void:
	if stats == null:
		return

	# Build list of effects to remove (iterate backwards to safely modify)
	var effects_to_remove: Array[String] = []

	for effect_state: Dictionary in stats.status_effects:
		var effect_type: String = effect_state.get("type", "")

		# Look up effect data from registry
		var effect_data: StatusEffectData = ModLoader.status_effect_registry.get_effect(effect_type)

		if effect_data:
			# Data-driven: check removed_on_damage flag
			if effect_data.removed_on_damage:
				# Check removal chance
				if randi_range(1, 100) <= effect_data.removal_on_damage_chance:
					effects_to_remove.append(effect_type)
					if DEBUG_MODE:
						print("[Unit] %s: %s removed by damage!" % [get_display_name(), effect_data.display_name])
		else:
			# Effect not found in registry - this should be fixed by adding the effect to a mod
			push_warning("Unit: Status effect '%s' not found in registry. Add it via StatusEffectData resource." % effect_type)

	# Remove flagged effects
	for effect_type: String in effects_to_remove:
		remove_status_effect(effect_type)


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

	var has_sprite_frames: bool = character_data and character_data.sprite_frames
	if dimmed:
		# Dim to ~60% brightness to show unit has acted
		sprite.modulate = _get_faction_modulate(has_sprite_frames) * Color(0.6, 0.6, 0.6, 1.0)
	else:
		sprite.modulate = _get_faction_modulate(has_sprite_frames)


## Reset all units to undimmed state (call at round start)
func reset_acted_visual() -> void:
	_set_acted_visual(false)


## Get faction-appropriate modulate color
## has_character_sprite: true if using character sprite_frames, false if using placeholder
func _get_faction_modulate(has_character_sprite: bool) -> Color:
	if has_character_sprite:
		match faction:
			"player": return TINT_PLAYER
			"enemy": return TINT_ENEMY
			_: return TINT_NEUTRAL
	else:
		# Use centralized UIColors for placeholder sprites
		match faction:
			"player": return UIColors.FACTION_ALLY
			"enemy": return UIColors.FACTION_ENEMY
			_: return UIColors.FACTION_NEUTRAL


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


# =============================================================================
# FACING SYSTEM (SF2-Authentic: Units face direction of movement/action)
# =============================================================================

## Set facing direction and update sprite animation
## direction: "up", "down", "left", "right"
func set_facing(direction: String) -> void:
	facing_direction = direction.to_lower()
	_play_directional_animation()


## Face toward a target position (for attacks, spells, etc.)
## target_pos: Grid position to face toward
func face_toward(target_pos: Vector2i) -> void:
	var delta: Vector2i = target_pos - grid_position
	set_facing(FacingUtils.get_dominant_direction(delta))


## Convert Vector2i direction to string name (delegates to FacingUtils)
func _direction_to_string(direction: Vector2i) -> String:
	return FacingUtils.direction_to_string(direction)


## Play directional walk animation (SF2-authentic: walk plays continuously, even when stationary)
func _play_directional_animation() -> void:
	if not sprite or not sprite.sprite_frames:
		return

	var anim_name: String = "walk_" + facing_direction
	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
	elif sprite.sprite_frames.has_animation("walk_down"):
		sprite.play("walk_down")


## Update facing direction based on movement from one cell to another
func _update_facing_from_movement(from: Vector2i, to: Vector2i) -> void:
	var delta: Vector2i = to - from
	if delta == Vector2i.ZERO:
		return
	facing_direction = FacingUtils.get_dominant_direction(delta)


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
	stats = UnitStatsScript.new()
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


func _exit_tree() -> void:
	# Kill any active tweens to prevent callbacks on freed node
	if _movement_tween and _movement_tween.is_valid():
		_movement_tween.kill()
		_movement_tween = null
	if _health_bar_tween and _health_bar_tween.is_valid():
		_health_bar_tween.kill()
		_health_bar_tween = null
