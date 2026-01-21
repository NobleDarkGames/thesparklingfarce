@tool
class_name NPCNode
extends Area2D

const FacingUtils = preload("res://core/utils/facing_utils.gd")
const DEBUG_MODE: bool = false  # TEMP: Enable for patrol debugging

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
##
## NPCNode is an Area2D for simplicity - it doesn't need physics movement.
## Cinematics can still move it via its CinematicActor child.

## Preload CinematicActor script for child creation
const CinematicActorScript = preload("res://core/components/cinematic_actor.gd")

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

## Signal emitted when interaction starts (before cinematic plays)
signal interaction_started(npc: NPCNode, player: Node2D)

## Signal emitted when interaction ends (after cinematic finishes)
signal interaction_ended(npc: NPCNode)

# =============================================================================
# AMBIENT PATROL STATE
# =============================================================================

## Loaded patrol cinematic data
var _patrol_cinematic: Resource = null  # CinematicData

## Command queue for patrol execution
var _patrol_command_queue: Array[Dictionary] = []

## Patrol execution flags
var _patrol_command_completed: bool = false
var _patrol_wait_timer: float = 0.0
var _patrol_is_waiting: bool = false
var _is_patrolling: bool = false
var _patrol_paused: bool = false


## Editor tile size constant (GridManager may not be available in editor)
const EDITOR_TILE_SIZE: int = 32


func _ready() -> void:
	# Ensure collision shape exists (both editor and runtime)
	_ensure_collision_shape()

	# In editor, enable transform notifications for grid snapping
	if Engine.is_editor_hint():
		set_notify_transform(true)
		queue_redraw()
		return

	# Runtime initialization only
	# Add to "npcs" group for easy lookup
	add_to_group("npcs")

	# Calculate grid position from world position
	_update_grid_position()

	# Create CinematicActor child for cinematic control
	_create_cinematic_actor()

	# Setup visual from npc_data if sprite not manually set
	if not sprite:
		sprite = _find_or_create_sprite()

	# Start ambient patrol if configured
	if DEBUG_MODE:
		var ambient_id: String = npc_data.ambient_cinematic_id if npc_data else "(no npc_data)"
		print("[NPCNode] %s: Checking ambient patrol - ambient_cinematic_id='%s'" % [name, ambient_id])
	if npc_data and not npc_data.ambient_cinematic_id.is_empty():
		call_deferred("_start_ambient_patrol")


func _process(delta: float) -> void:
	# Only process when patrolling
	if not _is_patrolling or _patrol_paused:
		return

	# Handle wait timer
	if _patrol_is_waiting:
		_patrol_wait_timer -= delta
		if _patrol_wait_timer <= 0.0:
			_patrol_is_waiting = false
			_patrol_command_completed = true

	# Execute next command when ready
	if _patrol_command_completed:
		_execute_next_patrol_command()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_snap_to_grid()


## Snap position to grid center (editor only)
func _snap_to_grid() -> void:
	var tile_size: int = EDITOR_TILE_SIZE
	# Snap to grid cell center
	var snapped_x: float = floorf(position.x / tile_size) * tile_size + tile_size / 2.0
	var snapped_y: float = floorf(position.y / tile_size) * tile_size + tile_size / 2.0
	var snapped_pos: Vector2 = Vector2(snapped_x, snapped_y)

	# Only update if actually changed (avoid infinite loop)
	if position != snapped_pos:
		set_notify_transform(false)  # Temporarily disable to avoid recursion
		position = snapped_pos
		set_notify_transform(true)
		queue_redraw()


func _update_grid_position() -> void:
	grid_position = GridManager.world_to_cell(global_position)
	if DEBUG_MODE:
		var npc_id: String = npc_data.npc_id if npc_data else "unknown"
		print("[NPCNode] '%s' (%s) positioned at world %s -> grid %s" % [name, npc_id, global_position, grid_position])


## Ensure this NPC has a collision shape for Area2D detection
func _ensure_collision_shape() -> void:
	var existing_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if existing_shape:
		return

	# Create a default collision shape
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"

	var shape: RectangleShape2D = RectangleShape2D.new()
	# Use GridManager tile size if available, otherwise default to 32
	var tile_size: float = 32.0
	if not Engine.is_editor_hint() and GridManager:
		tile_size = float(GridManager.get_tile_size())
	shape.size = Vector2(tile_size * 0.8, tile_size * 0.8)  # Slightly smaller than tile

	collision.shape = shape
	add_child(collision)


