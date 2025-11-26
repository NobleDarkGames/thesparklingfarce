# Phase 2.5.1 - Mod Extensibility Improvements

**Status:** Planned (Not Started)
**Priority:** Medium
**Dependencies:** Phase 2.5 complete ✅
**Target:** Before Phase 4 (Equipment/Magic/Items)
**Estimated Effort:** 8-12 hours

---

## Overview

Phase 2.5 successfully implemented collision detection and trigger systems, providing the critical infrastructure needed for campaign creation. However, Modro's comprehensive review identified 4 critical gaps in mod extensibility that limit the platform's ability to support total conversion mods and third-party content creators.

This phase addresses those gaps to ensure The Sparkling Farce truly fulfills its mission as a modding platform, not just a single game.

---

## Strategic Context

**From Commander Claudius:**
> "The trigger system foundation is solid and authentic to Shining Force patterns. However, for this to be a true platform, modders need the same extensibility we have."

**From Modro (Moddability Score: 6.5/10):**
> "Current implementation: Functional but NOT mod-friendly. Four critical issues prevent total conversion mods."

**Captain's Decision:**
> "It will be some time before we need full extensive total conversion mod support. But update our plans to work on that soon."

---

## Problem Statement

The current Phase 2.5 implementation has these mod system integration gaps:

### 1. ModLoader Cannot Discover Triggers (CRITICAL)
**Impact:** Modders cannot add new trigger types without editing core code
**Current State:** Triggers must be manually instantiated in scenes
**Desired State:** ModLoader discovers and registers trigger types from mods

### 2. TriggerType Enum Cannot Be Extended (CRITICAL)
**Impact:** Total conversion mods stuck with base game's trigger types
**Current State:** `enum TriggerType { BATTLE, DIALOG, CHEST, DOOR, CUTSCENE, TRANSITION, CUSTOM }`
**Desired State:** String-based type system with mod registration

### 3. GameState Flag Namespace Collision (HIGH)
**Impact:** Mod A can accidentally overwrite Mod B's story flags
**Current State:** Global `story_flags` dictionary with no namespacing
**Desired State:** Namespaced flags like `"mod_name:flag_name"`

### 4. Hardcoded TileSet Paths (MEDIUM)
**Impact:** Replacing base tilesets requires editing scene files
**Current State:** `res://mods/_base_game/tilesets/terrain_placeholder.tres`
**Desired State:** ModLoader provides tileset resolution by name

---

## Success Criteria

### Functional Requirements
- ✅ ModLoader can discover and register custom trigger scripts from any mod
- ✅ Mods can define custom trigger types without enum limitations
- ✅ Story flags are namespaced to prevent mod conflicts
- ✅ TileSets can be overridden by mod priority without scene edits

### Technical Requirements
- ✅ Zero breaking changes to existing triggers and scenes
- ✅ Backward compatibility with Phase 2.5 implementation
- ✅ Performance impact < 5ms on mod loading
- ✅ Clear documentation for modders

### Quality Requirements
- ✅ Lt. Claudette code review: 4.5/5 or higher
- ✅ Commander Claudius platform alignment: Approved
- ✅ Modro moddability score: 8.5/10 or higher
- ✅ All existing tests pass

---

## Proposed Solutions

### Issue 1: ModLoader Trigger Discovery

**Approach:** Extend ModLoader to discover scripts in `mods/*/triggers/` directories

```gdscript
# In ModLoader
var registered_triggers: Dictionary = {}  # trigger_name -> script_path

func _discover_triggers(mod_config: Dictionary) -> void:
    var triggers_dir: String = mod_config.path + "/triggers"
    if not DirAccess.dir_exists_absolute(triggers_dir):
        return

    var dir: DirAccess = DirAccess.open(triggers_dir)
    for file in dir.get_files():
        if file.ends_with(".gd"):
            var trigger_name: String = file.get_basename()
            registered_triggers[trigger_name] = triggers_dir + "/" + file

func get_trigger_script(trigger_name: String) -> Script:
    if trigger_name in registered_triggers:
        return load(registered_triggers[trigger_name])
    return null
```

