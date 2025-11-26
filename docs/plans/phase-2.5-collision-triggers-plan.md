# Phase 2.5: Map Collision & Trigger System Implementation Plan

**Date:** November 25, 2025
**Status:** APPROVED by Commander Claudius
**Priority:** CRITICAL - Blocks all Phase 4+ work

---

## MISSION OBJECTIVE

Fix critical infrastructure gaps in map exploration system to enable playable campaign gameplay loop (explore → battle → explore).

## CRITICAL ISSUES IDENTIFIED

### Issue #1: Collision Detection - BROKEN
- **Location:** `scenes/map_exploration/hero_controller.gd:162`
- **Problem:** `_is_tile_walkable()` returns `true` for ALL tiles
- **Impact:** Hero can walk through walls, water, obstacles

### Issue #2: Trigger System - EMPTY STUB
- **Location:** `scenes/map_exploration/hero_controller.gd:165-173`
- **Problem:** `_check_tile_triggers()` contains only `pass`
- **Impact:** Cannot initiate battles, events, or NPC interactions from map

### Issue #3: No TileSet Configuration
- **Location:** `scenes/map_exploration/map_test.tscn:13-14`
- **Problem:** TileMapLayer has `tile_set = null`
- **Impact:** No tile data exists for collision system to check

---

## IMPLEMENTATION PHASES

### Priority 1: Map Tileset & Collision Setup

**Objective:** Create foundational tileset with collision data

**Tasks:**
1. Create placeholder tile assets (16x16 colored PNG squares)
   - Green = Grass (walkable)
   - Gray = Wall (blocked)
   - Blue = Water (blocked)
   - Brown = Road/Path (walkable)
   - Yellow = Door (special trigger)
   - Red = Battle trigger tile (testing only)

2. Create TileSet resource
   - Setup physics layers for collision
   - Configure tile collision shapes
   - Assign tiles to appropriate layers

3. Integrate TileSet with TileMapLayer
   - Configure map_test.tscn with new tileset
   - Paint test map with walkable/blocked tiles
   - Add decorative layer (non-colliding)

**Deliverables:**
- Functional TileSet resource
- Test map with collision data
- Visual distinction between walkable/impassable

---

### Priority 2: Hero Collision Detection

**Objective:** Implement proper collision checking in hero_controller.gd

**Tasks:**
1. Add TileMapLayer reference to HeroController
2. Implement `_is_tile_walkable()` using TileMap collision layers
3. Test hero movement against walls, water, obstacles
4. Verify party following still works correctly
5. Add edge-of-map bounds checking

**Current Code (BROKEN):**
```gdscript
func _is_tile_walkable(tile_pos: Vector2i) -> bool:
    # TODO: Check TileMap for collision/walkability
    # For now, allow all movement
    return true  # ALLOWS WALKING THROUGH WALLS!
```

**Target Implementation:**
```gdscript
@onready var tile_map: TileMapLayer = get_node("../../ObstacleLayer")

func _is_tile_walkable(tile_pos: Vector2i) -> bool:
    # Check if tile is within map bounds
    if not _is_within_map_bounds(tile_pos):
        return false

    # Check obstacle layer for collision
    var tile_data: TileData = tile_map.get_cell_tile_data(tile_pos)
    if tile_data == null:
        return true  # No tile = walkable

    # Check physics layer 0 for collision
    return not tile_data.get_collision_polygons_count(0) > 0
```

**Deliverables:**
- Working collision detection
- Hero cannot walk through walls
- Party followers respect collision
- Smooth movement around obstacles

---

### Priority 3: Trigger System Foundation

**Objective:** Create extensible, mod-friendly trigger architecture

**Architecture Decision (per Commander Claudius):**
- Use Area2D-based triggers (NOT tile-based detection in hero_controller)
- Decouple trigger logic from HeroController
- Implement story flag system from day one
- Support conditional triggers (required/forbidden flags)

**Tasks:**

