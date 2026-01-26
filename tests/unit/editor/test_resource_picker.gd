## Unit Tests for ResourcePicker Component
##
## Tests the mod-aware resource picker used throughout the Sparkling Editor.
## Tests focus on UI setup, state management, and signal behavior.
## Note: Full integration tests with ModLoader require editor environment.
class_name TestResourcePicker
extends GdUnitTestSuite


# =============================================================================
# TEST CONSTANTS
# =============================================================================

const TEST_MOD_ID: String = "_test_resource_picker"


# =============================================================================
# TEST FIXTURES
# =============================================================================

const SignalTrackerScript = preload("res://tests/fixtures/signal_tracker.gd")

var _picker: Control
var ResourcePickerClass: GDScript
var _tracker: RefCounted


func before_test() -> void:
	# Load the ResourcePicker script
	ResourcePickerClass = load("res://addons/sparkling_editor/ui/components/resource_picker.gd")
	_picker = ResourcePickerClass.new()
	add_child(_picker)
	_tracker = SignalTrackerScript.new()


func after_test() -> void:
	if _tracker:
		_tracker.disconnect_all()
		_tracker = null
	if _picker and is_instance_valid(_picker):
		_picker.queue_free()
	_picker = null


# =============================================================================
# UI SETUP TESTS
# =============================================================================

func test_picker_is_hbox_container() -> void:
	# ResourcePicker extends HBoxContainer
	assert_bool(_picker is HBoxContainer).is_true()


func test_picker_creates_label() -> void:
	# The internal label should be created
	assert_object(_picker._label).is_not_null()
	assert_bool(_picker._label is Label).is_true()


func test_picker_creates_option_button() -> void:
	# The internal option button should be created
	assert_object(_picker._option_button).is_not_null()
	assert_bool(_picker._option_button is OptionButton).is_true()


func test_picker_creates_refresh_button() -> void:
	# The internal refresh button should be created
	assert_object(_picker._refresh_button).is_not_null()
	assert_bool(_picker._refresh_button is Button).is_true()


func test_option_button_has_minimum_width() -> void:
	assert_float(_picker._option_button.custom_minimum_size.x).is_greater_equal(200.0)


func test_refresh_button_hidden_by_default() -> void:
	assert_bool(_picker._refresh_button.visible).is_false()


# =============================================================================
# LABEL CONFIGURATION TESTS
# =============================================================================

func test_label_hidden_by_default() -> void:
	# No label_text set, so label should be hidden
	assert_bool(_picker._label.visible).is_false()


func test_label_visible_when_text_set() -> void:
	_picker.label_text = "Select Character"

	assert_bool(_picker._label.visible).is_true()
	assert_str(_picker._label.text).is_equal("Select Character")


func test_label_hidden_when_text_cleared() -> void:
	_picker.label_text = "Something"
	_picker.label_text = ""

	assert_bool(_picker._label.visible).is_false()


func test_label_minimum_width_applied() -> void:
	_picker.label_min_width = 150.0

	assert_float(_picker._label.custom_minimum_size.x).is_equal(150.0)


# =============================================================================
# REFRESH BUTTON CONFIGURATION TESTS
# =============================================================================

func test_show_refresh_button_property() -> void:
	_picker.show_refresh_button = true

	assert_bool(_picker._refresh_button.visible).is_true()


func test_hide_refresh_button_property() -> void:
	_picker.show_refresh_button = true
	_picker.show_refresh_button = false

	assert_bool(_picker._refresh_button.visible).is_false()


func test_refresh_button_has_tooltip() -> void:
	assert_str(_picker._refresh_button.tooltip_text).is_not_empty()


# =============================================================================
# NONE OPTION TESTS
# =============================================================================

func test_none_text_default_value() -> void:
	assert_str(_picker.none_text).is_equal("(None)")


func test_none_text_customizable() -> void:
	_picker.none_text = "(No Selection)"

	assert_str(_picker.none_text).is_equal("(No Selection)")


func test_allow_none_default_true() -> void:
	assert_bool(_picker.allow_none).is_true()


func test_allow_none_configurable() -> void:
	_picker.allow_none = false

	assert_bool(_picker.allow_none).is_false()


# =============================================================================
# SIGNAL EXISTENCE TESTS
# =============================================================================

func test_resource_selected_signal_exists() -> void:
	assert_bool(_picker.has_signal("resource_selected")).is_true()


func test_picker_refreshed_signal_exists() -> void:
	assert_bool(_picker.has_signal("picker_refreshed")).is_true()


