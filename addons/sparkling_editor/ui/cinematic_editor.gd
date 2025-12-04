@tool
extends Control

## Cinematic Editor - Simple File Browser
## Lists cinematic JSON files and opens them in Godot's built-in code editor.
## This keeps things simple - JSON is human-readable and Godot's editor is excellent.

signal active_mod_changed(mod_id: String)
signal file_opened(path: String)

const DialogLinePopupScript: GDScript = preload("res://addons/sparkling_editor/ui/components/dialog_line_popup.gd")

# UI Components
var cinematic_list: ItemList
var refresh_button: Button
var create_button: Button
var edit_button: Button
var delete_button: Button
var add_dialog_button: Button
var help_label: RichTextLabel

# Popup for quick dialog line creation
var dialog_line_popup: Window

# Current state
var cinematics: Array[Dictionary] = []  # [{path: String, mod_id: String, name: String}]


func _ready() -> void:
	_setup_ui()
	_refresh_cinematic_list()


func _setup_ui() -> void:
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Header with buttons
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header)

	var title_label: Label = Label.new()
	title_label.text = "Cinematics"
	title_label.add_theme_font_size_override("font_size", 18)
	header.add_child(title_label)

	header.add_spacer(false)

	create_button = Button.new()
	create_button.text = "New"
	create_button.tooltip_text = "Create a new cinematic JSON file"
	create_button.pressed.connect(_on_create_pressed)
	header.add_child(create_button)

	refresh_button = Button.new()
	refresh_button.text = "Refresh"
	refresh_button.tooltip_text = "Refresh the cinematic list"
	refresh_button.pressed.connect(_refresh_cinematic_list)
	header.add_child(refresh_button)

	# File list
	cinematic_list = ItemList.new()
	cinematic_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cinematic_list.item_activated.connect(_on_item_activated)
	cinematic_list.item_selected.connect(_on_item_selected)
	cinematic_list.allow_reselect = true
	main_vbox.add_child(cinematic_list)

	# Action buttons row
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(action_row)

	edit_button = Button.new()
	edit_button.text = "Edit in Code Editor"
	edit_button.tooltip_text = "Open the selected cinematic in Godot's code editor"
	edit_button.pressed.connect(_on_edit_pressed)
	edit_button.disabled = true
	action_row.add_child(edit_button)

	# Quick Add Dialog Line button
	add_dialog_button = Button.new()
	add_dialog_button.text = "Quick Add Dialog"
	add_dialog_button.tooltip_text = "Create a dialog_line command with character picker, copies JSON to clipboard"
	add_dialog_button.pressed.connect(_on_add_dialog_pressed)
	action_row.add_child(add_dialog_button)

	action_row.add_spacer(false)

	delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.tooltip_text = "Delete the selected cinematic file"
	delete_button.pressed.connect(_on_delete_pressed)
	delete_button.disabled = true
	action_row.add_child(delete_button)

	# Help text
	help_label = RichTextLabel.new()
	help_label.bbcode_enabled = true
	help_label.fit_content = true
	help_label.scroll_active = false
	help_label.custom_minimum_size.y = 80
	help_label.text = _get_help_text()
	main_vbox.add_child(help_label)


func _get_help_text() -> String:
	return """[color=gray]Cinematics are JSON files that define sequences of commands:
dialog_line, move_entity, camera_shake, fade_screen, wait, etc.

[b]Quick Add Dialog[/b]: Select a character, type text, and copy formatted JSON to clipboard.
Double-click a cinematic to edit in Godot's code editor.[/color]"""


func _refresh_cinematic_list() -> void:
	cinematics.clear()
	cinematic_list.clear()

	# Scan all mods for cinematic JSON files
	var mods_dir: String = "res://mods/"
	var dir: DirAccess = DirAccess.open(mods_dir)
	if not dir:
		push_warning("CinematicEditor: Cannot open mods directory")
		return

	dir.list_dir_begin()
	var mod_name: String = dir.get_next()
	while mod_name != "":
		if dir.current_is_dir() and not mod_name.begins_with("."):
			_scan_mod_cinematics(mods_dir + mod_name)
		mod_name = dir.get_next()
	dir.list_dir_end()

	# Sort by mod + name
	cinematics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var key_a: String = a.mod_id + "/" + a.name
		var key_b: String = b.mod_id + "/" + b.name
		return key_a < key_b
	)

	# Populate list
	for entry: Dictionary in cinematics:
		var display_text: String = "[%s] %s" % [entry.mod_id, entry.name]
		cinematic_list.add_item(display_text)

	# Reset button states
	edit_button.disabled = true
	delete_button.disabled = true