#### 3.1: Story Flag System
Create `core/systems/game_state.gd` autoload singleton:
```gdscript
extends Node

var story_flags: Dictionary = {}
var completed_triggers: Dictionary = {}

func has_flag(flag_name: String) -> bool:
    return story_flags.get(flag_name, false)

func set_flag(flag_name: String, value: bool = true) -> void:
    story_flags[flag_name] = value
    flag_changed.emit(flag_name, value)

func is_trigger_completed(trigger_id: String) -> bool:
    return completed_triggers.get(trigger_id, false)

func set_trigger_completed(trigger_id: String) -> void:
    completed_triggers[trigger_id] = true
    trigger_completed.emit(trigger_id)

signal flag_changed(flag_name: String, value: bool)
signal trigger_completed(trigger_id: String)
```

#### 3.2: MapTrigger Base Class
Create `core/components/map_trigger.gd`:
```gdscript
class_name MapTrigger
extends Area2D

enum TriggerType { BATTLE, DIALOG, CHEST, DOOR, CUTSCENE, TRANSITION, CUSTOM }

@export var trigger_type: TriggerType = TriggerType.BATTLE
@export var trigger_id: String = ""  # Unique identifier
@export var one_shot: bool = true
@export var required_flags: Array[String] = []  # Must have these
@export var forbidden_flags: Array[String] = []  # Must NOT have these
@export var trigger_data: Dictionary = {}  # Type-specific payload

signal triggered(trigger: MapTrigger, player: Node2D)

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("hero"):
        if can_trigger():
            activate(body)

func can_trigger() -> bool:
    # Check if already triggered (for one-shot)
    if one_shot and GameState.is_trigger_completed(trigger_id):
        return false

    # Check required flags
    for flag in required_flags:
        if not GameState.has_flag(flag):
            return false

    # Check forbidden flags
    for flag in forbidden_flags:
        if GameState.has_flag(flag):
            return false

    return true

func activate(player: Node2D) -> void:
    triggered.emit(self, player)

    # Mark as completed for one-shot triggers
    if one_shot:
        GameState.set_trigger_completed(trigger_id)
```

#### 3.3: TriggerManager (Dispatcher)
Create `core/systems/trigger_manager.gd` autoload:
```gdscript
extends Node

func _ready() -> void:
    # Connect to all MapTrigger signals in current scene
    pass

func _on_trigger_activated(trigger: MapTrigger, player: Node2D) -> void:
    match trigger.trigger_type:
        MapTrigger.TriggerType.BATTLE:
            _handle_battle_trigger(trigger)
        MapTrigger.TriggerType.DIALOG:
            _handle_dialog_trigger(trigger)
        # ... etc

func _handle_battle_trigger(trigger: MapTrigger) -> void:
    var battle_id: String = trigger.trigger_data.get("battle_id", "")
    if battle_id.is_empty():
        push_error("Battle trigger missing battle_id")
        return

    # Transition to battle
    BattleManager.start_battle(battle_id)
```

**Deliverables:**
- GameState autoload with flag system
- MapTrigger base class (Area2D)
- TriggerManager dispatcher
- Save system integration (flags persist)

---

### Priority 4: Battle Triggers

**Objective:** Implement explore → battle → explore gameplay loop

**Tasks:**
1. Create BattleTrigger scene (extends MapTrigger)
2. Add collision shape (rectangular Area2D)
3. Configure trigger_type = BATTLE
4. Add battle_id to trigger_data
5. Test one-shot functionality
6. Implement scene transition (map → battle → map)
7. Handle post-battle return (restore hero position)
8. Mark trigger as completed after victory

**Example Trigger Configuration:**
```
BattleTrigger_001:
  trigger_id: "first_battle"
  trigger_type: BATTLE
  one_shot: true
  required_flags: []
  forbidden_flags: []
  trigger_data:
    battle_id: "tutorial_battle_001"
    return_position: Vector2(5, 7)
```

**Integration with BattleManager:**
- BattleManager.start_battle() already exists
- Need to add return-to-map functionality
- Store pre-battle scene path and hero position
- Emit battle_completed signal
- TriggerManager handles transition back to map

**Deliverables:**
- Working battle triggers
- Scene transition system
- Post-battle return to map
- One-shot trigger completion

---

### Priority 5: Extended Triggers (Future)

**Deferred to later phases:**
- Dialog triggers
- Chest/treasure triggers
- Door triggers (keys, unlocking)
- Cutscene triggers
- Scene transition triggers
- NPC interaction triggers

