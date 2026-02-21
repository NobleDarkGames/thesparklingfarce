@tool
class_name InteractableNode
extends Area2D

## InteractableNode - A map object that players can search/interact with.
##
## When the player presses interact while facing this object,
## it triggers rewards and/or cinematics based on the interactable's data.
##
## USAGE:
## 1. Add InteractableNode to your map scene
## 2. Set interactable_data to reference an InteractableData resource
## 3. Position on the grid (auto-snaps in editor)

const EDITOR_TILE_SIZE: int = 32

# Game Juice: Interaction confirmation flash
const INTERACT_FLASH_COLOR: Color = Color(1.5, 1.5, 1.5)
const INTERACT_FLASH_DURATION: float = 0.1

@export var interactable_data: InteractableData:
	set(value):
		interactable_data = value
		if Engine.is_editor_hint():
			_update_editor_sprite()
			queue_redraw()

var sprite: Sprite2D = null
var grid_position: Vector2i = Vector2i.ZERO
var _interaction_prompt: Control = null

signal interaction_requested(interactable: InteractableNode, player: Node2D, result: Dictionary)
signal interaction_started(interactable: InteractableNode, player: Node2D)
signal interaction_ended(interactable: InteractableNode)


func _ready() -> void:
	_ensure_collision_shape()

	if Engine.is_editor_hint():
		set_notify_transform(true)
		_update_editor_sprite()
		queue_redraw()
		return

	add_to_group("interactables")
	_update_grid_position()
	_setup_sprite()
	_create_interaction_prompt()


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


func _setup_sprite() -> void:
	sprite = get_node_or_null("Sprite2D")
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.centered = true
		add_child(sprite)
	_update_sprite_texture()


func _create_interaction_prompt() -> void:
	_interaction_prompt = InteractionPrompt.new()
	_interaction_prompt.name = "InteractionPrompt"
	_interaction_prompt.prompt_symbol = "?"
	_interaction_prompt.can_interact_callback = _can_show_prompt
	add_child(_interaction_prompt)


func _can_show_prompt() -> bool:
	if not interactable_data:
		return false
	return interactable_data.can_interact().get("can_interact", false)


func _update_sprite_texture() -> void:
	if not sprite or not interactable_data:
		return
	var texture: Texture2D = interactable_data.get_current_sprite()
	sprite.texture = texture if texture else _create_placeholder_texture()


func _update_editor_sprite() -> void:
	if not Engine.is_editor_hint():
		return

	var editor_sprite: Sprite2D = _get_or_create_sprite()
	if interactable_data and interactable_data.sprite_closed:
		editor_sprite.texture = interactable_data.sprite_closed
	else:
		editor_sprite.texture = _create_placeholder_texture()


func _get_or_create_sprite() -> Sprite2D:
	var existing: Sprite2D = get_node_or_null("Sprite2D")
	if existing:
		return existing
	var new_sprite: Sprite2D = Sprite2D.new()
	new_sprite.name = "Sprite2D"
	new_sprite.centered = true
	add_child(new_sprite)
	return new_sprite


func _create_placeholder_texture() -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.4, 0.2))

	# Chest lid indicator
	for x: int in range(4, 28):
		img.set_pixel(x, 8, Color(0.4, 0.25, 0.1))
		img.set_pixel(x, 9, Color(0.4, 0.25, 0.1))

	# Keyhole indicator
	for y: int in range(14, 20):
		img.set_pixel(15, y, Color(0.2, 0.1, 0.05))
		img.set_pixel(16, y, Color(0.2, 0.1, 0.05))

	return ImageTexture.create_from_image(img)


func interact(player: Node2D) -> void:
	if not interactable_data:
		push_warning("InteractableNode: Cannot interact - no interactable_data set")
		return

	var check: Dictionary = interactable_data.can_interact()
	if not check.get("can_interact", false):
		if check.get("reason", "") == "already_opened":
			_show_already_opened_message()
		return

	var request_result: Dictionary = {"cancel": false, "reason": ""}
	interaction_requested.emit(self, player, request_result)

	if request_result.get("cancel", false):
		var cancel_reason: String = request_result.get("reason", "")
		if not cancel_reason.is_empty():
			_show_dialog(cancel_reason)
		return

	_flash_on_interact()
	interaction_started.emit(self, player)
	CinematicsManager.set_interaction_context({"interactable_id": interactable_data.interactable_id})

	var cinematic_id: String = interactable_data.get_cinematic_id_for_state()

	if cinematic_id.is_empty():
		_complete_interaction()
		return

	if cinematic_id.begins_with("__auto_interactable__"):
		_play_auto_cinematic()
		return

	if not CinematicsManager.play_cinematic(cinematic_id):
		push_error("InteractableNode: Failed to play cinematic '%s'" % cinematic_id)
		_complete_interaction()
		return

	_connect_cinematic_end_signal()


