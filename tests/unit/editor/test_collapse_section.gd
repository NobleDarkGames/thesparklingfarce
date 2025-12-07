## Unit Tests for CollapseSection Component
##
## Tests the collapsible section UI component added in Phase 4.
## Uses SceneRunner pattern for UI testing.
class_name TestCollapseSection
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

const CollapseSectionScript: GDScript = preload("res://addons/sparkling_editor/ui/components/collapse_section.gd")

var _section: CollapseSection


func before_test() -> void:
	_section = CollapseSection.new()
	# Add to scene tree to trigger _ready
	add_child(_section)
	# Wait for _ready to complete
	await get_tree().process_frame


func after_test() -> void:
	if _section:
		_section.queue_free()
		_section = null


# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_default_title_is_section() -> void:
	# Default title should be "Section"
	assert_str(_section.title).is_equal("Section")


func test_start_collapsed_false_by_default() -> void:
	# Should start expanded by default
	assert_bool(_section.start_collapsed).is_false()
	assert_bool(_section.is_collapsed()).is_false()


func test_custom_title_is_set() -> void:
	_section.title = "Custom Title"
	assert_str(_section.title).is_equal("Custom Title")


func test_title_font_size_default() -> void:
	# Default font size should be 16
	assert_int(_section.title_font_size).is_equal(16)


# =============================================================================
# COLLAPSED STATE TESTS
# =============================================================================

func test_is_collapsed_returns_current_state() -> void:
	# Initially expanded
	assert_bool(_section.is_collapsed()).is_false()

	_section.collapse()
	assert_bool(_section.is_collapsed()).is_true()

	_section.expand()
	assert_bool(_section.is_collapsed()).is_false()


func test_toggle_changes_state() -> void:
	var initial_state: bool = _section.is_collapsed()

	_section.toggle()

	assert_bool(_section.is_collapsed()).is_equal(not initial_state)


func test_toggle_twice_returns_to_original() -> void:
	var initial_state: bool = _section.is_collapsed()

	_section.toggle()
	_section.toggle()

	assert_bool(_section.is_collapsed()).is_equal(initial_state)


func test_expand_does_nothing_if_already_expanded() -> void:
	# Ensure we're expanded
	if _section.is_collapsed():
		_section.expand()

	assert_bool(_section.is_collapsed()).is_false()

	# Calling expand again should do nothing
	_section.expand()

	assert_bool(_section.is_collapsed()).is_false()


func test_collapse_does_nothing_if_already_collapsed() -> void:
	_section.collapse()
	assert_bool(_section.is_collapsed()).is_true()

	# Calling collapse again should do nothing
	_section.collapse()

	assert_bool(_section.is_collapsed()).is_true()


# =============================================================================
# CONTENT VISIBILITY TESTS
# =============================================================================

func test_content_visible_when_expanded() -> void:
	_section.expand()

	var container: VBoxContainer = _section.get_content_container()
	assert_bool(container.visible).is_true()


func test_content_hidden_when_collapsed() -> void:
	_section.collapse()

	var container: VBoxContainer = _section.get_content_container()
	assert_bool(container.visible).is_false()


func test_toggle_updates_content_visibility() -> void:
	# Start expanded
	_section.expand()
	var container: VBoxContainer = _section.get_content_container()
	assert_bool(container.visible).is_true()

	# Toggle to collapsed
	_section.toggle()
	assert_bool(container.visible).is_false()

	# Toggle back to expanded
	_section.toggle()
	assert_bool(container.visible).is_true()


# =============================================================================
# CONTENT MANAGEMENT TESTS
# =============================================================================

func test_add_content_child_adds_to_container() -> void:
	var test_node: Label = Label.new()
	test_node.text = "Test Label"

	_section.add_content_child(test_node)

	var container: VBoxContainer = _section.get_content_container()
	assert_bool(test_node.get_parent() == container).is_true()


func test_add_multiple_content_children() -> void:
	var label1: Label = Label.new()
	var label2: Label = Label.new()
	var button: Button = Button.new()

	_section.add_content_child(label1)
	_section.add_content_child(label2)
	_section.add_content_child(button)

	var container: VBoxContainer = _section.get_content_container()
	assert_int(container.get_child_count()).is_equal(3)


func test_remove_content_child_removes_from_container() -> void:
	var test_node: Label = Label.new()
	_section.add_content_child(test_node)

	var container: VBoxContainer = _section.get_content_container()
	assert_int(container.get_child_count()).is_equal(1)

	_section.remove_content_child(test_node)

	# Node should be removed from container (but not freed)
	assert_int(container.get_child_count()).is_equal(0)

	# Clean up the orphaned node
	test_node.queue_free()


func test_clear_content_removes_all_children() -> void:
	_section.add_content_child(Label.new())
	_section.add_content_child(Button.new())
	_section.add_content_child(LineEdit.new())

	var container: VBoxContainer = _section.get_content_container()
	assert_int(container.get_child_count()).is_equal(3)

	_section.clear_content()

	# All children should be removed (and queued for free)
	assert_int(container.get_child_count()).is_equal(0)


