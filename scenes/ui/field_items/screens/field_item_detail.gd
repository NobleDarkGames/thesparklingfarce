extends "res://scenes/ui/shared/character_detail_base.gd"

## FieldItemDetail - Hero inventory view for field menu (SF2 authentic)
##
## Extends CharacterDetailBase with:
## - NO L/R character cycling (shows hero only)
## - FIELD_MENU context for ItemActionMenu (no GIVE action)
## - Simpler hints (no "L/R: Switch Character")

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
	# FIELD_MENU context (value 3) - NO GIVE action
	var ItemActionMenuClass: Script = load("res://scenes/ui/item_action_menu.gd")
	return ItemActionMenuClass.Context.FIELD_MENU


func _supports_character_cycling() -> bool:
	# SF2 authentic: field menu is hero only
	return false


func _handle_give_action(item_id: String) -> void:
	# Should never happen with FIELD_MENU context, but handle gracefully
	_show_result("Give is only available at the Caravan!", false)


func _on_back_focus_entered() -> void:
	focused_slot_id = ""
	focused_inventory_index = -1
	focused_item_id = ""
	_update_details_panel("", "Return to field menu")
	play_sfx("cursor_move")


# =============================================================================
# INPUT HANDLING (NO L/R CYCLING - SF2 AUTHENTIC)
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Don't process input if popup is open
	if _item_action_menu and _item_action_menu.is_menu_active():
		return

	# NO L/R character cycling - field menu is hero only (SF2 authentic)
	# Just handle cancel/back
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_on_back_requested()
		get_viewport().set_input_as_handled()


func _on_back_requested() -> void:
	go_back()
