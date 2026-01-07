@tool
extends Control

## Main editor panel for The Sparkling Farce content editor
## Uses EditorTabRegistry for decoupled tab management
##
## Benefits of registry-based approach:
## - Adding new editors doesn't require modifying this file
## - Consistent refresh interface across all tabs
## - Tabs automatically sorted by category and priority
## - Mod-provided tabs use the same system as built-in tabs

# Editor settings persistence
const EDITOR_SETTINGS_PATH: String = "user://sparkling_editor_settings.json"

# Registry for tab management
var tab_registry: EditorTabRegistry

# Core UI components
var tab_container: TabContainer
var mod_selector: OptionButton
var mod_info_label: Label

# Two-tier category navigation
var category_bar: HBoxContainer
var category_buttons: Dictionary = {}  # category_id -> Button
var current_category: String = "content"  # Default to Content category

# Mod Creation Wizard
var create_mod_dialog: ConfirmationDialog
var wizard_mod_id_edit: LineEdit
var wizard_mod_name_edit: LineEdit
var wizard_author_edit: LineEdit
var wizard_description_edit: TextEdit
var wizard_type_dropdown: OptionButton
var wizard_error_label: Label


func _init() -> void:
	# Editor plugins don't reliably call _ready, so we use _init with deferred setup
	call_deferred("_setup_ui")


func _ready() -> void:
	pass


func _setup_ui() -> void:
	# Get the TabContainer from the scene
	tab_container = get_node("TabContainer")

	if not tab_container:
		push_error("TabContainer not found in scene!")
		return

	# Set minimum width to prevent extreme collapse, but allow laptop-friendly widths
	custom_minimum_size = Vector2(600, 0)

	# Configure TabContainer positioning (leave space for mod selector + category bar)
	tab_container.anchor_bottom = 1.0
	tab_container.offset_top = 80  # 40 for mod selector + 40 for category bar
	tab_container.offset_bottom = 0

	# Add mod selector UI at the top
	_create_mod_selector_ui()

	# Make tabs more visible with custom theme overrides
	tab_container.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	tab_container.add_theme_constant_override("side_margin", 10)

	# Initialize the tab registry and create tabs
	_initialize_tab_registry()

	# Create category bar after tabs are registered (needs category info)
	_create_category_bar()


# =============================================================================
# TAB REGISTRY INTEGRATION
# =============================================================================

func _initialize_tab_registry() -> void:
	## Initialize the EditorTabRegistry and create all tabs
	tab_registry = EditorTabRegistry.new()

	# Register built-in tabs
	tab_registry.register_builtin_tabs()

	# Register mod-provided tabs
	_register_mod_editor_extensions()

	# Create all tabs in sorted order
	_create_tabs_from_registry()


func _register_mod_editor_extensions() -> void:
	## Discover and register editor extensions from all mods
	if not ModLoader:
		return

	var mods: Array[ModManifest] = ModLoader.get_all_mods()

	for mod: ModManifest in mods:
		if mod.editor_extensions.is_empty():
			continue

		for ext_id: String in mod.editor_extensions.keys():
			var ext_config: Dictionary = mod.editor_extensions[ext_id]
			tab_registry.register_mod_tab(mod.mod_id, ext_id, ext_config, mod.mod_directory)


func _create_tabs_from_registry() -> void:
	## Create all tabs from the registry in sorted order
	var tabs: Array[Dictionary] = tab_registry.get_all_tabs_sorted()

	for tab_info: Dictionary in tabs:
		_create_tab_from_info(tab_info)


