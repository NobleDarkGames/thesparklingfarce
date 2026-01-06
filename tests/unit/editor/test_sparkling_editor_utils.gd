## Unit Tests for SparklingEditorUtils
##
## Tests the editor utility functions added in Phase 3.
## Focuses on ID generation and file operations that can run headlessly.
class_name TestSparklingEditorUtils
extends GdUnitTestSuite


# =============================================================================
# ID GENERATION TESTS
# =============================================================================

func test_generate_id_from_name_converts_to_snake_case() -> void:
	var result: String = SparklingEditorUtils.generate_id_from_name("Town Guard")
	assert_str(result).is_equal("town_guard")


func test_generate_id_from_name_handles_spaces() -> void:
	var result: String = SparklingEditorUtils.generate_id_from_name("My Cool Character Name")
	assert_str(result).is_equal("my_cool_character_name")


func test_generate_id_from_name_handles_hyphens() -> void:
	var result: String = SparklingEditorUtils.generate_id_from_name("fire-sword")
	assert_str(result).is_equal("fire_sword")


func test_generate_id_from_name_removes_special_chars() -> void:
	var result: String = SparklingEditorUtils.generate_id_from_name("Hero! @Special #Character")
	assert_str(result).is_equal("hero_special_character")


func test_generate_id_from_name_handles_empty_input() -> void:
	var result: String = SparklingEditorUtils.generate_id_from_name("")
	assert_str(result).is_empty()


func test_generate_id_from_name_handles_whitespace_only() -> void:
	var result: String = SparklingEditorUtils.generate_id_from_name("   ")
	assert_str(result).is_empty()


func test_generate_id_from_name_cleans_consecutive_underscores() -> void:
	var result: String = SparklingEditorUtils.generate_id_from_name("a - - b")
	assert_str(result).is_equal("a_b")


func test_generate_id_from_name_preserves_numbers() -> void:
	var result: String = SparklingEditorUtils.generate_id_from_name("Guard 42")
	assert_str(result).is_equal("guard_42")


func test_generate_id_from_name_lowercase_only() -> void:
	var result: String = SparklingEditorUtils.generate_id_from_name("UPPERCASE NAME")
	assert_str(result).is_equal("uppercase_name")


func test_generate_id_from_name_strips_leading_trailing_whitespace() -> void:
	var result: String = SparklingEditorUtils.generate_id_from_name("  padded name  ")
	assert_str(result).is_equal("padded_name")


# =============================================================================
# NAMESPACED ID TESTS
# =============================================================================

func test_generate_namespaced_id_combines_mod_and_name() -> void:
	var result: String = SparklingEditorUtils.generate_namespaced_id("_sandbox", "Town Guard")
	assert_str(result).is_equal("_sandbox:town_guard")


func test_generate_namespaced_id_handles_empty_name() -> void:
	var result: String = SparklingEditorUtils.generate_namespaced_id("_sandbox", "")
	assert_str(result).is_empty()


func test_generate_namespaced_id_preserves_mod_id_case() -> void:
	var result: String = SparklingEditorUtils.generate_namespaced_id("MyMod", "Item Name")
	assert_str(result).is_equal("MyMod:item_name")


# =============================================================================
# CONSTANTS TESTS
# =============================================================================

func test_default_label_width_is_reasonable() -> void:
	assert_int(SparklingEditorUtils.DEFAULT_LABEL_WIDTH).is_greater(0)
	assert_int(SparklingEditorUtils.DEFAULT_LABEL_WIDTH).is_less(500)


func test_section_font_size_is_reasonable() -> void:
	assert_int(SparklingEditorUtils.SECTION_FONT_SIZE).is_greater(10)
	assert_int(SparklingEditorUtils.SECTION_FONT_SIZE).is_less(30)


func test_help_font_size_is_smaller_than_section() -> void:
	assert_int(SparklingEditorUtils.HELP_FONT_SIZE).is_less(SparklingEditorUtils.SECTION_FONT_SIZE)


