# Test Coverage Plan for Sparkling Editor Phases 1-4

**Prepared by:** Major Testo, Reliability Officer, USS Torvalds
**Stardate:** 2025.340 (December 6, 2025)
**Status:** Ready for Implementation

---

## Executive Summary

This document outlines a comprehensive test plan for the recent Sparkling Editor improvements implemented in Phases 1-4. The analysis covers commits 382faa8 through 6b04406, which introduced significant new features including registries, utility classes, UI components, and editor refactoring.

The project uses **GdUnit4** as its testing framework, with tests located in `/tests/unit/` organized by system area.

---

## Current Test Coverage Status

### Existing Test Coverage (Good)

| Area | Test File | Status |
|------|-----------|--------|
| TriggerTypeRegistry | `tests/unit/mod_system/test_trigger_type_registry.gd` | COVERED |
| TilesetResolution (ModLoader API) | `tests/unit/mod_system/test_tileset_resolution.gd` | COVERED |
| Namespaced Flags | `tests/unit/mod_system/test_namespaced_flags.gd` | COVERED |
| Combat Calculator | `tests/unit/combat/test_combat_calculator.gd` | COVERED |
| Map Metadata/Spawn Points | `tests/unit/map/` | COVERED |
| Equipment Systems | `tests/unit/equipment/` | COVERED |
| Crafting System | `tests/unit/crafting/` | COVERED |
| Storage/Save System | `tests/unit/storage/` | COVERED |
| Promotion System | `tests/unit/promotion/` | COVERED |

### Missing Test Coverage (Gap Analysis)

The following new components from Phases 1-4 lack test coverage:

| Priority | Component | Location | Risk Level |
|----------|-----------|----------|------------|
| **P1 - Critical** | AIBrainRegistry | `core/registries/ai_brain_registry.gd` | HIGH |
| **P1 - Critical** | TilesetRegistry | `core/registries/tileset_registry.gd` | HIGH |
| **P2 - High** | SparklingEditorUtils | `addons/sparkling_editor/ui/editor_utils.gd` | MEDIUM |
| **P2 - High** | EditorThemeUtils | `addons/sparkling_editor/ui/editor_theme_utils.gd` | MEDIUM |
| **P2 - High** | CollapseSection | `addons/sparkling_editor/ui/components/collapse_section.gd` | MEDIUM |
| **P2 - High** | JsonEditorBase | `addons/sparkling_editor/ui/json_editor_base.gd` | MEDIUM |
| **P3 - Medium** | PartyTemplateEditor | `addons/sparkling_editor/ui/party_template_editor.gd` | LOW |
| **P3 - Medium** | SaveSlotEditor | `addons/sparkling_editor/ui/save_slot_editor.gd` | LOW |
| **P3 - Medium** | MapTemplate | `core/templates/map_template.gd` | LOW |

---

## Priority 1: Critical Registry Tests

### 1.1 AIBrainRegistry Tests

**File:** `tests/unit/registries/test_ai_brain_registry.gd`
**Estimated Effort:** 2-3 hours
**Can Run Headlessly:** YES

#### Test Cases

1. **Registration from Config**
   - `test_register_from_config_adds_brain` - Verify brains are added from mod.json config
   - `test_register_from_config_validates_path_field` - Verify error on missing path
   - `test_register_from_config_handles_empty_id` - Verify error on empty brain ID
   - `test_register_from_config_emits_signal` - Verify registrations_changed signal

2. **Override Behavior**
   - `test_later_mod_overrides_earlier_brain` - Higher priority mod wins
   - `test_override_clears_cached_instance` - Cache invalidated on override

3. **Directory Discovery**
   - `test_discover_from_directory_finds_ai_files` - Auto-discovers ai_*.gd files
   - `test_discover_strips_ai_prefix_from_id` - ai_aggressive.gd becomes "aggressive"
   - `test_discover_skips_already_registered` - Config takes priority over discovery
   - `test_discover_returns_count` - Returns number discovered