## Create a CinematicActor child so cinematics can control this NPC
func _create_cinematic_actor() -> void:
	# Determine actor_id
	var actor_id: String = actor_id_override
	if actor_id.is_empty() and npc_data:
		actor_id = npc_data.npc_id

	if actor_id.is_empty():
		push_warning("NPCNode: No actor_id available - NPC cannot be controlled by cinematics")
		return

	# Create CinematicActor as child
	cinematic_actor = Node.new()
	cinematic_actor.set_script(CinematicActorScript)
	cinematic_actor.name = "CinematicActor"
	cinematic_actor.set("actor_id", actor_id)

	# CinematicActor will auto-register with CinematicsManager in its _ready()
	add_child(cinematic_actor)


## Find existing sprite or create one from npc_data
## Always creates AnimatedSprite2D with directional animations
func _find_or_create_sprite() -> AnimatedSprite2D:
	# Check for existing AnimatedSprite2D first (preferred)
	var existing_animated: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	if existing_animated:
		return existing_animated

	# Check for existing Sprite2D (legacy support, will be replaced)
	var existing_static: Sprite2D = get_node_or_null("Sprite2D")
	if existing_static:
		# Convert to AnimatedSprite2D
		var texture: Texture2D = existing_static.texture
		existing_static.queue_free()
		return _create_animated_sprite_from_texture(texture)

	# Create AnimatedSprite2D from npc_data
	var frames: SpriteFrames = null
	if npc_data:
		frames = npc_data.get_sprite_frames()

	if frames:
		var animated_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		animated_sprite.sprite_frames = frames
		animated_sprite.centered = true
		add_child(animated_sprite)
		# Play initial idle animation
		_play_idle_animation_on_sprite(animated_sprite)
		return animated_sprite

	# Fallback: create default placeholder sprite
	return _create_default_animated_sprite()


## Create AnimatedSprite2D from a static texture (for legacy conversion)
func _create_animated_sprite_from_texture(texture: Texture2D) -> AnimatedSprite2D:
	var animated_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	animated_sprite.centered = true

	# Create SpriteFrames with the static texture for all directions
	var frames: SpriteFrames = _create_sprite_frames_from_texture(texture)
	animated_sprite.sprite_frames = frames

	add_child(animated_sprite)
	_play_idle_animation_on_sprite(animated_sprite)
	return animated_sprite


## Create SpriteFrames from a single static texture (all directions use same image)
## SF2-authentic: only walk animations (no separate idle)
func _create_sprite_frames_from_texture(texture: Texture2D) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()

	for direction: String in FacingUtils.DIRECTIONS:
		var walk_name: String = "walk_" + direction

		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, 4.0)
		frames.add_frame(walk_name, texture)

	return frames


## Create default placeholder AnimatedSprite2D
func _create_default_animated_sprite() -> AnimatedSprite2D:
	var animated_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	animated_sprite.centered = true

	# Try to load default NPC spritesheet
	var default_spritesheet_path: String = "res://core/assets/defaults/sprites/default_npc_spritesheet.png"
	if ResourceLoader.exists(default_spritesheet_path):
		var texture: Texture2D = load(default_spritesheet_path)
		animated_sprite.sprite_frames = _create_sprite_frames_from_spritesheet(texture)
	else:
		# Ultimate fallback: create procedural placeholder
		animated_sprite.sprite_frames = _create_procedural_placeholder_frames()

	add_child(animated_sprite)
	_play_idle_animation_on_sprite(animated_sprite)
	return animated_sprite


## Create SpriteFrames from a 64x128 spritesheet (2 columns x 4 rows)
## Layout: columns are frames, rows are directions (down, up, left, right)
## SF2-authentic: only walk animations (no separate idle)
func _create_sprite_frames_from_spritesheet(texture: Texture2D) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	var frame_width: int = 32
	var frame_height: int = 32

	var direction_order: Array[String] = ["down", "left", "right", "up"]

	for row: int in range(4):
		var direction: String = direction_order[row]
		var walk_name: String = "walk_" + direction

		# Create walk animation (both frames)
		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, 6.0)

		for col: int in range(2):
			var walk_region: Rect2 = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)
			var walk_texture: AtlasTexture = AtlasTexture.new()
			walk_texture.atlas = texture
			walk_texture.region = walk_region
			frames.add_frame(walk_name, walk_texture)

	return frames


