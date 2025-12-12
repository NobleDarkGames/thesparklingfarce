extends CanvasLayer

## MembersInterfaceController - Main controller for multi-screen party members interface
##
## Manages screen stack, shared context, and provides SF2-style member management.
## Uses the same architecture as CaravanInterfaceController for consistency.
##
## Key Responsibilities:
## - Screen transitions and navigation stack
## - Reuses CaravanContext (with GIVE mode) for session state
## - L/R bumper character cycling support
##
## Screen Flow:
## member_select -> member_detail (with L/R cycling)
##                     -> give_recipient_select (for Give action)
##                     -> depot_browser (for Depot access, reuses Caravan screen)

# Preload CaravanContext (reused with GIVE mode extensions)
const CaravanContextClass: GDScript = preload("res://scenes/ui/caravan/caravan_context.gd")

signal members_closed()

## Shared context across all screens (CaravanContext with GIVE mode)
var context: RefCounted = null

## Currently active screen instance
var current_screen: Control = null

## Current screen name (for history tracking)
var current_screen_name: String = ""

## Screen scene cache (lazy loaded)
var _screen_scenes: Dictionary = {}

## Screen names mapped to scene paths
const SCREEN_PATHS: Dictionary = {
	"member_select": "res://scenes/ui/members/screens/member_select.tscn",
	"member_detail": "res://scenes/ui/members/screens/member_detail.tscn",
	"give_recipient_select": "res://scenes/ui/members/screens/give_recipient_select.tscn",
	# Reuse Caravan's depot browser for depot access
	"depot_browser": "res://scenes/ui/caravan/screens/depot_browser.tscn",
}

## Node references
@onready var screen_container: Control = %ScreenContainer
@onready var header_label: Label = %HeaderLabel
@onready var hint_label: Label = %HintLabel
@onready var input_blocker: ColorRect = %InputBlocker


func _ready() -> void:
	context = CaravanContextClass.new()
	hide()


# =============================================================================
# OPEN/CLOSE
# =============================================================================

## Open the members interface
## @param start_character_uid: Optional UID to start on specific character
func open_members(start_character_uid: String = "") -> void:
	context.initialize()

	# Set starting character if specified
	if not start_character_uid.is_empty():
		context.set_current_member_by_uid(start_character_uid)
	else:
		context.current_member_index = 0

	show()

	# Start with member select screen
	push_screen("member_select")


## Close the members interface
func close_interface() -> void:
	_clear_current_screen()
	context.cleanup()
	hide()
	members_closed.emit()


## Check if the members interface is currently open
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
		# At root - close members
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
		push_error("MembersInterfaceController: Failed to load screen '%s'" % screen_name)
		return

	# Instantiate and add to container
	current_screen = scene.instantiate()
	current_screen_name = screen_name

	# Add to tree FIRST so @onready vars are available
	screen_container.add_child(current_screen)

	# THEN initialize (now @onready vars are set)
	if current_screen.has_method("initialize"):
		current_screen.initialize(self, context)

	# Update hint based on screen
	_update_hint_for_screen(screen_name)


## Get cached scene or load it
func _get_screen_scene(screen_name: String) -> PackedScene:
	# Return cached if available
	if screen_name in _screen_scenes:
		return _screen_scenes[screen_name]

	# Check if path exists
	if screen_name not in SCREEN_PATHS:
		push_error("MembersInterfaceController: Unknown screen name '%s'" % screen_name)
		return null

	var path: String = SCREEN_PATHS[screen_name]

	# Check if file exists before loading
	if not ResourceLoader.exists(path):
		push_error("MembersInterfaceController: Screen scene not found at '%s'" % path)
		return null

	# Load and cache
	var scene: PackedScene = load(path) as PackedScene
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

## Update the header label
func update_header(text: String) -> void:
	if header_label:
		header_label.text = text


## Update the hint label based on current screen
func _update_hint_for_screen(screen_name: String) -> void:
	if not hint_label:
		return

	match screen_name:
		"member_select":
			hint_label.text = "A: Select | B: Close"
		"member_detail":
			hint_label.text = "L/R: Switch | A: Select | B: Back"
		"give_recipient_select":
			hint_label.text = "A: Give | B: Cancel"
		"depot_browser":
			hint_label.text = "A: Select | L/R: Filter | B: Back"
		_:
			hint_label.text = ""


# =============================================================================
# INPUT BLOCKING
# =============================================================================

## Block input during transitions (future use)
func _set_input_blocked(blocked: bool) -> void:
	if input_blocker:
		input_blocker.visible = blocked
