## Unit Tests for ResourcePickerWidget Component
##
## Tests the unified resource picker widget used in the cinematic editor.
## Focus on NPC prefix handling which was a bug fix - NPC actors couldn't
## be used as speakers in dialog_line commands because the prefix wasn't
## preserved correctly.
##
## Bug fixed in commit 980353c
class_name TestResourcePickerWidget
extends GdUnitTestSuite


# =============================================================================
# TEST FIXTURES
# =============================================================================

var _widget: Control
var ResourcePickerWidgetClass: GDScript


func before_test() -> void:
	ResourcePickerWidgetClass = load("res://addons/sparkling_editor/ui/components/widgets/resource_picker_widget.gd")
	_widget = ResourcePickerWidgetClass.new(ResourcePickerWidgetClass.ResourceType.SPEAKER)
	add_child(_widget)


func after_test() -> void:
	if _widget and is_instance_valid(_widget):
		_widget.queue_free()
	_widget = null


# =============================================================================
# BASIC SETUP TESTS
# =============================================================================

func test_widget_extends_editor_widget_base() -> void:
	# Verify the widget is a subclass of EditorWidgetBase by checking for expected properties
	assert_bool(_widget.has_method("set_value")).is_true()
	assert_bool(_widget.has_method("get_value")).is_true()
	assert_bool(_widget.has_method("set_context")).is_true()
	assert_bool(_widget.has_signal("value_changed")).is_true()


func test_widget_creates_option_button() -> void:
	assert_object(_widget._option_button).is_not_null()
	assert_bool(_widget._option_button is OptionButton).is_true()


func test_widget_defaults_to_allow_none() -> void:
	assert_bool(_widget.allow_none).is_true()


func test_widget_default_none_label() -> void:
	assert_str(_widget.none_label).is_equal("(None)")


# =============================================================================
# NPC PREFIX DETECTION TESTS
# Regression tests for bug where NPC speakers weren't recognized
# =============================================================================

func test_is_npc_value_detects_npc_prefix() -> void:
	assert_bool(_widget._is_npc_value("npc:town_guard")).is_true()


func test_is_npc_value_rejects_character_id() -> void:
	assert_bool(_widget._is_npc_value("max")).is_false()


func test_is_npc_value_rejects_empty_string() -> void:
	assert_bool(_widget._is_npc_value("")).is_false()


func test_is_npc_value_rejects_partial_prefix() -> void:
	# "npc" without colon should not be detected as NPC
	assert_bool(_widget._is_npc_value("npc")).is_false()


func test_is_npc_value_case_sensitive() -> void:
	# Prefix should be lowercase "npc:"
	assert_bool(_widget._is_npc_value("NPC:town_guard")).is_false()


# =============================================================================
# NPC PREFIX FORMATTING TESTS
# =============================================================================

func test_format_npc_value_adds_prefix() -> void:
	var result: String = _widget._format_npc_value("town_guard")
	assert_str(result).is_equal("npc:town_guard")


func test_format_npc_value_handles_empty_id() -> void:
	var result: String = _widget._format_npc_value("")
	assert_str(result).is_equal("npc:")


func test_format_npc_value_preserves_special_characters() -> void:
	var result: String = _widget._format_npc_value("guard_01_east")
	assert_str(result).is_equal("npc:guard_01_east")


# =============================================================================
# NPC PREFIX PARSING TESTS
# =============================================================================

func test_parse_npc_value_strips_prefix() -> void:
	var result: String = _widget._parse_npc_value("npc:town_guard")
	assert_str(result).is_equal("town_guard")


func test_parse_npc_value_passes_through_non_npc() -> void:
	var result: String = _widget._parse_npc_value("max")
	assert_str(result).is_equal("max")


func test_parse_npc_value_handles_empty_string() -> void:
	var result: String = _widget._parse_npc_value("")
	assert_str(result).is_equal("")


func test_parse_npc_value_handles_empty_npc_id() -> void:
	# "npc:" with nothing after should return empty string
	var result: String = _widget._parse_npc_value("npc:")
	assert_str(result).is_equal("")


# =============================================================================
# NPC VALUE ROUNDTRIP TESTS
# Critical: values must survive format -> parse cycle
# =============================================================================

func test_npc_value_roundtrip_preserves_id() -> void:
	var original: String = "shopkeeper"
	var formatted: String = _widget._format_npc_value(original)
	var parsed: String = _widget._parse_npc_value(formatted)
	assert_str(parsed).is_equal(original)


