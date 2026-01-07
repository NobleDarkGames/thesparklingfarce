@tool
class_name InteractableNode
extends Area2D

## InteractableNode - A map object that players can search/interact with.
##
## When the player presses interact while facing this object,
## it triggers rewards and/or cinematics based on the interactable's data.
##
## SF2-AUTHENTIC BEHAVIOR:
## - Same interaction as NPCs (face + press action)
## - Immediate feedback on search
## - State-based sprites (closed -> opened for chests)
##
## USAGE:
## 1. Add InteractableNode to your map scene
## 2. Set interactable_data to reference an InteractableData resource
## 3. Position on the grid (auto-snaps in editor)
##
## Unlike NPCs, interactables use static sprites that change based on state,
## not directional animations.

## The interactable data resource defining this object's behavior
@export var interactable_data: InteractableData:
	set(value):
		interactable_data = value
		if Engine.is_editor_hint():
			_update_editor_sprite()
			queue_redraw()

## Visual representation (Sprite2D for static state-based sprites)
var sprite: Sprite2D = null

## Grid position (updated when placed or moved)
var grid_position: Vector2i = Vector2i.ZERO

## Signal emitted BEFORE interaction processing begins (allows mods to cancel)
## Connect to this signal and set result["cancel"] = true to block the interaction
## Optionally set result["reason"] to show a custom message explaining why
signal interaction_requested(interactable: InteractableNode, player: Node2D, result: Dictionary)

## Signal emitted when interaction starts (after request was approved)
signal interaction_started(interactable: InteractableNode, player: Node2D)

## Signal emitted when interaction ends
signal interaction_ended(interactable: InteractableNode)

## Editor tile size constant
const EDITOR_TILE_SIZE: int = 32


func _ready() -> void:
	# Ensure collision shape exists
	_ensure_collision_shape()

	# In editor, enable transform notifications for grid snapping
	if Engine.is_editor_hint():
		set_notify_transform(true)
		_update_editor_sprite()
		queue_redraw()
		return

	# Runtime initialization only
	add_to_group("interactables")

	# Calculate grid position from world position
	_update_grid_position()

	# Setup visual from interactable_data
	_setup_sprite()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_snap_to_grid()


## Snap position to grid center (editor only)
func _snap_to_grid() -> void:
	var tile_size: int = EDITOR_TILE_SIZE
	var snapped_x: float = floorf(position.x / tile_size) * tile_size + tile_size / 2.0
	var snapped_y: float = floorf(position.y / tile_size) * tile_size + tile_size / 2.0
	var snapped_pos: Vector2 = Vector2(snapped_x, snapped_y)

	if position != snapped_pos:
		set_notify_transform(false)
		position = snapped_pos
		set_notify_transform(true)
		queue_redraw()


func _update_grid_position() -> void:
	grid_position = GridManager.world_to_cell(global_position)


## Ensure this interactable has a collision shape
func _ensure_collision_shape() -> void:
	var existing_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if existing_shape:
		return

	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"

	var shape: RectangleShape2D = RectangleShape2D.new()
	var tile_size: float = 32.0
	if not Engine.is_editor_hint() and GridManager:
		tile_size = float(GridManager.get_tile_size())
	shape.size = Vector2(tile_size * 0.8, tile_size * 0.8)

	collision.shape = shape
	add_child(collision)


## Setup the sprite from interactable_data
func _setup_sprite() -> void:
	# Find or create sprite
	sprite = get_node_or_null("Sprite2D")
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.centered = true
		add_child(sprite)

	# Update texture based on current state
	_update_sprite_texture()


## Update sprite texture based on opened state
func _update_sprite_texture() -> void:
	if not sprite or not interactable_data:
		return

	var texture: Texture2D = interactable_data.get_current_sprite()
	if texture:
		sprite.texture = texture
	else:
		# Create procedural placeholder
		sprite.texture = _create_placeholder_texture()


