extends CanvasLayer

## CaravanInterfaceController - Main controller for multi-screen caravan depot interface
##
## Manages screen stack, shared context, and coordinates with StorageManager/PartyManager.
## Unlike ShopController, this is free (no gold transactions) and simpler (no queue panel).
##
## Key Responsibilities:
## - Screen transitions and navigation stack
## - CaravanContext lifecycle management
## - Integration with CaravanController autoload (for menu state)
##
## Architecture Note:
## This controller is instantiated by ExplorationUIManager or CaravanController,
## NOT as an autoload. It provides the multi-screen UI experience for the depot.

# Preload dependencies to avoid load order issues
const CaravanContextClass: GDScript = preload("res://scenes/ui/caravan/caravan_context.gd")

signal depot_closed()

## Shared context across all screens
var context: RefCounted = null  # Actually CaravanContext, typed as RefCounted for load order

## Currently active screen instance
var current_screen: Control = null

## Current screen name (for history tracking)
var current_screen_name: String = ""

## Screen scene cache (lazy loaded)
var _screen_scenes: Dictionary = {}

## Whether opened from caravan interaction (affects close behavior)
var _from_caravan_interaction: bool = false

## Screen names mapped to scene paths
## Note: These paths are placeholders - screens will be implemented later
const SCREEN_PATHS: Dictionary = {
	"action_select": "res://scenes/ui/caravan/screens/action_select.tscn",
	"depot_browser": "res://scenes/ui/caravan/screens/depot_browser.tscn",
	"char_select": "res://scenes/ui/caravan/screens/char_select.tscn",
	"char_inventory": "res://scenes/ui/caravan/screens/char_inventory.tscn",
}

## Node references
@onready var screen_container: Control = %ScreenContainer
@onready var header_label: Label = %HeaderLabel
@onready var depot_count_label: Label = %DepotCountLabel
@onready var input_blocker: ColorRect = %InputBlocker


func _ready() -> void:
	context = CaravanContextClass.new()
	hide()

	# Connect to StorageManager signals for depot count updates
	if StorageManager:
		StorageManager.depot_changed.connect(_on_depot_changed)


func _exit_tree() -> void:
	# Clean up StorageManager signal connections
	if StorageManager:
		if StorageManager.depot_changed.is_connected(_on_depot_changed):
			StorageManager.depot_changed.disconnect(_on_depot_changed)


# =============================================================================
# OPEN/CLOSE
# =============================================================================

## Open the caravan depot interface
## @param from_caravan: true if triggered by interacting with Caravan sprite on overworld
func open_depot(from_caravan: bool = false) -> void:
	_from_caravan_interaction = from_caravan
	context.initialize()

	# Update header
	_update_depot_count()

	show()

	# Start with action select screen
	push_screen("action_select")


## Close the caravan depot interface
func close_interface() -> void:
	_clear_current_screen()
	context.cleanup()
	hide()
	depot_closed.emit()


## Check if the depot interface is currently open
func is_open() -> bool:
	return visible


# =============================================================================
# SCREEN NAVIGATION
# =============================================================================

## Navigate to a new screen (adds current to history)
func push_screen(screen_name: String) -> void:
	if not current_screen_name.is_empty():
		context.push_to_history(current_screen_name)
	_transition_to_screen(screen_name)


## Go back to previous screen
func pop_screen() -> void:
	var previous: String = context.pop_from_history()
	if previous.is_empty():
		# At root - close depot
		close_interface()
	else:
		_transition_to_screen(previous)


## Replace current screen without adding to history
func replace_screen(screen_name: String) -> void:
	_transition_to_screen(screen_name)


## Internal screen transition
func _transition_to_screen(screen_name: String) -> void:
	_clear_current_screen()

	# Load screen scene
	var scene: PackedScene = _get_screen_scene(screen_name)
	if not scene:
		push_error("CaravanInterfaceController: Failed to load screen '%s'" % screen_name)
		return

	# Instantiate and add to container
	current_screen = scene.instantiate()
	current_screen_name = screen_name

	# Add to tree FIRST so @onready vars are available
	screen_container.add_child(current_screen)

	# THEN initialize (now @onready vars are set)
	if current_screen.has_method("initialize"):
		current_screen.initialize(self, context)


## Get cached scene or load it
func _get_screen_scene(screen_name: String) -> PackedScene:
	# Return cached if available
	if screen_name in _screen_scenes:
		var cached: Variant = _screen_scenes[screen_name]
		return cached if cached is PackedScene else null

	# Check if path exists
	if screen_name not in SCREEN_PATHS:
		push_error("CaravanInterfaceController: Unknown screen name '%s'" % screen_name)
		return null

	var path: String = DictUtils.get_string(SCREEN_PATHS, screen_name, "")

	# Check if file exists before loading
	if not ResourceLoader.exists(path):
		push_error("CaravanInterfaceController: Screen scene not found at '%s'" % path)
		return null

	# Load and cache
	var loaded: Resource = load(path)
	var scene: PackedScene = loaded if loaded is PackedScene else null
	if scene:
		_screen_scenes[screen_name] = scene
	return scene


## Clear the current screen
func _clear_current_screen() -> void:
	if current_screen:
		# Notify screen it's being removed
		if current_screen.has_method("_on_screen_exit"):
			current_screen._on_screen_exit()
		current_screen.queue_free()
		current_screen = null
	current_screen_name = ""


# =============================================================================
# DISPLAY UPDATES
# =============================================================================

## Update the depot item count display
func _update_depot_count() -> void:
	if depot_count_label and StorageManager:
		var count: int = StorageManager.get_depot_size()
		depot_count_label.text = "ITEMS: %d" % count


## Handle depot contents changed
func _on_depot_changed() -> void:
	_update_depot_count()


# =============================================================================
# INPUT BLOCKING
# =============================================================================

## Block input during transitions (future use)
func _set_input_blocked(blocked: bool) -> void:
	if input_blocker:
		input_blocker.visible = blocked