**Mod Structure:**
```
mods/my_campaign/
  triggers/
    lava_trap_trigger.gd   # Discovered automatically
    teleport_trigger.gd     # Discovered automatically
```

**Backward Compatibility:** Existing triggers continue to work via `extends MapTrigger`

---

### Issue 2: Extensible Trigger Types

**Approach:** Replace enum with string-based registration system

**Before:**
```gdscript
enum TriggerType { BATTLE, DIALOG, CHEST, DOOR, CUTSCENE, TRANSITION, CUSTOM }
@export var trigger_type: TriggerType = TriggerType.BATTLE
```

**After:**
```gdscript
@export var trigger_type: String = "battle"  # String-based, extensible

# MapTrigger validates against registered types
func _validate_trigger_type() -> bool:
    return ModLoader.is_trigger_type_registered(trigger_type)
```

**Migration Strategy:**
- Add string-based `trigger_type_name: String` export
- Keep enum for backward compatibility (deprecated)
- If `trigger_type_name` is empty, use enum value as fallback
- Remove enum in Phase 5

**Mod Example:**
```gdscript
# mods/my_campaign/triggers/lava_trap_trigger.gd
extends MapTrigger

func _init() -> void:
    trigger_type = "lava_trap"  # Custom type
    ModLoader.register_trigger_type("lava_trap")
```

---

### Issue 3: Namespaced Story Flags

**Approach:** Require namespace prefix for all flags

**Before:**
```gdscript
GameState.set_flag("bridge_destroyed")  # No namespace
GameState.has_flag("bridge_destroyed")
```

**After:**
```gdscript
# Explicit namespace (recommended for mods)
GameState.set_flag("my_campaign:bridge_destroyed")
GameState.has_flag("my_campaign:bridge_destroyed")

# Auto-namespace using current mod context
GameState.set_flag_scoped("bridge_destroyed")  # Becomes "my_campaign:bridge_destroyed"
```

**Implementation:**
```gdscript
# In GameState
var current_mod_namespace: String = "_base_game"  # Set by ModLoader

func set_flag_scoped(flag_name: String, value: bool = true) -> void:
    var namespaced_flag: String = current_mod_namespace + ":" + flag_name
    set_flag(namespaced_flag, value)

func has_flag_scoped(flag_name: String) -> bool:
    var namespaced_flag: String = current_mod_namespace + ":" + flag_name
    return has_flag(namespaced_flag)
```

**Migration Strategy:**
- Existing flags without `:` work as-is (default `_base_game` namespace)
- New flags should use explicit namespaces
- Add deprecation warning for non-namespaced flags in Phase 4

---

### Issue 4: TileSet Resolution by Name

**Approach:** ModLoader provides resource lookup by logical name

**Before:**
```gdscript
# Hardcoded in scene files
tile_set = preload("res://mods/_base_game/tilesets/terrain_placeholder.tres")
```

**After:**
```gdscript
# Scene file references logical name
@export var tileset_name: String = "terrain_placeholder"

func _ready() -> void:
    tile_set = ModLoader.get_tileset(tileset_name)
```

**ModLoader Implementation:**
```gdscript
var registered_tilesets: Dictionary = {}  # name -> TileSet resource

func register_tileset(name: String, tileset: TileSet) -> void:
    # Higher priority mods override lower priority
    if name not in registered_tilesets or _should_override(name):
        registered_tilesets[name] = tileset

func get_tileset(name: String) -> TileSet:
    return registered_tilesets.get(name, null)
```

**Mod Declaration (mod.json):**
```json
{
  "provides": {
    "tilesets": {
      "terrain_placeholder": "res://mods/my_mod/tilesets/my_terrain.tres"
    }
  }
}
```

---

## Implementation Plan

### Phase 2.5.1.1 - Trigger Discovery (3-4 hours)
1. Extend ModLoader._discover_mod_content() to scan `triggers/` directories
2. Add registered_triggers dictionary
3. Implement get_trigger_script() lookup
4. Test with custom trigger in _sandbox mod