## Create procedural placeholder SpriteFrames (colored rectangle)
## SF2-authentic: only walk animations (no separate idle)
func _create_procedural_placeholder_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()

	# Create a simple colored square as placeholder
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.6, 0.8))  # Blue-ish for NPC

	# Add a simple face indicator
	for x: int in range(10, 14):
		img.set_pixel(x, 10, Color.BLACK)  # Left eye
	for x: int in range(18, 22):
		img.set_pixel(x, 10, Color.BLACK)  # Right eye
	for x: int in range(12, 20):
		img.set_pixel(x, 20, Color.BLACK)  # Mouth

	var texture: ImageTexture = ImageTexture.create_from_image(img)

	for direction: String in FacingUtils.DIRECTIONS:
		var walk_name: String = "walk_" + direction

		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, 4.0)
		frames.add_frame(walk_name, texture)

	return frames


## Helper to play walk animation on a sprite (SF2-authentic: walk plays even when stationary)
func _play_idle_animation_on_sprite(animated_sprite: AnimatedSprite2D) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var anim_name: String = "walk_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


## Get the actor_id this NPC uses for cinematics
func get_actor_id() -> String:
	if not actor_id_override.is_empty():
		return actor_id_override
	if npc_data:
		return npc_data.npc_id
	return ""


## Called when the player interacts with this NPC
## player: The HeroController or similar player node
func interact(player: Node2D) -> void:
	if DEBUG_MODE:
		print("[NPCNode] interact() called on '%s' (npc_id='%s')" % [name, npc_data.npc_id if npc_data else "null"])

	if not npc_data:
		push_warning("NPCNode: Cannot interact - no npc_data set")
		return

	# Pause any active patrol during interaction
	if _is_patrolling:
		pause_patrol()

	# Emit signal before processing
	interaction_started.emit(self, player)

	# Face the player if configured to do so
	if npc_data.face_player_on_interact:
		_face_toward(player)

	# Get the appropriate cinematic based on game state
	var cinematic_id: String = npc_data.get_cinematic_id_for_state()
	if DEBUG_MODE:
		print("[NPCNode] Generated cinematic_id: '%s'" % cinematic_id)

	# Set interaction context so other systems can identify this NPC
	CinematicsManager.set_interaction_context({"npc_id": npc_data.npc_id})

	if cinematic_id.is_empty():
		if DEBUG_MODE:
			print("[NPCNode] Cinematic ID is empty - aborting interaction")
		# No cinematic - emit signal and clean up
		CinematicsManager.cinematic_ended.emit("")
		CinematicsManager.clear_interaction_context()
		interaction_ended.emit(self)
		# Resume patrol if active
		if _is_patrolling:
			resume_patrol()
		return

	# Play the cinematic
	if DEBUG_MODE:
		print("[NPCNode] Calling CinematicsManager.play_cinematic('%s')" % cinematic_id)
	var success: bool = CinematicsManager.play_cinematic(cinematic_id)
	if DEBUG_MODE:
		print("[NPCNode] play_cinematic() returned: %s" % success)

	if not success:
		push_error("NPCNode: Failed to play cinematic '%s' for NPC '%s'" % [cinematic_id, npc_data.npc_id])
		CinematicsManager.clear_interaction_context()
		interaction_ended.emit(self)
		# Resume patrol if active
		if _is_patrolling:
			resume_patrol()
		return

	# Connect to cinematic end signal to emit our own end signal
	if not CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
		CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)


## Called when the cinematic finishes
func _on_cinematic_ended(_cinematic_id: String) -> void:
	CinematicsManager.clear_interaction_context()
	interaction_ended.emit(self)

	# Resume patrol if we were patrolling before interaction
	if _is_patrolling:
		resume_patrol()


## Face toward a target node (usually the player)
func _face_toward(target: Node2D) -> void:
	if not target:
		return

	# Check for facing override
	if npc_data and not npc_data.facing_override.is_empty():
		set_facing(npc_data.facing_override)
		return

	# Calculate direction to target and set facing
	var delta: Vector2 = target.global_position - global_position
	set_facing(FacingUtils.get_dominant_direction_float(delta))


## Set the facing direction
func set_facing(direction: String) -> void:
	facing_direction = direction.to_lower()
	play_idle_animation()

	# Update cinematic actor facing if available
	if cinematic_actor and cinematic_actor.has_method("set_facing"):
		cinematic_actor.set_facing(facing_direction)


## Play walk animation for current facing direction (SF2-authentic: walk plays even when stationary)
func play_idle_animation() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var anim_name: String = "walk_" + facing_direction
	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


