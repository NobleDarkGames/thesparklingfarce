extends Node

## SceneManager - Autoload singleton for managing scene transitions
## Handles transitions between different game states (menu, battle, HQ, etc.)
## and provides fade effects for smooth scene changes.
##
## IMPORTANT: This is the central authority for screen fades. Other systems
## (like CinematicsManager) should use SceneManager's fade methods rather than
## creating their own overlays.
##
## Scene paths are looked up from ModRegistry, allowing mods to override
## core scenes like opening_cinematic, main_menu, save_slot_selector, etc.

signal scene_transition_started(from_scene: String, to_scene: String)
signal scene_transition_completed(scene: String)
signal fade_started(to_black: bool)
signal fade_completed(is_black: bool)

# Scene ID constants (used for registry lookups)
const SCENE_OPENING_CINEMATIC: String = "opening_cinematic"
const SCENE_MAIN_MENU: String = "main_menu"
const SCENE_SAVE_SLOT_SELECTOR: String = "save_slot_selector"

# Fallback paths (used only if no mod registers these scenes)
const FALLBACK_OPENING_CINEMATIC: String = "res://scenes/cinematics/opening_cinematic_stage.tscn"
const FALLBACK_MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"
const FALLBACK_SAVE_SLOT_SELECTOR: String = "res://scenes/ui/save_slot_selector.tscn"
const FALLBACK_BATTLE_LOADER: String = "res://scenes/battle_loader.tscn"

# Transition settings
const FADE_DURATION: float = 0.3

var current_scene_path: String = ""
var previous_scene_path: String = ""
var is_transitioning: bool = false

## Save slot selector mode: "new_game" or "load_game"
var save_slot_mode: String = "new_game"

## Current fade state - true if screen is currently faded to black
var is_faded_to_black: bool = false

## Whether a fade animation is currently in progress
var is_fading: bool = false

# Fade overlay (CanvasLayer to ensure it's always on top)
var _fade_canvas_layer: CanvasLayer
var fade_overlay: ColorRect


func _ready() -> void:
	# Create fade overlay
	_create_fade_overlay()

	# Track current scene
	var root: Window = get_tree().root
	var current: Node = root.get_child(root.get_child_count() - 1)
	current_scene_path = current.scene_file_path


## Create a full-screen black overlay for fade transitions
## Uses CanvasLayer to ensure it persists across scene changes and renders on top
func _create_fade_overlay() -> void:
	# Create a CanvasLayer at a high layer to render above everything
	_fade_canvas_layer = CanvasLayer.new()
	_fade_canvas_layer.name = "SceneManagerFadeLayer"
	_fade_canvas_layer.layer = 128  # Very high layer to be above everything

	fade_overlay = ColorRect.new()
	fade_overlay.name = "FadeOverlay"
	fade_overlay.color = Color.BLACK
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Make it cover the entire screen
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Start fully transparent
	fade_overlay.modulate.a = 0.0

	# Add overlay to canvas layer
	_fade_canvas_layer.add_child(fade_overlay)

	# Add canvas layer to root (deferred to avoid issues during autoload init)
	get_tree().root.call_deferred("add_child", _fade_canvas_layer)


## Transition to a new scene with fade effect
## If use_fade is true, will fade to black, switch scene, then fade from black
## If screen is already faded to black (e.g., from cinematic), will only fade from black
func change_scene(scene_path: String, use_fade: bool = true) -> void:
	if is_transitioning:
		push_warning("SceneManager: Already transitioning, ignoring request")
		return

	if not ResourceLoader.exists(scene_path):
		push_error("SceneManager: Scene does not exist: %s" % scene_path)
		return

	is_transitioning = true
	previous_scene_path = current_scene_path

	scene_transition_started.emit(current_scene_path, scene_path)

	if use_fade:
		# Only fade to black if not already black
		if not is_faded_to_black:
			await _fade_to_black()
		await _switch_scene(scene_path)
		await _fade_from_black()
	else:
		await _switch_scene(scene_path)
		# If screen was faded to black, we still need to fade from black!
		if is_faded_to_black:
			await _fade_from_black()

	current_scene_path = scene_path
	is_transitioning = false

	scene_transition_completed.emit(scene_path)


