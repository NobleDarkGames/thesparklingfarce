extends Node

## PauseMenuManager - Global autoload for pause menu management
##
## Listens for sf_pause input and toggles the pause menu.
## Instantiates a persistent PauseMenuController (CanvasLayer) added to root.
## Manages get_tree().paused state and blocks opening during cinematics,
## dialog, debug console, or shops.
##
## Usage (automatic - no setup required):
##   # Press Escape/Start to toggle the pause menu
##   PauseMenuManager.open_pause_menu()
##   PauseMenuManager.close_pause_menu()
##   PauseMenuManager.is_open()

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the pause menu opens
signal pause_menu_opened()

## Emitted when the pause menu closes
signal pause_menu_closed()

# =============================================================================
# CONSTANTS
# =============================================================================

const CONTROLLER_SCENE_PATH: String = "res://scenes/ui/pause_menu/pause_menu_controller.tscn"

# =============================================================================
# STATE
# =============================================================================

## The persistent pause menu controller (CanvasLayer, survives scene transitions)
var _controller: CanvasLayer = null

## Whether the pause menu is currently open
var _is_open: bool = false

## Whether the system is initialized
var _initialized: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Must process when paused so we can close the menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Defer initialization to ensure other autoloads are ready
	call_deferred("_initialize")


func _initialize() -> void:
	if _initialized:
		return

	if ResourceLoader.exists(CONTROLLER_SCENE_PATH):
		_controller = load(CONTROLLER_SCENE_PATH).instantiate()
	else:
		push_warning("PauseMenuManager: Controller scene not found at '%s', pause menu disabled" % CONTROLLER_SCENE_PATH)
		_initialized = true
		return

	_controller.name = "PauseMenuController"
	_controller.visible = false
	_controller.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().root.call_deferred("add_child", _controller)

	_initialized = true

# =============================================================================
# INPUT
# =============================================================================

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("sf_pause"):
		return

	if _is_open:
		close_pause_menu()
		get_viewport().set_input_as_handled()
		return

	if _can_open_pause():
		open_pause_menu()
		get_viewport().set_input_as_handled()

# =============================================================================
# BLOCKING CONDITIONS
# =============================================================================

## Check whether the pause menu is allowed to open right now.
## Blocked during cinematics, dialog, debug console, and shops.
## Allowed during battle so players can access Settings mid-combat.
func _can_open_pause() -> bool:
	# Block during cinematics
	if CinematicsManager and CinematicsManager.is_cinematic_active():
		return false

	# Block during dialog
	if DialogManager and DialogManager.is_dialog_active():
		return false

	# Block during debug console
	if DebugConsole and "is_open" in DebugConsole and DebugConsole.is_open:
		return false

	# Block during shops
	if ShopManager and ShopManager.is_shop_open():
		return false

	# Block if exploration menus are open
	if ExplorationUIManager and ExplorationUIManager.is_blocking_input():
		return false

	return true

# =============================================================================
# PUBLIC API
# =============================================================================

## Open the pause menu and pause the game tree
func open_pause_menu() -> void:
	if _is_open:
		return
	if not _controller:
		return

	_is_open = true
	_controller.visible = true
	get_tree().paused = true
	pause_menu_opened.emit()


## Close the pause menu and unpause the game tree
func close_pause_menu() -> void:
	if not _is_open:
		return

	_is_open = false
	if _controller:
		_controller.visible = false
	get_tree().paused = false
	pause_menu_closed.emit()


## Check if the pause menu is currently open
func is_open() -> bool:
	return _is_open
