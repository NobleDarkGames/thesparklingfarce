class_name CombatResultsPanel
extends CanvasLayer

## Combat Results Panel - Shows XP gains after each combat action
##
## Displays in Shining Force style:
## - Attacker's XP gain (damage/kill)
## - Formation XP for nearby allies
## - Brief, non-intrusive, dismissed with button press

signal results_dismissed

## Timing constants
const FADE_IN_DURATION: float = 0.15
const AUTO_DISMISS_DELAY: float = 2.5  ## Auto-dismiss if no input
const ENTRY_STAGGER: float = 0.08  ## Delay between each XP entry appearing

## Colors - use centralized UIColors class

## UI References
@onready var panel: PanelContainer = $Panel
@onready var entries_container: VBoxContainer = $Panel/MarginContainer/VBox/EntriesContainer
@onready var continue_label: Label = $Panel/MarginContainer/VBox/ContinueLabel

## State
var _can_dismiss: bool = false
var _auto_dismiss_timer: float = 0.0
var _combat_actions: Array[String] = []  ## Queued combat action text to display
var _xp_entries: Array[Dictionary] = []  ## Queued XP entries to display


func _ready() -> void:
	# Start hidden
	panel.modulate.a = 0.0
	continue_label.visible = false

	# Position at bottom-right of screen (SF style)
	layer = 90  ## Below level-up celebration (101) and victory/defeat (100)


func _process(delta: float) -> void:
	if _can_dismiss:
		_auto_dismiss_timer -= delta
		if _auto_dismiss_timer <= 0.0:
			_dismiss()


func _input(event: InputEvent) -> void:
	if not _can_dismiss:
		return

	# Block all input while visible
	get_viewport().set_input_as_handled()

	if event.is_action_pressed("sf_confirm") or event.is_action_pressed("sf_cancel"):
		AudioManager.play_sfx("ui_confirm", AudioManager.SFXCategory.UI)
		_dismiss()


## Queue a combat action to be shown (e.g., "Max hit with CHAOS BREAKER for 12 damage!")
## Call this for each combat phase, then call show_results()
func add_combat_action(action_text: String, is_critical: bool = false, is_miss: bool = false) -> void:
	# Store with metadata for coloring
	var entry: String = action_text
	if is_miss:
		entry = "MISS:" + action_text
	elif is_critical:
		entry = "CRIT:" + action_text
	_combat_actions.append(entry)


## Queue an XP entry to be shown
## Call this multiple times to add entries, then call show_results()
func add_xp_entry(unit_name: String, amount: int, source: String) -> void:
	_xp_entries.append({
		"name": unit_name,
		"amount": amount,
		"source": source
	})


## Show the combat results panel with all queued entries
func show_results() -> void:
	if _combat_actions.is_empty() and _xp_entries.is_empty():
		# Nothing to show, dismiss immediately
		results_dismissed.emit()
		return

	_can_dismiss = false
	_auto_dismiss_timer = AUTO_DISMISS_DELAY

	# Clear previous entries
	for child: Node in entries_container.get_children():
		child.queue_free()

	# Fade in panel
	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, FADE_IN_DURATION)
	await tween.finished

	# First: Display combat actions (attack/spell info)
	for action_entry: String in _combat_actions:
		var is_miss: bool = action_entry.begins_with("MISS:")
		var is_critical: bool = action_entry.begins_with("CRIT:")
		var display_text: String = action_entry
		if is_miss:
			display_text = action_entry.substr(5)  # Remove "MISS:" prefix
		elif is_critical:
			display_text = action_entry.substr(5)  # Remove "CRIT:" prefix

		var row: Label = _create_combat_action_row(display_text, is_critical, is_miss)
		row.modulate.a = 0.0
		entries_container.add_child(row)

		var row_tween: Tween = create_tween()
		row_tween.tween_property(row, "modulate:a", 1.0, 0.1)
		AudioManager.play_sfx("ui_select", AudioManager.SFXCategory.UI)

		await get_tree().create_timer(ENTRY_STAGGER).timeout

	# Clear combat actions queue
	_combat_actions.clear()

	# Second: Separate XP entries from formation entries for batching
	var combat_entries: Array[Dictionary] = []
	var formation_total: int = 0
	var formation_count: int = 0

	for entry: Dictionary in _xp_entries:
		var source: String = DictUtils.get_string(entry, "source", "")
		var amount: int = DictUtils.get_int(entry, "amount", 0)
		if source == "formation":
			formation_total += amount
			formation_count += 1
		else:
			combat_entries.append(entry)

	# Add XP entries with stagger (attacker's damage/kill XP)
	for entry: Dictionary in combat_entries:
		var entry_name: String = DictUtils.get_string(entry, "name", "")
		var entry_amount: int = DictUtils.get_int(entry, "amount", 0)
		var entry_source: String = DictUtils.get_string(entry, "source", "")
		var row: HBoxContainer = _create_xp_row(entry_name, entry_amount, entry_source)
		row.modulate.a = 0.0
		entries_container.add_child(row)

		var row_tween: Tween = create_tween()
		row_tween.tween_property(row, "modulate:a", 1.0, 0.1)
		AudioManager.play_sfx("ui_select", AudioManager.SFXCategory.UI)

		await get_tree().create_timer(ENTRY_STAGGER).timeout

	# Add batched formation entry if any allies received formation XP
	if formation_count > 0:
		var formation_text: String = "Formation Bonus"
		if formation_count > 1:
			formation_text = "Formation (%d allies)" % formation_count
		var row: HBoxContainer = _create_formation_batch_row(formation_text, formation_total)
		row.modulate.a = 0.0
		entries_container.add_child(row)

		var row_tween: Tween = create_tween()
		row_tween.tween_property(row, "modulate:a", 1.0, 0.1)
		AudioManager.play_sfx("ui_select", AudioManager.SFXCategory.UI)

		await get_tree().create_timer(ENTRY_STAGGER).timeout

	# Clear the XP queue
	_xp_entries.clear()

	# Show continue prompt and allow dismiss
	continue_label.visible = true
	_can_dismiss = true