4. **Lookup API**
   - `test_get_all_brain_ids_returns_sorted_array` - Alphabetical order
   - `test_get_all_brains_returns_metadata_array` - Sorted by display_name
   - `test_get_brain_returns_copy_of_metadata` - Returns duplicate, not reference
   - `test_get_brain_returns_empty_for_unknown` - Graceful handling
   - `test_has_brain_is_case_insensitive` - "Aggressive" matches "aggressive"
   - `test_get_display_name_falls_back_to_capitalize` - Unknown brain gets capitalized ID
   - `test_get_description_returns_empty_for_unknown` - Graceful empty string
   - `test_get_brain_path_returns_full_path` - Includes mod directory
   - `test_get_source_mod_tracks_origin` - Returns registering mod ID

5. **Instance Management**
   - `test_get_brain_instance_returns_resource` - Loads and returns AIBrain
   - `test_get_brain_instance_caches_result` - Same instance on repeated calls
   - `test_get_brain_instance_returns_null_for_unknown` - Graceful null
   - `test_get_all_brain_instances_loads_all` - Bulk loading

6. **Utility Functions**
   - `test_clear_mod_registrations_empties_all` - Full reset
   - `test_clear_mod_registrations_emits_signal` - Signal emitted
   - `test_get_stats_returns_counts` - brain_count and cached_instances

### 1.2 TilesetRegistry Tests

**File:** `tests/unit/registries/test_tileset_registry.gd`
**Estimated Effort:** 2-3 hours
**Can Run Headlessly:** YES

#### Test Cases

1. **Registration from Config**
   - `test_register_from_config_adds_tileset` - Basic registration
   - `test_register_from_config_validates_path_field` - Error on missing path
   - `test_register_from_config_handles_empty_id` - Error on empty tileset ID
   - `test_register_from_config_emits_signal` - registrations_changed signal

2. **Override Behavior**
   - `test_later_mod_overrides_earlier_tileset` - Higher priority wins
   - `test_override_logs_warning` - Warning message on override

3. **Directory Discovery**
   - `test_discover_from_directory_finds_tres_files` - Auto-discovers *.tres
   - `test_discover_skips_already_registered` - Config takes priority
   - `test_discover_returns_count` - Returns number discovered

4. **Lookup API**
   - `test_get_all_tileset_ids_returns_sorted_array` - Alphabetical order
   - `test_get_all_tilesets_excludes_resource_field` - No cached resource in metadata
   - `test_get_tileset_info_returns_copy` - Returns duplicate
   - `test_get_tileset_info_returns_empty_for_unknown` - Graceful handling
   - `test_has_tileset_is_case_insensitive` - Case-insensitive lookup
   - `test_get_display_name_falls_back_to_capitalize` - Unknown gets capitalized
   - `test_get_tileset_path_returns_full_path` - Includes mod directory
   - `test_get_source_mod_tracks_origin` - Returns registering mod ID

5. **Resource Loading**
   - `test_get_tileset_lazy_loads_resource` - Loads TileSet on first access
   - `test_get_tileset_caches_result` - Same resource on repeated calls
   - `test_get_tileset_returns_null_for_unknown` - Graceful null
   - `test_get_all_tileset_paths_returns_array` - Backwards compatibility

6. **Utility Functions**
   - `test_clear_mod_registrations_empties_all` - Full reset
   - `test_clear_mod_registrations_emits_signal` - Signal emitted
   - `test_get_stats_returns_count` - tileset_count

---

## Priority 2: Utility Class Tests

### 2.1 SparklingEditorUtils Tests

**File:** `tests/unit/editor/test_sparkling_editor_utils.gd`
**Estimated Effort:** 1-2 hours
**Can Run Headlessly:** YES (no UI required for static methods)

#### Test Cases

1. **ID Generation**
   - `test_generate_id_from_name_converts_to_snake_case` - "Town Guard" -> "town_guard"
   - `test_generate_id_from_name_removes_special_chars` - "Hero!" -> "hero"
   - `test_generate_id_from_name_handles_empty_input` - Returns empty string
   - `test_generate_id_from_name_cleans_consecutive_underscores` - "a__b" -> "a_b"
   - `test_generate_namespaced_id_combines_mod_and_name` - "mod:resource_name"

2. **Directory Operations**
   - `test_ensure_directory_exists_creates_missing` - Creates if needed
   - `test_ensure_directory_exists_returns_true_for_existing` - No error for existing
   - `test_get_unique_filename_returns_base_if_available` - "npc.tres" if free
   - `test_get_unique_filename_appends_number_if_taken` - "npc_2.tres" if exists