## Update editor sprite preview
func _update_editor_sprite() -> void:
	if not Engine.is_editor_hint():
		return

	# Find or create sprite for editor preview
	var editor_sprite: Sprite2D = get_node_or_null("Sprite2D")
	if not editor_sprite:
		editor_sprite = Sprite2D.new()
		editor_sprite.name = "Sprite2D"
		editor_sprite.centered = true
		add_child(editor_sprite)

	if interactable_data and interactable_data.sprite_closed:
		editor_sprite.texture = interactable_data.sprite_closed
	else:
		editor_sprite.texture = _create_placeholder_texture()


## Create a placeholder texture for objects without sprites
func _create_placeholder_texture() -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)

	# Brown color for chest placeholder
	img.fill(Color(0.6, 0.4, 0.2))

	# Add simple chest lid indicator
	for x: int in range(4, 28):
		img.set_pixel(x, 8, Color(0.4, 0.25, 0.1))
		img.set_pixel(x, 9, Color(0.4, 0.25, 0.1))

	# Add keyhole indicator
	for y: int in range(14, 20):
		img.set_pixel(15, y, Color(0.2, 0.1, 0.05))
		img.set_pixel(16, y, Color(0.2, 0.1, 0.05))

	return ImageTexture.create_from_image(img)


## Called when the player interacts with this object
## @param player: The HeroController or similar player node
func interact(player: Node2D) -> void:
	if not interactable_data:
		push_warning("InteractableNode: Cannot interact - no interactable_data set")
		return

	# Check if interaction is allowed
	var check: Dictionary = interactable_data.can_interact()
	if not check.get("can_interact", false):
		var reason: String = check.get("reason", "")
		if reason == "already_opened":
			_show_already_opened_message()
		# For other reasons (missing/forbidden flags), silently fail
		# (the object shouldn't be interactable yet)
		return

	# Allow mods to intercept/cancel the interaction
	var request_result: Dictionary = {"cancel": false, "reason": ""}
	interaction_requested.emit(self, player, request_result)

	if request_result.get("cancel", false):
		var cancel_reason: String = request_result.get("reason", "")
		if not cancel_reason.is_empty():
			# Show the rejection message
			CinematicsManager.play_inline_cinematic([{
				"type": "dialog",
				"params": {"text": cancel_reason}
			}])
		return

	# Emit signal before processing (request was approved)
	interaction_started.emit(self, player)

	# Set interaction context for cinematics
	CinematicsManager.set_interaction_context({"interactable_id": interactable_data.interactable_id})

	# Get the cinematic to play
	var cinematic_id: String = interactable_data.get_cinematic_id_for_state()

	if cinematic_id.is_empty():
		# No cinematic but interaction happened - still update state
		_complete_interaction()
		return

	# Check for auto-generated cinematic
	if cinematic_id.begins_with("__auto_interactable__"):
		_play_auto_cinematic()
		return

	# Play explicit cinematic
	var success: bool = CinematicsManager.play_cinematic(cinematic_id)

	if not success:
		push_error("InteractableNode: Failed to play cinematic '%s'" % cinematic_id)
		_complete_interaction()
		return

	# Connect to cinematic end
	if not CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
		CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)


## Play auto-generated cinematic for default behavior
func _play_auto_cinematic() -> void:
	# Build and execute inline cinematic commands
	var commands: Array[Dictionary] = []

	# Grant rewards first (grant_items command)
	if interactable_data.has_rewards():
		commands.append({
			"type": "grant_items",
			"params": {
				"items": interactable_data.item_rewards,
				"gold": interactable_data.gold_reward,
				"show_message": true
			}
		})

	# Show dialog text if present
	if not interactable_data.dialog_text.is_empty():
		commands.append({
			"type": "dialog",
			"params": {
				"text": interactable_data.dialog_text
			}
		})

	# If no commands (empty object), show type-specific default message
	if commands.is_empty():
		var default_msg: String = _get_default_empty_message()
		commands.append({
			"type": "dialog",
			"params": {
				"text": default_msg
			}
		})

	# Execute inline cinematic
	CinematicsManager.play_inline_cinematic(commands)

	# Connect to completion
	if not CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
		CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)


