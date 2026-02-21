## InteractionPrompt - Visual indicator shown when player can interact
##
## Shows a bubble with "!" or "?" above NPCs and interactables when:
## - Player is within 2 tiles (Manhattan distance)
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
var _current_amplitude: float = 0.0  ## Current bob amplitude (ramps up on show)
var _was_showing: bool = false  ## Track show transitions for amplitude ramp

## Animation constants
const BOB_AMPLITUDE: float = 2.5  ## Pixels of vertical bob (2-3px per spec)
const BOB_FREQUENCY: float = 3.0  ## Cycles per second
const FADE_DURATION: float = 0.12  ## Seconds for fade in/out (0.1-0.15 per spec)
const VERTICAL_OFFSET: float = -20.0  ## Base offset above parent center
const PROMPT_RAMP_DURATION: float = 0.3  ## Seconds for bob amplitude to ramp up


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

	# Detect show transition and reset amplitude for ramp effect
	if should_show and not _was_showing:
		_current_amplitude = 0.0
	_was_showing = should_show

	# Animate alpha toward target
	var target_alpha: float = 1.0 if should_show else 0.0
	var fade_speed: float = 1.0 / FADE_DURATION

	if _current_alpha < target_alpha:
		_current_alpha = minf(_current_alpha + fade_speed * delta, target_alpha)
	elif _current_alpha > target_alpha:
		_current_alpha = maxf(_current_alpha - fade_speed * delta, target_alpha)

	modulate.a = _current_alpha

	# Ramp bob amplitude toward full when showing, decay when hiding
	if should_show:
		var ramp_speed: float = BOB_AMPLITUDE / PROMPT_RAMP_DURATION if PROMPT_RAMP_DURATION > 0.0 else BOB_AMPLITUDE
		_current_amplitude = minf(_current_amplitude + ramp_speed * delta, BOB_AMPLITUDE)
	else:
		_current_amplitude = 0.0

	# Apply bob animation when visible
	if _current_alpha > 0.0 and _label:
		var bob_offset: float = sin(_time_elapsed * BOB_FREQUENCY * TAU) * _current_amplitude
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

	# Get hero's grid position
	if not "grid_position" in hero:
		return

	var hero_grid: Vector2i = hero.grid_position

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

	# Check if hero is within 2 tiles (Manhattan distance)
	var delta: Vector2i = our_grid - hero_grid
	if absi(delta.x) + absi(delta.y) > 2:
		return  # Too far away

	# All checks passed
	should_show = true
