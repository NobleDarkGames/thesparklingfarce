extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## ChurchPromoteSelect - Promotion path selection for church promotion service
##
## Shows available promotion paths for the selected character.
## If only one path exists, executes promotion immediately.
## Otherwise, lets player choose their path.

## Colors matching project standards
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)

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
	var character_uid: String = context.selected_destination
	var character: CharacterData = _get_character_data(character_uid)
	var char_name: String = character.character_name if character else "Character"
	header_label.text = "CHOOSE %s'S PATH" % char_name.to_upper()


func _get_character_data(character_uid: String) -> CharacterData:
	if not PartyManager:
		return null
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == character_uid:
			return character
	return null


func _get_promotion_paths(character_uid: String) -> Array[Dictionary]:
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
	if not save_data:
		return []

	var character: CharacterData = _get_character_data(character_uid)
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
	var can_afford: bool = _get_gold() >= cost

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
			button.add_theme_color_override("font_color", COLOR_DISABLED)

		path_grid.add_child(button)
		path_buttons.append(button)

		button.pressed.connect(_on_path_selected.bind(target_class))
		button.focus_entered.connect(_on_button_focus_entered.bind(button))
		button.focus_exited.connect(_on_button_focus_exited.bind(button))
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))


func _get_gold() -> int:
	if context and context.save_data:
		return context.save_data.gold
	return 0


func _on_path_selected(target_class: ClassData) -> void:
	_execute_promotion(target_class)


func _execute_promotion(target_class: ClassData) -> void:
	var character_uid: String = context.selected_destination
	var character: CharacterData = _get_character_data(character_uid)
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
	
	# Capture old class BEFORE promotion
	var old_class: ClassData = save_data.get_current_class(character) if save_data else null
	
	var result: Dictionary = ShopManager.church_promote(character_uid, target_class)

	if result.get("success", false):
		var char_name: String = character.character_name if character else "Character"

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
		print("[ChurchPromoteSelect] Promotion failed: %s" % result.get("error", "Unknown error"))
		# Go back to character select on failure
		go_back()


func _show_promotion_ceremony(character_uid: String, old_class: ClassData, new_class: ClassData, stat_changes: Dictionary) -> void:
	var character: CharacterData = _get_character_data(character_uid)
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
	# After ceremony, go to transaction result
	push_screen("transaction_result")


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
		if i == selected_index and btn.has_focus():
			btn.add_theme_color_override("font_color", COLOR_SELECTED)
		else:
			btn.add_theme_color_override("font_color", COLOR_NORMAL)


func _on_back_pressed() -> void:
	go_back()


func _on_screen_exit() -> void:
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)
	path_buttons.clear()
