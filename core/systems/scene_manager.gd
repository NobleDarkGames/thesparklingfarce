extends Node

## SceneManager - Autoload singleton for managing scene transitions
## Handles transitions between different game states (menu, battle, HQ, etc.)
## and provides fade effects for smooth scene changes

signal scene_transition_started(from_scene: String, to_scene: String)
signal scene_transition_completed(scene: String)

# Scene paths
const OPENING_CINEMATIC: String = "res://scenes/cinematics/opening_cinematic_stage.tscn"
const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"
const SAVE_SLOT_SELECTOR: String = "res://scenes/ui/save_slot_selector.tscn"
const BATTLE_LOADER: String = "res://mods/_sandbox/scenes/sandbox_battle_test.tscn"

# Transition settings
const FADE_DURATION: float = 0.3

var current_scene_path: String = ""
var previous_scene_path: String = ""
var is_transitioning: bool = false

# Fade overlay
var fade_overlay: ColorRect


func _ready() -> void:
	print("SceneManager: Initializing...")

	# Create fade overlay
	_create_fade_overlay()

	# Track current scene
	var root: Window = get_tree().root
	var current: Node = root.get_child(root.get_child_count() - 1)
	current_scene_path = current.scene_file_path

	print("SceneManager: Current scene: %s" % current_scene_path)


## Create a full-screen black overlay for fade transitions
func _create_fade_overlay() -> void:
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Make it cover the entire screen
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Start fully transparent
	fade_overlay.modulate.a = 0.0

	# Add to tree at top level (deferred to avoid issues during autoload init)
	get_tree().root.call_deferred("add_child", fade_overlay)


## Transition to a new scene with fade effect
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
	print("SceneManager: Transitioning from %s to %s" % [current_scene_path, scene_path])

	if use_fade:
		await _fade_to_black()
		await _switch_scene(scene_path)
		await _fade_from_black()
	else:
		await _switch_scene(scene_path)

	current_scene_path = scene_path
	is_transitioning = false

	scene_transition_completed.emit(scene_path)
	print("SceneManager: Transition complete")


## Actually switch the scene
func _switch_scene(scene_path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneManager: Failed to load scene: %s (error: %d)" % [scene_path, error])

	# Wait one frame for scene to load
	await get_tree().process_frame


## Fade to black
func _fade_to_black() -> void:
	if not fade_overlay:
		return

	# Ensure overlay is in tree (may not be if deferred add hasn't completed)
	if not fade_overlay.is_inside_tree():
		await get_tree().process_frame

	var tween: Tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished


## Fade from black
func _fade_from_black() -> void:
	if not fade_overlay:
		return

	var tween: Tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished


## Convenience functions for common transitions

func goto_opening_cinematic(use_fade: bool = true) -> void:
	change_scene(OPENING_CINEMATIC, use_fade)


func goto_main_menu(use_fade: bool = true) -> void:
	change_scene(MAIN_MENU, use_fade)


func goto_save_slot_selector(use_fade: bool = true) -> void:
	change_scene(SAVE_SLOT_SELECTOR, use_fade)


func goto_battle(battle_scene_path: String = BATTLE_LOADER, use_fade: bool = true) -> void:
	change_scene(battle_scene_path, use_fade)


## Go back to previous scene
func go_back(use_fade: bool = true) -> void:
	if previous_scene_path.is_empty():
		push_warning("SceneManager: No previous scene to return to")
		return

	change_scene(previous_scene_path, use_fade)


## Get the current scene node
func get_current_scene() -> Node:
	var root: Window = get_tree().root
	return root.get_child(root.get_child_count() - 1)