## Actually switch the scene
func _switch_scene(scene_path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneManager: Failed to load scene: %s (error: %d)" % [scene_path, error])

	# Wait one frame for scene to load
	await get_tree().process_frame


## Fade to black (internal use - updates state)
func _fade_to_black() -> void:
	await fade_to_black(FADE_DURATION)


## Fade from black (internal use - updates state)
func _fade_from_black() -> void:
	await fade_from_black(FADE_DURATION)


## PUBLIC: Fade the screen to black
## Can be called by CinematicsManager or other systems
## @param duration: Fade duration in seconds (default uses FADE_DURATION)
## @param color: Fade color (default black)
func fade_to_black(duration: float = FADE_DURATION, color: Color = Color.BLACK) -> void:
	if not fade_overlay:
		return

	if is_fading:
		push_warning("SceneManager: Fade already in progress")
		return

	# Ensure overlay is in tree (may not be if deferred add hasn't completed)
	if not fade_overlay.is_inside_tree():
		await get_tree().process_frame

	is_fading = true
	fade_overlay.color = color
	fade_started.emit(true)

	var tween: Tween = create_tween()
	if not tween:
		push_error("SceneManager: create_tween() returned null in fade_to_black")
		is_fading = false
		return
	tween.tween_property(fade_overlay, "modulate:a", 1.0, duration)
	await tween.finished

	is_faded_to_black = true
	is_fading = false
	fade_completed.emit(true)


## PUBLIC: Fade the screen from black (reveal)
## Can be called by CinematicsManager or other systems
## @param duration: Fade duration in seconds (default uses FADE_DURATION)
func fade_from_black(duration: float = FADE_DURATION) -> void:
	if not fade_overlay:
		return

	if is_fading:
		push_warning("SceneManager: Fade already in progress")
		return

	is_fading = true
	fade_started.emit(false)

	var tween: Tween = create_tween()
	if not tween:
		push_error("SceneManager: create_tween() returned null in fade_from_black")
		is_fading = false
		return
	tween.tween_property(fade_overlay, "modulate:a", 0.0, duration)
	await tween.finished

	is_faded_to_black = false
	is_fading = false
	fade_completed.emit(false)


## PUBLIC: Immediately set screen to black (no animation)
## Useful for instant transitions or initialization
func set_black() -> void:
	if fade_overlay:
		fade_overlay.modulate.a = 1.0
		is_faded_to_black = true


## PUBLIC: Immediately clear fade (no animation)
## Useful for error recovery or forced clear
func clear_fade() -> void:
	if fade_overlay:
		fade_overlay.modulate.a = 0.0
		is_faded_to_black = false


## Get a scene path from ModRegistry, with fallback to hardcoded path
## scene_id: The scene identifier (e.g., "opening_cinematic")
## fallback: Path to use if scene is not registered
func get_scene_path(scene_id: String, fallback: String = "") -> String:
	if ModLoader and ModLoader.registry:
		var registered_path: String = ModLoader.registry.get_scene_path(scene_id)
		if not registered_path.is_empty():
			return registered_path

	if fallback.is_empty():
		push_warning("SceneManager: Scene '%s' not registered and no fallback provided" % scene_id)
	return fallback


## Convenience functions for common transitions

func goto_opening_cinematic(use_fade: bool = true) -> void:
	var scene_path: String = get_scene_path(SCENE_OPENING_CINEMATIC, FALLBACK_OPENING_CINEMATIC)
	await change_scene(scene_path, use_fade)


func goto_main_menu(use_fade: bool = true) -> void:
	var scene_path: String = get_scene_path(SCENE_MAIN_MENU, FALLBACK_MAIN_MENU)
	await change_scene(scene_path, use_fade)


func goto_save_slot_selector(mode: String = "new_game", use_fade: bool = true) -> void:
	save_slot_mode = mode
	var scene_path: String = get_scene_path(SCENE_SAVE_SLOT_SELECTOR, FALLBACK_SAVE_SLOT_SELECTOR)
	await change_scene(scene_path, use_fade)


func goto_battle(battle_scene_path: String = "", use_fade: bool = true) -> void:
	if battle_scene_path.is_empty():
		battle_scene_path = FALLBACK_BATTLE_LOADER
	await change_scene(battle_scene_path, use_fade)


## Go back to previous scene
func go_back(use_fade: bool = true) -> void:
	if previous_scene_path.is_empty():
		push_warning("SceneManager: No previous scene to return to")
		return

	await change_scene(previous_scene_path, use_fade)


## Get the current scene node
func get_current_scene() -> Node:
	var root: Window = get_tree().root
	return root.get_child(root.get_child_count() - 1)
