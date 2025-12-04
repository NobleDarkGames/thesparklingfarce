extends Control

## Main Menu - Primary game menu
## Allows player to start new game or load existing save

@onready var new_game_button: Button = %NewGameButton
@onready var load_game_button: Button = %LoadGameButton
@onready var quit_button: Button = %QuitButton
@onready var title_label: Label = $TitleContainer/Title
@onready var version_label: Label = $VersionLabel

## Animation settings
const TITLE_FADE_DURATION: float = 0.6
const BUTTON_STAGGER_DELAY: float = 0.1
const BUTTON_SLIDE_DURATION: float = 0.3
const BUTTON_HOVER_SCALE: float = 1.08
const BUTTON_FOCUS_SCALE: float = 1.05
const BUTTON_SCALE_DURATION: float = 0.1

## Track original button positions for animations
var _button_original_positions: Dictionary = {}


func _ready() -> void:
	# Connect button signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Setup hover/focus effects for all buttons
	var buttons: Array[Button] = [new_game_button, load_game_button, quit_button]
	for button: Button in buttons:
		_setup_button_effects(button)

	# Run entrance animation
	await _play_entrance_animation()

	# Position sparkle particles at screen center
	_position_sparkle_particles()

	# Focus the first button after animation
	new_game_button.grab_focus()


## Position sparkle particles at screen center for full-screen starfield effect
func _position_sparkle_particles() -> void:
	var particles: CPUParticles2D = get_node_or_null("TitleContainer/SparkleParticles")
	if not particles:
		return

	# Get the viewport/screen size and center particles
	var viewport_size: Vector2 = get_viewport_rect().size
	particles.global_position = viewport_size / 2.0

	# Update emission rect to cover full screen
	particles.emission_rect_extents = viewport_size / 2.0


## Setup hover and focus effects for a button
func _setup_button_effects(button: Button) -> void:
	# Store original scale
	button.pivot_offset = button.size / 2.0

	# Connect focus signals
	button.focus_entered.connect(_on_button_focus_entered.bind(button))
	button.focus_exited.connect(_on_button_focus_exited.bind(button))

	# Connect hover signals
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button))


## Animate button scale on focus
func _on_button_focus_entered(button: Button) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(BUTTON_FOCUS_SCALE, BUTTON_FOCUS_SCALE), BUTTON_SCALE_DURATION)


func _on_button_focus_exited(button: Button) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_SCALE_DURATION)


func _on_button_mouse_entered(button: Button) -> void:
	if not button.has_focus():
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2(BUTTON_HOVER_SCALE, BUTTON_HOVER_SCALE), BUTTON_SCALE_DURATION)


func _on_button_mouse_exited(button: Button) -> void:
	if not button.has_focus():
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE, BUTTON_SCALE_DURATION)


## Play the entrance animation sequence
func _play_entrance_animation() -> void:
	var buttons: Array[Button] = [new_game_button, load_game_button, quit_button]

	# Setup initial states - everything invisible
	title_label.modulate.a = 0.0
	version_label.modulate.a = 0.0

	for button: Button in buttons:
		button.modulate.a = 0.0
		_button_original_positions[button] = button.position
		button.position.x -= 50  # Start offset to the left

	# Wait a beat after scene transition
	await get_tree().create_timer(0.15).timeout

	# Fade in title with slight scale punch
	var title_tween: Tween = create_tween()
	title_label.pivot_offset = title_label.size / 2.0
	title_label.scale = Vector2(0.9, 0.9)
	title_tween.set_parallel(true)
	title_tween.tween_property(title_label, "modulate:a", 1.0, TITLE_FADE_DURATION)
	title_tween.tween_property(title_label, "scale", Vector2.ONE, TITLE_FADE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Wait a bit, then stagger in buttons
	await get_tree().create_timer(0.2).timeout

	for i: int in range(buttons.size()):
		var button: Button = buttons[i]
		var delay: float = i * BUTTON_STAGGER_DELAY

		var button_tween: Tween = create_tween()
		button_tween.set_parallel(true)
		button_tween.tween_property(button, "modulate:a", 1.0, BUTTON_SLIDE_DURATION).set_delay(delay)
		button_tween.tween_property(button, "position:x", _button_original_positions[button].x, BUTTON_SLIDE_DURATION).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Fade in version label last
	await get_tree().create_timer(0.3).timeout
	var version_tween: Tween = create_tween()
	version_tween.tween_property(version_label, "modulate:a", 0.6, 0.3)  # Subtle, not fully opaque


func _on_new_game_pressed() -> void:
	# Go to save slot selector in "new game" mode
	# The selector will create a new save in the chosen slot (overwriting if occupied)
	SceneManager.goto_save_slot_selector("new_game")


func _on_load_game_pressed() -> void:
	# Go to save slot selector in "load game" mode
	# The selector will load an existing save from the chosen slot
	SceneManager.goto_save_slot_selector("load_game")


func _on_quit_pressed() -> void:
	get_tree().quit()