func _play_auto_cinematic() -> void:
	var commands: Array[Dictionary] = []

	if interactable_data.has_rewards():
		commands.append({
			"type": "grant_items",
			"params": {
				"items": interactable_data.item_rewards,
				"gold": interactable_data.gold_reward,
				"show_message": true
			}
		})

	if commands.is_empty():
		commands.append({
			"type": "dialog",
			"params": {"text": InteractableData.get_default_empty_message(interactable_data.interactable_type)}
		})

	CinematicsManager.play_inline_cinematic(commands)
	_connect_cinematic_end_signal()


func _show_already_opened_message() -> void:
	_show_dialog(InteractableData.get_already_opened_message(interactable_data.interactable_type))


func _show_dialog(text: String) -> void:
	CinematicsManager.play_inline_cinematic([{"type": "dialog", "params": {"text": text}}])


func _connect_cinematic_end_signal() -> void:
	if not CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
		CinematicsManager.cinematic_ended.connect(_on_cinematic_ended, CONNECT_ONE_SHOT)


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


func _complete_interaction() -> void:
	interactable_data.mark_opened()
	_update_sprite_texture()
	CinematicsManager.clear_interaction_context()
	interaction_ended.emit(self)


func _on_cinematic_ended(_cinematic_id: String) -> void:
	_complete_interaction()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if CinematicsManager and CinematicsManager.cinematic_ended.is_connected(_on_cinematic_ended):
		CinematicsManager.cinematic_ended.disconnect(_on_cinematic_ended)


func get_display_name() -> String:
	return interactable_data.display_name if interactable_data else name


func is_at_grid_position(pos: Vector2i) -> bool:
	return grid_position == pos


func teleport_to_grid(pos: Vector2i) -> void:
	grid_position = pos
	global_position = GridManager.cell_to_world(pos)


# =============================================================================
# EDITOR VISUALIZATION
# =============================================================================

func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var color: Color = _get_editor_state_color()
	draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), color, false, 2.0)
	_draw_type_icon(color)

	var label: String = _get_editor_label()
	if not label.is_empty():
		var font: Font = ThemeDB.fallback_font
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		draw_string(font, Vector2(-text_size.x / 2.0, -20.0), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)


func _draw_type_icon(color: Color) -> void:
	if not interactable_data:
		draw_string(ThemeDB.fallback_font, Vector2(-4, 6), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)
		return

	match interactable_data.interactable_type:
		InteractableData.InteractableType.CHEST:
			draw_rect(Rect2(-8, -4, 16, 10), color, true)
			draw_line(Vector2(-8, -2), Vector2(8, -2), color.darkened(0.3), 2.0)
		InteractableData.InteractableType.BOOKSHELF:
			draw_rect(Rect2(-6, -8, 12, 16), color, true)
			for i: int in range(3):
				draw_line(Vector2(-4, -6 + i * 5), Vector2(4, -6 + i * 5), color.darkened(0.3), 1.0)
		InteractableData.InteractableType.BARREL:
			draw_circle(Vector2.ZERO, 8.0, color)
			draw_arc(Vector2.ZERO, 8.0, 0, TAU, 16, color.darkened(0.3), 2.0)
		InteractableData.InteractableType.SIGN:
			draw_rect(Rect2(-8, -6, 16, 8), color, true)
			draw_line(Vector2(0, 2), Vector2(0, 10), color.darkened(0.3), 2.0)
		InteractableData.InteractableType.LEVER:
			draw_circle(Vector2(0, 4), 4.0, color)
			draw_line(Vector2(0, 4), Vector2(0, -8), color, 2.0)
		_:
			draw_string(ThemeDB.fallback_font, Vector2(-4, 6), "*", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)


func _get_editor_state_color() -> Color:
	if not interactable_data:
		return Color.RED
	if not interactable_data is InteractableData:
		return Color.ORANGE

	var data: InteractableData = interactable_data as InteractableData
	if not data or not data.validate():
		return Color.ORANGE
	if data.has_rewards():
		return Color.GOLD
	return Color.CYAN


func _get_editor_label() -> String:
	if interactable_data:
		if not interactable_data.display_name.is_empty():
			return interactable_data.display_name
		if not interactable_data.interactable_id.is_empty():
			return interactable_data.interactable_id
	return name