---

## GODOT 4.5 TILEMAP STRUCTURE

```
MapScene (Node2D)
├─ GroundLayer (TileMapLayer) - grass, floors, roads (always walkable)
├─ ObstacleLayer (TileMapLayer) - walls, water, cliffs (collision enabled)
├─ DecorationLayer (TileMapLayer) - visual flair (non-colliding)
├─ TriggerLayer (Node2D) - MapTrigger instances
├─ NPCLayer (Node2D) - NPC characters (future)
└─ PartyLayer (Node2D) - Hero + Followers
```

---

## SHINING FORCE AUTHENTICITY REQUIREMENTS

### Collision System
1. **Binary Collision** - Tiles are walkable or not (no gradual movement costs yet)
2. **NPC Blocking** - NPCs block movement (temporary obstacles)
3. **Layered Terrain** - Ground (always walkable) + Obstacles (blocked)

### Trigger System
1. **Invisible Triggers** - Battles trigger on tile entry (no visible markers in SF)
2. **One-Shot Battles** - Mark as completed after victory
3. **Story Flags** - Control trigger availability based on progress
4. **Trigger Types:**
   - Battle triggers (one-shot)
   - Door triggers (open/close, key checks)
   - Chest triggers (one-shot, grant items)
   - NPC dialog triggers (repeatable, flag-based)
   - Scene transitions (teleport to new maps)
   - Cutscene triggers (conditional on story)

---

## ASSET ORGANIZATION

**Decision Pending:** Consult Modro (mod architect) on proper location for placeholder tiles.

**Options:**
1. Store in `mods/_base_game/` (engine test content)
2. Create new `mods/_test_sandbox/` (overlay mod for testing)
3. Other architecture recommended by Modro

**Requirements:**
- Must follow "content is in mods" philosophy
- Must be easily replaceable by mod creators
- Should not pollute engine/core directories

---

## TESTING CHECKLIST

### Phase 1 Tests (Collision)
- [ ] Hero cannot walk through gray wall tiles
- [ ] Hero cannot walk into blue water tiles
- [ ] Hero CAN walk on green grass tiles
- [ ] Hero CAN walk on brown road tiles
- [ ] Party followers respect collision
- [ ] Camera follows hero smoothly
- [ ] Movement animation plays correctly

### Phase 2 Tests (Triggers)
- [ ] Stepping on battle trigger initiates battle
- [ ] Battle trigger only fires once (one-shot)
- [ ] Required flags prevent trigger activation
- [ ] Forbidden flags prevent trigger activation
- [ ] After battle victory, return to map at correct position
- [ ] Trigger marked as completed in GameState
- [ ] Save system persists completed triggers

---

## SUCCESS CRITERIA

Phase 2.5 is COMPLETE when:
1. ✅ Hero collision detection works (cannot walk through walls)
2. ✅ Battle triggers work (explore → battle → explore loop functional)
3. ✅ Story flag system implemented
4. ✅ One-shot triggers mark as completed
5. ✅ Save system persists flags and trigger state
6. ✅ Test map demonstrates all functionality

---

## ESTIMATED EFFORT

- **Priority 1** (Tileset): 1-2 hours
- **Priority 2** (Collision): 2-3 hours
- **Priority 3** (Trigger Foundation): 3-4 hours
- **Priority 4** (Battle Triggers): 2-3 hours

**Total:** 8-12 hours for complete Phase 2.5 implementation

---

## NEXT PHASES (After Phase 2.5)

Only proceed to these after Phase 2.5 is COMPLETE:

- **Phase 4:** Equipment, Magic, Item Usage
- **Phase 5:** Advanced AI, Status Effects, Terrain
- **Phase 6:** Headquarters, World Map, Campaign Structure

**Rationale:** Cannot test shops/equipment without working exploration loop. Cannot create campaigns without working triggers.

---

## REFERENCES

- Commander Claudius Strategic Assessment (November 25, 2025)
- `/home/user/dev/sparklingfarce/scenes/map_exploration/hero_controller.gd` (lines 155-173)
- `/home/user/dev/sparklingfarce/scenes/map_exploration/map_test.tscn`
- Godot 4.5 TileMapLayer documentation
- Shining Force game design patterns
