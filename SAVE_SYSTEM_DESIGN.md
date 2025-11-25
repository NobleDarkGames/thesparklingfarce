# Save System Design Document
## Shining Force-Style Save Slot System for The Sparkling Farce

**Created:** November 24, 2025
**Status:** Planning Phase

---

## Table of Contents
1. [Research Summary](#research-summary)
2. [Design Goals](#design-goals)
3. [Current Codebase Analysis](#current-codebase-analysis)
4. [Architecture Overview](#architecture-overview)
5. [Data Structure Specification](#data-structure-specification)
6. [Mod Compatibility Strategy](#mod-compatibility-strategy)
7. [Implementation Plan](#implementation-plan)
8. [UI/UX Design](#uiux-design)
9. [Testing Strategy](#testing-strategy)

---

## Research Summary

### Shining Force Save Systems

**Shining Force 1 (Genesis):**
- **3 save slots** in battery-backed RAM
- Save manager: Simone the advisor
- Operations: START (new game), CONT. (continue), DEL (delete), COPY (backup)
- In-game saves at churches via priests
- Auto-save on battle quit

**Shining Force 2 (Genesis):**
- **2 save slots** in battery-backed RAM
- Similar menu structure with witch character
- Same four operations

**Shining Force: Resurrection of the Dark Dragon (GBA):**
- **3 save slots** on cartridge
- Modernized but familiar interface

### Common Elements Across All Games
1. Multiple save slots for different playthroughs or backup saves
2. Title screen save manager character/interface
3. Four standard operations
4. Visual indication of selected slot (pulsing/highlighting)
5. Each slot stores complete game state: party data, character levels, inventory, story position

---

## Design Goals

### Core Requirements
1. **Multiple Save Slots** - 3 independent slots for different players/playthroughs
2. **Shining Force Authenticity** - Familiar menu flow and operations
3. **Mod Compatibility** - Handle mod additions/removals gracefully
4. **Data Integrity** - Prevent corruption, validate on load
5. **User-Friendly** - Clear feedback, no lost progress
6. **Platform-Independent** - Works on Windows, Linux, Mac

### Nice-to-Have Features
- Cloud save support (future)
- Save file export/import
- Auto-save after battles
- Multiple save profiles (beyond 3 slots)
- Save file compression

---

## Current Codebase Analysis

### Existing Architecture Strengths

**✅ Autoload System Already Established:**
```
ModLoader → PartyManager → ExperienceManager → AudioManager →
GridManager → TurnManager → InputManager → BattleManager → AIController
```
Perfect insertion point: `SaveManager` should load AFTER `ModLoader` but BEFORE game systems that need save data.

**✅ Resource-Based Data Model:**
- `CharacterData` - Immutable character templates
- `PartyData` - Party composition with formation
- `BattleData` - Battle configuration
- All data already in `.tres` format (easy to reference in saves)

**✅ Runtime State Tracking:**
- `UnitStats` - Tracks current HP, MP, XP, level, status effects
- `PartyManager` - Manages active party composition
- `ExperienceManager` - Handles XP gains and level-ups

**✅ Mod System:**
- `ModLoader` - Discovers and loads mods
- `ModRegistry` - Tracks all loaded resources
- `ModManifest` - Mod metadata (mod.json)
- Each mod has unique `mod_id`

### What's Missing (Needs Implementation)

**❌ No Save/Load Infrastructure:**
- No SaveManager autoload
- No save data structures
- No serialization/deserialization logic
- No save file I/O

**❌ No Persistent Character Data:**
- `CharacterData` is immutable (base template)
- No way to store "Max is level 10 with 1250 XP"
- Equipment changes not persisted
- Learned abilities not tracked beyond battle

**❌ No Campaign/Story Progress Tracking:**
- No concept of "chapters" or "story flags"
- Battles are standalone (no sequence)
- No world map or headquarters system yet

**❌ No Inventory System:**
- Items exist as resources
- No player inventory container
- No gold/currency tracking

**🔶 PartyManager is Lightweight:**
- Currently just holds `Array[CharacterData]` references
- Doesn't persist between battles
- No stat modifications stored
- Perfect foundation to build upon

---

## Architecture Overview

### Component Hierarchy

```
SaveManager (Autoload)
├── SaveSlot (Class) × 3
│   ├── SaveData (Resource)
│   │   ├── CampaignProgress
│   │   ├── PartyState
│   │   │   └── CharacterSaveData × N
│   │   ├── InventoryState
│   │   └── ModCompatibility
│   └── SlotMetadata (quick preview)
└── SaveSlotUI (Scene)
    ├── SlotSelector
    ├── SlotInfoDisplay
    └── ConfirmationDialog
```

### File Structure

```
user://saves/
├── slot_1.sav         # Full save data (JSON or ConfigFile)
├── slot_2.sav
├── slot_3.sav
└── slots.meta         # Quick metadata for all slots (menu display)
```

**Why `user://` ?**
- Platform-independent (Windows: AppData, Linux: .local/share, Mac: Library/Application Support)
- Persists across game updates
- User-writable without admin rights
- Godot built-in support

---

## Data Structure Specification

### SaveData (Main Save File)

```gdscript
class_name SaveData
extends Resource

# ============================================================================
# METADATA
# ============================================================================

## Save version (for migration if data structure changes)
@export var save_version: int = 1

## When this save was created
@export var created_timestamp: int = 0  # Unix timestamp

## When this save was last modified
@export var last_played_timestamp: int = 0  # Unix timestamp

## Total playtime in seconds
@export var playtime_seconds: int = 0

## Which slot this save occupies (1, 2, or 3)
@export var slot_number: int = 1

# ============================================================================
# MOD COMPATIBILITY
# ============================================================================

## List of mods that were active when this save was created
## Format: Array of {mod_id: String, version: String}
@export var active_mods: Array[Dictionary] = []

## Base game version
@export var game_version: String = "0.1.0"

# ============================================================================
# CAMPAIGN PROGRESS
# ============================================================================

## Current campaign chapter/location
## Example: "chapter_1", "headquarters", "battle_5"
@export var current_location: String = "headquarters"

## Story flags (quest completion, dialogue choices, etc.)
## Format: {"flag_name": bool}
@export var story_flags: Dictionary = {}

## Completed battles (by battle resource ID)
## Example: ["battle_prologue", "battle_1", "battle_2"]
@export var completed_battles: Array[String] = []

## Available battles (unlocked but not yet completed)
@export var available_battles: Array[String] = []

# ============================================================================
# PARTY STATE
# ============================================================================

## Active party members (persistent character data)
@export var party_members: Array[CharacterSaveData] = []

## Reserve/headquarters roster (recruited but not deployed)
@export var reserve_members: Array[CharacterSaveData] = []

## Maximum party size (can increase through story)
@export var max_party_size: int = 8

# ============================================================================
# INVENTORY & ECONOMY
# ============================================================================

## Current gold amount
@export var gold: int = 0

## Items in inventory
## Format: [{item_id: String, mod_id: String, quantity: int}]
@export var inventory: Array[Dictionary] = []

# ============================================================================
# STATISTICS (for player reference)
# ============================================================================

@export var total_battles: int = 0
@export var battles_won: int = 0
@export var total_enemies_defeated: int = 0
@export var total_damage_dealt: int = 0
@export var total_healing_done: int = 0
```

### CharacterSaveData (Persistent Character State)

```gdscript
class_name CharacterSaveData
extends Resource

## Reference to base CharacterData (mod_id + resource_id)
@export var character_mod_id: String = ""
@export var character_resource_id: String = ""

## If base CharacterData is missing (mod removed), store fallback data
@export var fallback_character_name: String = ""
@export var fallback_class_name: String = ""

# ============================================================================
# PERSISTENT STATS (Override CharacterData base stats)
# ============================================================================

@export var level: int = 1
@export var current_xp: int = 0

## Current stats (after level-ups and growth)
@export var current_hp: int = 10
@export var max_hp: int = 10
@export var current_mp: int = 5
@export var max_mp: int = 5

@export var strength: int = 5
@export var defense: int = 5
@export var agility: int = 5
@export var intelligence: int = 5
@export var luck: int = 5

# ============================================================================
# EQUIPMENT (Persistent across battles)
# ============================================================================

## Equipped items (by mod_id + resource_id)
## Format: [{slot: String, mod_id: String, item_id: String}]
## Slots: "weapon", "armor", "accessory_1", "accessory_2"
@export var equipped_items: Array[Dictionary] = []

# ============================================================================
# ABILITIES (Learned abilities persist)
# ============================================================================

## Learned abilities (by mod_id + resource_id)
## Format: [{mod_id: String, ability_id: String}]
@export var learned_abilities: Array[Dictionary] = []

# ============================================================================
# STATUS (For campaign persistence)
# ============================================================================

## If character is alive (for permadeath scenarios)
@export var is_alive: bool = true

## If character is available (not temporarily unavailable due to story)
@export var is_available: bool = true

## Recruitment chapter (when they joined the party)
@export var recruitment_chapter: String = ""
```

### SlotMetadata (Quick Preview)

```gdscript
class_name SlotMetadata
extends Resource

## Slot number (1, 2, 3)
@export var slot_number: int = 1

## Is this slot occupied?
@export var is_occupied: bool = false

## Quick display info (no need to load full save)
@export var party_leader_name: String = ""
@export var current_location: String = ""
@export var average_level: int = 1
@export var playtime_seconds: int = 0
@export var last_played_timestamp: int = 0

## Mod compatibility warning
@export var has_mod_mismatch: bool = false
```

---

## Mod Compatibility Strategy

### The Problem

**Scenario:** Player saves game with `my_custom_mod` active, then:
1. Removes the mod
2. Loads the save
3. **What happens to modded characters/items?**

### Solution: Graceful Degradation

**Tier 1: Core Game Content (Always Available)**
- Base game mods: `_base_game`, `base_game`
- Load priority: 0-99
- **Guarantee:** Always present, never removed

**Tier 2: Optional Mods (May Be Missing)**
- Custom mods: `my_mod`, `expansion_pack`
- Load priority: 100+
- **Strategy:** Store mod_id with every resource reference

**Handling Missing Mods:**

```gdscript
# When loading a character from save
func load_character_from_save(char_save: CharacterSaveData) -> CharacterData:
    # Try to load from ModRegistry
    var char_data = ModLoader.registry.get_resource(
        char_save.character_resource_id,
        "character",
        char_save.character_mod_id
    )

    if char_data != null:
        return char_data  # Success!

    # Mod is missing - check if it's critical
    if char_save.character_mod_id in ["_base_game", "base_game"]:
        push_error("CRITICAL: Base game character missing!")
        return null

    # Optional mod - create placeholder character
    push_warning("Character '%s' from mod '%s' not found - creating placeholder" % [
        char_save.fallback_character_name,
        char_save.character_mod_id
    ])

    return _create_placeholder_character(char_save)
```

**Placeholder Strategy:**
- Preserve all stats, level, XP
- Use a generic "Unknown Class" placeholder
- Mark as "from missing mod: X"
- If mod is re-enabled, restore full data
- Allow player to remove placeholder characters

**Save File Validation:**

```gdscript
func validate_save_compatibility(save_data: SaveData) -> Dictionary:
    var report = {
        "is_compatible": true,
        "warnings": [],
        "errors": [],
        "missing_mods": [],
        "changed_mods": []
    }

    # Check each mod that was active in the save
    for mod_dict in save_data.active_mods:
        var mod_id: String = mod_dict.mod_id
        var saved_version: String = mod_dict.version

        # Is mod still loaded?
        if not ModLoader._is_mod_loaded(mod_id):
            report.missing_mods.append(mod_id)

            # Is it a critical mod?
            if mod_id in ["_base_game", "base_game"]:
                report.errors.append("Missing critical mod: " + mod_id)
                report.is_compatible = false
            else:
                report.warnings.append("Missing optional mod: " + mod_id)
        else:
            # Mod is loaded - check version
            var current_manifest = ModLoader.get_mod_manifest(mod_id)
            if current_manifest.version != saved_version:
                report.changed_mods.append({
                    "mod_id": mod_id,
                    "saved_version": saved_version,
                    "current_version": current_manifest.version
                })
                report.warnings.append("Mod version changed: %s (%s → %s)" % [
                    mod_id, saved_version, current_manifest.version
                ])

    return report
```

**User-Facing Warnings:**

When loading a save:
```
⚠ Warning: This save uses mods that are no longer active:
  - my_custom_mod (v1.2.3)
  - expansion_pack (v0.5.0)

Some characters or items may be unavailable.
Continue anyway? [Yes] [No]
```

---

## Implementation Plan

### Phase 1: Foundation (Core Save/Load)

**Goal:** Basic save and load functionality without UI

#### 1.1 Create Core Classes

**Files to Create:**
- `core/systems/save_manager.gd` - Main save system autoload
- `core/resources/save_data.gd` - SaveData resource
- `core/resources/character_save_data.gd` - CharacterSaveData resource
- `core/resources/slot_metadata.gd` - SlotMetadata resource

**SaveManager Methods:**
```gdscript
func save_to_slot(slot_number: int, save_data: SaveData) -> bool
func load_from_slot(slot_number: int) -> SaveData
func delete_slot(slot_number: int) -> bool
func copy_slot(from_slot: int, to_slot: int) -> bool
func get_slot_metadata(slot_number: int) -> SlotMetadata
func get_all_slot_metadata() -> Array[SlotMetadata]
func is_slot_occupied(slot_number: int) -> bool
```

**SaveData Methods:**
```gdscript
func serialize_to_dict() -> Dictionary
func deserialize_from_dict(data: Dictionary) -> void
func validate() -> bool
func get_display_summary() -> String
```

#### 1.2 Serialization System

**Format Choice: JSON**
- Human-readable (easier debugging)
- Godot built-in support (`JSON.stringify`, `JSON.parse_string`)
- Version control friendly (for debugging saves)
- Platform-independent

**Example Save File:**
```json
{
  "save_version": 1,
  "created_timestamp": 1732485600,
  "last_played_timestamp": 1732485600,
  "playtime_seconds": 3600,
  "slot_number": 1,
  "active_mods": [
    {"mod_id": "base_game", "version": "1.0.0"},
    {"mod_id": "_sandbox", "version": "1.0.0"}
  ],
  "game_version": "0.1.0",
  "current_location": "headquarters",
  "story_flags": {
    "prologue_complete": true,
    "met_mentor": true
  },
  "completed_battles": ["battle_prologue", "battle_1"],
  "party_members": [
    {
      "character_mod_id": "base_game",
      "character_resource_id": "hero_max",
      "level": 5,
      "current_xp": 250,
      "max_hp": 35,
      "current_hp": 35,
      "strength": 12,
      "learned_abilities": [
        {"mod_id": "base_game", "ability_id": "heal_1"}
      ]
    }
  ],
  "gold": 500,
  "inventory": [
    {"item_id": "healing_herb", "mod_id": "base_game", "quantity": 5}
  ]
}
```

#### 1.3 Integration with Existing Systems

**Modify PartyManager:**
```gdscript
## Export current party to save data
func export_to_save() -> Array[CharacterSaveData]:
    var save_array: Array[CharacterSaveData] = []

    for unit in _active_units:  # Need to track spawned units
        var char_save = CharacterSaveData.new()
        char_save.populate_from_unit(unit)
        save_array.append(char_save)

    return save_array

## Import party from save data
func import_from_save(saved_characters: Array[CharacterSaveData]) -> void:
    party_members.clear()

    for char_save in saved_characters:
        var character_data = _resolve_character_data(char_save)
        if character_data:
            party_members.append(character_data)
            # TODO: Apply saved stats (level, XP, equipment)
```

**CharacterSaveData Helper:**
```gdscript
## Populate from a Unit instance (in battle)
func populate_from_unit(unit: Unit) -> void:
    # Get base character reference
    var char_data: CharacterData = unit.character_data
    character_mod_id = _get_mod_id_for_resource(char_data)
    character_resource_id = _get_resource_id_for_resource(char_data)

    # Fallback data
    fallback_character_name = char_data.character_name
    fallback_class_name = char_data.character_class.class_name

    # Copy current stats from unit
    level = unit.stats.level
    current_xp = unit.stats.current_xp
    current_hp = unit.stats.current_hp
    max_hp = unit.stats.max_hp
    # ... etc

    # Copy equipped items
    equipped_items.clear()
    for item in unit.equipped_items:
        equipped_items.append({
            "slot": "weapon",  # TODO: get actual slot
            "mod_id": _get_mod_id_for_resource(item),
            "item_id": _get_resource_id_for_resource(item)
        })
```

#### 1.4 Testing

**Test Scenes:**
- `test_save_basic.gd` - Create save, load save, verify data
- `test_save_mod_compat.gd` - Save with mod, remove mod, load save
- `test_save_corruption.gd` - Load invalid JSON, missing files

---

### Phase 2: Save Slot UI

**Goal:** Shining Force-style save slot menu

#### 2.1 Create Save Slot Menu Scene

**File:** `scenes/ui/save_slot_menu.tscn`

**Structure:**
```
SaveSlotMenu (Control, fullscreen)
├── Background (ColorRect - dark semi-transparent)
├── Title (Label - "Select Save Slot")
├── SlotContainer (VBoxContainer)
│   ├── SlotDisplay1 (Panel)
│   │   ├── SlotNumber (Label - "Slot 1")
│   │   ├── SlotInfo (VBoxContainer)
│   │   │   ├── LeaderName (Label - "Max")
│   │   │   ├── Location (Label - "Chapter 3")
│   │   │   ├── Level (Label - "Lv. 8-10")
│   │   │   ├── Playtime (Label - "12:34:56")
│   │   │   └── LastPlayed (Label - "Last played: Nov 24")
│   │   └── EmptyLabel (Label - "Empty Slot" - only if slot empty)
│   ├── SlotDisplay2 (Panel)
│   └── SlotDisplay3 (Panel)
├── ActionButtons (HBoxContainer)
│   ├── StartButton (Button - "New Game")
│   ├── ContinueButton (Button - "Continue")
│   ├── DeleteButton (Button - "Delete")
│   └── CopyButton (Button - "Copy")
└── ConfirmDialog (AcceptDialog - for delete/copy confirmations)
```

**Visual Style:**
- Inspired by Shining Force aesthetics
- Pixel art fonts
- Selected slot has pulsing border or highlight
- Disabled buttons grayed out based on context

#### 2.2 Menu State Machine

**States:**
```gdscript
enum MenuState {
    SELECTING_SLOT,    # Choosing which slot to act on
    SELECTING_ACTION,  # Choosing NEW/CONTINUE/DELETE/COPY
    CONFIRMING_DELETE, # "Are you sure you want to delete?"
    SELECTING_COPY_DEST # "Copy to which slot?"
}
```

**Navigation:**
- Up/Down: Select slot
- Enter: Confirm selection → transition to action selection
- Escape: Cancel/go back
- Left/Right: Navigate action buttons when in action mode

#### 2.3 Integration Points

**Where to show the menu:**

1. **Game Startup** (when launching the game)
   - Show SaveSlotMenu before anything else
   - After slot selected, load data and go to main menu/headquarters

2. **In-Game Save** (at churches/save points - future phase)
   - Pause game
   - Show SaveSlotMenu with limited actions (save only, no new game)
   - Resume after save

3. **Title Screen** (once we have one)
   - "Continue" option → SaveSlotMenu
   - "New Game" option → SaveSlotMenu with first empty slot selected

**Script:** `scenes/ui/save_slot_menu.gd`

```gdscript
extends Control

signal slot_selected(slot_number: int, save_data: SaveData)
signal new_game_started(slot_number: int)
signal menu_cancelled

@onready var slot_displays: Array[Panel] = [
    $SlotContainer/SlotDisplay1,
    $SlotContainer/SlotDisplay2,
    $SlotContainer/SlotDisplay3
]

var selected_slot: int = 0  # 0, 1, 2 (maps to slot numbers 1, 2, 3)
var menu_state: MenuState = MenuState.SELECTING_SLOT

func _ready() -> void:
    _refresh_slot_displays()
    _highlight_slot(selected_slot)

func _refresh_slot_displays() -> void:
    for i in range(3):
        var metadata = SaveManager.get_slot_metadata(i + 1)
        _update_slot_display(i, metadata)

func _update_slot_display(slot_index: int, metadata: SlotMetadata) -> void:
    var display = slot_displays[slot_index]

    if not metadata.is_occupied:
        display.get_node("EmptyLabel").visible = true
        display.get_node("SlotInfo").visible = false
    else:
        display.get_node("EmptyLabel").visible = false
        display.get_node("SlotInfo").visible = true
        display.get_node("SlotInfo/LeaderName").text = metadata.party_leader_name
        display.get_node("SlotInfo/Location").text = metadata.current_location
        display.get_node("SlotInfo/Level").text = "Lv. %d" % metadata.average_level
        display.get_node("SlotInfo/Playtime").text = _format_playtime(metadata.playtime_seconds)
        display.get_node("SlotInfo/LastPlayed").text = _format_timestamp(metadata.last_played_timestamp)

func _on_continue_pressed() -> void:
    var slot_number = selected_slot + 1
    if not SaveManager.is_slot_occupied(slot_number):
        return  # Button should be disabled, but safety check

    var save_data = SaveManager.load_from_slot(slot_number)
    if save_data:
        slot_selected.emit(slot_number, save_data)
    else:
        push_error("Failed to load slot %d" % slot_number)

func _on_new_game_pressed() -> void:
    var slot_number = selected_slot + 1
    if SaveManager.is_slot_occupied(slot_number):
        # Show confirmation dialog
        # TODO: Implement overwrite warning
        pass

    new_game_started.emit(slot_number)
```

---

### Phase 3: Campaign State Management

**Goal:** Track story progress, battles, and world state

#### 3.1 Create Campaign Manager

**File:** `core/systems/campaign_manager.gd`

```gdscript
extends Node

## Current campaign state (loaded from save or new game)
var current_save: SaveData = null

## Track which slot we're playing on
var active_slot_number: int = -1

## Playtime tracking
var session_start_time: int = 0

func _ready() -> void:
    # Start tracking playtime
    session_start_time = Time.get_unix_time_from_system()

func start_new_campaign(slot_number: int) -> void:
    current_save = SaveData.new()
    current_save.slot_number = slot_number
    current_save.created_timestamp = Time.get_unix_time_from_system()
    current_save.last_played_timestamp = current_save.created_timestamp
    current_save.game_version = ProjectSettings.get_setting("application/config/version")

    # Populate active mods
    for manifest in ModLoader.loaded_mods:
        current_save.active_mods.append({
            "mod_id": manifest.mod_id,
            "version": manifest.version
        })

    # Set starting state
    current_save.current_location = "prologue"
    current_save.gold = 100  # Starting gold

    # Add starting party (TODO: Get from game config)
    # For now, hardcoded for testing
    _add_starting_party()

    active_slot_number = slot_number
    print("CampaignManager: New campaign started in slot %d" % slot_number)

func load_campaign(slot_number: int) -> bool:
    var save_data = SaveManager.load_from_slot(slot_number)
    if not save_data:
        return false

    # Validate mod compatibility
    var compat_report = _validate_mod_compatibility(save_data)
    if not compat_report.is_compatible:
        push_error("Save is incompatible: %s" % compat_report.errors)
        return false

    if not compat_report.warnings.is_empty():
        print("Load warnings: %s" % compat_report.warnings)
        # TODO: Show warning dialog to player

    current_save = save_data
    active_slot_number = slot_number

    # Restore game state
    _restore_party_from_save()
    # TODO: Restore inventory, story flags, etc.

    print("CampaignManager: Loaded campaign from slot %d" % slot_number)
    return true

func save_current_campaign() -> bool:
    if current_save == null or active_slot_number == -1:
        push_error("No active campaign to save")
        return false

    # Update timestamps and playtime
    var now = Time.get_unix_time_from_system()
    current_save.last_played_timestamp = now
    current_save.playtime_seconds += (now - session_start_time)
    session_start_time = now  # Reset for next save

    # Export current party state
    current_save.party_members = PartyManager.export_to_save()

    # Save to file
    return SaveManager.save_to_slot(active_slot_number, current_save)

func set_story_flag(flag_name: String, value: bool = true) -> void:
    if current_save:
        current_save.story_flags[flag_name] = value

func has_story_flag(flag_name: String) -> bool:
    if current_save:
        return current_save.story_flags.get(flag_name, false)
    return false

func complete_battle(battle_id: String) -> void:
    if current_save:
        if not current_save.completed_battles.has(battle_id):
            current_save.completed_battles.append(battle_id)
            current_save.total_battles += 1
            current_save.battles_won += 1
```

#### 3.2 Auto-Save Hooks

**After Battle:**
```gdscript
# In BattleManager._on_battle_ended()
func _on_battle_ended(victory: bool) -> void:
    # Existing cleanup code...

    if victory:
        # Record battle completion
        if CampaignManager.current_save:
            CampaignManager.complete_battle(current_battle_data.battle_id)

        # Auto-save (optional - can be a setting)
        if Settings.auto_save_enabled:
            CampaignManager.save_current_campaign()
```

**At Save Points (Churches):**
```gdscript
# In future dialogue/interaction system
func _on_priest_talk() -> void:
    show_priest_menu()  # Heal, Save, etc.

func _on_save_selected() -> void:
    if CampaignManager.save_current_campaign():
        show_message("Game saved successfully!")
    else:
        show_message("Failed to save!")
```

---

### Phase 4: Advanced Features

#### 4.1 Save File Migration

**Handle save version changes:**
```gdscript
func migrate_save_data(save_dict: Dictionary) -> Dictionary:
    var version: int = save_dict.get("save_version", 1)

    match version:
        1:
            # v1 → v2: Added inventory system
            if version < 2:
                save_dict["inventory"] = []
                save_dict["gold"] = 0
                save_dict["save_version"] = 2

            # v2 → v3: Added story flags
            if version < 3:
                save_dict["story_flags"] = {}
                save_dict["save_version"] = 3

    return save_dict
```

#### 4.2 Cloud Save Integration (Future)

**Structure for cloud saves:**
```gdscript
## Upload save to cloud service (Steam Cloud, Epic, etc.)
func upload_to_cloud(slot_number: int) -> bool:
    # Platform-specific implementation
    pass

## Download save from cloud
func download_from_cloud(slot_number: int) -> bool:
    # Platform-specific implementation
    pass

## Sync all slots (merge conflicts handled by newest timestamp)
func sync_all_slots() -> void:
    pass
```

#### 4.3 Save File Export/Import

**For sharing saves, troubleshooting:**
```gdscript
func export_save_to_file(slot_number: int, export_path: String) -> bool:
    var save_data = SaveManager.load_from_slot(slot_number)
    if not save_data:
        return false

    var json_string = JSON.stringify(save_data.serialize_to_dict(), "\t")
    var file = FileAccess.open(export_path, FileAccess.WRITE)
    if file:
        file.store_string(json_string)
        file.close()
        return true
    return false

func import_save_from_file(import_path: String, slot_number: int) -> bool:
    var file = FileAccess.open(import_path, FileAccess.READ)
    if not file:
        return false

    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    var parse_result = json.parse(json_string)
    if parse_result != OK:
        return false

    var save_data = SaveData.new()
    save_data.deserialize_from_dict(json.data)

    return SaveManager.save_to_slot(slot_number, save_data)
```

---

## UI/UX Design

### Menu Flow Diagram

```
┌─────────────────────────┐
│   Game Startup          │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Save Slot Menu         │
│  ┌─────────────────┐    │
│  │ ○ Slot 1: Max   │◄───┼─── Up/Down to select
│  │   Slot 2: Empty │    │
│  │   Slot 3: Anna  │    │
│  └─────────────────┘    │
│                         │
│  [New] [Continue]       │◄─── Enter to choose action
│  [Delete] [Copy]        │
└───────────┬─────────────┘
            │
       ┌────┴────┐
       │         │
       ▼         ▼
┌──────────┐  ┌──────────┐
│ Continue │  │ New Game │
│  Game    │  │          │
└──────────┘  └──────────┘
       │         │
       └────┬────┘
            │
            ▼
      ┌────────────┐
      │ Load Save  │
      │  Data      │
      └──────┬─────┘
             │
             ▼
      ┌────────────┐
      │ Start Game │
      │ (Battle or │
      │ HQ Scene)  │
      └────────────┘
```

### Keyboard/Gamepad Controls

**In Slot Selection:**
- Up/Down Arrow: Navigate slots
- Enter/Space/Z: Confirm selection
- Escape/X: Cancel (quit to desktop if at startup)

**In Action Selection:**
- Left/Right Arrow: Navigate buttons
- Enter/Space/Z: Confirm action
- Escape/X: Back to slot selection

### Visual Feedback

**Selected Slot:**
- Pulsing border (alpha: 0.7 → 1.0 → 0.7, 1 second cycle)
- Slightly brighter background
- Arrow indicator ">"

**Disabled Actions:**
- "Continue" grayed out if slot is empty
- "Delete" grayed out if slot is empty
- "Copy" grayed out if slot is empty
- "New Game" shows "(Overwrite)" warning if slot occupied

**Mod Mismatch Warning:**
```
┌─────────────────────────────────┐
│  ⚠ Mod Compatibility Warning    │
├─────────────────────────────────┤
│  This save was created with     │
│  different mods:                │
│                                 │
│  Missing:                       │
│  • my_custom_mod (v1.2.0)       │
│                                 │
│  Changed:                       │
│  • base_game (v1.0.0 → v1.1.0)  │
│                                 │
│  Some content may be missing.   │
│  Continue anyway?               │
│                                 │
│      [Yes]        [No]          │
└─────────────────────────────────┘
```

---

## Testing Strategy

### Unit Tests

**File:** `tests/test_save_system.gd`

```gdscript
extends GutTest

func test_save_to_slot():
    var save_data = SaveData.new()
    save_data.current_location = "test_location"
    save_data.gold = 500

    var success = SaveManager.save_to_slot(1, save_data)
    assert_true(success, "Save should succeed")

    var loaded = SaveManager.load_from_slot(1)
    assert_not_null(loaded, "Loaded save should not be null")
    assert_eq(loaded.current_location, "test_location")
    assert_eq(loaded.gold, 500)

func test_delete_slot():
    # Create a save
    var save_data = SaveData.new()
    SaveManager.save_to_slot(1, save_data)

    # Verify it exists
    assert_true(SaveManager.is_slot_occupied(1))

    # Delete it
    SaveManager.delete_slot(1)

    # Verify it's gone
    assert_false(SaveManager.is_slot_occupied(1))

func test_copy_slot():
    # Create a save in slot 1
    var save_data = SaveData.new()
    save_data.gold = 999
    SaveManager.save_to_slot(1, save_data)

    # Copy to slot 2
    SaveManager.copy_slot(1, 2)

    # Verify both exist and are identical
    var slot1 = SaveManager.load_from_slot(1)
    var slot2 = SaveManager.load_from_slot(2)

    assert_eq(slot1.gold, 999)
    assert_eq(slot2.gold, 999)
    assert_eq(slot2.slot_number, 2, "Copied slot should have correct slot number")

func test_mod_compatibility_check():
    var save_data = SaveData.new()
    save_data.active_mods = [
        {"mod_id": "base_game", "version": "1.0.0"},
        {"mod_id": "missing_mod", "version": "1.0.0"}
    ]

    var report = CampaignManager._validate_mod_compatibility(save_data)

    assert_true(report.warnings.size() > 0, "Should have warning for missing mod")
    assert_true("missing_mod" in report.missing_mods)
```

### Integration Tests

**File:** `tests/test_save_integration.gd`

```gdscript
extends GutTest

func test_save_and_restore_party():
    # Set up a party
    var hero = load("res://mods/base_game/data/characters/hero.tres")
    PartyManager.set_party([hero])

    # Modify hero's stats (simulate level-up)
    var unit = _create_mock_unit_from_character(hero)
    unit.stats.level = 5
    unit.stats.current_xp = 250

    # Save campaign
    CampaignManager.start_new_campaign(1)
    CampaignManager.current_save.party_members = PartyManager.export_to_save()
    CampaignManager.save_current_campaign()

    # Clear party
    PartyManager.clear_party()

    # Load campaign
    CampaignManager.load_campaign(1)

    # Verify party restored
    assert_eq(PartyManager.get_party_size(), 1)
    # TODO: Verify level and XP restored correctly
```

### Manual Test Scenarios

**Checklist:**

1. **Basic Save/Load**
   - [ ] Create new game in slot 1
   - [ ] Play a battle
   - [ ] Save game
   - [ ] Quit and restart
   - [ ] Continue from slot 1
   - [ ] Verify party state restored

2. **Multiple Slots**
   - [ ] Create saves in all 3 slots
   - [ ] Each with different party/progress
   - [ ] Load each slot and verify correct state

3. **Delete Slot**
   - [ ] Delete slot 2
   - [ ] Verify slot 2 now shows "Empty"
   - [ ] Verify slots 1 and 3 unaffected

4. **Copy Slot**
   - [ ] Copy slot 1 to slot 2
   - [ ] Verify both are identical
   - [ ] Modify slot 2 (play a battle)
   - [ ] Verify slot 1 unchanged

5. **Mod Compatibility**
   - [ ] Create save with base game only
   - [ ] Add a test mod (with new character)
   - [ ] Create save with test mod active
   - [ ] Remove test mod
   - [ ] Load second save
   - [ ] Verify warning shown
   - [ ] Verify game doesn't crash (graceful degradation)

6. **File Corruption Recovery**
   - [ ] Manually corrupt a save file (invalid JSON)
   - [ ] Try to load it
   - [ ] Verify error message shown
   - [ ] Verify game doesn't crash

7. **Overwrite Protection**
   - [ ] Try to start new game in occupied slot
   - [ ] Verify warning shown
   - [ ] Cancel and verify original save intact
   - [ ] Confirm overwrite and verify new save created

---

## Technical Notes

### File Paths

**Save Directory:** `user://saves/`
- Windows: `%APPDATA%\Godot\app_userdata\The Sparkling Farce\saves\`
- Linux: `~/.local/share/godot/app_userdata/The Sparkling Farce/saves/`
- Mac: `~/Library/Application Support/Godot/app_userdata/The Sparkling Farce/saves/`

**Save Files:**
- `slot_1.sav` - Full save data (JSON format)
- `slot_2.sav`
- `slot_3.sav`
- `slots.meta` - Quick metadata (JSON format)

### Performance Considerations

**Lazy Loading:**
- Only load full save when continuing (not for menu display)
- Use `slots.meta` for quick preview in menu
- Update metadata when saving

**Save Size:**
- Estimate: 50-200 KB per save (depends on party size, inventory)
- JSON is human-readable but larger than binary
- For later optimization: Use compressed binary format

**Save Frequency:**
- Auto-save: After each battle (configurable)
- Manual save: At churches/save points
- Quick save: F5 hotkey (future feature)

### Security Considerations

**Save Tampering:**
- No encryption planned (single-player game)
- Modding community may want to edit saves (this is fine)
- For competitive/speedrun integrity, consider checksums (future)

**Path Traversal:**
```gdscript
# Validate slot number to prevent path traversal
func _validate_slot_number(slot: int) -> bool:
    return slot >= 1 and slot <= 3
```

---

## Future Enhancements

### Phase 5+: Advanced Features

**Auto-Save Slots:**
- 3 manual slots + 1 auto-save slot
- Auto-save persists across sessions

**Quick Save/Load:**
- F5 to quick save
- F9 to quick load
- Separate from manual slots

**Save Screenshots:**
- Capture screenshot when saving
- Display in slot preview (like modern RPGs)

**Statistics Tracking:**
- Detailed stats: turns taken, damage dealt, healing done
- Per-character statistics
- Battle performance grades

**New Game+:**
- Complete game, start over with party intact
- Increased difficulty
- Unlockables

**Permadeath Mode:**
- Optional hardcore mode
- Dead characters stay dead
- Saved in campaign flags

---

## Summary

This save system design:

✅ **Authentic to Shining Force** - 3 slots, familiar menu flow, START/CONT/DEL/COPY operations
✅ **Mod-Compatible** - Gracefully handles mod additions/removals
✅ **Extensible** - Easy to add new save data fields
✅ **User-Friendly** - Clear warnings, no data loss
✅ **Platform-Independent** - Uses Godot's `user://` system
✅ **Testable** - Unit tests and integration tests defined
✅ **Future-Proof** - Save version migration strategy

### Implementation Timeline

**Week 1-2:** Phase 1 (Core Save/Load)
**Week 3:** Phase 2 (Save Slot UI)
**Week 4:** Phase 3 (Campaign State)
**Later:** Phase 4+ (Advanced Features)

**Estimated Total Effort:** 40-60 hours of development + testing

---

**End of Design Document**