func test_npc_value_roundtrip_with_underscores() -> void:
	var original: String = "town_guard_captain"
	var formatted: String = _widget._format_npc_value(original)
	var parsed: String = _widget._parse_npc_value(formatted)
	assert_str(parsed).is_equal(original)


func test_npc_value_roundtrip_with_numbers() -> void:
	var original: String = "guard_01"
	var formatted: String = _widget._format_npc_value(original)
	var parsed: String = _widget._parse_npc_value(formatted)
	assert_str(parsed).is_equal(original)


# =============================================================================
# VALUE GET/SET TESTS
# =============================================================================

func test_get_value_returns_empty_initially() -> void:
	assert_str(_widget.get_value()).is_equal("")


func test_set_value_stores_character_id() -> void:
	_widget.set_value("max")
	assert_str(_widget._current_value).is_equal("max")


func test_set_value_stores_npc_with_prefix() -> void:
	_widget.set_value("npc:town_guard")
	assert_str(_widget._current_value).is_equal("npc:town_guard")


func test_set_value_handles_null() -> void:
	_widget.set_value(null)
	assert_str(_widget._current_value).is_equal("")


func test_get_value_returns_set_value() -> void:
	_widget.set_value("npc:shopkeeper")
	assert_str(_widget.get_value()).is_equal("npc:shopkeeper")


# =============================================================================
# RESOURCE TYPE TESTS
# =============================================================================

func test_speaker_type_set_correctly() -> void:
	assert_int(_widget.resource_type).is_equal(ResourcePickerWidgetClass.ResourceType.SPEAKER)


func test_can_create_shop_picker() -> void:
	var shop_widget: Control = ResourcePickerWidgetClass.new(ResourcePickerWidgetClass.ResourceType.SHOP)
	add_child(shop_widget)
	assert_int(shop_widget.resource_type).is_equal(ResourcePickerWidgetClass.ResourceType.SHOP)
	shop_widget.queue_free()


func test_can_create_battle_picker() -> void:
	var battle_widget: Control = ResourcePickerWidgetClass.new(ResourcePickerWidgetClass.ResourceType.BATTLE)
	add_child(battle_widget)
	assert_int(battle_widget.resource_type).is_equal(ResourcePickerWidgetClass.ResourceType.BATTLE)
	battle_widget.queue_free()


func test_can_create_actor_picker() -> void:
	var actor_widget: Control = ResourcePickerWidgetClass.new(ResourcePickerWidgetClass.ResourceType.ACTOR)
	add_child(actor_widget)
	assert_int(actor_widget.resource_type).is_equal(ResourcePickerWidgetClass.ResourceType.ACTOR)
	actor_widget.queue_free()


# =============================================================================
# SIGNAL EMISSION TESTS
# =============================================================================

var _signal_value: String = ""


func _on_value_changed(value: Variant) -> void:
	_signal_value = str(value) if value != null else ""


func test_value_changed_signal_emits_on_selection() -> void:
	_signal_value = ""
	_widget.value_changed.connect(_on_value_changed)
	
	# Manually add an NPC item to simulate population
	# add_item(text, id) adds at next index (0), so use index 0 for metadata/selection
	_widget._option_button.add_item("Town Guard (NPC)", 1)
	_widget._option_button.set_item_metadata(0, {"type": "npc", "id": "town_guard"})

	# Simulate selection (index 0, not ID 1)
	_widget._on_item_selected(0)
	
	# Should emit "npc:town_guard"
	assert_str(_signal_value).is_equal("npc:town_guard")


func test_value_changed_signal_emits_character_without_prefix() -> void:
	_signal_value = ""
	_widget.value_changed.connect(_on_value_changed)

	# Add a character item (adds at index 0)
	_widget._option_button.add_item("Max", 1)
	_widget._option_button.set_item_metadata(0, {"type": "character", "id": "abc123"})

	# Simulate selection (index 0)
	_widget._on_item_selected(0)

	# Should emit character UID without prefix
	assert_str(_signal_value).is_equal("abc123")


func test_value_changed_signal_emits_empty_for_none() -> void:
	_signal_value = "initial"
	_widget.value_changed.connect(_on_value_changed)
	
	# Add none option (index 0 by default)
	_widget._option_button.clear()
	_widget._option_button.add_item("(None)", 0)
	_widget._option_button.set_item_metadata(0, {"type": "none", "id": ""})
	
	# Simulate selection of none
	_widget._on_item_selected(0)
	
	assert_str(_signal_value).is_equal("")
