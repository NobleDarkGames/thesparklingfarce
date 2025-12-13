@tool
class_name NPCNode
extends Area2D

const FacingUtils: GDScript = preload("res://core/utils/facing_utils.gd")

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
const CinematicActorScript: GDScript = preload("res://core/components/cinematic_actor.gd")

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

## Visual representation (can be Sprite2D or AnimatedSprite2D)
@export var sprite: Node2D

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
func _find_or_create_sprite() -> Node2D:
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
func _create_sprite_frames_from_texture(texture: Texture2D) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()

	for direction: String in FacingUtils.DIRECTIONS:
		var idle_name: String = "idle_" + direction
		var walk_name: String = "walk_" + direction

		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.set_animation_speed(idle_name, 4.0)
		frames.add_frame(idle_name, texture)

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
func _create_sprite_frames_from_spritesheet(texture: Texture2D) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	var frame_width: int = 32
	var frame_height: int = 32

	var direction_order: Array[String] = ["down", "left", "right", "up"]

	for row: int in range(4):
		var direction: String = direction_order[row]
		var idle_name: String = "idle_" + direction
		var walk_name: String = "walk_" + direction

		# Create idle animation (first frame only)
		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.set_animation_speed(idle_name, 4.0)

		var idle_region: Rect2 = Rect2(0, row * frame_height, frame_width, frame_height)
		var idle_texture: AtlasTexture = AtlasTexture.new()
		idle_texture.atlas = texture
		idle_texture.region = idle_region
		frames.add_frame(idle_name, idle_texture)

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
		var idle_name: String = "idle_" + direction
		var walk_name: String = "walk_" + direction

		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.set_animation_speed(idle_name, 4.0)
		frames.add_frame(idle_name, texture)

		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, 4.0)
		frames.add_frame(walk_name, texture)

	return frames


## Helper to play idle animation on a sprite
func _play_idle_animation_on_sprite(animated_sprite: AnimatedSprite2D) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var anim_name: String = "idle_" + facing_direction
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
	if not npc_data:
		push_warning("NPCNode: Cannot interact - no npc_data set")
		return

	# Emit signal before processing
	interaction_started.emit(self, player)

	# Face the player if configured to do so
	if npc_data.face_player_on_interact:
		_face_toward(player)

	# Get the appropriate cinematic based on game state
	var cinematic_id: String = npc_data.get_cinematic_id_for_state()

	if cinematic_id.is_empty():
		push_warning("NPCNode: No cinematic to play for NPC '%s'" % npc_data.npc_id)
		interaction_ended.emit(self)
		return

	# Play the cinematic
	var success: bool = CinematicsManager.play_cinematic(cinematic_id)

	if not success:
		push_error("NPCNode: Failed to play cinematic '%s' for NPC '%s'" % [cinematic_id, npc_data.npc_id])
		interaction_ended.emit(self)
		return

	# Connect to cinematic end signal to emit our own end signal
	if not CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
		CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)


## Called when the cinematic finishes
func _on_cinematic_ended(_cinematic_id: String) -> void:
	interaction_ended.emit(self)


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


## Play idle animation for current facing direction
func play_idle_animation() -> void:
	if not sprite or not sprite is AnimatedSprite2D:
		return
	var animated_sprite: AnimatedSprite2D = sprite as AnimatedSprite2D
	if not animated_sprite.sprite_frames:
		return
	var anim_name: String = "idle_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)


## Play walk animation for current facing direction
func play_walk_animation() -> void:
	if not sprite or not sprite is AnimatedSprite2D:
		return
	var animated_sprite: AnimatedSprite2D = sprite as AnimatedSprite2D
	if not animated_sprite.sprite_frames:
		return
	var anim_name: String = "walk_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
	elif animated_sprite.sprite_frames.has_animation("idle_" + facing_direction):
		# Fallback to idle if no walk animation
		animated_sprite.play("idle_" + facing_direction)


## Get the display name for this NPC (for UI/dialogs)
func get_display_name() -> String:
	if npc_data:
		return npc_data.get_display_name()
	return name


## Check if this NPC is at a specific grid position
func is_at_grid_position(pos: Vector2i) -> bool:
	return grid_position == pos


## Teleport NPC to a grid position (for cinematics/scripting)
func teleport_to_grid(pos: Vector2i) -> void:
	grid_position = pos
	global_position = GridManager.cell_to_world(pos)


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