func _create_tab_from_info(tab_info: Dictionary) -> void:
	## Create a single tab from registry info
	var tab_id: String = DictUtils.get_string(tab_info, "id", "")
	var display_name: String = DictUtils.get_string(tab_info, "display_name", tab_id.capitalize())
	var scene_path: String = DictUtils.get_string(tab_info, "scene_path", "")
	var is_static: bool = DictUtils.get_bool(tab_info, "is_static", false)

	var tab_control: Control

	if is_static:
		# Static tabs are created programmatically (e.g., Overview)
		tab_control = _create_static_tab(tab_id)
	else:
		# Load and instantiate scene
		if scene_path.is_empty():
			push_warning("Tab '%s' has no scene_path" % tab_id)
			return

		if not ResourceLoader.exists(scene_path):
			push_warning("Tab '%s' scene not found: %s" % [tab_id, scene_path])
			return

		var scene: PackedScene = load(scene_path)
		if not scene:
			push_error("Failed to load tab scene: " + scene_path)
			return

		tab_control = scene.instantiate()
		if not tab_control:
			push_error("Failed to instantiate tab: " + scene_path)
			return

	if tab_control:
		tab_control.name = display_name
		tab_container.add_child(tab_control)
		tab_registry.set_instance(tab_id, tab_control)


func _create_static_tab(tab_id: String) -> Control:
	## Create static tabs that don't have scene files
	match tab_id:
		"overview":
			return _create_overview_content()
		_:
			push_warning("Unknown static tab: " + tab_id)
			return null