## Cleanup signal connections when node is freed
func _exit_tree() -> void:
	# Disconnect from CinematicsManager to prevent dangling signal connections
	# Use get() to safely access the signal without throwing if CinematicsManager isn't ready
	var cm: Node = get_node_or_null("/root/CinematicsManager")
	if cm and is_instance_valid(cm) and cm.has_signal("cinematic_ended"):
		if cm.is_connected("cinematic_ended", _on_cinematic_ended):
			cm.disconnect("cinematic_ended", _on_cinematic_ended)


## Play walk animation for current facing direction
func play_walk_animation() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var anim_name: String = "walk_" + facing_direction
	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
	elif sprite.sprite_frames.has_animation("walk_down"):
		# Fallback to walk_down if no directional animation
		sprite.play("walk_down")


## Get the display name for this NPC (for UI/dialogs)
func get_display_name() -> String:
	if npc_data:
		return npc_data.get_display_name()
	return name


## Check if this NPC is at a specific grid position
## Uses live global_position for accuracy during movement (not cached grid_position)
func is_at_grid_position(pos: Vector2i) -> bool:
	var current_grid_pos: Vector2i = GridManager.world_to_cell(global_position)
	return current_grid_pos == pos


## Teleport NPC to a grid position (for cinematics/scripting)
func teleport_to_grid(pos: Vector2i) -> void:
	grid_position = pos
	global_position = GridManager.cell_to_world(pos)


# =============================================================================
# AMBIENT PATROL SYSTEM
# =============================================================================

## Start ambient patrol from configured cinematic
func _start_ambient_patrol() -> void:
	if not npc_data or npc_data.ambient_cinematic_id.is_empty():
		if DEBUG_MODE:
			print("[NPCNode] %s: No ambient_cinematic_id configured" % name)
		return

	if DEBUG_MODE:
		print("[NPCNode] %s: Starting ambient patrol with cinematic '%s'" % [name, npc_data.ambient_cinematic_id])

	_patrol_cinematic = ModLoader.registry.get_cinematic(npc_data.ambient_cinematic_id)
	if not _patrol_cinematic:
		push_warning("NPCNode '%s': Ambient cinematic '%s' not found in registry" % [name, npc_data.ambient_cinematic_id])
		return

	# Populate command queue
	_patrol_command_queue.clear()
	var command_count: int = _patrol_cinematic.get_command_count()
	if DEBUG_MODE:
		print("[NPCNode] %s: Cinematic has %d commands, loop=%s" % [name, command_count, _patrol_cinematic.loop])
	for i: int in range(command_count):
		var cmd: Dictionary = _patrol_cinematic.get_command(i)
		_patrol_command_queue.append(cmd)
		if DEBUG_MODE:
			print("[NPCNode] %s: Queued command %d: %s" % [name, i, cmd])

	if _patrol_command_queue.is_empty():
		push_warning("NPCNode '%s': Ambient cinematic '%s' has no commands" % [name, npc_data.ambient_cinematic_id])
		return

	_is_patrolling = true
	_patrol_command_completed = true
	set_process(true)
	if DEBUG_MODE:
		print("[NPCNode] %s: Patrol started successfully" % name)


## Execute the next patrol command
func _execute_next_patrol_command() -> void:
	_patrol_command_completed = false

	# Check if queue is empty - loop if configured
	if _patrol_command_queue.is_empty():
		if _patrol_cinematic.loop:
			# Restart from beginning
			var command_count: int = _patrol_cinematic.get_command_count()
			for i: int in range(command_count):
				_patrol_command_queue.append(_patrol_cinematic.get_command(i))
		else:
			_is_patrolling = false
			set_process(false)
			return

	if _patrol_command_queue.is_empty():
		return

	var command: Dictionary = _patrol_command_queue.pop_front()
	var command_type: String = command.get("type", "")

	# Handle supported patrol commands
	match command_type:
		"move_entity":
			_execute_patrol_move(command)
		"wait":
			_execute_patrol_wait(command)
		"set_facing":
			_execute_patrol_facing(command)
		_:
			# Skip unsupported commands silently
			_patrol_command_completed = true