func test_body_font_size_is_between_help_and_section() -> void:
	assert_int(SparklingEditorUtils.BODY_FONT_SIZE).is_greater_equal(SparklingEditorUtils.HELP_FONT_SIZE)
	assert_int(SparklingEditorUtils.BODY_FONT_SIZE).is_less_equal(SparklingEditorUtils.SECTION_FONT_SIZE)


# =============================================================================
# UI CREATION HELPER TESTS
# =============================================================================

func test_create_section_returns_vbox_container() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Test Section")
	assert_object(section).is_not_null()
	assert_object(section).is_instanceof(VBoxContainer)
	section.queue_free()


func test_create_section_has_label_child() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Test Title")

	# First child should be a label
	var first_child: Node = section.get_child(0)
	assert_object(first_child).is_instanceof(Label)

	var label: Label = first_child as Label
	assert_str(label.text).is_equal("Test Title")

	section.queue_free()


func test_create_section_has_separator() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Test")

	# Second child should be a separator
	var second_child: Node = section.get_child(1)
	assert_object(second_child).is_instanceof(HSeparator)

	section.queue_free()


func test_create_section_adds_to_parent_when_provided() -> void:
	var parent: VBoxContainer = VBoxContainer.new()
	var section: VBoxContainer = SparklingEditorUtils.create_section("Test", parent)

	assert_int(parent.get_child_count()).is_equal(1)
	assert_object(parent.get_child(0)).is_same(section)

	parent.queue_free()


func test_create_field_row_returns_hbox_container() -> void:
	var row: HBoxContainer = SparklingEditorUtils.create_field_row("Label:")
	assert_object(row).is_not_null()
	assert_object(row).is_instanceof(HBoxContainer)
	row.queue_free()


func test_create_field_row_has_label_with_text() -> void:
	var row: HBoxContainer = SparklingEditorUtils.create_field_row("Name:")

	var first_child: Node = row.get_child(0)
	assert_object(first_child).is_instanceof(Label)

	var label: Label = first_child as Label
	assert_str(label.text).is_equal("Name:")

	row.queue_free()


func test_create_field_row_label_has_custom_width() -> void:
	var row: HBoxContainer = SparklingEditorUtils.create_field_row("Name:", 200)

	var label: Label = row.get_child(0) as Label
	assert_float(label.custom_minimum_size.x).is_equal(200.0)

	row.queue_free()


func test_create_field_row_uses_default_width() -> void:
	var row: HBoxContainer = SparklingEditorUtils.create_field_row("Name:")

	var label: Label = row.get_child(0) as Label
	assert_float(label.custom_minimum_size.x).is_equal(float(SparklingEditorUtils.DEFAULT_LABEL_WIDTH))

	row.queue_free()


func test_create_help_label_returns_label() -> void:
	var help: Label = SparklingEditorUtils.create_help_label("Help text")
	assert_object(help).is_not_null()
	assert_object(help).is_instanceof(Label)
	assert_str(help.text).is_equal("Help text")
	help.queue_free()


func test_create_help_label_has_subdued_color() -> void:
	var help: Label = SparklingEditorUtils.create_help_label("Help")

	# Should have a gray-ish font color override
	var color: Color = help.get_theme_color("font_color")
	# The color should be somewhat gray (R, G, B roughly equal and not too bright)
	assert_float(color.r).is_less(0.8)

	help.queue_free()


func test_add_separator_returns_hseparator() -> void:
	var parent: VBoxContainer = VBoxContainer.new()
	var sep: HSeparator = SparklingEditorUtils.add_separator(parent)

	assert_object(sep).is_instanceof(HSeparator)
	assert_int(parent.get_child_count()).is_equal(1)

	parent.queue_free()


func test_add_separator_has_minimum_height() -> void:
	var parent: VBoxContainer = VBoxContainer.new()
	var sep: HSeparator = SparklingEditorUtils.add_separator(parent, 25.0)

	assert_float(sep.custom_minimum_size.y).is_equal(25.0)

	parent.queue_free()


