@tool
class_name NPCNode
extends Area2D

## NPCNode - A map entity that players can interact with.
## When the player presses the interact button facing this NPC,
## it triggers a cinematic based on the NPC's data and game state.
##
## THE KEY UNIFICATION: Dialog IS a cinematic.
## NPCs don't just show dialog - they trigger full cinematics.
## This allows NPCs to walk around, trigger camera effects, etc.
##
## USAGE:
## 1. Add NPCNode to your map scene
## 2. Set npc_data to reference an NPCData resource
## 3. Position on the grid
## 4. The NPCNode auto-creates a CinematicActor child so cinematics can control it

const FacingUtils = preload("res://core/utils/facing_utils.gd")
const CinematicActorScript = preload("res://core/components/cinematic_actor.gd")

const DEBUG_MODE: bool = false
const EDITOR_TILE_SIZE: int = 32
const ANIMATION_SPEED_STATIC: float = 4.0
const ANIMATION_SPEED_SPRITESHEET: float = 6.0

# Game Juice: Interaction confirmation flash
const INTERACT_FLASH_COLOR: Color = Color(1.5, 1.5, 1.5)
const INTERACT_FLASH_DURATION: float = 0.1

## The NPC data resource defining this NPC's behavior
@export var npc_data: NPCData:
	set(value):
		npc_data = value
		if Engine.is_editor_hint():
			queue_redraw()

## Optional: Override the actor_id for cinematics
## If empty, uses npc_data.npc_id
@export var actor_id_override: String = "":
	set(value):
		actor_id_override = value
		if Engine.is_editor_hint():
			queue_redraw()

## Visual representation (AnimatedSprite2D for directional animations)
@export var sprite: AnimatedSprite2D

## Current facing direction (for sprite display)
var facing_direction: String = "down"

## Grid position (updated when placed or moved)
var grid_position: Vector2i = Vector2i.ZERO

## Reference to auto-created CinematicActor child
var cinematic_actor: Node = null

## Reference to interaction prompt indicator
var _interaction_prompt: Control = null

signal interaction_started(npc: NPCNode, player: Node2D)
signal interaction_ended(npc: NPCNode)

# Ambient patrol state
var _patrol_cinematic: CinematicData = null
var _patrol_command_queue: Array[Dictionary] = []
var _patrol_command_completed: bool = false
var _patrol_wait_timer: float = 0.0
var _patrol_is_waiting: bool = false
var _is_patrolling: bool = false
var _patrol_paused: bool = false


func _ready() -> void:
	_ensure_collision_shape()

	if Engine.is_editor_hint():
		set_notify_transform(true)
		queue_redraw()
		return

	add_to_group("npcs")
	_update_grid_position()
	_create_cinematic_actor()
	if not sprite:
		sprite = _find_or_create_sprite()
	_create_interaction_prompt()

	if npc_data and not npc_data.ambient_cinematic_id.is_empty():
		_debug("Checking ambient patrol - ambient_cinematic_id='%s'" % npc_data.ambient_cinematic_id)
		call_deferred("_start_ambient_patrol")


## Debug print helper - only outputs when DEBUG_MODE is true
func _debug(message: String) -> void:
	if DEBUG_MODE:
		print("[NPCNode] %s: %s" % [name, message])


func _process(delta: float) -> void:
	if not _is_patrolling or _patrol_paused:
		return

	if _patrol_is_waiting:
		_patrol_wait_timer -= delta
		if _patrol_wait_timer <= 0.0:
			_patrol_is_waiting = false
			_patrol_command_completed = true

	if _patrol_command_completed:
		_execute_next_patrol_command()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_snap_to_grid()


func _snap_to_grid() -> void:
	var snapped_pos: Vector2 = _calculate_grid_center(position)
	if position != snapped_pos:
		set_notify_transform(false)
		position = snapped_pos
		set_notify_transform(true)
		queue_redraw()


func _calculate_grid_center(pos: Vector2) -> Vector2:
	var snapped_x: float = floorf(pos.x / EDITOR_TILE_SIZE) * EDITOR_TILE_SIZE + EDITOR_TILE_SIZE / 2.0
	var snapped_y: float = floorf(pos.y / EDITOR_TILE_SIZE) * EDITOR_TILE_SIZE + EDITOR_TILE_SIZE / 2.0
	return Vector2(snapped_x, snapped_y)


func _update_grid_position() -> void:
	grid_position = GridManager.world_to_cell(global_position)
	var npc_id: String = npc_data.npc_id if npc_data else "unknown"
	_debug("'%s' (%s) positioned at world %s -> grid %s" % [name, npc_id, global_position, grid_position])