## Execute patrol move command
func _execute_patrol_move(command: Dictionary) -> void:
	if DEBUG_MODE:
		print("[NPCNode] %s: _execute_patrol_move called with command: %s" % [name, command])

	if not cinematic_actor:
		if DEBUG_MODE:
			print("[NPCNode] %s: No cinematic_actor - skipping move" % name)
		_patrol_command_completed = true
		return

	var params: Dictionary = command.get("params", {})
	var path: Array = params.get("path", [])
	var speed: float = params.get("speed", 2.0)

	if DEBUG_MODE:
		print("[NPCNode] %s: path=%s (type=%s), speed=%s" % [name, path, typeof(path), speed])

	if path.is_empty():
		if DEBUG_MODE:
			print("[NPCNode] %s: Path is empty - skipping move" % name)
		_patrol_command_completed = true
		return

	# Convert path to Vector2i array
	var waypoints: Array[Vector2i] = []
	for point: Variant in path:
		if DEBUG_MODE:
			print("[NPCNode] %s: Processing path point: %s (type=%s)" % [name, point, typeof(point)])
		if point is Array and point.size() >= 2:
			waypoints.append(Vector2i(int(point[0]), int(point[1])))
		elif point is Vector2i:
			waypoints.append(point)
		elif point is Vector2:
			# Handle Vector2 (converted from JSON)
			var v2: Vector2 = point
			waypoints.append(Vector2i(int(v2.x), int(v2.y)))

	if DEBUG_MODE:
		print("[NPCNode] %s: Waypoints after conversion: %s" % [name, waypoints])

	if waypoints.is_empty():
		if DEBUG_MODE:
			print("[NPCNode] %s: Waypoints empty after conversion - skipping move" % name)
		_patrol_command_completed = true
		return

	# For ambient patrols, use waypoints directly without A* pathfinding expansion
	# The patrol route is explicitly defined by the modder, so we follow it as-is
	var full_path: Array[Vector2i] = waypoints
	if DEBUG_MODE:
		print("[NPCNode] %s: Using waypoints directly (no A* expansion): %s" % [name, full_path])

	# Start movement via CinematicActor
	cinematic_actor.move_along_path(full_path, speed)
	if not cinematic_actor.movement_completed.is_connected(_on_patrol_move_completed):
		cinematic_actor.movement_completed.connect(_on_patrol_move_completed, CONNECT_ONE_SHOT)


## Callback when patrol movement completes
func _on_patrol_move_completed() -> void:
	# Update grid_position to match new world position
	_update_grid_position()
	_patrol_command_completed = true


## Execute patrol wait command
func _execute_patrol_wait(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	var duration: float = params.get("duration", 1.0)
	_patrol_wait_timer = duration
	_patrol_is_waiting = true


## Execute patrol set_facing command
func _execute_patrol_facing(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	var direction: String = params.get("direction", "down")
	set_facing(direction)
	_patrol_command_completed = true


## Pause patrol (called during player interaction)
func pause_patrol() -> void:
	_patrol_paused = true


## Resume patrol (called after interaction ends)
func resume_patrol() -> void:
	_patrol_paused = false


## Check if NPC is currently patrolling
func is_patrolling() -> bool:
	return _is_patrolling


# =============================================================================
# EDITOR VISUALIZATION
# =============================================================================

## Draw placeholder visualization in editor for easy NPC placement
func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	# Determine state color
	var color: Color = _get_editor_state_color()

	# Draw a circle as placeholder (16px radius for visibility)
	draw_circle(Vector2.ZERO, 16.0, color)

	# Draw darker outline
	draw_arc(Vector2.ZERO, 16.0, 0, TAU, 32, color.darkened(0.3), 2.0)

	# Draw ID label above the circle
	var label: String = _get_editor_label()
	if not label.is_empty():
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 10
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = Vector2(-text_size.x / 2.0, -24.0)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


## Get the color for editor visualization based on NPC state
func _get_editor_state_color() -> Color:
	if not npc_data:
		return Color.RED  # No data = broken

	# Check if any cinematic is configured
	var cinematic_id: String = ""
	if not npc_data.interaction_cinematic_id.is_empty():
		cinematic_id = npc_data.interaction_cinematic_id
	elif not npc_data.fallback_cinematic_id.is_empty():
		cinematic_id = npc_data.fallback_cinematic_id

	if cinematic_id.is_empty() and npc_data.conditional_cinematics.is_empty():
		return Color.YELLOW  # Has data but no cinematics

	# Has data and cinematics configured
	return Color.CYAN


## Get the label to display in editor
func _get_editor_label() -> String:
	if npc_data:
		if not npc_data.npc_name.is_empty():
			return npc_data.npc_name
		if not npc_data.npc_id.is_empty():
			return npc_data.npc_id
	if not actor_id_override.is_empty():
		return actor_id_override
	return name