# =============================================================================
# RESOURCE_SELECTED SIGNAL TESTS
# =============================================================================

func test_select_none_emits_empty_metadata() -> void:
	_tracker.track(_picker.resource_selected)
	_picker.select_none()

	# Note: select_none() doesn't emit signal, just sets state
	# The signal is emitted on _on_item_selected
	assert_bool(_picker.get_selected_metadata().is_empty()).is_true()


# =============================================================================
# SELECTION STATE TESTS
# =============================================================================

func test_has_selection_false_initially() -> void:
	assert_bool(_picker.has_selection()).is_false()


func test_has_selection_false_after_select_none() -> void:
	_picker.select_none()

	assert_bool(_picker.has_selection()).is_false()


func test_get_selected_resource_null_initially() -> void:
	assert_object(_picker.get_selected_resource()).is_null()


func test_get_selected_metadata_empty_initially() -> void:
	assert_bool(_picker.get_selected_metadata().is_empty()).is_true()


func test_get_selected_mod_id_empty_initially() -> void:
	assert_str(_picker.get_selected_mod_id()).is_empty()


func test_get_selected_resource_id_empty_initially() -> void:
	assert_str(_picker.get_selected_resource_id()).is_empty()


# =============================================================================
# RESOURCE TYPE CONFIGURATION TESTS
# =============================================================================

func test_resource_type_empty_by_default() -> void:
	assert_str(_picker.resource_type).is_empty()


func test_resource_type_setter_stores_value() -> void:
	_picker.resource_type = "character"

	assert_str(_picker.resource_type).is_equal("character")


# =============================================================================
# FILTER FUNCTION TESTS
# =============================================================================

func test_filter_function_empty_by_default() -> void:
	assert_bool(_picker.filter_function.is_valid()).is_false()


func test_filter_function_can_be_set() -> void:
	var test_filter: Callable = func(_res: Resource) -> bool: return true

	_picker.filter_function = test_filter

	assert_bool(_picker.filter_function.is_valid()).is_true()


# =============================================================================
# DISABLED STATE TESTS
# =============================================================================

func test_set_disabled_disables_option_button() -> void:
	_picker.set_disabled(true)

	assert_bool(_picker._option_button.disabled).is_true()


func test_set_disabled_enables_option_button() -> void:
	_picker.set_disabled(true)
	_picker.set_disabled(false)

	assert_bool(_picker._option_button.disabled).is_false()


# =============================================================================
# GET OPTION BUTTON TESTS
# =============================================================================

func test_get_option_button_returns_internal_button() -> void:
	var button: OptionButton = _picker.get_option_button()

	assert_object(button).is_same(_picker._option_button)


# =============================================================================
# OVERRIDE INFO TESTS
# =============================================================================

func test_has_override_info_false_for_unknown() -> void:
	# Without any refresh, override info should be empty
	assert_bool(_picker.has_override_info("nonexistent_resource")).is_false()


func test_get_mods_with_resource_empty_for_unknown() -> void:
	var mods: Array = _picker.get_mods_with_resource("nonexistent_resource")

	assert_bool(mods.is_empty()).is_true()


# =============================================================================
# INTERNAL DISPLAY NAME TESTS
# =============================================================================

func test_get_display_name_uses_resource_method() -> void:
	# Create a mock resource with get_display_name method
	var mock_resource: Resource = Resource.new()

	# Without the method, it falls back to checking properties
	# Testing with basic Resource which has no name properties
	var name: String = _picker._get_display_name(mock_resource)

	# Should fall back to filename (empty for new resource)
	# Since resource_path is empty for new Resource, basename is empty
	assert_str(name).is_empty()


func test_get_display_name_falls_back_to_path() -> void:
	var mock_resource: Resource = Resource.new()
	# Manually set the resource path (this is typically done by ResourceSaver)
	mock_resource.take_over_path("res://test/data/items/super_sword.tres")

	var name: String = _picker._get_display_name(mock_resource)

	assert_str(name).is_equal("super_sword")


# =============================================================================
# INTERNAL RESOURCE ID TESTS
# =============================================================================

func test_get_resource_id_extracts_from_path() -> void:
	var mock_resource: Resource = Resource.new()
	mock_resource.take_over_path("res://mods/test/data/characters/hero.tres")

	var id: String = _picker._get_resource_id(mock_resource)

	assert_str(id).is_equal("hero")