**Deliverables:**
- ModLoader.get_trigger_script() method
- Trigger discovery in mod loading pipeline
- Test trigger in _sandbox

### Phase 2.5.1.2 - String-Based Trigger Types (2-3 hours)
1. Add trigger_type_name export to MapTrigger
2. Implement ModLoader.register_trigger_type()
3. Add validation in MapTrigger._ready()
4. Create migration path for existing triggers

**Deliverables:**
- String-based trigger type system
- Backward compatibility for enum
- Updated MapTrigger documentation

### Phase 2.5.1.3 - Namespaced Flags (2-3 hours)
1. Add current_mod_namespace to GameState
2. Implement set_flag_scoped() / has_flag_scoped()
3. ModLoader sets namespace when loading mods
4. Add namespace validation

**Deliverables:**
- Scoped flag methods
- Namespace tracking in ModLoader
- Migration guide for existing flags

### Phase 2.5.1.4 - TileSet Resolution (1-2 hours)
1. Implement ModLoader.register_tileset()
2. Add tileset discovery from mod.json
3. Implement get_tileset() lookup with priority
4. Update collision_test_001.tscn to use lookup

**Deliverables:**
- TileSet registration system
- mod.json tileset declaration support
- Updated test scene

---

## Testing Strategy

### Unit Tests
- ModLoader trigger discovery (scan directories, load scripts)
- Trigger type registration and validation
- Flag namespace collision prevention
- TileSet priority override

### Integration Tests
- Load mod with custom trigger, verify discovery
- Custom trigger activates correctly
- Namespaced flags isolated between mods
- TileSet override by higher priority mod

### Regression Tests
- All Phase 2.5 tests pass
- Existing triggers work unchanged
- Story flags backward compatible
- Collision test scene still works

---

## Documentation Requirements

### For Modders
- **Trigger Creation Guide** - How to create custom trigger types
- **Story Flag Best Practices** - Namespace conventions
- **Asset Override Guide** - How to replace tilesets

### For Core Team
- **ModLoader Architecture** - Updated with new discovery systems
- **Migration Guide** - How to update Phase 2.5 content

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Breaking existing triggers | Low | High | Backward compatibility layer, thorough testing |
| Performance regression | Low | Medium | Benchmark mod loading, lazy loading triggers |
| Flag namespace confusion | Medium | Medium | Clear documentation, helper methods |
| TileSet override conflicts | Low | Low | Clear priority rules, warnings |

---

## Open Questions

1. **Trigger Type Enum Deprecation Timeline**
   - Keep enum until Phase 5?
   - Add deprecation warnings in Phase 4?
   - **Decision:** TBD by Captain

2. **Flag Namespace Enforcement**
   - Require namespaces immediately or gradual migration?
   - Warning vs error for non-namespaced flags?
   - **Decision:** TBD by Captain

3. **TileSet Lookup Performance**
   - Cache lookups or load on demand?
   - Preload all tilesets or lazy load?
   - **Decision:** TBD by Lt. Claudbrain

---

## Success Metrics

**Before Phase 2.5.1:**
- Moddability Score: 6.5/10
- Trigger extensibility: Hardcoded enum
- Flag isolation: None
- Asset override: Manual scene editing

**After Phase 2.5.1:**
- Moddability Score: 8.5/10+ (target)
- Trigger extensibility: Fully dynamic
- Flag isolation: Namespace protected
- Asset override: Declarative (mod.json)

---

## Next Steps After Completion

1. **Update MOD_SYSTEM.md** with new capabilities
2. **Create example mod** demonstrating all 4 improvements
3. **Proceed to Phase 2.5.2** (Scene Transitions)
4. **Blog post** - "The Sparkling Farce: Building a True Modding Platform"

---

**Plan Created:** November 25, 2025
**Author:** Commander Claudius, Modro, Lt. Claudbrain
**Approved By:** Captain (pending)
**Target Start:** After Phase 2.5.2 completion
