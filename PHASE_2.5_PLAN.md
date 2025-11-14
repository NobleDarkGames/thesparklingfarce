# Phase 2.5 Plan - Mod System Architecture

## Overview

Phase 2.5 establishes a comprehensive mod system that separates the game engine from game content, treating even the base game as "just another mod." This enables extensive modding support where developers can create modifications, total conversions, or entirely new games using The Sparkling Farce platform.

**Status**: Planning
**Priority**: Critical (Must complete before Phase 3 Runtime Systems)
**Philosophy**: "The base game is a mod" - Complete engine/content separation

---

## Research Summary

### Key Insights from Industry

**Game Modding Best Practices**:
- Modular design with clear module boundaries
- Avoid singletons - use context objects for communication
- Architecture is about change - design for extensibility
- Documentation and debugging tools are critical for modders

**Godot-Specific Approaches**:
- `ProjectSettings.load_resource_pack()` is the foundation
- Use `addons/` for third-party assets and mods
- Custom resources implement flyweight and type object patterns
- PackedScenes for complex objects, not code construction

**Kenshi's Approach (Forgotten Construction Set)**:
- Clear separation: Engine code vs. Content data
- All content in external files (mod folder structure)
- Modding tool (FCS) = their editor, like our Sparkling Editor
- Mods can override/extend core content
- Mod loading order determines priority (bottom overrides top)

---

## Current Architecture Analysis

### Current Structure
```
/sparklingfarce
├── addons/sparkling_editor/    # Editor plugin (engine)
├── core/
│   ├── resources/              # Resource definitions (engine)
│   ├── components/             # Game components (engine)
│   └── systems/                # Game systems (engine)
├── data/                       # Content (SHOULD BE MOD)
│   ├── abilities/
│   ├── battles/
│   ├── characters/
│   ├── classes/
│   ├── dialogues/
│   └── items/
├── assets/                     # Media files (SHOULD BE MOD)
└── templates/                  # Example resources
```

### Problems with Current Architecture

1. **No Mod System**: Content is hardcoded in `data/` and `assets/`
2. **No Mod Loading**: No way to load external mod folders
3. **No Mod Priority**: No load order or conflict resolution
4. **No Base Game Mod**: Base content not structured as a mod
5. **Path Hardcoding**: Editors use `res://data/` paths directly

---

## Proposed Architecture

### New Directory Structure

```
/sparklingfarce
├── addons/sparkling_editor/    # EDITOR TOOL (stays here)
├── core/                       # ENGINE CODE (stays here)
│   ├── resources/              # Resource type definitions
│   ├── components/             # Reusable components
│   ├── systems/                # Core systems (Grid, Turn, Battle)
│   └── mod_system/             # NEW: Mod loading system
│       ├── mod_loader.gd       # Discovers and loads mods
│       ├── mod_manifest.gd     # Mod metadata resource
│       ├── mod_registry.gd     # Tracks loaded content
│       └── mod_conflict.gd     # Handles conflicts/overrides
├── mods/                       # NEW: All game content here
│   ├── _base_game/             # Base game as first mod
│   │   ├── mod.json            # Mod manifest
│   │   ├── data/               # All .tres files
│   │   │   ├── abilities/
│   │   │   ├── battles/
│   │   │   ├── characters/
│   │   │   ├── classes/
│   │   │   ├── dialogues/
│   │   │   └── items/
│   │   └── assets/             # All media files
│   │       ├── icons/
│   │       ├── sprites/
│   │       └── music/
│   ├── example_mod/            # Example mod structure
│   │   ├── mod.json
│   │   ├── data/
│   │   └── assets/
│   └── user_mod/               # User's custom mod
│       ├── mod.json
│       ├── data/
│       └── assets/
└── templates/                  # Template resources (for editor)
```

### Mod Manifest Format (mod.json)