3. **Mod Scanning**
   - `test_scan_all_mod_directories_returns_array` - Array of folder names
   - `test_scan_all_mod_directories_excludes_hidden` - No .git, .godot
   - `test_scan_mods_for_files_returns_metadata` - mod_id, path, filename

### 2.2 EditorThemeUtils Tests

**File:** `tests/unit/editor/test_editor_theme_utils.gd`
**Estimated Effort:** 1 hour
**Can Run Headlessly:** PARTIAL (fallback colors testable, editor colors need @tool context)

#### Test Cases

1. **Fallback Colors**
   - `test_get_fallback_color_error_is_red` - Color(1.0, 0.3, 0.3)
   - `test_get_fallback_color_warning_is_orange` - Color(1.0, 0.7, 0.2)
   - `test_get_fallback_color_font_is_light` - Color(0.9, 0.9, 0.9)
   - `test_get_fallback_color_disabled_is_gray` - Color(0.6, 0.6, 0.6)
   - `test_get_fallback_color_accent_is_blue` - Color(0.4, 0.6, 1.0)
   - `test_get_fallback_color_unknown_is_white` - Color(1.0, 1.0, 1.0)

2. **Success Color**
   - `test_get_success_color_returns_green` - Color(0.4, 0.8, 0.4)

3. **StyleBox Creation**
   - `test_create_error_panel_style_returns_stylebox` - StyleBoxFlat type
   - `test_create_error_panel_style_has_border` - Border width > 0
   - `test_create_info_panel_style_returns_stylebox` - StyleBoxFlat type
   - `test_create_success_panel_style_returns_stylebox` - StyleBoxFlat type

### 2.3 CollapseSection Tests

**File:** `tests/unit/editor/test_collapse_section.gd`
**Estimated Effort:** 1-2 hours
**Can Run Headlessly:** YES (SceneRunner approach)

#### Test Cases

1. **Initialization**
   - `test_default_title_is_section` - Default "Section" title
   - `test_start_collapsed_false_by_default` - Starts expanded
   - `test_start_collapsed_can_be_set_true` - Respects start_collapsed
   - `test_title_setter_updates_label` - Dynamic title updates

2. **Toggle Behavior**
   - `test_toggle_changes_state` - _is_collapsed flips
   - `test_toggle_updates_content_visibility` - Content hidden/shown
   - `test_toggle_emits_signal` - toggled signal with is_collapsed
   - `test_expand_does_nothing_if_already_expanded` - Idempotent
   - `test_collapse_does_nothing_if_already_collapsed` - Idempotent

3. **Content Management**
   - `test_add_content_child_adds_to_container` - Correct parent
   - `test_remove_content_child_removes_from_container` - Node removed
   - `test_clear_content_removes_all_children` - All cleared
   - `test_get_content_container_returns_vbox` - VBoxContainer type

4. **Header Display**
   - `test_header_shows_minus_when_expanded` - "[-]" indicator
   - `test_header_shows_plus_when_collapsed` - "[+]" indicator
   - `test_header_button_triggers_toggle` - Click toggles state

### 2.4 JsonEditorBase Tests

**File:** `tests/unit/editor/test_json_editor_base.gd`
**Estimated Effort:** 1-2 hours
**Can Run Headlessly:** YES

#### Test Cases

1. **JSON File Operations**
   - `test_load_json_file_returns_dictionary` - Valid JSON parsed
   - `test_load_json_file_shows_error_for_invalid_path` - Error handling
   - `test_load_json_file_shows_error_for_invalid_json` - Parse error handling
   - `test_save_json_file_writes_formatted_json` - Tab-indented output
   - `test_save_json_file_returns_false_on_error` - Error handling

2. **Directory Operations**
   - `test_ensure_directory_exists_creates_recursive` - Creates parents
   - `test_ensure_directory_exists_returns_true_for_existing` - No error

3. **Resource Scanning**
   - `test_scan_all_mods_for_resources_returns_array` - Array of dictionaries
   - `test_scan_directory_finds_json_files` - Finds *.json by default
   - `test_scan_directory_respects_file_extension` - Custom extension works

4. **JSON Validation Helpers**
   - `test_validate_json_string_returns_parsed_data` - Valid JSON returns data
   - `test_validate_json_string_returns_null_for_invalid` - Invalid returns null
   - `test_is_valid_json_returns_true_for_empty` - Empty string is valid
   - `test_is_valid_json_returns_true_for_valid` - Valid JSON returns true
   - `test_is_valid_json_returns_false_for_invalid` - Invalid returns false

