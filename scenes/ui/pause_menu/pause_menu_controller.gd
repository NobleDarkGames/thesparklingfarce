extends CanvasLayer

## PauseMenuController - Screen stack manager for the pause menu
##
## Manages a stack of pause menu screens (main, settings, etc.).
## Instantiated by PauseMenuManager and added to the scene root.
## Listens for PauseMenuManager signals to open/close.
##
## Architecture:
## - PauseMenuManager handles input, pausing, and visibility
## - This controller handles screen instantiation and navigation
## - Individual screens handle their own UI and input

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the controller wants the pause menu closed (e.g., last screen popped)
signal pause_closed()

# =============================================================================
# CONSTANTS
# =============================================================================

## Screen name -> scene path mapping
const SCREEN_PATHS: Dictionary = {
	"main": "res://scenes/ui/pause_menu/screens/main_pause_screen.tscn",
	"settings": "res://scenes/ui/pause_menu/screens/settings_screen.tscn",
}

# =============================================================================
# STATE
# =============================================================================

## Stack of active screen instances (newest on top)
var _screen_stack: Array[Control] = []

## Screen scene cache (lazy loaded)
var _screen_scenes: Dictionary = {}

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var input_blocker: ColorRect = %InputBlocker
@onready var screen_container: Control = %ScreenContainer

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	# Connect to PauseMenuManager signals for open/close coordination
	if PauseMenuManager:
		PauseMenuManager.pause_menu_opened.connect(_on_pause_menu_opened)
		PauseMenuManager.pause_menu_closed.connect(_on_pause_menu_closed)

	# Connect our own signal back to manager for stack-driven close
	pause_closed.connect(_on_pause_closed)


func _exit_tree() -> void:
	if PauseMenuManager:
		if PauseMenuManager.pause_menu_opened.is_connected(_on_pause_menu_opened):
			PauseMenuManager.pause_menu_opened.disconnect(_on_pause_menu_opened)
		if PauseMenuManager.pause_menu_closed.is_connected(_on_pause_menu_closed):
			PauseMenuManager.pause_menu_closed.disconnect(_on_pause_menu_closed)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Called when PauseMenuManager opens the pause menu
func _on_pause_menu_opened() -> void:
	open_pause()


## Called when PauseMenuManager closes the pause menu (e.g., pressing Escape again)
func _on_pause_menu_closed() -> void:
	close_pause()


## Called when our own pause_closed signal fires (last screen popped)
func _on_pause_closed() -> void:
	PauseMenuManager.close_pause_menu()

# =============================================================================
# PUBLIC API
# =============================================================================

## Open the pause menu and push the main screen
func open_pause() -> void:
	visible = true
	push_screen("main")


## Close the pause menu and clear all screens
func close_pause() -> void:
	_clear_all_screens()
	visible = false


## Push a new screen onto the stack
func push_screen(screen_name: String) -> void:
	# Hide current top screen (if any)
	if not _screen_stack.is_empty():
		var current: Control = _screen_stack.back()
		current.visible = false

	# Load and instantiate the new screen
	var scene: PackedScene = _get_screen_scene(screen_name)
	if not scene:
		push_error("PauseMenuController: Failed to load screen '%s'" % screen_name)
		return

	var screen: Control = scene.instantiate()
	screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	screen_container.add_child(screen)

	# Initialize the screen with a reference to this controller
	if screen.has_method("initialize"):
		screen.initialize(self)

	_screen_stack.push_back(screen)


## Pop the current screen off the stack
func pop_screen() -> void:
	if _screen_stack.is_empty():
		return

	# Remove and free the top screen
	var top: Control = _screen_stack.pop_back()
	if is_instance_valid(top):
		if top.has_method("_on_screen_exit"):
			top._on_screen_exit()
		top.queue_free()

	# Show the previous screen, or signal close if stack is empty
	if not _screen_stack.is_empty():
		var previous: Control = _screen_stack.back()
		previous.visible = true
	else:
		pause_closed.emit()

# =============================================================================
# INTERNAL
# =============================================================================

## Get a cached screen scene or load it
func _get_screen_scene(screen_name: String) -> PackedScene:
	if screen_name in _screen_scenes:
		return _screen_scenes[screen_name] as PackedScene

	if screen_name not in SCREEN_PATHS:
		push_error("PauseMenuController: Unknown screen name '%s'" % screen_name)
		return null

	var path: String = SCREEN_PATHS[screen_name]
	if not ResourceLoader.exists(path):
		push_error("PauseMenuController: Screen scene not found at '%s'" % path)
		return null

	var scene: PackedScene = load(path) as PackedScene
	if scene:
		_screen_scenes[screen_name] = scene
	return scene


## Clear all screens from the stack
func _clear_all_screens() -> void:
	while not _screen_stack.is_empty():
		var screen: Control = _screen_stack.pop_back()
		if is_instance_valid(screen):
			if screen.has_method("_on_screen_exit"):
				screen._on_screen_exit()
			screen.queue_free()
