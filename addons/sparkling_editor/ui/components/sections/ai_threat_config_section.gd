@tool
class_name AIThreatConfigSection
extends EditorSectionBase

## AI Threat Configuration section for Character Editor
## Manages threat modifier slider and threat tags for AI targeting

# UI Components
var threat_modifier_slider: HSlider
var threat_modifier_value_label: Label
var threat_tags_container: HFlowContainer
var custom_tag_edit: LineEdit
var add_tag_button: Button

# Current state
var _current_threat_tags: Array[String] = []

# Common threat tags with descriptions (for quick-add buttons)
const COMMON_THREAT_TAGS: Dictionary = {
	"priority_target": "AI focuses this unit first",
	"avoid": "AI ignores this unit when targeting",
	"vip": "High-value target for protection (non-boss)",
	"healer": "Explicitly marks as healer (usually auto-detected)",
	"tank": "Marks as a defensive unit"
}


func build_ui(parent: Control) -> void:
	create_collapse_section("AI Threat Configuration", true)
	parent.add_child(section_root)

	var content: VBoxContainer = get_content_container()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(content)
	form.on_change(mark_dirty)
	form.add_help_text("Advanced settings for AI targeting behavior")

	# Threat Modifier with slider and preset buttons
	_build_threat_modifier_ui(content)

	form.add_separator()

	# Threat Tags section
	_build_threat_tags_ui(content, form)


func _build_threat_modifier_ui(content: VBoxContainer) -> void:
	var modifier_container: VBoxContainer = VBoxContainer.new()

	# Header with label and value display
	var modifier_header: HBoxContainer = HBoxContainer.new()
	var modifier_label: Label = Label.new()
	modifier_label.text = "Threat Modifier:"
	modifier_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	modifier_label.tooltip_text = "Multiplier for AI threat calculations. Higher = AI prioritizes protecting/attacking this unit more."
	modifier_header.add_child(modifier_label)

	threat_modifier_value_label = Label.new()
	threat_modifier_value_label.text = "1.0"
	threat_modifier_value_label.custom_minimum_size.x = 40
	modifier_header.add_child(threat_modifier_value_label)
	modifier_container.add_child(modifier_header)

	# Slider
	var slider_container: HBoxContainer = HBoxContainer.new()
	threat_modifier_slider = HSlider.new()
	threat_modifier_slider.min_value = 0.0
	threat_modifier_slider.max_value = 5.0
	threat_modifier_slider.step = 0.1
	threat_modifier_slider.value = 1.0
	threat_modifier_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	threat_modifier_slider.custom_minimum_size.x = 200
	threat_modifier_slider.tooltip_text = "Multiplier for AI targeting priority. 0.5 = low priority, 1.0 = normal, 2.0+ = high priority target."
	threat_modifier_slider.value_changed.connect(_on_threat_modifier_changed)
	slider_container.add_child(threat_modifier_slider)
	modifier_container.add_child(slider_container)

	# Preset buttons
	var preset_container: HBoxContainer = HBoxContainer.new()
	preset_container.add_theme_constant_override("separation", 4)

	var preset_label: Label = Label.new()
	preset_label.text = "Presets:"
	preset_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	preset_container.add_child(preset_label)

	var presets: Array[Dictionary] = [
		{"label": "Fodder (0.5)", "value": 0.5, "tooltip": "Enemies deprioritize this unit"},
		{"label": "Normal (1.0)", "value": 1.0, "tooltip": "Default threat level"},
		{"label": "Elite (1.5)", "value": 1.5, "tooltip": "Slightly higher priority"},
		{"label": "Boss (2.0)", "value": 2.0, "tooltip": "High priority protection/targeting"},
		{"label": "VIP (3.0)", "value": 3.0, "tooltip": "Maximum priority"}
	]

	for preset: Dictionary in presets:
		var btn: Button = Button.new()
		btn.text = preset.label
		btn.tooltip_text = preset.tooltip
		btn.pressed.connect(_on_threat_modifier_preset.bind(preset.value))
		preset_container.add_child(btn)

	modifier_container.add_child(preset_container)
	content.add_child(modifier_container)