func _scan_mod_cinematics(mod_path: String) -> void:
	var cinematics_path: String = mod_path + "/data/cinematics/"
	var dir: DirAccess = DirAccess.open(cinematics_path)
	if not dir:
		return

	var mod_id: String = mod_path.get_file()

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var entry: Dictionary = {
				"path": cinematics_path + file_name,
				"mod_id": mod_id,
				"name": file_name.get_basename()
			}
			cinematics.append(entry)
		file_name = dir.get_next()
	dir.list_dir_end()


func _on_item_selected(index: int) -> void:
	edit_button.disabled = false
	delete_button.disabled = false


func _on_item_activated(index: int) -> void:
	_open_in_editor(index)


func _on_edit_pressed() -> void:
	var selected: PackedInt32Array = cinematic_list.get_selected_items()
	if selected.is_empty():
		return
	_open_in_editor(selected[0])


func _on_add_dialog_pressed() -> void:
	# Create popup if needed
	if not dialog_line_popup:
		dialog_line_popup = DialogLinePopupScript.new()
		dialog_line_popup.dialog_created.connect(_on_dialog_line_created)
		add_child(dialog_line_popup)

	dialog_line_popup.show_popup()


func _on_dialog_line_created(json_text: String) -> void:
	# JSON is already copied to clipboard by the popup
	# Show a brief confirmation
	print("Dialog line JSON copied to clipboard - paste into your cinematic file")


func _open_in_editor(index: int) -> void:
	if index < 0 or index >= cinematics.size():
		return

	var entry: Dictionary = cinematics[index]
	_navigate_to_file(entry.path)
	file_opened.emit(entry.path)


## Navigate to a file in the FileSystem dock and select it
func _navigate_to_file(path: String) -> void:
	if not Engine.is_editor_hint():
		return

	# Navigate to the file in the FileSystem dock
	EditorInterface.get_file_system_dock().navigate_to_path(path)
	# Select the file so user can double-click to open in code editor
	EditorInterface.select_file(path)


func _on_create_pressed() -> void:
	# Create a new cinematic in the active mod
	var active_mod: String = _get_active_mod()
	if active_mod.is_empty():
		push_warning("CinematicEditor: No active mod selected")
		return

	# Generate unique name
	var base_name: String = "new_cinematic"
	var counter: int = 1
	var cinematics_dir: String = "res://mods/%s/data/cinematics/" % active_mod

	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute(cinematics_dir)

	var new_path: String = cinematics_dir + base_name + ".json"
	while FileAccess.file_exists(new_path):
		new_path = cinematics_dir + base_name + "_" + str(counter) + ".json"
		counter += 1

	# Create template
	var template: Dictionary = {
		"cinematic_id": new_path.get_file().get_basename(),
		"cinematic_name": "New Cinematic",
		"description": "Description here",
		"can_skip": true,
		"disable_player_input": true,
		"commands": [
			{
				"type": "fade_screen",
				"params": {
					"fade_type": "in",
					"duration": 1.0
				}
			},
			{
				"type": "dialog_line",
				"params": {
					"character_id": "CHARACTER_UID_HERE",
					"text": "Hello! This is example dialog.",
					"emotion": "neutral"
				}
			},
			{
				"type": "wait",
				"params": {
					"duration": 0.5
				}
			},
			{
				"type": "fade_screen",
				"params": {
					"fade_type": "out",
					"duration": 1.0
				}
			}
		]
	}

	# Write file
	var file: FileAccess = FileAccess.open(new_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(template, "  "))
		file.close()
		# Scan filesystem to pick up new file
		EditorInterface.get_resource_filesystem().scan()
		_refresh_cinematic_list()
		# Navigate to and select the new file
		_navigate_to_file(new_path)
	else:
		push_error("CinematicEditor: Failed to create file: %s" % new_path)


func _on_delete_pressed() -> void:
	var selected: PackedInt32Array = cinematic_list.get_selected_items()
	if selected.is_empty():
		return

	var index: int = selected[0]
	if index < 0 or index >= cinematics.size():
		return

	var entry: Dictionary = cinematics[index]
	var path: String = entry.path

	# Confirm deletion
	var confirm_dialog: ConfirmationDialog = ConfirmationDialog.new()
	confirm_dialog.title = "Delete Cinematic"
	confirm_dialog.dialog_text = "Delete '%s'?\n\nThis cannot be undone." % entry.name
	confirm_dialog.confirmed.connect(func() -> void:
		DirAccess.remove_absolute(path)
		_refresh_cinematic_list()
	)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()


func _get_active_mod() -> String:
	# Try to get from parent (main panel tracks active mod)
	var parent: Node = get_parent()
	while parent:
		if parent.has_method("get_active_mod_id"):
			return parent.get_active_mod_id()
		parent = parent.get_parent()

	# Fallback to _sandbox
	return "_sandbox"


## Called when active mod changes (from main panel)
func set_active_mod(mod_id: String) -> void:
	# Could filter to show only this mod's cinematics
	# For now, we show all mods with prefix
	pass


## Refresh when tab becomes visible
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_cinematic_list()