# =============================================================================
# FILE OPERATION TESTS (using temp directory)
# =============================================================================

const TEST_DIR: String = "user://test_sparkling_utils/"


func before() -> void:
	# Ensure test directory exists
	DirAccess.make_dir_recursive_absolute(TEST_DIR)


func after() -> void:
	# Clean up test directory
	_cleanup_test_dir()


func _cleanup_test_dir() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

		# Remove the test directory itself
		DirAccess.remove_absolute(TEST_DIR)


func test_ensure_directory_exists_creates_missing() -> void:
	var test_path: String = TEST_DIR + "new_subdir/"

	# Ensure it doesn't exist first
	if DirAccess.dir_exists_absolute(test_path):
		DirAccess.remove_absolute(test_path)

	var result: bool = SparklingEditorUtils.ensure_directory_exists(test_path)

	assert_bool(result).is_true()
	assert_bool(DirAccess.dir_exists_absolute(test_path)).is_true()


func test_ensure_directory_exists_returns_true_for_existing() -> void:
	# TEST_DIR already exists from before()
	var result: bool = SparklingEditorUtils.ensure_directory_exists(TEST_DIR)
	assert_bool(result).is_true()


func test_get_unique_filename_returns_base_if_available() -> void:
	# Directory is empty, so base name should be available
	var filename: String = SparklingEditorUtils.get_unique_filename(TEST_DIR, "npc", ".tres")
	assert_str(filename).is_equal("npc.tres")


func test_get_unique_filename_appends_number_if_taken() -> void:
	# Create the base file
	var file: FileAccess = FileAccess.open(TEST_DIR + "item.tres", FileAccess.WRITE)
	file.store_string("test")
	file.close()

	var filename: String = SparklingEditorUtils.get_unique_filename(TEST_DIR, "item", ".tres")
	assert_str(filename).is_equal("item_2.tres")


func test_get_unique_filename_increments_until_free() -> void:
	# Create multiple files
	for i in range(1, 4):
		var suffix: String = "" if i == 1 else "_%d" % i
		var file: FileAccess = FileAccess.open(TEST_DIR + "char%s.tres" % suffix, FileAccess.WRITE)
		file.store_string("test")
		file.close()

	var filename: String = SparklingEditorUtils.get_unique_filename(TEST_DIR, "char", ".tres")
	assert_str(filename).is_equal("char_4.tres")


# =============================================================================
# MOD SCANNING TESTS
# =============================================================================

func test_scan_all_mod_directories_returns_array() -> void:
	var mods: Array[String] = SparklingEditorUtils.scan_all_mod_directories()

	# Should return an array (may be empty if mods/ doesn't exist)
	assert_object(mods).is_not_null()


func test_scan_all_mod_directories_finds_valid_mods() -> void:
	var mods: Array[String] = SparklingEditorUtils.scan_all_mod_directories()

	# If mods directory exists, it should find at least one mod
	# We don't assume any specific mod (like _base_game) exists
	if mods.size() > 0:
		# Each mod ID should be a valid non-empty string
		for mod_id: String in mods:
			assert_str(mod_id).is_not_empty()
			# Mod IDs should not have path separators
			assert_bool("/" in mod_id).is_false()


func test_scan_all_mod_directories_excludes_hidden() -> void:
	var mods: Array[String] = SparklingEditorUtils.scan_all_mod_directories()

	# Should not include hidden directories starting with .
	for mod: String in mods:
		assert_bool(mod.begins_with(".")).is_false()


func test_scan_mods_for_files_returns_metadata_array() -> void:
	var results: Array[Dictionary] = SparklingEditorUtils.scan_mods_for_files("data/characters", ".tres")

	# Should return array of dictionaries
	assert_object(results).is_not_null()

	# If any results found, verify structure
	if results.size() > 0:
		var first: Dictionary = results[0]
		assert_bool("mod_id" in first).is_true()
		assert_bool("path" in first).is_true()
		assert_bool("filename" in first).is_true()