func _ensure_collision_shape() -> void:
	if get_node_or_null("CollisionShape2D"):
		return

	var tile_size: float = 32.0
	if not Engine.is_editor_hint() and GridManager:
		tile_size = float(GridManager.get_tile_size())

	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(tile_size * 0.8, tile_size * 0.8)
	collision.shape = shape
	add_child(collision)


func _create_cinematic_actor() -> void:
	var actor_id: String = get_actor_id()
	if actor_id.is_empty():
		push_warning("NPCNode: No actor_id available - NPC cannot be controlled by cinematics")
		return

	cinematic_actor = Node.new()
	cinematic_actor.set_script(CinematicActorScript)
	cinematic_actor.name = "CinematicActor"
	cinematic_actor.set("actor_id", actor_id)
	add_child(cinematic_actor)


func _create_interaction_prompt() -> void:
	_interaction_prompt = InteractionPrompt.new()
	_interaction_prompt.name = "InteractionPrompt"
	_interaction_prompt.prompt_symbol = "!"
	_interaction_prompt.can_interact_callback = _can_show_interaction_prompt
	add_child(_interaction_prompt)


func _can_show_interaction_prompt() -> bool:
	if not npc_data:
		return false
	return (
		not npc_data.interaction_cinematic_id.is_empty() or
		not npc_data.fallback_cinematic_id.is_empty() or
		not npc_data.conditional_cinematics.is_empty()
	)


func _find_or_create_sprite() -> AnimatedSprite2D:
	var existing_animated: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	if existing_animated:
		return existing_animated

	# Convert legacy Sprite2D to AnimatedSprite2D
	var existing_static: Sprite2D = get_node_or_null("Sprite2D")
	if existing_static:
		var texture: Texture2D = existing_static.texture
		existing_static.queue_free()
		if texture == null:
			push_warning("NPCNode '%s': Legacy Sprite2D has null texture, skipping conversion" % name)
		else:
			return _create_animated_sprite(_create_sprite_frames_from_texture(texture))

	# Create from npc_data or use default
	var frames: SpriteFrames = npc_data.get_sprite_frames() if npc_data else null
	if frames:
		return _create_animated_sprite(frames)

	return _create_default_animated_sprite()


func _create_animated_sprite(frames: SpriteFrames) -> AnimatedSprite2D:
	var animated_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	animated_sprite.sprite_frames = frames
	animated_sprite.centered = true
	add_child(animated_sprite)
	_play_idle_animation_on_sprite(animated_sprite)
	return animated_sprite


func _create_sprite_frames_from_texture(texture: Texture2D) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	for direction: String in FacingUtils.DIRECTIONS:
		var walk_name: String = "walk_" + direction
		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, ANIMATION_SPEED_STATIC)
		frames.add_frame(walk_name, texture)
	return frames


func _create_default_animated_sprite() -> AnimatedSprite2D:
	var default_path: String = "res://core/assets/defaults/sprites/default_npc_spritesheet.png"
	var frames: SpriteFrames
	if ResourceLoader.exists(default_path):
		frames = _create_sprite_frames_from_spritesheet(load(default_path))
	else:
		frames = _create_procedural_placeholder_frames()
	return _create_animated_sprite(frames)


func _create_sprite_frames_from_spritesheet(texture: Texture2D) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	var direction_order: Array[String] = ["down", "left", "right", "up"]

	for row: int in range(4):
		var walk_name: String = "walk_" + direction_order[row]
		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, ANIMATION_SPEED_SPRITESHEET)

		for col: int in range(2):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * 32, row * 32, 32, 32)
			frames.add_frame(walk_name, atlas)

	return frames


func _create_procedural_placeholder_frames() -> SpriteFrames:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.6, 0.8))

	# Simple face indicator
	for x: int in range(10, 14):
		img.set_pixel(x, 10, Color.BLACK)
	for x: int in range(18, 22):
		img.set_pixel(x, 10, Color.BLACK)
	for x: int in range(12, 20):
		img.set_pixel(x, 20, Color.BLACK)

	return _create_sprite_frames_from_texture(ImageTexture.create_from_image(img))


func _play_idle_animation_on_sprite(animated_sprite: AnimatedSprite2D) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var anim_name: String = "walk_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


func get_actor_id() -> String:
	if not actor_id_override.is_empty():
		return actor_id_override
	if npc_data:
		return npc_data.npc_id
	return ""


