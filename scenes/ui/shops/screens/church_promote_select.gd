extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## ChurchPromoteSelect - Promotion path selection for church promotion service
##
## Shows available promotion paths for the selected character.
## If only one path exists, executes promotion immediately.
## Otherwise, lets player choose their path.

var path_buttons: Array[Button] = []
var selected_index: int = 0
var _available_paths: Array[Dictionary] = []

@onready var header_label: Label = %HeaderLabel
@onready var path_grid: GridContainer = %PathGrid
@onready var back_button: Button = %BackButton


func _on_initialized() -> void:
	var character_uid: String = context.selected_destination
	_available_paths = _get_promotion_paths(character_uid)

	# If only one path, execute immediately (SF2 behavior)
	if _available_paths.size() == 1:
		_execute_promotion(_available_paths[0].target_class)
		return

	_update_header()
	_populate_path_grid()

	back_button.pressed.connect(_on_back_pressed)

	await get_tree().process_frame
	if path_buttons.size() > 0:
		path_buttons[0].grab_focus()
		selected_index = 0
	else:
		back_button.grab_focus()


func _update_header() -> void:
	var char_name: String = get_character_name(context.selected_destination)
	header_label.text = "CHOOSE %s'S PATH" % char_name.to_upper()


func _get_promotion_paths(character_uid: String) -> Array[Dictionary]:
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
	if not save_data:
		return []

	var character: CharacterData = get_character_by_uid(character_uid)
	if not character:
		return []

	# Build temporary unit for PromotionManager query
	var unit: Unit = _build_unit_for_query(character, save_data)
	if not unit:
		return []

	var paths: Array[Dictionary] = PromotionManager.get_available_promotions_detailed(unit)
	unit.queue_free()

	return paths


## Build a temporary Unit for PromotionManager queries
func _build_unit_for_query(character: CharacterData, save_data: CharacterSaveData) -> Unit:
	var unit: Unit = Unit.new()
	unit.character_data = character

	var stats: UnitStats = UnitStats.new()
	stats.level = save_data.level
	stats.current_hp = save_data.current_hp
	stats.max_hp = save_data.max_hp
	stats.current_mp = save_data.current_mp
	stats.max_mp = save_data.max_mp
	stats.strength = save_data.strength
	stats.defense = save_data.defense
	stats.agility = save_data.agility
	stats.intelligence = save_data.intelligence
	stats.luck = save_data.luck
	stats.class_data = save_data.get_current_class(character)

	unit.stats = stats
	return unit


func _populate_path_grid() -> void:
	# Clear existing
	for child: Node in path_grid.get_children():
		child.queue_free()
	path_buttons.clear()

	var character_uid: String = context.selected_destination
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
	if not save_data:
		return

	var cost: int = save_data.level * 100
	var can_afford: bool = get_current_gold() >= cost

	for path_info: Dictionary in _available_paths:
		var target_class: ClassData = path_info.get("target_class") as ClassData
		if not target_class:
			continue

		var display_name: String = path_info.get("display_name", target_class.display_name)
		var is_available: bool = path_info.get("is_available", true)
		var required_item: ItemData = path_info.get("required_item") as ItemData

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(200, 60)
		button.focus_mode = Control.FOCUS_ALL

		# Build button text
		var lines: Array[String] = [display_name]
		if required_item:
			var item_note: String = "(Requires %s)" % required_item.item_name if not is_available else "(Uses %s)" % required_item.item_name
			lines.append(item_note)
		lines.append("%d G" % cost)
		button.text = "\n".join(lines)

		# Disable if can't afford or item requirement not met
		if not can_afford or not is_available:
			button.disabled = true
			button.add_theme_color_override("font_color", UIColors.MENU_DISABLED)

		path_grid.add_child(button)
		path_buttons.append(button)

		button.pressed.connect(_on_path_selected.bind(target_class))
		button.focus_entered.connect(_on_button_focus_entered.bind(button))
		button.focus_exited.connect(_on_button_focus_exited.bind(button))
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))


