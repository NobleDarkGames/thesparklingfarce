extends "res://scenes/ui/shared/character_detail_base.gd"

## MemberDetail - Character equipment and inventory management (keyboard-first)
##
## Extends CharacterDetailBase with:
## - L/R character cycling support
## - EXPLORATION context for ItemActionMenu (includes GIVE action)
## - Give action handling that pushes to recipient selection

# =============================================================================
# UI REFERENCES (connect to scene nodes)
# =============================================================================

@onready var _header_label: Label = %HeaderLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _cycle_hint_label: Label = %CycleHintLabel
@onready var _equipment_list: VBoxContainer = %EquipmentList
@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _details_panel: PanelContainer = %DetailsPanel
@onready var _item_name_label: Label = %ItemNameLabel
@onready var _item_desc_label: Label = %ItemDescLabel
@onready var _result_label: Label = %ResultLabel
@onready var _back_button: Button = %BackButton


func _on_initialized() -> void:
	# Wire up UI references to base class
	header_label = _header_label
	stats_label = _stats_label
	cycle_hint_label = _cycle_hint_label
	equipment_list = _equipment_list
	inventory_list = _inventory_list
	details_panel = _details_panel
	item_name_label = _item_name_label
	item_desc_label = _item_desc_label
	result_label = _result_label
	back_button = _back_button

	# Call base initialization
	_on_initialized_base()


# =============================================================================
# OVERRIDES
# =============================================================================

func _get_action_menu_context() -> int:
	# EXPLORATION context (value 1) - includes GIVE action
	var ItemActionMenuClass: Script = load("res://scenes/ui/item_action_menu.gd")
	return ItemActionMenuClass.Context.EXPLORATION


func _supports_character_cycling() -> bool:
	return true


func _handle_give_action(item_id: String) -> void:
	# Enter GIVE mode and go to recipient selection
	if context:
		context.set_give_mode(character_uid, item_id)
	play_sfx("menu_select")
	push_screen("give_recipient_select")


func _on_back_focus_entered() -> void:
	focused_slot_id = ""
	focused_inventory_index = -1
	focused_item_id = ""
	_update_details_panel("", "Return to member list")
	play_sfx("cursor_move")


# =============================================================================
# L/R CHARACTER CYCLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Don't process L/R if a popup is open
	if _item_action_menu and _item_action_menu.is_menu_active():
		return

	# L/R bumpers - CRITICAL SF2 pattern for character cycling
	# Check if shoulder actions exist before using them (may not be mapped)
	var left_shoulder: bool = InputMap.has_action("sf_left_shoulder") and event.is_action_pressed("sf_left_shoulder")
	var right_shoulder: bool = InputMap.has_action("sf_right_shoulder") and event.is_action_pressed("sf_right_shoulder")

	if left_shoulder or event.is_action_pressed("ui_page_up"):
		_cycle_to_previous_member()
		get_viewport().set_input_as_handled()
	elif right_shoulder or event.is_action_pressed("ui_page_down"):
		_cycle_to_next_member()
		get_viewport().set_input_as_handled()
	else:
		# Let base class handle ui_cancel/sf_cancel for back navigation
		super._input(event)


func _cycle_to_previous_member() -> void:
	if get_party_size() <= 1:
		return
	cycle_member(-1)
	_refresh_character_display()
	play_sfx("cursor_move")


func _cycle_to_next_member() -> void:
	if get_party_size() <= 1:
		return
	cycle_member(1)
	_refresh_character_display()
	play_sfx("cursor_move")