func interact(player: Node2D) -> void:
	_debug("interact() called (npc_id='%s')" % (npc_data.npc_id if npc_data else "null"))

	if not npc_data:
		push_warning("NPCNode: Cannot interact - no npc_data set")
		return

	_flash_on_interact()

	if _is_patrolling:
		pause_patrol()

	interaction_started.emit(self, player)

	if npc_data.face_player_on_interact:
		_face_toward(player)

	var cinematic_id: String = npc_data.get_cinematic_id_for_state()
	_debug("Generated cinematic_id: '%s'" % cinematic_id)

	CinematicsManager.set_interaction_context({"npc_id": npc_data.npc_id})

	if cinematic_id.is_empty():
		_debug("Cinematic ID is empty - aborting interaction")
		_end_interaction_early()
		return

	# Connect signal BEFORE play_cinematic to avoid race condition with instant cinematics
	if not CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
		CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)

	_debug("Calling CinematicsManager.play_cinematic('%s')" % cinematic_id)
	var success: bool = CinematicsManager.play_cinematic(cinematic_id)
	_debug("play_cinematic() returned: %s" % success)

	if not success:
		# Disconnect since cinematic never started
		if CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
			CinematicsManager.cinematic_ended.disconnect(_on_cinematic_ended)
		push_error("NPCNode: Failed to play cinematic '%s' for NPC '%s'" % [cinematic_id, npc_data.npc_id])
		_end_interaction_early()
		return


## Flash sprite bright on interaction confirmation
func _flash_on_interact() -> void:
	if not SettingsManager.are_flash_effects_enabled():
		return
	if not is_instance_valid(sprite):
		return
	sprite.modulate = INTERACT_FLASH_COLOR
	var duration: float = GameJuice.get_adjusted_duration(INTERACT_FLASH_DURATION)
	var tween: Tween = sprite.create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, duration)


func _end_interaction_early() -> void:
	# Only do local cleanup -- do NOT emit CinematicsManager.cinematic_ended
	# as no cinematic was actually started. Impersonating another system's signal
	# can corrupt cinematic state.
	CinematicsManager.clear_interaction_context()
	interaction_ended.emit(self)
	if _is_patrolling:
		resume_patrol()


func _on_cinematic_ended(_cinematic_id: String) -> void:
	CinematicsManager.clear_interaction_context()
	interaction_ended.emit(self)
	if _is_patrolling:
		resume_patrol()


func _face_toward(target: Node2D) -> void:
	if not target:
		return

	if npc_data and not npc_data.facing_override.is_empty():
		set_facing(npc_data.facing_override)
		return

	var delta: Vector2 = target.global_position - global_position
	set_facing(FacingUtils.get_dominant_direction_float(delta))


func set_facing(direction: String) -> void:
	facing_direction = direction.to_lower()
	play_idle_animation()
	if cinematic_actor and cinematic_actor.has_method("set_facing"):
		cinematic_actor.set_facing(facing_direction)


func play_idle_animation() -> void:
	_play_directional_animation("walk_")


func play_walk_animation() -> void:
	_play_directional_animation("walk_")