```json
{
  "id": "base_game",
  "name": "The Sparkling Farce - Base Game",
  "version": "1.0.0",
  "author": "Sparkling Farce Team",
  "description": "The base game content for The Sparkling Farce",
  "godot_version": "4.5",
  "dependencies": [],
  "load_priority": 0,
  "content": {
    "data_path": "data/",
    "assets_path": "assets/"
  },
  "overrides": [],
  "tags": ["base", "official"]
}
```

---

## Implementation Plan

### Step 1: Create Mod System Core

**Files to Create**:
1. `core/mod_system/mod_manifest.gd`
   - Resource class for mod metadata
   - Load from JSON, validate structure
   - Store dependencies, version, paths

2. `core/mod_system/mod_loader.gd`
   - Autoload singleton (necessary for mod system)
   - Scan `mods/` folder on game start
   - Load mods in priority order
   - Handle dependencies and conflicts

3. `core/mod_system/mod_registry.gd`
   - Track all loaded resources by type
   - Provide lookup functions (get all classes, get character by name, etc.)
   - Handle resource overrides (later mod overrides earlier)

4. `core/mod_system/mod_conflict.gd`
   - Detect ID conflicts between mods
   - Provide conflict resolution UI (Phase 3)
   - Log warnings for modders

### Step 2: Restructure Content as Base Mod

**Actions**:
1. Create `mods/_base_game/` directory
2. Move all content from `data/` to `mods/_base_game/data/`
3. Move all content from `assets/` to `mods/_base_game/assets/`
4. Create `mods/_base_game/mod.json` manifest
5. Update all .tres file paths to be relative to mod

### Step 3: Update Editor to be Mod-Aware

**Files to Modify**:
1. `addons/sparkling_editor/ui/base_resource_editor.gd`
   - Change `resource_directory` to query ModRegistry
   - Support multiple mod sources
   - Add "Active Mod" selector dropdown
   - Save to active mod's directory

2. `addons/sparkling_editor/ui/main_panel.gd`
   - Add mod selector UI
   - Show current active mod
   - Allow switching between mods
   - Refresh editors when mod changes

**New Features**:
- "Create New Mod" button
- "Set Active Mod" dropdown
- Mod info panel (name, author, version)

### Step 4: Update Resource Loading System

**Strategy**:
- Use `ModRegistry.get_all_resources(type)` instead of `DirAccess`
- Resources identified by `mod_id:resource_id`
- Later mods can override earlier mod resources with same ID

**Example**:
```gdscript
# Old way (Phase 2)
var dir: DirAccess = DirAccess.open("res://data/characters/")

# New way (Phase 2.5)
var characters: Array[CharacterData] = ModRegistry.get_all_resources("character")
```

### Step 5: Create Example Mod

**Actions**:
1. Create `mods/example_mod/` directory
2. Create simple mod.json
3. Add 1-2 example characters/items
4. Document mod creation process
5. Test loading with base game

---

## Technical Implementation Details

### Mod Loading Process

```gdscript
# core/mod_system/mod_loader.gd (Autoload)
@tool
extends Node

var registry: ModRegistry
var loaded_mods: Array[ModManifest] = []

func _ready() -> void:
    registry = ModRegistry.new()
    _discover_mods()
    _load_mods_in_priority_order()
    _populate_registry()

func _discover_mods() -> void:
    # Scan mods/ folder
    # Parse each mod.json
    # Sort by load_priority

func _load_mods_in_priority_order() -> void:
    # Load base game first (priority 0)
    # Then load each mod
    # Handle dependencies
    # Apply overrides

func _populate_registry() -> void:
    # Scan each mod's data/ folder
    # Load all .tres files
    # Register with ModRegistry
```

### Resource Path Resolution

```gdscript
# Resources use virtual paths like:
# "mod://base_game/data/characters/hero.tres"
# "mod://user_mod/data/characters/custom_hero.tres"

# ModLoader provides resolution:
func resolve_mod_path(virtual_path: String) -> String:
    # Parse mod:// protocol
    # Find mod by ID
    # Return actual res:// path
```

