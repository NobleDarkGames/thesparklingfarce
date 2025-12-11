# Mod System Hardening - Phase 2 Plan

**Version**: 1.0.0
**Date**: 2025-12-11
**Author**: Lt. Claudbrain
**Status**: Proposed
**Prerequisite**: Phase 1 complete (mod-system-hardening-plan.md)

---

## Executive Summary

This plan addresses 20 issues from the second comprehensive mod system audit, organized into 6 implementation sub-phases. Unlike Phase 1's focus on security and extensibility foundations, Phase 2 targets **robustness, reliability, and infrastructure** needed for a production-quality modding platform.

**Total Estimated Effort**: 12-16 days
**Breaking Changes**: None (all changes are backwards compatible)
**Critical Path**: Sub-Phase 2A must complete first; others can partially parallelize

---

## Modder Persona Impact Summary

| Persona | Current Score | After Phase 2 | Key Improvements |
|---------|---------------|---------------|------------------|
| Accessibility Modder | 2/10 | 6/10 | SettingsManager (#11), UI Theme foundation (#12) |
| Competitive Modder | 2/10 | 7/10 | RandomManager (#5), atomic saves (#2), mod tracking (#3) |
| Localization Modder | 3/10 | 5/10 | Localization infrastructure foundation (#14) |
| Narrative Modder | 7/10 | 9/10 | Portrait path fix (#9), dialog race fix (#20) |
| Retro Modder | 5/10 | 7/10 | GameEventBus foundation (#13) |

---

## Sub-Phase Dependencies

```
Sub-Phase 2A (Critical Fixes)
       |
       v
Sub-Phase 2B (Save System) --> Sub-Phase 2C (State Management)
       |                              |
       v                              v
Sub-Phase 2D (Audio/UI)       Sub-Phase 2E (Infrastructure)
       |                              |
       +----------+-------------------+
                  |
                  v
        Sub-Phase 2F (Polish)
```

---

## Sub-Phase 2A: Critical Fixes (P0)

**Goal**: Fix issues that could ship broken experiences to players
**Estimated Effort**: 0.5 days
**Risk Level**: Very Low (minimal changes, high impact)
**Blocking Issues**: None
**Persona Impact**: All players/modders benefit immediately

### 2A.1 Debug Q-Key Quit Protection

**Issue #1**: Global Q key quits the game in production builds.

**File**: `core/systems/game_state.gd` lines 89-92

**Current Code**:
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_Q:
            get_tree().quit()
```

**Fixed Code**:
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    # Debug convenience: Q key quits game (development only)
    if OS.has_feature("debug"):
        if event is InputEventKey and event.pressed and not event.echo:
            if event.keycode == KEY_Q:
                get_tree().quit()
```

**Testing Requirements**:
- Manual test: Q key quits in editor
- Manual test: Q key does NOT quit in release export

**Effort**: 5 minutes

---

### 2A.2 Null Current Scene Guard

**Issue #8**: `get_tree().current_scene.scene_file_path` crashes if no scene loaded.

**File**: `core/systems/trigger_manager.gd` line 207

**Current Code**:
```gdscript
context.return_scene_path = get_tree().current_scene.scene_file_path
```

**Fixed Code**:
```gdscript
var current_scene: Node = get_tree().current_scene
if current_scene:
    context.return_scene_path = current_scene.scene_file_path
else:
    push_error("TriggerManager: No current scene when creating transition context")
    context.return_scene_path = ""
```

**Testing Requirements**:
- Unit test: No crash when current_scene is null
- Integration test: Normal battle trigger still works

**Effort**: 5 minutes

---

### 2A.3 Campaign Recovery Counter Reset

**Issue #19**: `_recovery_attempts` not reset on successful node entry.

**File**: `core/systems/campaign_manager.gd` around line 305

**Current Code** (in `enter_node()`, after successful processing):
```gdscript
# Process node based on type
_process_node(node)

return true
```

**Fixed Code**:
```gdscript
# Reset recovery counter on successful entry
_recovery_attempts = 0

# Process node based on type
_process_node(node)

return true
```

**Testing Requirements**:
- Unit test: Recovery counter resets after successful node entry
- Unit test: Failed entries still increment counter

**Effort**: 5 minutes

---

## Sub-Phase 2B: Save System Hardening (P0)

**Goal**: Prevent save corruption and ensure mod compatibility tracking
**Estimated Effort**: 2 days
**Risk Level**: Medium (touches critical persistence layer)
**Blocking Issues**: Sub-Phase 2A
**Persona Impact**: Competitive Modder (critical), all modders (high)

### 2B.1 Atomic Save Writes

**Issue #2**: Direct file write during save - crash corrupts the file.

**File**: `core/systems/save_manager.gd` lines 116-125

**Current Code**:
```gdscript
# Write to file
var file_path: String = _get_slot_file_path(slot_number)
var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)

if not file:
    push_error("SaveManager: Failed to open file for writing: %s" % file_path)
    save_completed.emit(slot_number, false)
    return false

file.store_string(json_string)
file.close()
```

**Fixed Code**:
```gdscript
# Write to temporary file first (atomic write pattern)
var file_path: String = _get_slot_file_path(slot_number)
var temp_path: String = file_path + ".tmp"
var backup_path: String = file_path + ".bak"

# Step 1: Write to temp file
var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
if not file:
    push_error("SaveManager: Failed to open temp file for writing: %s" % temp_path)
    save_completed.emit(slot_number, false)
    return false

file.store_string(json_string)
file.close()

# Verify temp file was written correctly
if not FileAccess.file_exists(temp_path):
    push_error("SaveManager: Temp file not created: %s" % temp_path)
    save_completed.emit(slot_number, false)
    return false

# Step 2: Create backup of existing save (if exists)
var dir: DirAccess = DirAccess.open(SAVE_DIRECTORY)
if not dir:
    push_error("SaveManager: Cannot open save directory")
    save_completed.emit(slot_number, false)
    return false

if FileAccess.file_exists(file_path):
    # Remove old backup if exists
    if FileAccess.file_exists(backup_path):
        dir.remove(backup_path)
    # Rename current save to backup
    var rename_err: Error = dir.rename(file_path, backup_path)
    if rename_err != OK:
        push_error("SaveManager: Failed to create backup: %d" % rename_err)
        # Continue anyway - temp file is still valid

# Step 3: Atomic rename - temp to final
var final_err: Error = dir.rename(temp_path, file_path)
if final_err != OK:
    push_error("SaveManager: Failed atomic rename: %d" % final_err)
    # Try to restore backup
    if FileAccess.file_exists(backup_path):
        dir.rename(backup_path, file_path)
    save_completed.emit(slot_number, false)
    return false

# Step 4: Remove backup (success)
if FileAccess.file_exists(backup_path):
    dir.remove(backup_path)
```

**Also update `_save_metadata_file()`** with same atomic pattern.

**Testing Requirements**:
- Unit test: Normal save works with atomic pattern
- Unit test: Simulated crash (delete temp mid-write) preserves old save
- Unit test: Backup file created and removed correctly
- Integration test: Multiple rapid saves don't corrupt

**Effort**: 0.5 day

---

### 2B.2 Save File Mod Dependency Tracking

**Issue #3**: Items/characters stored as IDs without mod source. Disabling mod = crashes.

**File**: `core/resources/save_data.gd` and `core/resources/character_save_data.gd`

**Implementation Strategy**:

1. **SaveData Enhancement** - Add mod validation on load:

Add to `save_data.gd` after `deserialize_from_dict()`:

```gdscript
## Validate that all referenced mods are still loaded
## Returns Dictionary with:
##   valid: bool - true if all mods present
##   missing_mods: Array[String] - list of missing mod IDs
##   orphaned_items: Array[String] - items from missing mods
##   orphaned_characters: Array[String] - characters from missing mods
func validate_mod_dependencies() -> Dictionary:
    var result: Dictionary = {
        "valid": true,
        "missing_mods": [],
        "orphaned_items": [],
        "orphaned_characters": []
    }

    # Get currently loaded mod IDs
    var loaded_mods: Array[String] = []
    if ModLoader:
        for mod: ModManifest in ModLoader.get_all_mods():
            loaded_mods.append(mod.mod_id)

    # Check active_mods against loaded mods
    for mod_info: Dictionary in active_mods:
        var mod_id: String = mod_info.get("mod_id", "")
        if not mod_id.is_empty() and mod_id not in loaded_mods:
            result["missing_mods"].append(mod_id)
            result["valid"] = false

    # Check inventory items
    for item_dict: Dictionary in inventory:
        var item_mod_id: String = item_dict.get("mod_id", "_base_game")
        if item_mod_id not in loaded_mods:
            result["orphaned_items"].append(item_dict.get("item_id", "unknown"))
            if item_mod_id not in result["missing_mods"]:
                result["missing_mods"].append(item_mod_id)
            result["valid"] = false

    # Check depot items (need to resolve mod source)
    for item_id: String in depot_items:
        if not ModLoader.registry.has_resource("item", item_id):
            result["orphaned_items"].append(item_id)
            result["valid"] = false

    # Check party members
    for char_save: CharacterSaveData in party_members:
        if not char_save.character_mod_id.is_empty():
            if char_save.character_mod_id not in loaded_mods:
                result["orphaned_characters"].append(char_save.fallback_character_name)
                if char_save.character_mod_id not in result["missing_mods"]:
                    result["missing_mods"].append(char_save.character_mod_id)
                result["valid"] = false

    return result
```

2. **SaveManager Integration** - Graceful degradation on load:

Add to `load_from_slot()` after deserialization:

```gdscript
# Validate mod dependencies
var mod_check: Dictionary = save_data.validate_mod_dependencies()
if not mod_check["valid"]:
    push_warning("SaveManager: Save file has missing mod dependencies:")
    for mod_id: String in mod_check["missing_mods"]:
        push_warning("  - Missing mod: %s" % mod_id)
    for item_id: String in mod_check["orphaned_items"]:
        push_warning("  - Orphaned item: %s (will be removed)" % item_id)
    for char_name: String in mod_check["orphaned_characters"]:
        push_warning("  - Orphaned character: %s (will be removed)" % char_name)

    # Clean up orphaned data
    save_data.remove_orphaned_content(mod_check)
```

3. **SaveData Cleanup Method**:

```gdscript
## Remove content from mods that are no longer loaded
func remove_orphaned_content(mod_check: Dictionary) -> void:
    # Remove orphaned inventory items
    var valid_inventory: Array[Dictionary] = []
    for item_dict: Dictionary in inventory:
        var item_id: String = item_dict.get("item_id", "")
        if item_id not in mod_check["orphaned_items"]:
            valid_inventory.append(item_dict)
    inventory = valid_inventory

    # Remove orphaned depot items
    var valid_depot: Array[String] = []
    for item_id: String in depot_items:
        if item_id not in mod_check["orphaned_items"]:
            valid_depot.append(item_id)
    depot_items = valid_depot

    # Remove orphaned party members (keep in reserve with warning)
    var valid_party: Array[CharacterSaveData] = []
    for char_save: CharacterSaveData in party_members:
        if char_save.fallback_character_name not in mod_check["orphaned_characters"]:
            valid_party.append(char_save)
    party_members = valid_party

    # Same for reserve_members
    var valid_reserve: Array[CharacterSaveData] = []
    for char_save: CharacterSaveData in reserve_members:
        if char_save.fallback_character_name not in mod_check["orphaned_characters"]:
            valid_reserve.append(char_save)
    reserve_members = valid_reserve
```

4. **SlotMetadata Enhancement** - Show mod mismatch in UI:

Add to `slot_metadata.gd`:

```gdscript
## True if this save has content from mods that are no longer loaded
@export var has_mod_mismatch: bool = false

## List of missing mod IDs (for display in UI)
@export var missing_mod_ids: Array[String] = []
```

Update `_update_metadata_for_slot()` in save_manager.gd to populate these fields.

**Testing Requirements**:
- Unit test: Save with all mods present validates successfully
- Unit test: Save with missing mod detected
- Unit test: Orphaned items cleaned up gracefully
- Unit test: Orphaned characters cleaned up gracefully
- Integration test: UI shows warning for saves with mod mismatch
- Manual test: Can still load and play save after disabling a mod

**Effort**: 1-1.5 days

---

### 2B.3 Save Data Type Validation

**Issue #17**: JSON values not type-checked during deserialization.

**File**: `core/resources/save_data.gd`

**Implementation**: Add type coercion helpers and apply throughout `deserialize_from_dict()`:

```gdscript
## Safe integer extraction from JSON (handles float conversion)
static func _safe_int(value: Variant, default: int = 0) -> int:
    if value is int:
        return value
    if value is float:
        return int(value)
    if value is String and value.is_valid_int():
        return value.to_int()
    return default


## Safe string extraction from JSON
static func _safe_string(value: Variant, default: String = "") -> String:
    if value is String:
        return value
    if value != null:
        return str(value)
    return default


## Safe bool extraction from JSON
static func _safe_bool(value: Variant, default: bool = false) -> bool:
    if value is bool:
        return value
    if value is int:
        return value != 0
    if value is String:
        return value.to_lower() in ["true", "1", "yes"]
    return default
```

**Update deserialization** (example):
```gdscript
# Before:
if "gold" in data:
    gold = data.gold

# After:
if "gold" in data:
    gold = _safe_int(data.gold, 0)
    if gold < 0:
        push_warning("SaveData: Negative gold value corrected to 0")
        gold = 0
```

Apply similar pattern to all fields in `deserialize_from_dict()`.

**Testing Requirements**:
- Unit test: Integer fields handle float JSON values
- Unit test: Negative values clamped appropriately
- Unit test: String values in numeric fields handled
- Unit test: Null values use defaults

**Effort**: 0.5 day

---

## Sub-Phase 2C: State Management Hardening (P0-P1)

**Goal**: Prevent flag collisions and state corruption
**Estimated Effort**: 1 day
**Risk Level**: Low (additive API, backwards compatible)
**Blocking Issues**: Sub-Phase 2A
**Persona Impact**: All modders (medium)

### 2C.1 Enforced Flag Namespacing

**Issue #4**: Two mods using same flag name overwrite each other silently.

**File**: `core/systems/game_state.gd`

**Implementation Strategy**: Add validation/warning mode (non-breaking), then enforce in strict mode.

```gdscript
## Flag namespacing enforcement mode
enum NamespaceMode {
    PERMISSIVE,  ## No enforcement, just warnings (default for backwards compatibility)
    STRICT       ## Reject non-namespaced flags from mods
}

var namespace_mode: NamespaceMode = NamespaceMode.PERMISSIVE

## Track which mod set each flag (for conflict detection)
var _flag_sources: Dictionary = {}  # flag_name -> mod_id


## Enhanced set_flag with source tracking
func set_flag(flag_name: String, value: bool = true, source_mod_id: String = "") -> void:
    # Namespace validation
    if not flag_name.is_empty():
        var is_namespaced: bool = ":" in flag_name

        # Detect potential conflicts
        if flag_name in _flag_sources and _flag_sources[flag_name] != source_mod_id:
            var original_source: String = _flag_sources[flag_name]
            push_warning("GameState: Flag '%s' being set by '%s' was originally set by '%s'" % [
                flag_name, source_mod_id if not source_mod_id.is_empty() else "unknown", original_source
            ])

        # Warn about non-namespaced flags from mods
        if not is_namespaced and not source_mod_id.is_empty() and source_mod_id != "_base_game":
            if namespace_mode == NamespaceMode.STRICT:
                push_error("GameState: STRICT mode - rejected non-namespaced flag '%s' from mod '%s'" % [
                    flag_name, source_mod_id
                ])
                return
            else:
                push_warning("GameState: Flag '%s' from mod '%s' should be namespaced as '%s:%s'" % [
                    flag_name, source_mod_id, source_mod_id, flag_name
                ])

    # Track source
    if not source_mod_id.is_empty():
        _flag_sources[flag_name] = source_mod_id

    # Existing logic
    if story_flags.get(flag_name) == value:
        return

    story_flags[flag_name] = value
    flag_changed.emit(flag_name, value)


## Enable strict namespace enforcement (call from mod's _ready or test setup)
func enable_strict_namespacing() -> void:
    namespace_mode = NamespaceMode.STRICT
    push_warning("GameState: Strict namespace mode enabled - non-namespaced mod flags will be rejected")


## Get all flags that appear to have conflicts (for debugging/editor)
func get_potential_flag_conflicts() -> Array[String]:
    var conflicts: Array[String] = []
    var seen_short_names: Dictionary = {}  # short_name -> [full_names]

    for flag_name: String in story_flags:
        var short_name: String = flag_name
        if ":" in flag_name:
            short_name = flag_name.split(":")[1]

        if short_name not in seen_short_names:
            seen_short_names[short_name] = []
        seen_short_names[short_name].append(flag_name)

    # Find short names used by multiple full names
    for short_name: String in seen_short_names:
        var full_names: Array = seen_short_names[short_name]
        if full_names.size() > 1:
            for full_name: String in full_names:
                if full_name not in conflicts:
                    conflicts.append(full_name)

    return conflicts
```

**Testing Requirements**:
- Unit test: Non-namespaced flag from base game works (permissive mode)
- Unit test: Non-namespaced flag from mod emits warning (permissive mode)
- Unit test: Non-namespaced flag from mod rejected (strict mode)
- Unit test: Conflict detection identifies same short name from different mods

**Effort**: 0.5 day

---

### 2C.2 GameState Import Validation

**Issue #18**: `import_state()` blindly copies dictionaries.

**File**: `core/systems/game_state.gd` lines 260-263

**Current Code**:
```gdscript
func import_state(state: Dictionary) -> void:
    story_flags = state.get("story_flags", {}).duplicate()
    completed_triggers = state.get("completed_triggers", {}).duplicate()
    campaign_data = state.get("campaign_data", {}).duplicate()
```

**Fixed Code**:
```gdscript
func import_state(state: Dictionary) -> void:
    # Validate story_flags structure
    var imported_flags: Variant = state.get("story_flags", {})
    if imported_flags is Dictionary:
        story_flags.clear()
        for key: Variant in imported_flags:
            if key is String:
                var value: Variant = imported_flags[key]
                if value is bool:
                    story_flags[key] = value
                else:
                    push_warning("GameState: Skipping invalid flag value for '%s' (expected bool)" % key)
            else:
                push_warning("GameState: Skipping non-string flag key")
    else:
        push_warning("GameState: story_flags is not a Dictionary, using empty")
        story_flags.clear()

    # Validate completed_triggers structure
    var imported_triggers: Variant = state.get("completed_triggers", {})
    if imported_triggers is Dictionary:
        completed_triggers.clear()
        for key: Variant in imported_triggers:
            if key is String:
                completed_triggers[key] = true  # Normalize to bool
            else:
                push_warning("GameState: Skipping non-string trigger key")
    else:
        push_warning("GameState: completed_triggers is not a Dictionary, using empty")
        completed_triggers.clear()

    # Validate campaign_data structure (more permissive - allows various value types)
    var imported_campaign: Variant = state.get("campaign_data", {})
    if imported_campaign is Dictionary:
        campaign_data = imported_campaign.duplicate()
    else:
        push_warning("GameState: campaign_data is not a Dictionary, using defaults")
        campaign_data = {
            "current_chapter": 0,
            "battles_won": 0,
            "treasures_found": 0,
        }
```

**Testing Requirements**:
- Unit test: Valid state imports correctly
- Unit test: Non-dictionary flags handled gracefully
- Unit test: Non-bool flag values rejected
- Unit test: Non-string keys rejected

**Effort**: 0.25 day

---

### 2C.3 Party Size Validation

**Issue #10**: Mod changes party size limit, existing save has more members than allowed.

**File**: `core/systems/party_manager.gd`

**Implementation**: Add validation called after mod load and save load.

```gdscript
## Validate and enforce party size limits
## Called after mod load or save load
## Returns Dictionary with:
##   adjusted: bool - true if party was modified
##   moved_to_reserve: Array[String] - character names moved to reserve
func validate_party_size() -> Dictionary:
    var result: Dictionary = {
        "adjusted": false,
        "moved_to_reserve": []
    }

    # Get current limit (may have changed due to mod)
    var max_size: int = MAX_ACTIVE_SIZE
    if ModLoader and ModLoader.party_config:
        max_size = ModLoader.party_config.get_max_active_size()

    # Check if active party exceeds limit
    if party_members.size() <= max_size:
        return result

    # Move excess members to reserve
    var excess_count: int = party_members.size() - max_size
    push_warning("PartyManager: Active party size (%d) exceeds limit (%d), moving %d to reserve" % [
        party_members.size(), max_size, excess_count
    ])

    # Move from end of active party (preserve hero at index 0)
    for i in range(excess_count):
        var move_idx: int = max_size  # Always move the first one past the limit
        if move_idx < party_members.size():
            var character: CharacterData = party_members[move_idx]
            result["moved_to_reserve"].append(character.character_name)
            party_members.remove_at(move_idx)
            # Add to reserve (at start so they're easy to bring back)
            party_members.append(character)  # Goes to reserve section

    result["adjusted"] = true
    return result
```

**Call from SaveManager after load**:
```gdscript
# After loading party data
var party_check: Dictionary = PartyManager.validate_party_size()
if party_check["adjusted"]:
    push_warning("SaveManager: Party size adjusted for current mod configuration")
    for char_name: String in party_check["moved_to_reserve"]:
        push_warning("  - Moved to reserve: %s" % char_name)
```

**Testing Requirements**:
- Unit test: Party within limit unchanged
- Unit test: Oversized party correctly trimmed
- Unit test: Hero never moved to reserve
- Unit test: Moved characters appear in reserve

**Effort**: 0.25 day

---

## Sub-Phase 2D: Audio and Asset Fixes (P1)

**Goal**: Fix race conditions and asset resolution issues
**Estimated Effort**: 1 day
**Risk Level**: Low (bug fixes with clear boundaries)
**Blocking Issues**: Sub-Phase 2A
**Persona Impact**: Narrative Modder (high), all modders (medium)

### 2D.1 Music Crossfade Race Condition

**Issue #7**: Rapid `play_music()` calls can race during fade.

**File**: `core/systems/audio_manager.gd` lines 106-131

**Implementation**:

```gdscript
## Track music transition state
var _music_transition_in_progress: bool = false
var _pending_music_request: Dictionary = {}  # {name: String, fade_in: float}


## Play background music from the current mod (loops automatically)
## @param music_name: Name of the music file (without extension)
## @param fade_in_duration: Duration of fade-in effect in seconds (default: 0.5)
func play_music(music_name: String, fade_in_duration: float = 0.5) -> void:
    # If transition in progress, queue this request
    if _music_transition_in_progress:
        _pending_music_request = {"name": music_name, "fade_in": fade_in_duration}
        return

    var stream: AudioStream = _load_audio(music_name, "music")
    if not stream:
        return  # Music file not found, fail silently

    # Check if already playing this track
    if _music_player.playing and _music_player.stream == stream:
        return  # Already playing requested music

    _music_transition_in_progress = true

    # Stop current music if playing
    if _music_player.playing:
        await _fade_out_music(fade_in_duration * 0.5)

    # Set up new music
    _music_player.stream = stream
    _music_player.volume_db = linear_to_db(0.0)  # Start silent for fade-in
    _music_player.play()

    # Fade in
    if fade_in_duration > 0.0:
        await _fade_in_music(fade_in_duration)
    else:
        _music_player.volume_db = linear_to_db(music_volume)

    _music_transition_in_progress = false

    # Process any pending request
    if not _pending_music_request.is_empty():
        var pending: Dictionary = _pending_music_request
        _pending_music_request = {}
        play_music(pending["name"], pending["fade_in"])


## Internal fade out helper
func _fade_out_music(duration: float) -> void:
    var tween: Tween = create_tween()
    tween.tween_method(
        func(vol: float) -> void: _music_player.volume_db = linear_to_db(vol),
        music_volume,
        0.0,
        duration
    )
    await tween.finished
    _music_player.stop()


## Internal fade in helper
func _fade_in_music(duration: float) -> void:
    var tween: Tween = create_tween()
    tween.tween_method(
        func(vol: float) -> void: _music_player.volume_db = linear_to_db(vol),
        0.0,
        music_volume,
        duration
    )
    await tween.finished
```

**Testing Requirements**:
- Unit test: Single play_music call works
- Unit test: Rapid calls don't crash
- Unit test: Most recent request is honored
- Manual test: No audio glitches during rapid scene changes

**Effort**: 0.25 day

---

### 2D.2 Portrait Path ModLoader Integration

**Issue #9**: Hardcoded portrait search paths bypass asset override system.

**File**: `scenes/ui/dialog_box.gd` lines 156-159

**Current Code**:
```gdscript
var search_paths: Array[String] = [
    "res://mods/_base_game/assets/portraits/%s" % portrait_filename,
    "res://assets/portraits/%s" % portrait_filename,
]
```

**Fixed Code**:
```gdscript
## Try to load portrait variant based on speaker name and emotion
## Uses ModLoader's asset override system for proper mod support
func _try_load_portrait_variant(speaker_name: String, emotion: String) -> Texture2D:
    # Normalize speaker name (lowercase, remove spaces)
    var normalized_speaker: String = speaker_name.to_lower().replace(" ", "_")
    var normalized_emotion: String = emotion.to_lower()

    # Build relative asset path
    var portrait_filename: String = "%s_%s.png" % [normalized_speaker, normalized_emotion]
    var relative_path: String = "portraits/%s" % portrait_filename

    # Use ModLoader's asset override system
    if ModLoader:
        var resolved_path: String = ModLoader.resolve_asset_path(relative_path, "res://mods/_base_game/assets/")
        if not resolved_path.is_empty():
            var portrait: Texture2D = load(resolved_path) as Texture2D
            if portrait:
                return portrait

    # Fallback: try without emotion (just speaker name)
    var fallback_filename: String = "%s.png" % normalized_speaker
    var fallback_relative: String = "portraits/%s" % fallback_filename

    if ModLoader:
        var fallback_path: String = ModLoader.resolve_asset_path(fallback_relative, "res://mods/_base_game/assets/")
        if not fallback_path.is_empty():
            var portrait: Texture2D = load(fallback_path) as Texture2D
            if portrait:
                return portrait

    # No portrait found
    return null
```

**Note**: This depends on `ModLoader.resolve_asset_path()` from Phase 1 (Issue #6, Section 2.2).

**Testing Requirements**:
- Unit test: Base game portraits load
- Unit test: Mod override portrait takes precedence
- Integration test: Dialog box shows mod's portrait

**Effort**: 0.25 day

---

### 2D.3 Scene Cache Clear on Mod Reload

**Issue #6**: Hot-reloaded mod scenes not reflected until restart.

**File**: `core/systems/battle_manager.gd` lines 87-93

**Current Code**:
```gdscript
## Clear cached scenes (called when mods reload to pick up new overrides)
func clear_scene_cache() -> void:
    _unit_scene = null
    # ... etc
```

**Implementation**: Connect to ModLoader signal automatically.

Add to `battle_manager.gd` in `_ready()` (or initialization):

```gdscript
func _ready() -> void:
    # Clear scene cache when mods reload (for hot-reload support)
    if ModLoader:
        if not ModLoader.mods_reloaded.is_connected(clear_scene_cache):
            ModLoader.mods_reloaded.connect(clear_scene_cache)
```

**Also check** if `ModLoader.mods_reloaded` signal exists. If not, add to `mod_loader.gd`:

```gdscript
## Emitted when mods are reloaded (for cache invalidation)
signal mods_reloaded()
```

Emit this signal at end of `reload_mods()` or equivalent function.

**Testing Requirements**:
- Manual test: Modify scene in mod, reload mods, see new scene in battle
- Unit test: Signal connected without duplicate connections

**Effort**: 0.25 day

---

### 2D.4 Dialog State Race Fix

**Issue #20**: Dialog signal can race with skip.

**File**: `core/systems/cinematics_manager.gd` lines 362-366

**Current Code**:
```gdscript
func _on_dialog_ended(dialogue_data: DialogueData) -> void:
    if current_state == State.WAITING_FOR_DIALOG:
        current_state = State.PLAYING
        _is_waiting = false
        _command_completed = true
```

**Fixed Code**:
```gdscript
func _on_dialog_ended(dialogue_data: DialogueData) -> void:
    # Guard against race with skip
    if current_state == State.IDLE or current_state == State.SKIPPING:
        return  # Already ended or being skipped

    if current_state == State.WAITING_FOR_DIALOG:
        current_state = State.PLAYING
        _is_waiting = false
        _command_completed = true
```

**Also update `skip_cinematic()`** to disconnect dialog signal:

```gdscript
func skip_cinematic() -> void:
    if current_state == State.IDLE:
        return

    if current_cinematic and not current_cinematic.can_skip:
        push_warning("CinematicsManager: Current cinematic cannot be skipped")
        return

    # Disconnect dialog signals to prevent race
    if DialogManager and DialogManager.dialog_ended.is_connected(_on_dialog_ended):
        DialogManager.dialog_ended.disconnect(_on_dialog_ended)

    # Interrupt any active async executor
    if _current_executor:
        _current_executor.interrupt()
        _current_executor = null

    emit_signal("cinematic_skipped")
    _end_cinematic()
```

**And reconnect in `_end_cinematic()`**:
```gdscript
func _end_cinematic() -> void:
    # ... existing cleanup ...

    # Reconnect dialog signal for next cinematic
    if DialogManager and not DialogManager.dialog_ended.is_connected(_on_dialog_ended):
        DialogManager.dialog_ended.connect(_on_dialog_ended)
```

**Testing Requirements**:
- Manual test: Rapidly skip during dialog doesn't crash
- Unit test: Skip during WAITING_FOR_DIALOG state handled cleanly

**Effort**: 0.25 day

---

## Sub-Phase 2E: Infrastructure Systems (P1-P2)

**Goal**: Add foundational systems needed by multiple modder personas
**Estimated Effort**: 5-7 days
**Risk Level**: Medium (new systems, but isolated)
**Blocking Issues**: Sub-Phase 2A
**Persona Impact**: Accessibility (critical), Competitive (high), all modders (medium)

### 2E.1 RandomManager Singleton

**Issue #5**: 23 `randi`/`randf` calls throughout codebase prevent deterministic replays.

**New File**: `core/systems/random_manager.gd`

```gdscript
extends Node

## RandomManager - Centralized random number generation with controllable seeds
##
## Provides named random streams for different game systems.
## Allows deterministic replays when seed is set at game start.
##
## Usage:
##   RandomManager.randi_combat()      # Combat-related random
##   RandomManager.randf_movement()    # Movement-related random
##   RandomManager.set_seeds(12345)    # Set all seeds for replay

## Named random streams
var _combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _movement_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _general_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Master seed (if set, used to derive all other seeds)
var _master_seed: int = 0
var _is_seeded: bool = false

## Signals for replay systems
signal seeds_set(master_seed: int)
signal random_used(stream: String, result: int)


func _ready() -> void:
    # Default: randomize all streams
    randomize_all()


## Set master seed (deterministic mode)
## Derives individual stream seeds from master
func set_master_seed(seed_value: int) -> void:
    _master_seed = seed_value
    _is_seeded = true

    # Derive stream seeds from master (simple offset)
    _combat_rng.seed = seed_value
    _movement_rng.seed = seed_value + 1000
    _loot_rng.seed = seed_value + 2000
    _general_rng.seed = seed_value + 3000

    seeds_set.emit(seed_value)


## Randomize all streams (non-deterministic mode)
func randomize_all() -> void:
    _combat_rng.randomize()
    _movement_rng.randomize()
    _loot_rng.randomize()
    _general_rng.randomize()
    _is_seeded = false


## Check if deterministic mode is active
func is_seeded() -> bool:
    return _is_seeded


## Get the master seed (0 if not seeded)
func get_master_seed() -> int:
    return _master_seed if _is_seeded else 0


# ==== Combat Stream ====

func randi_combat() -> int:
    return _combat_rng.randi()

func randi_range_combat(from: int, to: int) -> int:
    return _combat_rng.randi_range(from, to)

func randf_combat() -> float:
    return _combat_rng.randf()

func randf_range_combat(from: float, to: float) -> float:
    return _combat_rng.randf_range(from, to)


# ==== Movement Stream ====

func randi_movement() -> int:
    return _movement_rng.randi()

func randi_range_movement(from: int, to: int) -> int:
    return _movement_rng.randi_range(from, to)


# ==== Loot Stream ====

func randi_loot() -> int:
    return _loot_rng.randi()

func randi_range_loot(from: int, to: int) -> int:
    return _loot_rng.randi_range(from, to)


# ==== General Stream (UI, effects, non-gameplay) ====

func randi_general() -> int:
    return _general_rng.randi()

func randi_range_general(from: int, to: int) -> int:
    return _general_rng.randi_range(from, to)

func randf_general() -> float:
    return _general_rng.randf()


## Save RNG state (for save/load)
func export_state() -> Dictionary:
    return {
        "master_seed": _master_seed,
        "is_seeded": _is_seeded,
        "combat_state": _combat_rng.state,
        "movement_state": _movement_rng.state,
        "loot_state": _loot_rng.state,
        "general_state": _general_rng.state,
    }


## Restore RNG state (for save/load)
func import_state(state: Dictionary) -> void:
    _master_seed = state.get("master_seed", 0)
    _is_seeded = state.get("is_seeded", false)
    _combat_rng.state = state.get("combat_state", 0)
    _movement_rng.state = state.get("movement_state", 0)
    _loot_rng.state = state.get("loot_state", 0)
    _general_rng.state = state.get("general_state", 0)
```

**Migration**: Update existing `randi`/`randf` calls to use appropriate stream:

| File | Current | Replacement |
|------|---------|-------------|
| `combat_calculator.gd` | `randi_range(1, 100)` | `RandomManager.randi_range_combat(1, 100)` |
| `battle_manager.gd` | `randi_range(1, 100)` | `RandomManager.randi_range_combat(1, 100)` |
| `ai_*.gd` | `randi()` | `RandomManager.randi_movement()` |
| UI/visual effects | `randf()` | `RandomManager.randf_general()` |

**Testing Requirements**:
- Unit test: Same seed produces same sequence
- Unit test: Different streams are independent
- Unit test: State export/import restores sequence
- Integration test: Battle with seed is deterministic

**Effort**: 1 day

---

### 2E.2 SettingsManager Foundation

**Issue #11**: No way to add user preferences, accessibility options, or mod settings.

**New File**: `core/systems/settings_manager.gd`

```gdscript
extends Node

## SettingsManager - User preferences and mod settings
##
## Provides centralized settings storage with:
## - Engine settings (volume, display)
## - Accessibility options (text speed, screen shake)
## - Mod-extensible settings registration
##
## Settings persisted to user://settings.cfg

const SETTINGS_FILE: String = "user://settings.cfg"

## Core setting categories
enum Category {
    AUDIO,
    DISPLAY,
    ACCESSIBILITY,
    GAMEPLAY,
    MOD  # Mod-registered settings
}

## Signals
signal setting_changed(category: Category, key: String, value: Variant)
signal settings_loaded()
signal settings_saved()

## Settings storage
var _settings: Dictionary = {}

## Registered setting definitions (for validation and UI generation)
var _setting_definitions: Dictionary = {}  # "category:key" -> SettingDefinition

## Mod-registered settings
var _mod_settings: Dictionary = {}  # mod_id -> {key -> value}


func _ready() -> void:
    _register_core_settings()
    load_settings()


## Register all core engine settings
func _register_core_settings() -> void:
    # Audio
    register_setting(Category.AUDIO, "master_volume", {
        "type": TYPE_FLOAT,
        "default": 1.0,
        "min": 0.0,
        "max": 1.0,
        "display_name": "Master Volume"
    })
    register_setting(Category.AUDIO, "music_volume", {
        "type": TYPE_FLOAT,
        "default": 0.7,
        "min": 0.0,
        "max": 1.0,
        "display_name": "Music Volume"
    })
    register_setting(Category.AUDIO, "sfx_volume", {
        "type": TYPE_FLOAT,
        "default": 0.8,
        "min": 0.0,
        "max": 1.0,
        "display_name": "Sound Effects"
    })

    # Accessibility
    register_setting(Category.ACCESSIBILITY, "text_speed", {
        "type": TYPE_FLOAT,
        "default": 1.0,
        "min": 0.5,
        "max": 3.0,
        "display_name": "Text Speed"
    })
    register_setting(Category.ACCESSIBILITY, "screen_shake_enabled", {
        "type": TYPE_BOOL,
        "default": true,
        "display_name": "Screen Shake"
    })
    register_setting(Category.ACCESSIBILITY, "screen_shake_intensity", {
        "type": TYPE_FLOAT,
        "default": 1.0,
        "min": 0.0,
        "max": 2.0,
        "display_name": "Shake Intensity"
    })
    register_setting(Category.ACCESSIBILITY, "combat_animation_speed", {
        "type": TYPE_FLOAT,
        "default": 1.0,
        "min": 0.5,
        "max": 4.0,
        "display_name": "Combat Speed"
    })

    # Gameplay
    register_setting(Category.GAMEPLAY, "auto_end_turn", {
        "type": TYPE_BOOL,
        "default": true,
        "display_name": "Auto End Turn"
    })
    register_setting(Category.GAMEPLAY, "confirm_move", {
        "type": TYPE_BOOL,
        "default": false,
        "display_name": "Confirm Movement"
    })


## Register a setting definition
func register_setting(category: Category, key: String, definition: Dictionary) -> void:
    var full_key: String = "%d:%s" % [category, key]
    _setting_definitions[full_key] = definition

    # Initialize with default if not already set
    if category not in _settings:
        _settings[category] = {}
    if key not in _settings[category]:
        _settings[category][key] = definition.get("default")


## Get a setting value
func get_setting(category: Category, key: String) -> Variant:
    if category in _settings and key in _settings[category]:
        return _settings[category][key]

    # Return default from definition
    var full_key: String = "%d:%s" % [category, key]
    if full_key in _setting_definitions:
        return _setting_definitions[full_key].get("default")

    return null


## Set a setting value
func set_setting(category: Category, key: String, value: Variant) -> void:
    if category not in _settings:
        _settings[category] = {}

    var old_value: Variant = _settings[category].get(key)
    _settings[category][key] = value

    if old_value != value:
        setting_changed.emit(category, key, value)


## Convenience accessors for common settings
func get_text_speed() -> float:
    return get_setting(Category.ACCESSIBILITY, "text_speed")

func get_screen_shake_enabled() -> bool:
    return get_setting(Category.ACCESSIBILITY, "screen_shake_enabled")

func get_screen_shake_intensity() -> float:
    return get_setting(Category.ACCESSIBILITY, "screen_shake_intensity")

func get_combat_animation_speed() -> float:
    return get_setting(Category.ACCESSIBILITY, "combat_animation_speed")


## Register a mod setting (called by mods during initialization)
func register_mod_setting(mod_id: String, key: String, definition: Dictionary) -> void:
    var full_key: String = "mod:%s:%s" % [mod_id, key]
    _setting_definitions[full_key] = definition

    if mod_id not in _mod_settings:
        _mod_settings[mod_id] = {}
    if key not in _mod_settings[mod_id]:
        _mod_settings[mod_id][key] = definition.get("default")


## Get a mod setting
func get_mod_setting(mod_id: String, key: String) -> Variant:
    if mod_id in _mod_settings and key in _mod_settings[mod_id]:
        return _mod_settings[mod_id][key]

    var full_key: String = "mod:%s:%s" % [mod_id, key]
    if full_key in _setting_definitions:
        return _setting_definitions[full_key].get("default")

    return null


## Set a mod setting
func set_mod_setting(mod_id: String, key: String, value: Variant) -> void:
    if mod_id not in _mod_settings:
        _mod_settings[mod_id] = {}

    _mod_settings[mod_id][key] = value
    setting_changed.emit(Category.MOD, "%s:%s" % [mod_id, key], value)


## Save settings to file
func save_settings() -> void:
    var config: ConfigFile = ConfigFile.new()

    # Save core settings
    for category: int in _settings:
        var section: String = Category.keys()[category]
        for key: String in _settings[category]:
            config.set_value(section, key, _settings[category][key])

    # Save mod settings
    for mod_id: String in _mod_settings:
        var section: String = "MOD_%s" % mod_id
        for key: String in _mod_settings[mod_id]:
            config.set_value(section, key, _mod_settings[mod_id][key])

    var err: Error = config.save(SETTINGS_FILE)
    if err != OK:
        push_error("SettingsManager: Failed to save settings: %d" % err)
    else:
        settings_saved.emit()


## Load settings from file
func load_settings() -> void:
    var config: ConfigFile = ConfigFile.new()
    var err: Error = config.load(SETTINGS_FILE)

    if err != OK:
        # File doesn't exist or is invalid - use defaults
        return

    # Load core settings
    for category: int in Category.values():
        if category == Category.MOD:
            continue
        var section: String = Category.keys()[category]
        if config.has_section(section):
            for key: String in config.get_section_keys(section):
                set_setting(category, key, config.get_value(section, key))

    # Load mod settings (sections starting with "MOD_")
    for section: String in config.get_sections():
        if section.begins_with("MOD_"):
            var mod_id: String = section.substr(4)
            for key: String in config.get_section_keys(section):
                set_mod_setting(mod_id, key, config.get_value(section, key))

    settings_loaded.emit()


## Get all setting definitions for a category (for UI generation)
func get_category_definitions(category: Category) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var prefix: String = "%d:" % category

    for full_key: String in _setting_definitions:
        if full_key.begins_with(prefix):
            var key: String = full_key.substr(prefix.length())
            var definition: Dictionary = _setting_definitions[full_key].duplicate()
            definition["key"] = key
            result.append(definition)

    return result
```

**Add to project.godot autoloads** (after ModLoader, before AudioManager)

**Integration with existing systems** (example for AudioManager):
```gdscript
func _ready() -> void:
    # ... existing code ...

    # Apply saved settings
    if SettingsManager:
        sfx_volume = SettingsManager.get_setting(SettingsManager.Category.AUDIO, "sfx_volume")
        music_volume = SettingsManager.get_setting(SettingsManager.Category.AUDIO, "music_volume")
        _update_volumes()

        # Listen for changes
        SettingsManager.setting_changed.connect(_on_setting_changed)


func _on_setting_changed(category: int, key: String, value: Variant) -> void:
    if category == SettingsManager.Category.AUDIO:
        match key:
            "sfx_volume":
                sfx_volume = value
            "music_volume":
                set_music_volume(value)
```

**Testing Requirements**:
- Unit test: Settings persist across sessions
- Unit test: Defaults applied when no settings file
- Unit test: Mod settings isolated by mod_id
- Unit test: Setting changes emit signals
- Manual test: Volume changes take effect immediately

**Effort**: 2-3 days

---

### 2E.3 Trigger Data Type Validation

**Issue #16**: `trigger_data` not validated before access.

**File**: `core/systems/trigger_manager.gd` lines 189-225

**Implementation**: Add validation helper and apply to all handlers.

```gdscript
## Validate trigger_data structure and extract expected fields
## Returns Dictionary with validated fields, or empty dict if validation fails
func _validate_trigger_data(trigger: Node, required_fields: Array[String]) -> Dictionary:
    var trigger_data: Variant = trigger.get("trigger_data")

    if trigger_data == null:
        push_error("TriggerManager: Trigger has null trigger_data")
        return {}

    if not trigger_data is Dictionary:
        push_error("TriggerManager: trigger_data is not a Dictionary (got %s)" % typeof(trigger_data))
        return {}

    var data: Dictionary = trigger_data as Dictionary
    var result: Dictionary = {}

    for field: String in required_fields:
        if field not in data:
            push_error("TriggerManager: trigger_data missing required field '%s'" % field)
            return {}
        result[field] = data[field]

    # Copy optional fields
    for key: String in data:
        if key not in result:
            result[key] = data[key]

    return result


## Example usage in _handle_battle_trigger:
func _handle_battle_trigger(trigger: Node, player: Node2D) -> void:
    var data: Dictionary = _validate_trigger_data(trigger, ["battle_id"])
    if data.is_empty():
        return

    var battle_id: String = data["battle_id"]
    if not battle_id is String or battle_id.is_empty():
        push_error("TriggerManager: Battle trigger has invalid battle_id")
        return

    # ... rest of implementation
```

Apply similar validation to all `_handle_*_trigger` methods.

**Testing Requirements**:
- Unit test: Valid trigger_data passes
- Unit test: Missing required field detected
- Unit test: Non-dictionary trigger_data rejected
- Unit test: Empty string field values detected

**Effort**: 0.5 day

---

### 2E.4 Stale Actor Cleanup

**Issue #15**: `_registered_actors` can hold freed node references.

**File**: `core/systems/cinematics_manager.gd`

**Implementation**: Add validity check in `get_actor()`:

```gdscript
## Get a registered actor by ID
func get_actor(actor_id: String) -> CinematicActor:
    if actor_id not in _registered_actors:
        return null

    var actor: CinematicActor = _registered_actors[actor_id]

    # Check if actor is still valid (hasn't been freed)
    if not is_instance_valid(actor):
        push_warning("CinematicsManager: Actor '%s' was freed, removing from registry" % actor_id)
        _registered_actors.erase(actor_id)
        return null

    return actor


## Cleanup all invalid actors (call periodically or on scene change)
func cleanup_invalid_actors() -> void:
    var to_remove: Array[String] = []

    for actor_id: String in _registered_actors:
        if not is_instance_valid(_registered_actors[actor_id]):
            to_remove.append(actor_id)

    for actor_id: String in to_remove:
        _registered_actors.erase(actor_id)

    if not to_remove.is_empty():
        push_warning("CinematicsManager: Cleaned up %d stale actor references" % to_remove.size())
```

**Connect cleanup to scene changes**:
```gdscript
func _ready() -> void:
    # ... existing code ...

    # Cleanup stale actors on scene change
    if SceneManager:
        SceneManager.scene_transition_completed.connect(_on_scene_changed)


func _on_scene_changed(_path: String) -> void:
    cleanup_invalid_actors()
```

**Testing Requirements**:
- Unit test: Valid actor returned correctly
- Unit test: Freed actor returns null
- Unit test: Freed actor removed from registry
- Integration test: No crash when cinematic references freed actor

**Effort**: 0.25 day

---

## Sub-Phase 2F: Polish and Lower Priority (P2-P3)

**Goal**: Complete lower-risk improvements
**Estimated Effort**: 2-3 days
**Risk Level**: Low
**Blocking Issues**: Sub-Phases 2A-2E
**Persona Impact**: All modders (low-medium)

### 2F.1 UI Theme System Foundation

**Issue #12**: Colors hardcoded throughout UI code.

**New File**: `core/resources/ui_theme_config.gd`

```gdscript
class_name UIThemeConfig
extends Resource

## UI Theme Configuration
## Centralizes color definitions for consistent theming and mod overrides

@export_group("Primary Colors")
@export var background_color: Color = Color(0.1, 0.1, 0.15, 0.95)
@export var panel_color: Color = Color(0.15, 0.15, 0.2, 0.9)
@export var highlight_color: Color = Color(0.4, 0.8, 1.0, 1.0)
@export var selection_color: Color = Color(0.3, 0.6, 0.9, 0.8)

@export_group("Text Colors")
@export var text_primary: Color = Color.WHITE
@export var text_secondary: Color = Color(0.8, 0.8, 0.8, 1.0)
@export var text_disabled: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var text_warning: Color = Color(1.0, 0.8, 0.2, 1.0)
@export var text_error: Color = Color(1.0, 0.4, 0.4, 1.0)
@export var text_success: Color = Color(0.4, 1.0, 0.4, 1.0)

@export_group("Combat Colors")
@export var damage_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var heal_color: Color = Color(0.3, 1.0, 0.3, 1.0)
@export var critical_color: Color = Color(1.0, 1.0, 0.0, 1.0)
@export var miss_color: Color = Color(0.6, 0.6, 0.6, 1.0)

@export_group("Unit Colors")
@export var player_unit_tint: Color = Color(0.6, 0.8, 1.0, 1.0)
@export var enemy_unit_tint: Color = Color(1.0, 0.6, 0.6, 1.0)
@export var neutral_unit_tint: Color = Color(0.8, 0.8, 0.6, 1.0)

@export_group("Movement Range")
@export var move_range_color: Color = Color(0.0, 0.5, 1.0, 0.3)
@export var attack_range_color: Color = Color(1.0, 0.3, 0.0, 0.3)
@export var heal_range_color: Color = Color(0.0, 1.0, 0.3, 0.3)
```

**New Autoload**: `core/systems/ui_theme_manager.gd`

```gdscript
extends Node

## UIThemeManager - Manages UI theming with mod override support

var _active_theme: UIThemeConfig = null
var _default_theme: UIThemeConfig = null

signal theme_changed(theme: UIThemeConfig)


func _ready() -> void:
    # Load default theme
    _default_theme = UIThemeConfig.new()
    _active_theme = _default_theme

    # Check for mod theme override
    _load_mod_theme()


func _load_mod_theme() -> void:
    if ModLoader:
        var theme: Resource = ModLoader.registry.get_resource("ui_theme", "default")
        if theme and theme is UIThemeConfig:
            _active_theme = theme
            theme_changed.emit(_active_theme)


## Get the active theme
func get_theme() -> UIThemeConfig:
    return _active_theme


## Convenience accessors
func get_highlight_color() -> Color:
    return _active_theme.highlight_color

func get_damage_color() -> Color:
    return _active_theme.damage_color

# ... etc for all commonly used colors
```

**Migration Example** (for dialog_box.gd):
```gdscript
# Before:
speaker_label.modulate = Color(1.0, 1.0, 0.6, 1.0)  # Yellow tint

# After:
if UIThemeManager:
    speaker_label.modulate = UIThemeManager.get_highlight_color()
else:
    speaker_label.modulate = Color(1.0, 1.0, 0.6, 1.0)  # Fallback
```

**Note**: Full migration of all hardcoded colors is a larger effort. This phase establishes the foundation; migration can be incremental.

**Testing Requirements**:
- Unit test: Default theme loads
- Unit test: Mod theme overrides default
- Manual test: Color changes apply to UI

**Effort**: 1-1.5 days

---

### 2F.2 GameEventBus Foundation

**Issue #13**: Mods can observe but not modify game behavior (no pre-event signals).

**New File**: `core/systems/game_event_bus.gd`

```gdscript
extends Node

## GameEventBus - Central event system with pre/post hooks
##
## Allows mods to intercept and modify game events.
## Pre-events can cancel or modify the event.
## Post-events can react to completed events.

## Pre-combat event - emitted before combat calculations
## Listeners can modify the context dictionary
signal pre_combat(context: Dictionary)

## Post-combat event - emitted after combat resolves
signal post_combat(result: Dictionary)

## Pre-damage event - emitted before damage is applied
## Set context["cancelled"] = true to prevent damage
## Modify context["damage"] to change damage amount
signal pre_damage(context: Dictionary)

## Post-damage event - emitted after damage is applied
signal post_damage(result: Dictionary)

## Pre-level-up event
signal pre_level_up(context: Dictionary)

## Post-level-up event
signal post_level_up(result: Dictionary)

## Pre-item-use event
signal pre_item_use(context: Dictionary)

## Post-item-use event
signal post_item_use(result: Dictionary)


## Create a combat context for pre_combat event
static func create_combat_context(attacker: Node2D, defender: Node2D) -> Dictionary:
    return {
        "attacker": attacker,
        "defender": defender,
        "damage_multiplier": 1.0,
        "hit_modifier": 0,
        "crit_modifier": 0,
        "cancelled": false,
        "custom_data": {}  # Mods can add their own data
    }


## Create a damage context for pre_damage event
static func create_damage_context(target: Node2D, amount: int, source: Node2D, damage_type: String) -> Dictionary:
    return {
        "target": target,
        "damage": amount,
        "source": source,
        "damage_type": damage_type,  # "physical", "magic", "item", "environmental"
        "cancelled": false,
        "custom_data": {}
    }


## Create a level-up context
static func create_level_up_context(unit: Node2D, old_level: int, new_level: int) -> Dictionary:
    return {
        "unit": unit,
        "old_level": old_level,
        "new_level": new_level,
        "stat_bonus_multiplier": 1.0,
        "custom_data": {}
    }
```

**Integration Example** (in BattleManager):
```gdscript
func _execute_attack(attacker: Node2D, defender: Node2D) -> void:
    # Emit pre-combat event
    var context: Dictionary = GameEventBus.create_combat_context(attacker, defender)
    GameEventBus.pre_combat.emit(context)

    # Check if cancelled
    if context.get("cancelled", false):
        push_warning("BattleManager: Combat cancelled by event listener")
        return

    # Apply modifiers from context
    var damage_mult: float = context.get("damage_multiplier", 1.0)

    # ... existing combat logic, applying modifiers ...

    # Emit post-combat event
    var result: Dictionary = {
        "attacker": attacker,
        "defender": defender,
        "damage_dealt": actual_damage,
        "was_critical": was_critical,
        "defender_died": defender_died
    }
    GameEventBus.post_combat.emit(result)
```

**Mod Usage Example**:
```gdscript
# In a mod's initialization script
func _ready() -> void:
    GameEventBus.pre_damage.connect(_on_pre_damage)

func _on_pre_damage(context: Dictionary) -> void:
    var target: Node2D = context.get("target")

    # Example: Damage reduction aura
    if target and target.has_method("has_buff") and target.has_buff("protection_aura"):
        context["damage"] = int(context["damage"] * 0.75)
```

**Testing Requirements**:
- Unit test: Pre-event can cancel action
- Unit test: Pre-event can modify values
- Unit test: Post-event receives correct result
- Integration test: Multiple listeners work together

**Effort**: 1 day

---

### 2F.3 Localization Infrastructure Foundation

**Issue #14**: Strings hardcoded in GDScript files.

This is a large undertaking. Phase 2 establishes the **foundation** only:

**New File**: `core/systems/localization_manager.gd`

```gdscript
extends Node

## LocalizationManager - String table system for localization
##
## Phase 2 Foundation:
## - Load string tables from JSON
## - Simple key->string lookup
## - Placeholder for future translation work

const DEFAULT_LOCALE: String = "en"

var _string_tables: Dictionary = {}  # locale -> {key -> string}
var _current_locale: String = DEFAULT_LOCALE

signal locale_changed(new_locale: String)


func _ready() -> void:
    _load_string_tables()


## Load string tables from mods
func _load_string_tables() -> void:
    # Load base game strings first
    _load_strings_from_mod("_base_game")

    # Load mod strings (overrides base)
    if ModLoader:
        for mod: ModManifest in ModLoader.get_all_mods():
            if mod.mod_id != "_base_game":
                _load_strings_from_mod(mod.mod_id)


func _load_strings_from_mod(mod_id: String) -> void:
    var strings_path: String = "res://mods/%s/strings/%s.json" % [mod_id, _current_locale]

    if not FileAccess.file_exists(strings_path):
        return  # No strings file for this mod/locale

    var file: FileAccess = FileAccess.open(strings_path, FileAccess.READ)
    if not file:
        return

    var json: JSON = JSON.new()
    var err: Error = json.parse(file.get_as_text())
    file.close()

    if err != OK:
        push_error("LocalizationManager: Failed to parse %s" % strings_path)
        return

    var data: Dictionary = json.data

    if _current_locale not in _string_tables:
        _string_tables[_current_locale] = {}

    # Merge strings (mod overrides base)
    for key: String in data:
        _string_tables[_current_locale][key] = data[key]


## Get a localized string by key
## Returns the key itself if not found (for debugging)
func tr(key: String) -> String:
    if _current_locale in _string_tables:
        if key in _string_tables[_current_locale]:
            return _string_tables[_current_locale][key]

    # Fallback to default locale
    if DEFAULT_LOCALE in _string_tables:
        if key in _string_tables[DEFAULT_LOCALE]:
            return _string_tables[DEFAULT_LOCALE][key]

    # Return key as-is (shows what needs translation)
    return key


## Get a localized string with placeholder substitution
## Example: tr_format("ui.damage_dealt", {"amount": 15}) -> "Dealt 15 damage!"
func tr_format(key: String, values: Dictionary) -> String:
    var template: String = tr(key)

    for placeholder: String in values:
        template = template.replace("{%s}" % placeholder, str(values[placeholder]))

    return template


## Set the current locale
func set_locale(locale: String) -> void:
    if locale == _current_locale:
        return

    _current_locale = locale
    _string_tables.clear()
    _load_string_tables()
    locale_changed.emit(locale)


## Get available locales (based on what string files exist)
func get_available_locales() -> Array[String]:
    var locales: Array[String] = [DEFAULT_LOCALE]
    # TODO: Scan for available locale files
    return locales
```

**Example String Table** (`mods/_base_game/strings/en.json`):
```json
{
    "ui.confirm": "Confirm",
    "ui.cancel": "Cancel",
    "ui.back": "Back",
    "combat.damage_dealt": "Dealt {amount} damage!",
    "combat.critical_hit": "Critical hit!",
    "combat.miss": "Miss!",
    "menu.new_game": "New Game",
    "menu.continue": "Continue",
    "menu.settings": "Settings"
}
```

**Note**: Actual migration of hardcoded strings is NOT in Phase 2 scope. This establishes the infrastructure for future work.

**Testing Requirements**:
- Unit test: Basic key lookup works
- Unit test: Missing key returns key itself
- Unit test: Placeholder substitution works
- Unit test: Mod strings override base strings

**Effort**: 1 day

---

## Risk Assessment Summary

| Sub-Phase | Risk | Mitigation |
|-----------|------|------------|
| 2A Critical | Very Low | 5-minute fixes, high-impact |
| 2B Save System | Medium | Atomic writes are proven pattern; test thoroughly |
| 2C State Management | Low | Additive API, backwards compatible |
| 2D Audio/Assets | Low | Bug fixes with clear scope |
| 2E Infrastructure | Medium | New systems but isolated; extensive testing |
| 2F Polish | Low | Foundation only, migration separate |

---

## Testing Strategy

### Automated (Headless)
- All validation functions (save data, trigger data, state import)
- RandomManager determinism tests
- SettingsManager persistence tests
- Flag namespacing tests

### Manual Integration
- Save/load cycle with mod enable/disable
- Rapid music switching stress test
- Cinematic skip during dialog
- Portrait override from mod

### Regression
- Existing battle tests pass
- Existing mod loading tests pass
- No new warnings in base game flow

---

## Rollout Plan

1. **Sub-Phase 2A**: Immediate merge (5-minute fixes)
2. **Sub-Phase 2B**: Careful testing, backup creation
3. **Sub-Phase 2C-2D**: Standard testing cycle
4. **Sub-Phase 2E**: Feature branches, thorough integration testing
5. **Sub-Phase 2F**: Lower priority, can defer if schedule tight

---

## Success Criteria

**Competitive Modder** can:
- Set a seed for deterministic replay
- Trust that saves won't corrupt on crash
- Load saves even after disabling mods (graceful degradation)

**Accessibility Modder** can:
- Register custom accessibility settings
- Override UI colors via theme config
- Hook into game events to add accessibility features

**Narrative Modder** can:
- Override portrait assets without editing .tres files
- Trust that dialog races won't crash cinematics
- Use namespaced flags without collision

**All Modders** benefit from:
- No production Q-key quit
- Validated trigger data
- Cleaned up stale references
- Foundational infrastructure for future features

---

## Estimated Total Effort

| Sub-Phase | Days |
|-----------|------|
| 2A Critical Fixes | 0.5 |
| 2B Save System | 2 |
| 2C State Management | 1 |
| 2D Audio/Assets | 1 |
| 2E Infrastructure | 5-7 |
| 2F Polish | 2-3 |
| **Total** | **11.5-14.5 days** |

---

*End of Plan*

*"The difference between a good platform and a great platform is how gracefully it handles the unexpected." - Lt. Claudbrain*