func _create_overview_content() -> Control:
	## Create the Overview tab content
	var overview: VBoxContainer = VBoxContainer.new()

	var title: Label = Label.new()
	title.text = "The Sparkling Farce - Content Editor"
	title.add_theme_font_size_override("font_size", 24)
	overview.add_child(title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var description: RichTextLabel = RichTextLabel.new()
	description.bbcode_enabled = true
	description.text = """[b]Welcome to the Sparkling Editor![/b]

This editor allows you to create content for your tactical RPG game without writing code.

[b]Quick Start:[/b]
• Use the tabs above to browse and edit different types of content
• Use the Tools menu to create new characters, classes, items, and abilities
• All content is saved in the data/ folder as .tres Resource files
• You can also edit Resources directly in the Godot Inspector

[b]Content Types:[/b]
• [b]Characters:[/b] Create playable units and enemies with stats and equipment
• [b]Classes:[/b] Define character classes with movement and abilities
• [b]Items:[/b] Create weapons, accessories, and consumable items
• [b]Abilities:[/b] Define skills and spells for combat
• [b]Parties:[/b] Create and manage party compositions for battles
• [b]Battles:[/b] Configure tactical battle scenarios with enemies and objectives
• [b]Maps:[/b] Configure map metadata and connections
• [b]Cinematics:[/b] Create cutscenes and narrative sequences with dialog

[b]Next Steps:[/b]
1. Create some classes first (they're required for characters)
2. Create abilities that classes can learn
3. Create characters and assign them classes
4. Create items for characters to equip

For more information, check the documentation in the user_content folder."""
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.fit_content = true

	scroll.add_child(description)
	overview.add_child(scroll)

	return overview


func _refresh_all_editors() -> void:
	## Refresh all editor tabs using the registry
	## NOTE: This refreshes ALL tabs regardless of current category to ensure data sync
	if tab_registry:
		tab_registry.refresh_all()


# =============================================================================
# TWO-TIER CATEGORY NAVIGATION
# =============================================================================

func _create_category_bar() -> void:
	## Create the primary category bar for two-tier navigation
	var category_panel: PanelContainer = PanelContainer.new()
	category_panel.name = "CategoryBarPanel"
	category_panel.anchor_right = 1.0
	category_panel.offset_top = 40  # Below mod selector
	category_panel.offset_bottom = 80
	category_panel.size_flags_horizontal = Control.SIZE_FILL

	# Insert after mod selector panel
	var mod_panel: Control = get_node_or_null("ModSelectorPanel")
	if mod_panel:
		add_child(category_panel)
		move_child(category_panel, mod_panel.get_index() + 1)
	else:
		add_child(category_panel)

	category_bar = HBoxContainer.new()
	category_bar.add_theme_constant_override("separation", 4)
	category_panel.add_child(category_bar)

	# Load persisted category selection
	current_category = _load_last_selected_category()

	# Create category buttons
	_rebuild_category_buttons()

	# Apply initial category filter
	_apply_category_filter()


func _rebuild_category_buttons() -> void:
	## Rebuild category buttons based on registered tabs
	# Clear existing buttons
	for child: Node in category_bar.get_children():
		child.queue_free()
	category_buttons.clear()

	# Get categories that have tabs
	var categories: Array[String] = tab_registry.get_active_categories()

	for category: String in categories:
		var button: Button = Button.new()
		button.text = tab_registry.get_category_display_name(category)
		button.toggle_mode = true
		button.button_pressed = (category == current_category)
		button.pressed.connect(_on_category_button_pressed.bind(category))
		button.add_theme_font_size_override("font_size", 14)
		button.custom_minimum_size = Vector2(80, 0)

		category_bar.add_child(button)
		category_buttons[category] = button

	# Validate current_category exists
	if current_category not in categories and not categories.is_empty():
		current_category = categories[0]
		if current_category in category_buttons:
			category_buttons[current_category].button_pressed = true


func _on_category_button_pressed(category: String) -> void:
	## Handle category button press
	if category == current_category:
		# Don't allow deselection - keep current category selected
		if category in category_buttons:
			category_buttons[category].button_pressed = true
		return

	# Update button states
	for cat: String in category_buttons.keys():
		category_buttons[cat].button_pressed = (cat == category)

	current_category = category
	_save_last_selected_category(category)
	_apply_category_filter()


func _apply_category_filter() -> void:
	## Show only tabs that belong to the current category
	if not tab_container or not tab_registry:
		return

	var first_visible_index: int = -1
	var tab_count: int = tab_container.get_tab_count()

	for i: int in range(tab_count):
		var tab_control: Control = tab_container.get_tab_control(i)
		if not tab_control:
			continue

		# Find the tab's category
		var tab_category: String = _get_tab_category_by_control(tab_control)
		var should_show: bool = (tab_category == current_category)

		tab_container.set_tab_hidden(i, not should_show)

		if should_show and first_visible_index < 0:
			first_visible_index = i

	# Select first visible tab if current selection is hidden
	if first_visible_index >= 0:
		var current_tab: int = tab_container.current_tab
		if current_tab < 0 or tab_container.is_tab_hidden(current_tab):
			tab_container.current_tab = first_visible_index


func _get_tab_category_by_control(tab_control: Control) -> String:
	## Get the category of a tab by its Control instance
	for tab_id: String in tab_registry.get_all_tab_ids():
		var instance: Control = tab_registry.get_instance(tab_id)
		if instance == tab_control:
			var tab_info: Dictionary = tab_registry.get_tab(tab_id)
			return DictUtils.get_string(tab_info, "category", "content")
	return "content"


func _save_last_selected_category(category: String) -> void:
	var settings: Dictionary = _load_editor_settings()
	settings["last_selected_category"] = category
	_save_editor_settings(settings)


func _load_last_selected_category() -> String:
	var settings: Dictionary = _load_editor_settings()
	return DictUtils.get_string(settings, "last_selected_category", "content")


func _reload_mod_tabs() -> void:
	## Reload mod-provided tabs (called after mod reload)
	if not tab_registry:
		return

	# Clear existing mod tabs from registry and UI
	var mod_tab_ids: Array[String] = []
	for tab_id: String in tab_registry.get_all_tab_ids():
		if not tab_registry.get_source_mod(tab_id).is_empty():
			mod_tab_ids.append(tab_id)

	# Remove mod tabs from UI
	for tab_id: String in mod_tab_ids:
		var instance: Control = tab_registry.get_instance(tab_id)
		if instance and is_instance_valid(instance):
			instance.queue_free()

	# Clear mod registrations
	tab_registry.clear_mod_registrations()

	# Re-register mod tabs
	_register_mod_editor_extensions()

	# Create newly registered mod tabs
	var tabs: Array[Dictionary] = tab_registry.get_all_tabs_sorted()
	for tab_info: Dictionary in tabs:
		var tab_id: String = DictUtils.get_string(tab_info, "id", "")
		if not tab_registry.get_source_mod(tab_id).is_empty():
			if not tab_registry.has_instance(tab_id):
				_create_tab_from_info(tab_info)

	# Rebuild category buttons (Mods category may have appeared/disappeared)
	_rebuild_category_buttons()
	_apply_category_filter()


# =============================================================================
# MOD SELECTOR UI
# =============================================================================

func _create_mod_selector_ui() -> void:
	var mod_panel: PanelContainer = PanelContainer.new()
	mod_panel.name = "ModSelectorPanel"
	mod_panel.anchor_right = 1.0
	mod_panel.offset_bottom = 40
	mod_panel.size_flags_horizontal = Control.SIZE_FILL

	var tab_index: int = tab_container.get_index()
	add_child(mod_panel)
	move_child(mod_panel, tab_index)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	mod_panel.add_child(hbox)

	var label: Label = Label.new()
	label.text = "Active Mod:"
	label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	hbox.add_child(label)

	mod_selector = OptionButton.new()
	mod_selector.custom_minimum_size = Vector2(200, 0)
	mod_selector.item_selected.connect(_on_mod_selected)
	hbox.add_child(mod_selector)

	mod_info_label = Label.new()
	mod_info_label.add_theme_color_override("font_color", SparklingEditorUtils.get_disabled_color())
	mod_info_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	mod_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(mod_info_label)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh Mods"
	refresh_button.pressed.connect(_on_refresh_mods)
	hbox.add_child(refresh_button)

	var create_mod_button: Button = Button.new()
	create_mod_button.text = "Create New Mod"
	create_mod_button.tooltip_text = "Create a new mod with folder structure and mod.json"
	create_mod_button.pressed.connect(_show_create_mod_wizard)
	hbox.add_child(create_mod_button)

	_refresh_mod_list()


func _refresh_mod_list() -> void:
	if not mod_selector:
		return

	mod_selector.clear()

	if not ModLoader:
		push_warning("ModLoader not available")
		return

	var mods: Array[ModManifest] = ModLoader.get_all_mods()
	var active_index: int = 0

	var persisted_mod_id: String = _load_last_selected_mod()
	var target_mod_id: String = ""

	if not persisted_mod_id.is_empty() and ModLoader.get_mod(persisted_mod_id):
		target_mod_id = persisted_mod_id
	else:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			target_mod_id = active_mod.mod_id

	for i: int in range(mods.size()):
		var mod: ModManifest = mods[i]
		mod_selector.add_item(mod.mod_name, i)
		mod_selector.set_item_metadata(i, mod.mod_id)

		if mod.mod_id == target_mod_id:
			active_index = i

	if mods.size() > 0:
		mod_selector.select(active_index)
		_update_mod_info(active_index)

		var selected_mod_id: String = mod_selector.get_item_metadata(active_index)
		if ModLoader.get_active_mod() == null or ModLoader.get_active_mod().mod_id != selected_mod_id:
			ModLoader.set_active_mod(selected_mod_id)


func _on_mod_selected(index: int) -> void:
	var mod_id: String = mod_selector.get_item_metadata(index)

	if ModLoader and ModLoader.set_active_mod(mod_id):
		_save_last_selected_mod(mod_id)

		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			event_bus.active_mod_changed.emit(mod_id)

		_update_mod_info(index)
		_refresh_all_editors()
	else:
		push_error("Failed to set active mod: " + mod_id)


func _update_mod_info(index: int) -> void:
	if not mod_info_label or not mod_selector:
		return

	var mod_id: String = mod_selector.get_item_metadata(index)
	var mod: ModManifest = ModLoader.get_mod(mod_id)

	if mod:
		mod_info_label.text = "v%s by %s | Priority: %d" % [mod.version, mod.author, mod.load_priority]
	else:
		mod_info_label.text = ""


func _on_refresh_mods() -> void:
	if ModLoader:
		ModLoader.reload_mods()

		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			event_bus.mods_reloaded.emit()

		_refresh_mod_list()
		_reload_mod_tabs()
		_refresh_all_editors()


func get_active_mod_path() -> String:
	if ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			return "res://mods/" + active_mod.mod_id + "/"
	return ""


# =============================================================================
# SETTINGS PERSISTENCE
# =============================================================================

func _save_last_selected_mod(mod_id: String) -> void:
	var settings: Dictionary = _load_editor_settings()
	settings["last_selected_mod"] = mod_id
	_save_editor_settings(settings)


func _load_last_selected_mod() -> String:
	var settings: Dictionary = _load_editor_settings()
	return DictUtils.get_string(settings, "last_selected_mod", "")


func _load_editor_settings() -> Dictionary:
	if not FileAccess.file_exists(EDITOR_SETTINGS_PATH):
		return {}

	var file: FileAccess = FileAccess.open(EDITOR_SETTINGS_PATH, FileAccess.READ)
	if not file:
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		return parsed

	return {}


func _save_editor_settings(settings: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(EDITOR_SETTINGS_PATH, FileAccess.WRITE)
	if not file:
		push_warning("Failed to save editor settings to: " + EDITOR_SETTINGS_PATH)
		return

	file.store_string(JSON.stringify(settings, "\t"))
	file.close()


# =============================================================================
# MOD CREATION WIZARD
# =============================================================================

func _show_create_mod_wizard() -> void:
	if not create_mod_dialog:
		_create_mod_wizard_dialog()

	wizard_mod_id_edit.text = ""
	wizard_mod_name_edit.text = ""
	wizard_author_edit.text = ""
	wizard_description_edit.text = ""
	wizard_type_dropdown.select(0)
	wizard_error_label.text = ""
	wizard_error_label.visible = false

	create_mod_dialog.popup_centered()


func _create_mod_wizard_dialog() -> void:
	create_mod_dialog = ConfirmationDialog.new()
	create_mod_dialog.title = "Create New Mod"
	create_mod_dialog.ok_button_text = "Create Mod"
	create_mod_dialog.min_size = Vector2(500, 400)
	create_mod_dialog.confirmed.connect(_on_create_mod_confirmed)
	add_child(create_mod_dialog)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	create_mod_dialog.add_child(vbox)

	var id_label: Label = Label.new()
	id_label.text = "Mod ID (folder name, no spaces):"
	vbox.add_child(id_label)

	wizard_mod_id_edit = LineEdit.new()
	wizard_mod_id_edit.placeholder_text = "my_awesome_mod"
	wizard_mod_id_edit.text_changed.connect(_on_wizard_mod_id_changed)
	vbox.add_child(wizard_mod_id_edit)

	var name_label: Label = Label.new()
	name_label.text = "Display Name:"
	vbox.add_child(name_label)

	wizard_mod_name_edit = LineEdit.new()
	wizard_mod_name_edit.placeholder_text = "My Awesome Mod"
	vbox.add_child(wizard_mod_name_edit)

	var author_label: Label = Label.new()
	author_label.text = "Author:"
	vbox.add_child(author_label)

	wizard_author_edit = LineEdit.new()
	wizard_author_edit.placeholder_text = "Your Name"
	vbox.add_child(wizard_author_edit)

	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	vbox.add_child(desc_label)

	wizard_description_edit = TextEdit.new()
	wizard_description_edit.placeholder_text = "A brief description of your mod..."
	wizard_description_edit.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(wizard_description_edit)

	var type_label: Label = Label.new()
	type_label.text = "Mod Type:"
	vbox.add_child(type_label)

	wizard_type_dropdown = OptionButton.new()
	wizard_type_dropdown.add_item("Content Expansion (Priority 100-199)")
	wizard_type_dropdown.set_item_metadata(0, {"priority": 100, "type": "expansion"})
	wizard_type_dropdown.add_item("Override Pack (Priority 500-899)")
	wizard_type_dropdown.set_item_metadata(1, {"priority": 500, "type": "override"})
	wizard_type_dropdown.add_item("Total Conversion (Priority 9000+)")
	wizard_type_dropdown.set_item_metadata(2, {"priority": 9000, "type": "total_conversion"})
	vbox.add_child(wizard_type_dropdown)

	var type_help: Label = Label.new()
	type_help.text = "Content Expansion: Adds new content alongside base game\n" + \
		"Override Pack: Replaces specific base game content\n" + \
		"Total Conversion: Completely replaces the base game"
	type_help.add_theme_color_override("font_color", SparklingEditorUtils.get_disabled_color())
	type_help.add_theme_font_size_override("font_size", 12)
	vbox.add_child(type_help)

	wizard_error_label = Label.new()
	wizard_error_label.add_theme_color_override("font_color", SparklingEditorUtils.get_error_color())
	wizard_error_label.visible = false
	vbox.add_child(wizard_error_label)


func _on_wizard_mod_id_changed(new_id: String) -> void:
	# Auto-generate display name from ID
	if wizard_mod_name_edit.text.is_empty() or _is_auto_generated_name(wizard_mod_name_edit.text):
		var words: PackedStringArray = new_id.split("_")
		var title_words: Array = []
		for word: String in words:
			if not word.is_empty():
				title_words.append(word.capitalize())
		wizard_mod_name_edit.text = " ".join(title_words)

	# Real-time validation feedback
	_validate_wizard_mod_id(new_id)


func _validate_wizard_mod_id(mod_id: String) -> bool:
	wizard_error_label.visible = false

	if mod_id.is_empty():
		return true  # Don't show error for empty (will catch on submit)

	if not _is_valid_mod_id(mod_id):
		_show_wizard_error("Mod ID must start with a letter (or _ for platform mods), followed by lowercase letters, numbers, or underscores")
		return false

	var mod_path: String = "res://mods/" + mod_id + "/"
	if DirAccess.dir_exists_absolute(mod_path):
		_show_wizard_error("A mod with ID '%s' already exists" % mod_id)
		return false

	return true


func _is_auto_generated_name(name: String) -> bool:
	var id: String = wizard_mod_id_edit.text
	var words: PackedStringArray = id.split("_")
	var title_words: Array = []
	for word: String in words:
		if not word.is_empty():
			title_words.append(word.capitalize())
	return name == " ".join(title_words)


func _on_create_mod_confirmed() -> void:
	var mod_id: String = wizard_mod_id_edit.text.strip_edges()
	var mod_name: String = wizard_mod_name_edit.text.strip_edges()
	var author: String = wizard_author_edit.text.strip_edges()
	var description: String = wizard_description_edit.text.strip_edges()
	var type_data_value: Variant = wizard_type_dropdown.get_item_metadata(wizard_type_dropdown.selected)
	var type_data: Dictionary = DictUtils.get_dict({"data": type_data_value}, "data", {})

	if mod_id.is_empty():
		_show_wizard_error("Mod ID is required")
		return

	if not _validate_wizard_mod_id(mod_id):
		return  # Error already shown by validation function

	if mod_name.is_empty():
		mod_name = mod_id.replace("_", " ").capitalize()

	var success: bool = _create_mod_structure(mod_id, mod_name, author, description, type_data)
	if success:
		if ModLoader:
			ModLoader.reload_mods()
			_refresh_mod_list()

			ModLoader.set_active_mod(mod_id)
			for i: int in range(mod_selector.item_count):
				if mod_selector.get_item_metadata(i) == mod_id:
					mod_selector.select(i)
					_on_mod_selected(i)
					break

			var event_bus: Node = get_node_or_null("/root/EditorEventBus")
			if event_bus:
				event_bus.active_mod_changed.emit(mod_id)

			_refresh_all_editors()

		create_mod_dialog.hide()
	else:
		_show_wizard_error("Failed to create mod folder structure")


func _is_valid_mod_id(mod_id: String) -> bool:
	var regex: RegEx = RegEx.new()
	# Allow underscore prefix for platform mods (e.g., _platform_defaults, _starter_kit)
	regex.compile("^_?[a-z][a-z0-9_]*$")
	return regex.search(mod_id) != null


func _show_wizard_error(message: String) -> void:
	wizard_error_label.text = message
	wizard_error_label.visible = true


func _create_mod_structure(mod_id: String, mod_name: String, author: String, description: String, type_data: Dictionary) -> bool:
	var mod_path: String = "res://mods/" + mod_id + "/"

	var err: Error = DirAccess.make_dir_recursive_absolute(mod_path)
	if err != OK:
		push_error("Failed to create mod directory: " + mod_path)
		return false

	var subdirs: Array = [
		"data/characters",
		"data/classes",
		"data/items",
		"data/abilities",
		"data/battles",
		"data/parties",
		"data/dialogues",
		"data/campaigns",
		"data/cinematics",
		"data/maps",
		"data/npcs",
		"data/interactables",
		"data/terrain",
		"data/new_game_configs",
		"data/status_effects",
		"data/experience_configs",
		"data/ai_behaviors",
		"data/shops",
		"data/crafting_recipes",
		"data/crafters",
		"data/caravans",
		"assets/portraits",
		"assets/sprites/map",
		"assets/sprites/battle",
		"assets/icons/items",
		"assets/icons/abilities",
		"assets/tilesets",
		"assets/music",
		"assets/sfx",
		"maps",
		"scenes",
		"tilesets",
		"triggers"
	]

	for subdir: String in subdirs:
		err = DirAccess.make_dir_recursive_absolute(mod_path + subdir)
		if err != OK:
			push_warning("Failed to create subdirectory: " + subdir)

	var mod_json: Dictionary = {
		"id": mod_id,
		"name": mod_name,
		"version": "1.0.0",
		"author": author if not author.is_empty() else "Unknown",
		"description": description if not description.is_empty() else "A new mod for The Sparkling Farce",
		"godot_version": "4.5",
		"load_priority": DictUtils.get_int(type_data, "priority", 100),
		"dependencies": []
	}

	var type_str: String = DictUtils.get_string(type_data, "type", "")
	if type_str == "total_conversion":
		mod_json["hidden_campaigns"] = ["_base_game:*"]
		mod_json["party_config"] = {"replaces_lower_priority": true}
	elif type_str == "override":
		mod_json["party_config"] = {"replaces_lower_priority": false}

	var json_path: String = mod_path + "mod.json"
	var file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create mod.json: " + json_path)
		return false

	file.store_string(JSON.stringify(mod_json, "\t"))
	file.close()

	# Create default NewGameConfigData so modders have a starting point
	_create_default_new_game_config(mod_path, mod_name)

	return true


## Create a default NewGameConfigData for a new mod
## This ensures modders don't have to manually create one to have their party used
func _create_default_new_game_config(mod_path: String, mod_name: String) -> void:
	var config_path: String = mod_path + "data/new_game_configs/default_config.tres"

	# Use preload to get the script reference
	var config_script = preload("res://core/resources/new_game_config_data.gd")
	var config: Resource = config_script.new()

	# Set default values
	config.config_id = "default"
	config.config_name = mod_name + " Default"
	config.config_description = "Default starting configuration for " + mod_name + ". Customize starting conditions here."
	config.is_default = true
	config.starting_campaign_id = ""
	config.starting_location_label = ""
	config.starting_gold = 0
	config.starting_depot_items = []
	config.starting_story_flags = {}
	config.starting_party_id = ""  # Empty = uses auto-detect from character flags
	config.caravan_unlocked = false

	var save_err: Error = ResourceSaver.save(config, config_path)
	if save_err != OK:
		push_warning("Failed to create default NewGameConfigData: " + error_string(save_err))