### Mod Priority & Overrides

```gdscript
# If two mods have same resource ID:
# mods/_base_game/data/classes/hero.tres
# mods/balance_mod/data/classes/hero.tres

# The mod with HIGHER priority wins
# Balance mod (priority 100) overrides base game (priority 0)
```

---

## Benefits of This Architecture

### For Developers
- **Clear Separation**: Engine code vs game content
- **Reusable Platform**: Build entirely different games
- **Version Control**: Mods can be separate repos
- **Testing**: Test mods independently

### For Modders
- **Easy Discovery**: Drop folder in mods/, it loads
- **Non-Destructive**: Never modify base game files
- **Override System**: Replace any base game content
- **Total Conversions**: Create completely different games

### For Players
- **Mod Support**: Install mods easily
- **Mod Combinations**: Mix and match mods
- **Conflict Resolution**: Know when mods conflict
- **Mod Manager**: Future UI for enabling/disabling mods

---

## Editor Integration

### Sparkling Editor Changes

**New UI Elements**:
1. **Mod Selector** (top of main panel)
   - Dropdown: "Active Mod: [_base_game] ▼"
   - Shows all available mods
   - Switching refreshes all editors

2. **Mod Manager Tab** (new tab)
   - List all installed mods
   - Show mod info (name, version, author)
   - Enable/Disable mods (Phase 3)
   - Create new mod button
   - Export mod as .zip (Phase 3)

3. **Resource Browser Enhancements**
   - Show which mod each resource comes from
   - Filter by mod
   - Show override indicators (when mod overrides base game)

**Create New Mod Workflow**:
1. Click "Create New Mod" button
2. Enter mod details (name, author, ID)
3. Select base mod to extend (usually base_game)
4. Editor creates mod folder structure and manifest
5. Set as active mod
6. Start creating content

---

## Compatibility & Migration

### Phase 2 → Phase 2.5 Migration

**Automatic Migration Script**:
```gdscript
# tools/migrate_to_mod_system.gd
# Run once to convert Phase 2 structure to Phase 2.5

func migrate() -> void:
    # 1. Create mods/_base_game/ structure
    # 2. Move data/ content
    # 3. Move assets/ content
    # 4. Update all .tres file paths
    # 5. Generate base_game mod.json
```

**Path Updates**:
- Old: `res://data/characters/hero.tres`
- New: `mod://base_game/data/characters/hero.tres`
- Or: `res://mods/_base_game/data/characters/hero.tres`

### Backwards Compatibility

**Editor Support**:
- Sparkling Editor works with both structures (detect which)
- Show warning if old structure detected
- Offer one-click migration button

---

## Testing Strategy

### Unit Tests
1. Test mod discovery and loading
2. Test priority and override system
3. Test dependency resolution
4. Test mod manifest parsing

### Integration Tests
1. Load base game mod
2. Load example mod on top
3. Verify override behavior
4. Test editor mod switching

### Manual Tests
1. Create new mod from editor
2. Add content to custom mod
3. Override base game resource
4. Verify in-game (when runtime exists)

---

## Documentation Needs

### For Developers
1. Mod system architecture overview
2. Creating the ModLoader autoload
3. Using ModRegistry in code
4. Migration guide from Phase 2

### For Modders
1. Mod folder structure
2. mod.json format reference
3. Creating your first mod
4. Overriding base game content
5. Publishing and sharing mods

---

## Risks & Mitigation

### Risk 1: Path Refactoring Complexity
**Risk**: Updating all resource paths is error-prone
**Mitigation**: Create automated migration script, thorough testing

### Risk 2: Editor Complexity
**Risk**: Mod-aware editor becomes too complex
**Mitigation**: Start simple (just active mod selector), iterate

### Risk 3: Performance Impact
**Risk**: Loading many mods could be slow
**Mitigation**: Lazy loading, caching, Phase 3 optimization