## Get default message for empty interactables
func _get_default_empty_message() -> String:
	return InteractableData.get_default_empty_message(interactable_data.interactable_type)


## Show message for already-opened objects
func _show_already_opened_message() -> void:
	var msg: String = InteractableData.get_already_opened_message(interactable_data.interactable_type)

	# Play inline dialog
	CinematicsManager.play_inline_cinematic([{
		"type": "dialog",
		"params": {"text": msg}
	}])


## Complete the interaction (update state, emit signals)
func _complete_interaction() -> void:
	# Mark as opened (sets flag if one_shot)
	interactable_data.mark_opened()

	# Update visual to opened state
	_update_sprite_texture()

	# Clear context and emit completion
	CinematicsManager.clear_interaction_context()
	interaction_ended.emit(self)


## Called when cinematic finishes
func _on_cinematic_ended(_cinematic_id: String) -> void:
	_complete_interaction()


## Get the display name for this interactable
func get_display_name() -> String:
	if interactable_data:
		return interactable_data.display_name
	return name


## Check if this interactable is at a specific grid position
func is_at_grid_position(pos: Vector2i) -> bool:
	return grid_position == pos


## Teleport to a grid position
func teleport_to_grid(pos: Vector2i) -> void:
	grid_position = pos
	global_position = GridManager.cell_to_world(pos)


# =============================================================================
# EDITOR VISUALIZATION
# =============================================================================

## Draw visualization in editor
func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var color: Color = _get_editor_state_color()

	# Draw square outline (chests are boxy)
	var rect: Rect2 = Rect2(Vector2(-14, -14), Vector2(28, 28))
	draw_rect(rect, color, false, 2.0)

	# Draw type indicator icon in center
	_draw_type_icon(color)

	# Draw ID label
	var label: String = _get_editor_label()
	if not label.is_empty():
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 10
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = Vector2(-text_size.x / 2.0, -20.0)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


func _draw_type_icon(color: Color) -> void:
	if not interactable_data:
		# Question mark for no data
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(-4, 6), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)
		return

	match interactable_data.interactable_type:
		InteractableData.InteractableType.CHEST:
			# Draw simple chest shape
			draw_rect(Rect2(-8, -4, 16, 10), color, true)
			draw_line(Vector2(-8, -2), Vector2(8, -2), color.darkened(0.3), 2.0)
		InteractableData.InteractableType.BOOKSHELF:
			# Draw book shape
			draw_rect(Rect2(-6, -8, 12, 16), color, true)
			for i: int in range(3):
				draw_line(Vector2(-4, -6 + i * 5), Vector2(4, -6 + i * 5), color.darkened(0.3), 1.0)
		InteractableData.InteractableType.BARREL:
			# Draw barrel circle
			draw_circle(Vector2.ZERO, 8.0, color)
			draw_arc(Vector2.ZERO, 8.0, 0, TAU, 16, color.darkened(0.3), 2.0)
		InteractableData.InteractableType.SIGN:
			# Draw signpost
			draw_rect(Rect2(-8, -6, 16, 8), color, true)
			draw_line(Vector2(0, 2), Vector2(0, 10), color.darkened(0.3), 2.0)
		InteractableData.InteractableType.LEVER:
			# Draw lever
			draw_circle(Vector2(0, 4), 4.0, color)
			draw_line(Vector2(0, 4), Vector2(0, -8), color, 2.0)
		_:
			# Star for custom
			var font: Font = ThemeDB.fallback_font
			draw_string(font, Vector2(-4, 6), "*", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)


func _get_editor_state_color() -> Color:
	if not interactable_data:
		return Color.RED  # No data

	if not interactable_data.validate():
		return Color.ORANGE  # Invalid config

	if interactable_data.has_rewards():
		return Color.GOLD  # Has loot

	return Color.CYAN  # Valid, no rewards


func _get_editor_label() -> String:
	if interactable_data:
		if not interactable_data.display_name.is_empty():
			return interactable_data.display_name
		if not interactable_data.interactable_id.is_empty():
			return interactable_data.interactable_id
	return name
