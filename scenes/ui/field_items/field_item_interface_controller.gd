extends CanvasLayer

## FieldItemInterfaceController - Controller for field menu Item option
##
## Shows hero's inventory only, no character selection or cycling.
## SF2 authentic: field Item menu only shows the protagonist's items.
##
## Key differences from MembersInterfaceController:
## - Skips member_select, goes directly to field_item_detail
## - Disables L/R character cycling (single character only)
## - Uses FIELD_MENU context for ItemActionMenu (no GIVE action)
##
## Screen Flow:
## open_field_items() -> field_item_detail (hero only, no cycling)

const FieldItemContextClass: GDScript = preload("res://scenes/ui/field_items/field_item_context.gd")

signal field_items_closed()

## Context (FieldItemContext, not CaravanContext)
var context: RefCounted = null

## Currently active screen instance
var current_screen: Control = null

## Current screen name
var current_screen_name: String = ""

## Screen scene cache (lazy loaded)
var _screen_scenes: Dictionary = {}

## Screen names mapped to scene paths
const SCREEN_PATHS: Dictionary = {
	"field_item_detail": "res://scenes/ui/field_items/screens/field_item_detail.tscn",
}

## Node references
@onready var screen_container: Control = %ScreenContainer
@onready var header_label: Label = %HeaderLabel
@onready var hint_label: Label = %HintLabel
@onready var input_blocker: ColorRect = %InputBlocker


func _ready() -> void:
	context = FieldItemContextClass.new()
	hide()


# =============================================================================
# OPEN/CLOSE
# =============================================================================

## Open the field items interface (shows hero's inventory)
func open_field_items() -> void:
	context.initialize()
	show()
	# Go directly to detail screen (no member select - hero only)
	push_screen("field_item_detail")


## Close the field items interface
func close_interface() -> void:
	_clear_current_screen()
	context.cleanup()
	hide()
	field_items_closed.emit()


## Check if the field items interface is currently open
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
		# At root - close interface
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
		push_error("FieldItemInterfaceController: Failed to load screen '%s'" % screen_name)
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
		push_error("FieldItemInterfaceController: Unknown screen name '%s'" % screen_name)
		return null

	var path: String = SCREEN_PATHS[screen_name]

	# Check if file exists before loading
	if not ResourceLoader.exists(path):
		push_error("FieldItemInterfaceController: Screen scene not found at '%s'" % path)
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

## Update the header label
func update_header(text: String) -> void:
	if header_label:
		header_label.text = text


## Update the header/hint visibility based on current screen
## field_item_detail has its own header and hints, so hide parent's
func _update_hint_for_screen(screen_name: String) -> void:
	# field_item_detail has its own header (character name) and hints
	var hide_parent_ui: bool = (screen_name == "field_item_detail")

	if header_label:
		header_label.visible = not hide_parent_ui

	if not hint_label:
		return

	if hide_parent_ui:
		hint_label.visible = false
		return

	hint_label.visible = true
	hint_label.text = "A: Select | B: Close"


# =============================================================================
# INPUT BLOCKING
# =============================================================================

## Block input during transitions (future use)
func _set_input_blocked(blocked: bool) -> void:
	if input_blocker:
		input_blocker.visible = blocked
