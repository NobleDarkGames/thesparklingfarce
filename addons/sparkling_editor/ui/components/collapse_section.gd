@tool
extends VBoxContainer
class_name CollapseSection

## Reusable collapsible section component with clickable header
##
## Usage:
##   var section: CollapseSection = CollapseSection.new()
##   section.title = "Equipment"
##   section.add_content_child(my_widget)
##   parent.add_child(section)
##
## The header is clickable and toggles visibility of the content container.
## An arrow indicator shows the current state (collapsed/expanded).

## Emitted when the section is toggled
signal toggled(is_collapsed: bool)

## The title displayed in the header
@export var title: String = "Section":
	set(value):
		title = value
		if _title_label:
			_update_header_text()

## Whether the section starts collapsed
@export var start_collapsed: bool = false:
	set(value):
		start_collapsed = value
		if is_inside_tree() and not _initialized:
			_is_collapsed = value

## Font size for the title (0 uses default)
@export var title_font_size: int = 16:
	set(value):
		title_font_size = value
		if _title_label and value > 0:
			_title_label.add_theme_font_size_override("font_size", value)

## Internal state
var _is_collapsed: bool = false
var _initialized: bool = false

## UI references
var _header_button: Button
var _title_label: Label
var _content_container: VBoxContainer


func _init() -> void:
	# Nothing here - setup in _ready
	pass


func _ready() -> void:
	_setup_ui()
	_initialized = true

	# Apply initial collapsed state
	if start_collapsed:
		_is_collapsed = true
		_update_content_visibility()


func _setup_ui() -> void:
	# Create header button (clickable area)
	_header_button = Button.new()
	_header_button.flat = true
	_header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_header_button.pressed.connect(_on_header_pressed)
	add_child(_header_button)
	move_child(_header_button, 0)

	# The button will contain an HBox with arrow + title
	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_hbox.add_theme_constant_override("separation", 6)
	_header_button.add_child(header_hbox)

	# Title label with arrow indicator
	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if title_font_size > 0:
		_title_label.add_theme_font_size_override("font_size", title_font_size)
	header_hbox.add_child(_title_label)
	_update_header_text()

	# Content container
	_content_container = VBoxContainer.new()
	_content_container.name = "ContentContainer"
	add_child(_content_container)


## Update the header text with collapse indicator
func _update_header_text() -> void:
	if not _title_label:
		return

	# Use simple text arrows that work everywhere
	var arrow: String = "[-]" if not _is_collapsed else "[+]"
	_title_label.text = "%s %s" % [arrow, title]


## Handle header click
func _on_header_pressed() -> void:
	toggle()


## Toggle the collapsed state
func toggle() -> void:
	_is_collapsed = not _is_collapsed
	_update_content_visibility()
	_update_header_text()
	toggled.emit(_is_collapsed)


## Expand the section (show content)
func expand() -> void:
	if _is_collapsed:
		toggle()


## Collapse the section (hide content)
func collapse() -> void:
	if not _is_collapsed:
		toggle()


## Check if section is currently collapsed
func is_collapsed() -> bool:
	return _is_collapsed


## Update content visibility based on collapsed state
func _update_content_visibility() -> void:
	if _content_container:
		_content_container.visible = not _is_collapsed


## Add a child to the content container (not the header)
func add_content_child(node: Node) -> void:
	if _content_container:
		_content_container.add_child(node)
	elif is_inside_tree():
		# Fallback if called before _ready but we're still in tree
		call_deferred("add_content_child", node)
	else:
		# Node removed from tree before initialization - can't add child safely
		push_warning("CollapseSection: Cannot add child '%s' - section not in tree and not initialized" % node.name)


## Remove a child from the content container
func remove_content_child(node: Node) -> void:
	if _content_container and node.get_parent() == _content_container:
		_content_container.remove_child(node)


## Get the content container for direct manipulation
func get_content_container() -> VBoxContainer:
	return _content_container


## Clear all children from the content container
func clear_content() -> void:
	if not _content_container:
		return

	for child in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()