---

## Priority 3: Editor Component Tests

### 3.1 PartyTemplateEditor Tests

**File:** `tests/unit/editor/test_party_template_editor.gd`
**Estimated Effort:** 2-3 hours
**Can Run Headlessly:** PARTIAL (needs SceneRunner, may need mocked ModLoader)

#### Test Cases

1. **Resource Creation**
   - `test_create_new_resource_returns_party_data` - Correct type
   - `test_create_new_resource_has_default_values` - max_size = 8, empty members

2. **Validation**
   - `test_validate_fails_on_empty_party_name` - Error message
   - `test_validate_fails_on_no_members` - At least one member required
   - `test_validate_passes_with_valid_data` - Happy path

3. **Display Name**
   - `test_get_resource_display_name_shows_count` - "Party (2/8)" format

### 3.2 MapTemplate Tests

**File:** `tests/unit/map/test_map_template.gd`
**Estimated Effort:** 2-3 hours
**Can Run Headlessly:** PARTIAL (needs scene setup and autoloads)

#### Test Cases

1. **Spawn Point Handling**
   - `test_spawn_at_point_teleports_hero` - Uses spawn point position
   - `test_spawn_at_point_sets_facing` - Uses spawn point facing
   - `test_spawn_at_point_returns_false_for_unknown` - Graceful handling
   - `test_spawn_at_default_uses_default_spawn` - Finds default spawn

2. **Transition Context**
   - `test_handle_transition_context_prioritizes_spawn_point` - spawn_point_id first
   - `test_handle_transition_context_falls_back_to_position` - Grid position fallback
   - `test_handle_transition_context_clears_context` - Context cleared after use

3. **Party Follower Setup**
   - `test_setup_party_followers_hides_on_overworld` - caravan_visible check
   - `test_setup_party_followers_creates_followers_in_town` - Creates visible followers

---

## Test Implementation Order

Based on risk and testability, the recommended implementation order is:

### Phase A: Core Registries (Week 1)
1. AIBrainRegistry - New registry, high impact, fully testable headlessly
2. TilesetRegistry - New registry, high impact, fully testable headlessly

### Phase B: Utility Classes (Week 1-2)
3. SparklingEditorUtils - Static methods, easy to test
4. EditorThemeUtils - Mostly testable, some fallbacks
5. JsonEditorBase - File operations, testable with temp files
6. CollapseSection - UI component, needs SceneRunner

### Phase C: Editors (Week 2+)
7. PartyTemplateEditor - Complex, may need mocking
8. MapTemplate - Scene-based, needs careful setup
9. SaveSlotEditor - File system interactions

---

## Test Execution Instructions

### Running Tests Headlessly

```bash
# Run all tests
./godot --headless --script addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/

# Run specific test suite
./godot --headless --script addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit/registries/

# Run single test file
./godot --headless --script addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit/registries/test_ai_brain_registry.gd
```

### Running from Godot Editor

1. Open the GdUnit4 panel (bottom dock)
2. Click "Run All Tests" or right-click specific test to run

### Test Report Location

Test results are written to `/reports/` directory in JUnit XML format.

---

## Recommendations for Improving Testability

1. **Dependency Injection for ModLoader**: Consider adding optional ModLoader parameter to registry constructors to enable testing without autoload.

2. **Interface Extraction**: Extract interfaces for registries to enable mock implementations in tests.

3. **Test Fixtures Directory**: Create `tests/fixtures/` with sample mod.json files and resource files for consistent test data.

4. **Scene Testing Helpers**: Create utility functions for common scene setup patterns used across tests.

5. **Mock Autoloads**: Implement a MockAutoload pattern that can stand in for GameState, PartyManager, etc. during tests.

---

## Appendix: Test File Naming Convention

Following existing project patterns:

- Test files: `test_<component_name>.gd`
- Test class names: `Test<ComponentName>` (PascalCase)
- Test methods: `test_<behavior_description>` (snake_case)
- Test directories mirror source directories where practical

---

## Sign-Off

"Remember, Captain, a ship without tests is like a starship without shields - it may look impressive, but it will not survive first contact with production."

-- Major Testo, Reliability Officer