func _play_directional_animation(prefix: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var anim_name: String = prefix + facing_direction
	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
	elif sprite.sprite_frames.has_animation(prefix + "down"):
		sprite.play(prefix + "down")


func _exit_tree() -> void:
	if CinematicsManager and is_instance_valid(CinematicsManager):
		if CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
			CinematicsManager.cinematic_ended.disconnect(_on_cinematic_ended)


func get_display_name() -> String:
	if npc_data:
		return npc_data.get_display_name()
	return name


func is_at_grid_position(pos: Vector2i) -> bool:
	return GridManager.world_to_cell(global_position) == pos


func teleport_to_grid(pos: Vector2i) -> void:
	grid_position = pos
	global_position = GridManager.cell_to_world(pos)


# =============================================================================
# AMBIENT PATROL SYSTEM
# =============================================================================

func _start_ambient_patrol() -> void:
	if not npc_data or npc_data.ambient_cinematic_id.is_empty():
		_debug("No ambient_cinematic_id configured")
		return

	_debug("Starting ambient patrol with cinematic '%s'" % npc_data.ambient_cinematic_id)

	_patrol_cinematic = ModLoader.registry.get_cinematic(npc_data.ambient_cinematic_id)
	if not _patrol_cinematic:
		push_warning("NPCNode '%s': Ambient cinematic '%s' not found in registry" % [name, npc_data.ambient_cinematic_id])
		return

	_reload_patrol_commands()

	if _patrol_command_queue.is_empty():
		push_warning("NPCNode '%s': Ambient cinematic '%s' has no commands" % [name, npc_data.ambient_cinematic_id])
		return

	_is_patrolling = true
	_patrol_command_completed = true
	set_process(true)
	_debug("Patrol started successfully")


func _reload_patrol_commands() -> void:
	_patrol_command_queue.clear()
	var command_count: int = _patrol_cinematic.get_command_count()
	_debug("Cinematic has %d commands, loop=%s" % [command_count, _patrol_cinematic.loop])
	for i: int in range(command_count):
		var cmd: Dictionary = _patrol_cinematic.get_command(i)
		_patrol_command_queue.append(cmd)
		_debug("Queued command %d: %s" % [i, cmd])


func _execute_next_patrol_command() -> void:
	_patrol_command_completed = false

	if _patrol_command_queue.is_empty():
		if _patrol_cinematic.loop:
			_reload_patrol_commands()
		else:
			_is_patrolling = false
			set_process(false)
			return

	if _patrol_command_queue.is_empty():
		return

	var command: Dictionary = _patrol_command_queue.pop_front()
	match command.get("type", ""):
		"move_entity":
			_execute_patrol_move(command)
		"wait":
			_execute_patrol_wait(command)
		"set_facing":
			_execute_patrol_facing(command)
		_:
			_patrol_command_completed = true


func _execute_patrol_move(command: Dictionary) -> void:
	_debug("_execute_patrol_move called with command: %s" % command)

	if not cinematic_actor:
		_debug("No cinematic_actor - skipping move")
		_patrol_command_completed = true
		return

	var params: Dictionary = command.get("params", {})
	var path: Array = params.get("path", [])
	var speed: float = params.get("speed", 2.0)

	_debug("path=%s (type=%s), speed=%s" % [path, typeof(path), speed])

	if path.is_empty():
		_debug("Path is empty - skipping move")
		_patrol_command_completed = true
		return

	var waypoints: Array[Vector2i] = _convert_path_to_waypoints(path)
	_debug("Waypoints after conversion: %s" % [waypoints])

	if waypoints.is_empty():
		_debug("Waypoints empty after conversion - skipping move")
		_patrol_command_completed = true
		return

	_debug("Using waypoints directly (no A* expansion): %s" % [waypoints])
	cinematic_actor.move_along_path(waypoints, speed)
	if not cinematic_actor.movement_completed.is_connected(_on_patrol_move_completed):
		cinematic_actor.movement_completed.connect(_on_patrol_move_completed, CONNECT_ONE_SHOT)


func _convert_path_to_waypoints(path: Array) -> Array[Vector2i]:
	var waypoints: Array[Vector2i] = []
	for point: Variant in path:
		_debug("Processing path point: %s (type=%s)" % [point, typeof(point)])
		if point is Array and point.size() >= 2:
			waypoints.append(Vector2i(int(point[0]), int(point[1])))
		elif point is Vector2i:
			waypoints.append(point)
		elif point is Vector2:
			waypoints.append(Vector2i(int(point.x), int(point.y)))
	return waypoints


func _on_patrol_move_completed() -> void:
	_update_grid_position()
	_patrol_command_completed = true


func _execute_patrol_wait(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	_patrol_wait_timer = params.get("duration", 1.0)
	_patrol_is_waiting = true


func _execute_patrol_facing(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	set_facing(params.get("direction", "down"))
	_patrol_command_completed = true


func pause_patrol() -> void:
	_patrol_paused = true


func resume_patrol() -> void:
	_patrol_paused = false


func is_patrolling() -> bool:
	return _is_patrolling


# =============================================================================
# EDITOR VISUALIZATION
# =============================================================================

func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var color: Color = _get_editor_state_color()
	draw_circle(Vector2.ZERO, 16.0, color)
	draw_arc(Vector2.ZERO, 16.0, 0, TAU, 32, color.darkened(0.3), 2.0)

	var label: String = _get_editor_label()
	if not label.is_empty():
		var font: Font = ThemeDB.fallback_font
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		draw_string(font, Vector2(-text_size.x / 2.0, -24.0), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)


func _get_editor_state_color() -> Color:
	if not npc_data:
		return Color.RED

	var has_cinematic: bool = (
		not npc_data.interaction_cinematic_id.is_empty() or
		not npc_data.fallback_cinematic_id.is_empty() or
		not npc_data.conditional_cinematics.is_empty()
	)
	return Color.CYAN if has_cinematic else Color.YELLOW


func _get_editor_label() -> String:
	if npc_data:
		if not npc_data.npc_name.is_empty():
			return npc_data.npc_name
		if not npc_data.npc_id.is_empty():
			return npc_data.npc_id
	if not actor_id_override.is_empty():
		return actor_id_override
	return name