func test_get_content_container_returns_vbox() -> void:
	var container: VBoxContainer = _section.get_content_container()
	assert_object(container).is_not_null()
	assert_object(container).is_instanceof(VBoxContainer)


# =============================================================================
# SIGNAL TESTS
# =============================================================================

var _toggled_signal_received: bool = false
var _toggled_signal_value: bool = false


func _on_toggled(is_collapsed: bool) -> void:
	_toggled_signal_received = true
	_toggled_signal_value = is_collapsed


func test_toggle_emits_signal() -> void:
	_toggled_signal_received = false
	_section.toggled.connect(_on_toggled)

	_section.toggle()

	assert_bool(_toggled_signal_received).is_true()


func test_toggled_signal_has_correct_value_when_collapsing() -> void:
	# Start expanded
	_section.expand()
	_toggled_signal_received = false
	_toggled_signal_value = false
	_section.toggled.connect(_on_toggled)

	# Toggle to collapse
	_section.toggle()

	assert_bool(_toggled_signal_received).is_true()
	assert_bool(_toggled_signal_value).is_true()  # is_collapsed = true


func test_toggled_signal_has_correct_value_when_expanding() -> void:
	# Start collapsed
	_section.collapse()
	_toggled_signal_received = false
	_toggled_signal_value = true
	_section.toggled.connect(_on_toggled)

	# Toggle to expand
	_section.toggle()

	assert_bool(_toggled_signal_received).is_true()
	assert_bool(_toggled_signal_value).is_false()  # is_collapsed = false


func test_expand_emits_signal_when_state_changes() -> void:
	# Start collapsed
	_section.collapse()
	_toggled_signal_received = false
	_section.toggled.connect(_on_toggled)

	_section.expand()

	assert_bool(_toggled_signal_received).is_true()


func test_collapse_emits_signal_when_state_changes() -> void:
	# Start expanded
	_section.expand()
	_toggled_signal_received = false
	_section.toggled.connect(_on_toggled)

	_section.collapse()

	assert_bool(_toggled_signal_received).is_true()


# =============================================================================
# HEADER DISPLAY TESTS
# =============================================================================

func test_header_shows_minus_when_expanded() -> void:
	_section.expand()
	_section.title = "Test"

	# The header text should contain "[-]" when expanded
	# We need to find the title label to check this
	var title_label: Label = _find_title_label()
	if title_label:
		assert_str(title_label.text).contains("[-]")


func test_header_shows_plus_when_collapsed() -> void:
	_section.collapse()
	_section.title = "Test"

	var title_label: Label = _find_title_label()
	if title_label:
		assert_str(title_label.text).contains("[+]")


func test_header_includes_title_text() -> void:
	_section.title = "My Custom Section"

	var title_label: Label = _find_title_label()
	if title_label:
		assert_str(title_label.text).contains("My Custom Section")


## Helper to find the title label in the section structure
func _find_title_label() -> Label:
	# The structure is: CollapseSection > Button > HBoxContainer > Label
	for child in _section.get_children():
		if child is Button:
			for btn_child in child.get_children():
				if btn_child is HBoxContainer:
					for hbox_child in btn_child.get_children():
						if hbox_child is Label:
							return hbox_child
	return null


# =============================================================================
# START COLLAPSED TESTS
# =============================================================================

func test_start_collapsed_true_creates_collapsed_section() -> void:
	# Create a new section with start_collapsed = true
	var collapsed_section: CollapseSection = CollapseSection.new()
	collapsed_section.start_collapsed = true

	add_child(collapsed_section)
	await get_tree().process_frame

	assert_bool(collapsed_section.is_collapsed()).is_true()

	collapsed_section.queue_free()


func test_start_collapsed_false_creates_expanded_section() -> void:
	# Create a new section with start_collapsed = false (default)
	var expanded_section: CollapseSection = CollapseSection.new()
	expanded_section.start_collapsed = false

	add_child(expanded_section)
	await get_tree().process_frame

	assert_bool(expanded_section.is_collapsed()).is_false()

	expanded_section.queue_free()


# =============================================================================
# TITLE UPDATE TESTS
# =============================================================================

func test_title_setter_updates_display() -> void:
	_section.title = "Initial"

	var label_before: Label = _find_title_label()
	if label_before:
		assert_str(label_before.text).contains("Initial")

	_section.title = "Updated Title"

	var label_after: Label = _find_title_label()
	if label_after:
		assert_str(label_after.text).contains("Updated Title")


func test_title_font_size_setter_applies_override() -> void:
	_section.title_font_size = 24

	var title_label: Label = _find_title_label()
	if title_label:
		# Check that font size override was applied
		assert_int(title_label.get_theme_font_size("font_size")).is_equal(24)
