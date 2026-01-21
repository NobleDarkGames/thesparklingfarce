## InteractionPrompt - Visual indicator shown when player can interact
##
## Shows a bubble with "!" or "?" above NPCs and interactables when:
## - Player is adjacent (1 tile away)
## - Player is facing the object
## - Object is interactable (not already used for one-shot objects)
##
## Features smooth fade in/out and gentle bob animation.
class_name InteractionPrompt
extends Control


## The symbol to display ("!" for NPCs, "?" for interactables)
var prompt_symbol: String = "!":
	set(value):
		prompt_symbol = value
		if _label:
			_label.text = value

## Whether this prompt should currently be visible (based on player state)
var should_show: bool = false

## Callback to check if the parent object can be interacted with
## Set by parent node. Returns true if interaction is allowed.
var can_interact_callback: Callable = Callable()

## Internal state
var _label: Label = null
var _time_elapsed: float = 0.0
var _current_alpha: float = 0.0

## Animation constants
const BOB_AMPLITUDE: float = 2.5  ## Pixels of vertical bob (2-3px per spec)
const BOB_FREQUENCY: float = 3.0  ## Cycles per second
const FADE_DURATION: float = 0.12  ## Seconds for fade in/out (0.1-0.15 per spec)
const VERTICAL_OFFSET: float = -20.0  ## Base offset above parent center


func _ready() -> void:
	# Create the label for displaying the prompt symbol
	_label = Label.new()
	_label.text = prompt_symbol
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # Pixel-perfect for Monogram font

	# Load Monogram font
	var font_path: String = "res://assets/fonts/monogram.ttf"
	if ResourceLoader.exists(font_path):
		var font: Font = load(font_path)
		_label.add_theme_font_override("font", font)

	# Large, readable size
	_label.add_theme_font_size_override("font_size", 24)

	# White text with slight shadow for visibility
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)

	add_child(_label)

	# Position label centered above origin
	_label.position = Vector2(-8, VERTICAL_OFFSET)

	# Start invisible
	modulate.a = 0.0
	_current_alpha = 0.0

	# Don't process in editor
	if Engine.is_editor_hint():
		set_process(false)
		return


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_time_elapsed += delta

	# Check if we should be showing
	_update_visibility_state()

	# Animate alpha toward target
	var target_alpha: float = 1.0 if should_show else 0.0
	var fade_speed: float = 1.0 / FADE_DURATION

	if _current_alpha < target_alpha:
		_current_alpha = minf(_current_alpha + fade_speed * delta, target_alpha)
	elif _current_alpha > target_alpha:
		_current_alpha = maxf(_current_alpha - fade_speed * delta, target_alpha)

	modulate.a = _current_alpha

	# Apply bob animation when visible
	if _current_alpha > 0.0 and _label:
		var bob_offset: float = sin(_time_elapsed * BOB_FREQUENCY * TAU) * BOB_AMPLITUDE
		_label.position.y = VERTICAL_OFFSET + bob_offset


## Update whether prompt should be visible based on player state
func _update_visibility_state() -> void:
	should_show = false

	# Check if we can interact (parent may be opened/used)
	if can_interact_callback.is_valid():
		if not can_interact_callback.call():
			return

	# Find the hero
	var hero: Node = get_tree().get_first_node_in_group("hero")
	if not hero:
		return

	# Get hero's grid position and facing
	if not "grid_position" in hero or not "facing_direction" in hero:
		return

	var hero_grid: Vector2i = hero.grid_position
	var hero_facing: String = hero.facing_direction

	# Get our parent's grid position
	var parent_node: Node2D = get_parent() as Node2D
	if not parent_node:
		return

	var our_grid: Vector2i = Vector2i.ZERO
	if "grid_position" in parent_node:
		our_grid = parent_node.grid_position
	else:
		# Fallback: calculate from world position
		our_grid = GridManager.world_to_cell(parent_node.global_position)

	# Check if hero is exactly 1 tile away (adjacent)
	var delta: Vector2i = our_grid - hero_grid
	if absi(delta.x) + absi(delta.y) != 1:
		return  # Not adjacent (diagonal or farther doesn't count)

	# Check if hero is facing us
	var facing_vec: Vector2i = FacingUtils.string_to_direction(hero_facing)
	if facing_vec != delta:
		return  # Hero not facing us

	# All checks passed
	should_show = true
