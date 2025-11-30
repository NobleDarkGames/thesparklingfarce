## TurnOrderPanel - Shows upcoming unit turns in the AGI-based queue
##
## Displays current unit + next 2 units in turn order with faction color bars.
## Authentic to Shining Force 2's individual turn system (no phases).
##
## Connected to TurnManager signals for automatic updates.
class_name TurnOrderPanel
extends PanelContainer

## Faction colors for the indicator bars
const COLOR_ALLY: Color = Color(0.3, 0.6, 1.0, 1.0)  # Blue
const COLOR_ENEMY: Color = Color(1.0, 0.3, 0.3, 1.0)  # Red
const COLOR_NEUTRAL: Color = Color(1.0, 0.9, 0.3, 1.0)  # Yellow

## Brightness levels for visual hierarchy
const BRIGHTNESS_CURRENT: float = 1.0
const BRIGHTNESS_NEXT: float = 0.75
const BRIGHTNESS_UPCOMING: float = 0.55

## Animation settings
const SLIDE_IN_DURATION: float = 0.3
const TRANSITION_DURATION: float = 0.2
const SLIDE_OFFSET: float = -120.0  # Slides in from left

## UI node references (set up dynamically)
var _slots: Array[Control] = []
var _faction_bars: Array[ColorRect] = []
var _name_labels: Array[Label] = []

## State tracking
var _current_tween: Tween = null
var _is_initialized: bool = false


func _ready() -> void:
	# Start hidden (off-screen to the left)
	visible = false
	modulate.a = 1.0
	position.x = SLIDE_OFFSET

	# Build slot references after scene tree is ready
	call_deferred("_setup_slot_references")


## Set up references to child slot nodes
func _setup_slot_references() -> void:
	var vbox: VBoxContainer = $MarginContainer/VBoxContainer
	if not vbox:
		push_error("TurnOrderPanel: Missing VBoxContainer")
		return

	# Iterate through slot containers
	for i in range(3):
		var slot_name: String = "Slot%d" % i
		var slot: HBoxContainer = vbox.get_node_or_null(slot_name)
		if not slot:
			push_warning("TurnOrderPanel: Missing %s" % slot_name)
			continue

		_slots.append(slot)

		# Get faction bar and name label from slot
		var faction_bar: ColorRect = slot.get_node_or_null("FactionBar")
		var name_label: Label = slot.get_node_or_null("NameLabel")

		if faction_bar:
			_faction_bars.append(faction_bar)
		if name_label:
			_name_labels.append(name_label)

	_is_initialized = true


## Show the panel with slide-in animation (called on battle start)
func show_panel() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	visible = true
	position.x = SLIDE_OFFSET
	modulate.a = 1.0

	var duration: float = GameJuice.get_adjusted_duration(SLIDE_IN_DURATION)
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position:x", 0.0, duration)
	_current_tween.set_ease(Tween.EASE_OUT)
	_current_tween.set_trans(Tween.TRANS_CUBIC)


## Hide the panel with slide-out animation
func hide_panel() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	if not visible:
		return

	var duration: float = GameJuice.get_adjusted_duration(SLIDE_IN_DURATION)
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position:x", SLIDE_OFFSET, duration)
	_current_tween.set_ease(Tween.EASE_IN)
	_current_tween.set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_callback(func() -> void: visible = false)


## Update the turn order display
## active_unit: Currently acting unit
## upcoming_queue: Remaining units in turn queue (after active_unit)
func update_turn_order(active_unit: Node2D, upcoming_queue: Array[Node2D]) -> void:
	if not _is_initialized:
		call_deferred("update_turn_order", active_unit, upcoming_queue)
		return

	# Build display list: current + next 2
	var display_units: Array[Node2D] = []
	if active_unit:
		display_units.append(active_unit)

	# Add up to 2 more from upcoming queue
	var added: int = 0
	for unit in upcoming_queue:
		if added >= 2:
			break
		if unit and unit.is_alive():
			display_units.append(unit)
			added += 1

	# Update each slot
	for i in range(3):
		if i >= _slots.size():
			continue

		var slot: Control = _slots[i]

		if i < display_units.size():
			var unit: Node2D = display_units[i]
			_update_slot(i, unit, i == 0)
			slot.visible = true
		else:
			# No unit for this slot - hide it
			slot.visible = false


## Update a single slot with unit info
func _update_slot(slot_index: int, unit: Node2D, is_current: bool) -> void:
	if slot_index >= _faction_bars.size() or slot_index >= _name_labels.size():
		return

	var faction_bar: ColorRect = _faction_bars[slot_index]
	var name_label: Label = _name_labels[slot_index]

	# Set faction color
	var faction_color: Color = _get_faction_color(unit)
	faction_bar.color = faction_color

	# Set unit name (truncate if too long)
	var display_name: String = unit.get_display_name()
	if display_name.length() > 10:
		display_name = display_name.left(9) + "."
	name_label.text = display_name

	# Apply brightness based on position in queue
	var brightness: float
	match slot_index:
		0:
			brightness = BRIGHTNESS_CURRENT
		1:
			brightness = BRIGHTNESS_NEXT
		_:
			brightness = BRIGHTNESS_UPCOMING

	# Apply brightness to both faction bar and label
	faction_bar.modulate.a = brightness
	name_label.modulate = Color(brightness, brightness, brightness, 1.0)


## Get the faction color for a unit
func _get_faction_color(unit: Node2D) -> Color:
	if not unit:
		return COLOR_NEUTRAL

	if unit.has_method("is_player_unit") and unit.is_player_unit():
		return COLOR_ALLY
	elif unit.has_method("is_enemy_unit") and unit.is_enemy_unit():
		return COLOR_ENEMY
	else:
		return COLOR_NEUTRAL


## Animate a smooth transition when turn order changes
func animate_transition() -> void:
	if not _is_initialized:
		return

	# Quick fade out/in to emphasize the change
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	var duration: float = GameJuice.get_adjusted_duration(TRANSITION_DURATION)
	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 0.7, duration * 0.3)
	_current_tween.tween_property(self, "modulate:a", 1.0, duration * 0.7)