## Create a combat action row (e.g., "Max hit with CHAOS BREAKER for 12 damage!")
func _create_combat_action_row(text: String, is_critical: bool, is_miss: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	UIUtils.apply_monogram_style(label, 16)

	# Color based on hit type
	if is_miss:
		label.add_theme_color_override("font_color", UIColors.TEXT_MISS)
	elif is_critical:
		label.add_theme_color_override("font_color", UIColors.TEXT_CRITICAL)
	else:
		label.add_theme_color_override("font_color", UIColors.TEXT_WHITE)

	return label


## Create a batched formation XP row
func _create_formation_batch_row(label_text: String, total_xp: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Label
	var name_label: Label = Label.new()
	name_label.text = label_text
	UIUtils.apply_monogram_style(name_label, 16)
	name_label.add_theme_color_override("font_color", UIColors.XP_FORMATION)
	name_label.custom_minimum_size.x = 160
	row.add_child(name_label)

	# XP amount
	var xp_label: Label = Label.new()
	xp_label.text = "+%d XP" % total_xp
	UIUtils.apply_monogram_style(xp_label, 16)
	xp_label.add_theme_color_override("font_color", UIColors.XP_FORMATION)
	row.add_child(xp_label)

	return row


## Create a single XP entry row
func _create_xp_row(unit_name: String, amount: int, source: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Unit name
	var name_label: Label = Label.new()
	name_label.text = unit_name
	UIUtils.apply_monogram_style(name_label, 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.custom_minimum_size.x = 120
	row.add_child(name_label)

	# XP amount
	var xp_label: Label = Label.new()
	xp_label.text = "+%d XP" % amount
	UIUtils.apply_monogram_style(xp_label, 16)
	xp_label.custom_minimum_size.x = 60
	row.add_child(xp_label)

	# Source label with color
	var source_label: Label = Label.new()
	var source_text: String = ""
	var source_color: Color = Color.WHITE

	match source:
		"damage":
			source_text = "(Damage)"
			source_color = UIColors.XP_DAMAGE
			xp_label.add_theme_color_override("font_color", UIColors.XP_DAMAGE)
		"kill":
			source_text = "(Kill)"
			source_color = UIColors.XP_KILL
			xp_label.add_theme_color_override("font_color", UIColors.XP_KILL)
		"formation":
			source_text = "(Formation)"
			source_color = UIColors.XP_FORMATION
			xp_label.add_theme_color_override("font_color", UIColors.XP_FORMATION)
		_:
			source_text = "(%s)" % source.capitalize()
			source_color = Color.GRAY
			xp_label.add_theme_color_override("font_color", Color.GRAY)

	source_label.text = source_text
	UIUtils.apply_monogram_style(source_label, 16)
	source_label.add_theme_color_override("font_color", source_color)
	row.add_child(source_label)

	return row


func _dismiss() -> void:
	_can_dismiss = false

	# Fade out
	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	await tween.finished

	results_dismissed.emit()