func _build_threat_tags_ui(content: VBoxContainer, form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section_label("Threat Tags:")
	form.add_help_text("Click to add common tags, or type custom tags below")

	# Quick-add buttons for common tags
	var quick_tags_container: HFlowContainer = HFlowContainer.new()
	quick_tags_container.add_theme_constant_override("h_separation", 4)
	quick_tags_container.add_theme_constant_override("v_separation", 4)

	for tag: String in COMMON_THREAT_TAGS.keys():
		var btn: Button = Button.new()
		btn.text = "+ " + tag
		btn.tooltip_text = COMMON_THREAT_TAGS[tag]
		btn.pressed.connect(_on_add_threat_tag.bind(tag))
		quick_tags_container.add_child(btn)

	content.add_child(quick_tags_container)

	# Current tags display
	var current_tags_label: Label = Label.new()
	current_tags_label.text = "Active Tags:"
	content.add_child(current_tags_label)

	threat_tags_container = HFlowContainer.new()
	threat_tags_container.add_theme_constant_override("h_separation", 4)
	threat_tags_container.add_theme_constant_override("v_separation", 4)
	content.add_child(threat_tags_container)

	# Custom tag input
	custom_tag_edit = LineEdit.new()
	custom_tag_edit.placeholder_text = "e.g., flanker, glass_cannon"
	custom_tag_edit.tooltip_text = "Add custom tags for mod-specific AI behaviors. Use snake_case format."
	custom_tag_edit.text_submitted.connect(_on_custom_tag_submitted)

	var custom_tag_row: HBoxContainer = HBoxContainer.new()
	custom_tag_row.add_theme_constant_override("separation", 8)

	var custom_label: Label = Label.new()
	custom_label.text = "Custom Tag:"
	custom_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	custom_tag_row.add_child(custom_label)

	custom_tag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_tag_row.add_child(custom_tag_edit)

	add_tag_button = Button.new()
	add_tag_button.text = "Add"
	add_tag_button.pressed.connect(_on_add_custom_tag_pressed)
	custom_tag_row.add_child(add_tag_button)

	content.add_child(custom_tag_row)


func load_data() -> void:
	var character: CharacterData = get_resource() as CharacterData
	if not character:
		return

	# Load threat modifier (with fallback for characters without the field)
	var threat_modifier: float = 1.0
	if "ai_threat_modifier" in character:
		threat_modifier = character.ai_threat_modifier
	threat_modifier_slider.value = threat_modifier
	threat_modifier_value_label.text = "%.1f" % threat_modifier

	# Load threat tags (with fallback for characters without the field)
	_current_threat_tags.clear()
	if "ai_threat_tags" in character:
		for tag: String in character.ai_threat_tags:
			_current_threat_tags.append(tag)

	_refresh_threat_tags_display()


func save_data() -> void:
	var character: CharacterData = get_resource() as CharacterData
	if not character:
		return

	# Save threat modifier
	if "ai_threat_modifier" in character:
		character.ai_threat_modifier = threat_modifier_slider.value

	# Save threat tags
	if "ai_threat_tags" in character:
		var new_tags: Array[String] = []
		for tag: String in _current_threat_tags:
			new_tags.append(tag)
		character.ai_threat_tags = new_tags


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_threat_modifier_changed(value: float) -> void:
	threat_modifier_value_label.text = "%.1f" % value
	mark_dirty()


func _on_threat_modifier_preset(value: float) -> void:
	threat_modifier_slider.value = value
	threat_modifier_value_label.text = "%.1f" % value
	mark_dirty()


func _on_add_threat_tag(tag: String) -> void:
	if tag not in _current_threat_tags:
		_current_threat_tags.append(tag)
		_refresh_threat_tags_display()
		mark_dirty()


func _on_remove_threat_tag(tag: String) -> void:
	_current_threat_tags.erase(tag)
	_refresh_threat_tags_display()
	mark_dirty()


func _on_custom_tag_submitted(tag: String) -> void:
	_add_custom_tag(tag)


func _on_add_custom_tag_pressed() -> void:
	_add_custom_tag(custom_tag_edit.text)


func _add_custom_tag(tag: String) -> void:
	var clean_tag: String = tag.strip_edges().to_lower().replace(" ", "_")
	if clean_tag.is_empty():
		return
	if clean_tag not in _current_threat_tags:
		_current_threat_tags.append(clean_tag)
		_refresh_threat_tags_display()
		mark_dirty()
	custom_tag_edit.text = ""


func _refresh_threat_tags_display() -> void:
	# Clear existing tag buttons
	for child: Node in threat_tags_container.get_children():
		child.queue_free()

	if _current_threat_tags.is_empty():
		SparklingEditorUtils.add_empty_placeholder(threat_tags_container, "(No tags)")
		return

	# Create pill-style buttons for each tag
	for tag: String in _current_threat_tags:
		var tag_btn: Button = Button.new()
		tag_btn.text = tag + " x"
		tag_btn.tooltip_text = "Click to remove this tag"
		if tag in COMMON_THREAT_TAGS:
			tag_btn.tooltip_text = COMMON_THREAT_TAGS[tag] + "\nClick to remove"
		tag_btn.pressed.connect(_on_remove_threat_tag.bind(tag))
		threat_tags_container.add_child(tag_btn)