func _on_path_selected(target_class: ClassData) -> void:
	_execute_promotion(target_class)


func _execute_promotion(target_class: ClassData) -> void:
	var character_uid: String = context.selected_destination
	var character: CharacterData = get_character_by_uid(character_uid)
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)

	# Capture old class BEFORE promotion
	var old_class: ClassData = save_data.get_current_class(character) if save_data else null

	var result: Dictionary = ShopManager.church_promote(character_uid, target_class)

	if result.get("success", false):
		var char_name: String = get_character_name(character_uid)
		context.last_result = {
			"type": "promotion_complete",
			"success": true,
			"message": "%s has been promoted to %s!" % [char_name, target_class.display_name],
			"gold_spent": result.get("cost", 0),
			"character_uid": character_uid,
			"new_class": target_class,
			"stat_changes": result.get("stat_changes", {})
		}

		# Show promotion ceremony with captured old class
		_show_promotion_ceremony(character_uid, old_class, target_class, result.get("stat_changes", {}))
	else:
		context.last_result = {
			"success": false,
			"message": result.get("error", "Promotion failed")
		}
		push_screen("transaction_result")


func _show_promotion_ceremony(character_uid: String, old_class: ClassData, new_class: ClassData, stat_changes: Dictionary) -> void:
	var character: CharacterData = get_character_by_uid(character_uid)
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
	if not character or not save_data:
		push_screen("transaction_result")
		return

	# Build unit for ceremony display
	var unit: Unit = _build_unit_for_query(character, save_data)

	# Get or create ceremony
	var ceremony: PromotionCeremony = _get_or_create_ceremony()
	if not ceremony:
		push_screen("transaction_result")
		return

	# Add ceremony to tree if needed
	if not ceremony.is_inside_tree():
		get_tree().root.add_child(ceremony)

	# Connect dismissal signal and show ceremony
	ceremony.ceremony_dismissed.connect(_on_ceremony_dismissed, CONNECT_ONE_SHOT)
	await ceremony.show_promotion_with_stats(unit, old_class, new_class, stat_changes)
	
	# Guard: check if we're still valid after await
	if not is_instance_valid(self):
		if is_instance_valid(ceremony):
			ceremony.queue_free()
		return
	
	# CRITICAL: Remove ceremony from tree to stop blocking input
	ceremony.queue_free()


func _get_or_create_ceremony() -> PromotionCeremony:
	# Check if there's already one in the scene tree
	var existing: PromotionCeremony = get_tree().root.get_node_or_null("PromotionCeremony") as PromotionCeremony
	if existing:
		return existing

	# Try to load and instantiate
	var ceremony_scene: PackedScene = load("res://scenes/ui/promotion_ceremony.tscn") as PackedScene
	if ceremony_scene:
		return ceremony_scene.instantiate() as PromotionCeremony

	return null


func _on_ceremony_dismissed() -> void:
	# After ceremony, return to church action menu
	# The ceremony already showed the promotion success, so transaction_result is redundant
	go_back()
	go_back()  # Back past character select to church_action_select


func _on_button_focus_entered(btn: Button) -> void:
	selected_index = path_buttons.find(btn)
	_update_all_colors()


func _on_button_focus_exited(btn: Button) -> void:
	_update_all_colors()


func _on_button_mouse_entered(btn: Button) -> void:
	btn.grab_focus()


func _update_all_colors() -> void:
	for i: int in range(path_buttons.size()):
		var btn: Button = path_buttons[i]
		if btn.disabled:
			continue
		var is_focused: bool = i == selected_index and btn.has_focus()
		var color: Color = UIColors.MENU_SELECTED if is_focused else UIColors.MENU_NORMAL
		btn.add_theme_color_override("font_color", color)


func _on_back_pressed() -> void:
	go_back()


func _on_screen_exit() -> void:
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)
	path_buttons.clear()
