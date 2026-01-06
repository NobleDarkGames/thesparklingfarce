@tool
class_name NPCPreviewPanel
extends PanelContainer

## Live preview panel for NPC Editor
## Shows portrait, sprite, name, and dialog preview in real-time

# UI References
var preview_portrait: TextureRect
var preview_sprite: TextureRect
var preview_name_label: Label
var preview_dialog_label: Label

# External data sources (set by parent editor)
var name_source: LineEdit
var dialog_source: TextEdit
var character_picker_source: ResourcePicker
var portrait_path_source: LineEdit
var sprite_path_source: LineEdit


func _init() -> void:
	_setup_ui()


func _setup_ui() -> void:
	custom_minimum_size = Vector2(200, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.18)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", panel_style)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	# Title
	var title: Label = Label.new()
	title.text = "Preview"
	title.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	# Portrait preview section
	_add_portrait_section(content)

	# Sprite preview section
	_add_sprite_section(content)

	# Name preview section
	_add_name_section(content)

	# Dialog preview section
	_add_dialog_section(content)

	add_child(content)


func _add_portrait_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var label: Label = Label.new()
	label.text = "Portrait"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	section.add_child(label)

	var container: CenterContainer = CenterContainer.new()
	container.custom_minimum_size = Vector2(0, 80)

	preview_portrait = TextureRect.new()
	preview_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_portrait.custom_minimum_size = Vector2(64, 64)
	preview_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	container.add_child(preview_portrait)

	section.add_child(container)
	parent.add_child(section)


func _add_sprite_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var label: Label = Label.new()
	label.text = "Map Sprite"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	section.add_child(label)

	var container: CenterContainer = CenterContainer.new()
	container.custom_minimum_size = Vector2(0, 48)

	preview_sprite = TextureRect.new()
	preview_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_sprite.custom_minimum_size = Vector2(32, 32)
	preview_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # Pixel-perfect
	container.add_child(preview_sprite)

	section.add_child(container)
	parent.add_child(section)


func _add_name_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var label: Label = Label.new()
	label.text = "Display Name"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	section.add_child(label)

	preview_name_label = Label.new()
	preview_name_label.text = "(not set)"
	preview_name_label.add_theme_font_size_override("font_size", 14)
	preview_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(preview_name_label)

	parent.add_child(section)


func _add_dialog_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var label: Label = Label.new()
	label.text = "Dialog Preview"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	section.add_child(label)

	var dialog_box: PanelContainer = PanelContainer.new()
	var dialog_style: StyleBoxFlat = StyleBoxFlat.new()
	dialog_style.bg_color = Color(0.1, 0.1, 0.12)
	dialog_style.corner_radius_top_left = 4
	dialog_style.corner_radius_top_right = 4
	dialog_style.corner_radius_bottom_left = 4
	dialog_style.corner_radius_bottom_right = 4
	dialog_style.content_margin_left = 8
	dialog_style.content_margin_right = 8
	dialog_style.content_margin_top = 8
	dialog_style.content_margin_bottom = 8
	dialog_box.add_theme_stylebox_override("panel", dialog_style)

	preview_dialog_label = Label.new()
	preview_dialog_label.text = "(enter dialog text)"
	preview_dialog_label.add_theme_font_size_override("font_size", 11)
	preview_dialog_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	preview_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_dialog_label.custom_minimum_size.y = 60
	dialog_box.add_child(preview_dialog_label)

	section.add_child(dialog_box)
	parent.add_child(section)


## Connect to external UI controls for data binding
func bind_sources(
	p_name_source: LineEdit,
	p_dialog_source: TextEdit,
	p_character_picker: ResourcePicker,
	p_portrait_path: LineEdit,
	p_sprite_path: LineEdit
) -> void:
	name_source = p_name_source
	dialog_source = p_dialog_source
	character_picker_source = p_character_picker
	portrait_path_source = p_portrait_path
	sprite_path_source = p_sprite_path


## Update the preview panel with current data from bound sources
func update_preview() -> void:
	_update_name_preview()
	_update_dialog_preview()
	_update_portrait_preview()
	_update_sprite_preview()


func _update_name_preview() -> void:
	if not preview_name_label:
		return

	var name_text: String = ""
	if is_instance_valid(name_source):
		name_text = name_source.text.strip_edges()

	if name_text.is_empty():
		preview_name_label.text = "(not set)"
		preview_name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		preview_name_label.text = name_text
		preview_name_label.add_theme_color_override("font_color", Color(1, 1, 1))


func _update_dialog_preview() -> void:
	if not preview_dialog_label:
		return

	var dialog_text: String = ""
	if is_instance_valid(dialog_source):
		dialog_text = dialog_source.text.strip_edges()

	if dialog_text.is_empty():
		preview_dialog_label.text = "(enter dialog text)"
		preview_dialog_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		# Show first line or truncated preview
		var lines: PackedStringArray = dialog_text.split("\n")
		var preview_text: String = lines[0]
		if lines.size() > 1:
			preview_text += "\n..."
		preview_dialog_label.text = preview_text
		preview_dialog_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))


func _update_portrait_preview() -> void:
	if not preview_portrait:
		return

	var portrait_tex: Texture2D = null

	# Try character data first
	if is_instance_valid(character_picker_source) and character_picker_source.has_selection():
		var char_data: CharacterData = character_picker_source.get_selected_resource() as CharacterData
		if char_data and char_data.portrait:
			portrait_tex = char_data.portrait

	# Fall back to direct portrait path
	if not portrait_tex and is_instance_valid(portrait_path_source):
		var path: String = portrait_path_source.text.strip_edges()
		if not path.is_empty() and ResourceLoader.exists(path):
			portrait_tex = load(path) as Texture2D

	preview_portrait.texture = portrait_tex


func _update_sprite_preview() -> void:
	if not preview_sprite:
		return

	var sprite_tex: Texture2D = null

	# Try character data first
	if is_instance_valid(character_picker_source) and character_picker_source.has_selection():
		var char_data: CharacterData = character_picker_source.get_selected_resource() as CharacterData
		if char_data and char_data.map_sprite:
			sprite_tex = char_data.map_sprite

	# Fall back to direct sprite path
	if not sprite_tex and is_instance_valid(sprite_path_source):
		var path: String = sprite_path_source.text.strip_edges()
		if not path.is_empty() and ResourceLoader.exists(path):
			sprite_tex = load(path) as Texture2D

	preview_sprite.texture = sprite_tex