### Risk 4: Breaking Changes
**Risk**: Existing .tres files break
**Mitigation**: Support both old and new paths during transition

---

## Success Criteria

Phase 2.5 will be considered complete when:

✅ ModLoader system implemented and working
✅ Base game content moved to `mods/_base_game/`
✅ All resource paths updated and working
✅ Sparkling Editor is mod-aware
✅ Can create new mod from editor
✅ Example mod loads and overrides base game
✅ No regressions in Phase 2 functionality
✅ Migration guide documented
✅ Modder documentation complete

---

## Implementation Order

### Week 1: Core Infrastructure
1. Create `core/mod_system/` folder structure
2. Implement `ModManifest` resource
3. Implement `ModLoader` autoload
4. Implement `ModRegistry` singleton
5. Basic mod discovery and loading
6. Unit tests for mod system

### Week 2: Content Migration
1. Create automated migration script
2. Create `mods/_base_game/` structure
3. Move all content from `data/` and `assets/`
4. Update resource paths in .tres files
5. Create base game mod.json
6. Verify all resources load correctly

### Week 3: Editor Integration
1. Add mod selector to main panel
2. Update base_resource_editor for mod-awareness
3. Implement "Create New Mod" functionality
4. Add mod info display
5. Test editor with multiple mods
6. Create example mod

### Week 4: Testing & Documentation
1. Integration testing
2. Manual testing with real mods
3. Write developer documentation
4. Write modder documentation
5. Create tutorial videos/guides
6. Polish and bug fixes

---

## Future Enhancements (Phase 3+)

### Mod Manager UI
- In-game mod browser
- Enable/disable mods without editor
- Mod load order adjustment
- Conflict resolution UI

### Advanced Features
- Hot reloading mods during development
- Mod workshop integration (Steam, itch.io)
- Mod dependency auto-download
- Version compatibility checking
- Mod packaging and export

### Developer Tools
- Mod validator (check for errors)
- Conflict detector and resolver
- Performance profiler per mod
- Mod diff viewer (compare with base)

---

## Comparison with Other Systems

### Our System vs Kenshi FCS
| Feature | Kenshi FCS | Sparkling Editor |
|---------|-----------|------------------|
| Editor Tool | ✅ Yes | ✅ Yes |
| Mod Folder | ✅ Yes | ✅ Yes |
| Base Game = Mod | ✅ Yes | ✅ Yes (Phase 2.5) |
| Load Priority | ✅ Yes | ✅ Yes (Phase 2.5) |
| Override System | ✅ Yes | ✅ Yes (Phase 2.5) |
| In-Engine | ❌ External | ✅ Godot Plugin |

### Our System vs Skyrim/Fallout
| Feature | Bethesda Games | Sparkling Farce |
|---------|---------------|-----------------|
| .esp Files | ✅ Yes | ✅ mod.json |
| Load Order | ✅ Yes | ✅ Priority System |
| Conflicts | ⚠️ Manual | ✅ Auto-detect |
| Editor | ✅ Creation Kit | ✅ Sparkling Editor |
| Total Conversion | ✅ Yes | ✅ Yes |

---

## Timeline Estimate

**Total Time**: 3-4 weeks of development

- **Core Infrastructure**: 1 week
- **Content Migration**: 1 week
- **Editor Integration**: 1 week
- **Testing & Documentation**: 1 week

This phase is critical and should not be rushed. Getting mod architecture right now prevents major refactoring later.

---

## Next Steps

1. ✅ Create PHASE_2.5_PLAN.md (this document)
2. ⏳ Review and approve plan
3. ⏳ Create `core/mod_system/` folder
4. ⏳ Implement ModManifest resource
5. ⏳ Implement ModLoader autoload
6. ⏳ Test basic mod loading
7. ⏳ Begin content migration

---

**Created**: November 13, 2024
**Status**: Awaiting Approval
**Next Review**: After approval and before implementation