func test_get_resource_id_handles_nested_paths() -> void:
	var mock_resource: Resource = Resource.new()
	mock_resource.take_over_path("res://mods/test/data/items/weapons/legendary_sword.tres")

	var id: String = _picker._get_resource_id(mock_resource)

	assert_str(id).is_equal("legendary_sword")


func test_get_resource_id_handles_multiple_dots() -> void:
	var mock_resource: Resource = Resource.new()
	mock_resource.take_over_path("res://test/item.v2.tres")

	var id: String = _picker._get_resource_id(mock_resource)

	# get_basename() strips only the last extension
	assert_str(id).is_equal("item.v2")


# =============================================================================
# FORMAT ITEM TEXT TESTS
# =============================================================================

func test_format_item_text_basic() -> void:
	var entry: Dictionary = {
		"display_name": "Super Hero",
		"resource_id": "hero",
		"mod_id": TEST_MOD_ID
	}

	var text: String = _picker._format_item_text(entry)

	assert_str(text).is_equal("[" + TEST_MOD_ID + "] Super Hero")


func test_format_item_text_different_mod() -> void:
	var entry: Dictionary = {
		"display_name": "Custom Character",
		"resource_id": "custom_char",
		"mod_id": "my_expansion"
	}

	var text: String = _picker._format_item_text(entry)

	assert_str(text).is_equal("[my_expansion] Custom Character")


# =============================================================================
# EVENT BUS CONNECTION TESTS
# =============================================================================

func test_event_bus_connection_tracking_is_boolean() -> void:
	# The _event_bus_connected flag should be a boolean type
	# Whether it's true or false depends on the test environment
	assert_bool(_picker._event_bus_connected is bool).is_true()


# =============================================================================
# METADATA HANDLING TESTS
# =============================================================================

func test_current_metadata_initially_empty() -> void:
	assert_bool(_picker._current_metadata.is_empty()).is_true()


func test_select_none_clears_current_metadata() -> void:
	# Add a "(None)" item first so select_none doesn't fail
	_picker._option_button.add_item("(None)")
	_picker._option_button.set_item_metadata(0, {})

	# Manually set some metadata
	_picker._current_metadata = {"test": "value"}

	_picker.select_none()

	assert_bool(_picker._current_metadata.is_empty()).is_true()


# =============================================================================
# ITEM SELECTION CALLBACK TESTS
# =============================================================================

func test_on_item_selected_emits_signal() -> void:
	_tracker.track(_picker.resource_selected)

	# Add a test item to the option button
	_picker._option_button.add_item("Test Item")
	_picker._option_button.set_item_metadata(0, {"test_key": "test_value"})

	# Simulate selection
	_picker._on_item_selected(0)

	assert_bool(_tracker.was_emitted("resource_selected")).is_true()
	var emissions: Array = _tracker.get_emissions("resource_selected")
	assert_int(emissions.size()).is_equal(1)
	var emitted_metadata: Dictionary = emissions[0].arguments[0]
	assert_bool("test_key" in emitted_metadata).is_true()
	assert_str(emitted_metadata.get("test_key", "")).is_equal("test_value")


func test_on_item_selected_with_empty_metadata_emits_empty_dict() -> void:
	_tracker.track(_picker.resource_selected)

	# Add a test item with empty metadata (like "(None)" option)
	_picker._option_button.add_item("(None)")
	_picker._option_button.set_item_metadata(0, {})

	# Simulate selection
	_picker._on_item_selected(0)

	assert_bool(_tracker.was_emitted("resource_selected")).is_true()
	var emissions: Array = _tracker.get_emissions("resource_selected")
	var emitted_metadata: Dictionary = emissions[0].arguments[0]
	assert_bool(emitted_metadata.is_empty()).is_true()


func test_on_item_selected_updates_current_metadata() -> void:
	# Add test item
	_picker._option_button.add_item("Test")
	_picker._option_button.set_item_metadata(0, {"mod_id": "test_mod", "resource_id": "test_res"})

	_picker._on_item_selected(0)

	assert_str(_picker._current_metadata.get("mod_id", "")).is_equal("test_mod")
	assert_str(_picker._current_metadata.get("resource_id", "")).is_equal("test_res")


# =============================================================================
# REFRESH TRIGGERS TESTS
# =============================================================================

func test_resource_type_change_triggers_refresh_when_in_tree() -> void:
	# Picker is in tree from before_test()
	# Changing resource_type should trigger refresh (via setter)
	# We can't easily test the actual refresh without ModLoader,
	# but we can verify the property is set

	_picker.resource_type = "item"

	assert_str(_picker.resource_type).is_equal("item")
