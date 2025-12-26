# Cinematic Spawn Entity & Actors Array Implementation Plan

**STATUS: COMPLETE** (December 25, 2025)

## Overview

Enable data-driven cinematics by implementing `spawn_entity` and adding an `actors` array to cinematic JSON. This allows modders to create cinematics without Godot scene expertise.

## Implementation Summary

All phases implemented with additional features:

- **Spawnable Entity Registry** - Extensible handler pattern in `core/systems/cinematic_spawners/`
- **Built-in handlers**: CharacterSpawnHandler, NPCSpawnHandler, InteractableSpawnHandler
- **actors array** - Pre-spawn entities before commands execute
- **spawn_entity command** - Runtime spawning with `entity_type` + `entity_id` parameters
- **Backward compatibility** - `character_id` maps to `entity_type: "character"`
- **set_backdrop command** - Load maps as visual-only backdrops

## Original Plan (for reference)

### Implementation Tasks

### Phase 1: Implement spawn_entity Executor

**File:** `core/systems/cinematic_commands/spawn_entity_executor.gd`

**Parameters (from cinematic_editor.gd COMMAND_DEFINITIONS):**
- `actor_id`: String - unique ID for this spawned actor
- `position`: Vector2 (grid coordinates)
- `facing`: enum ["up", "down", "left", "right"]
- `character_id`: String - CharacterData to spawn (optional)

**Implementation:**
1. Look up CharacterData from ModLoader.registry if character_id provided
2. Create CharacterBody2D node as the entity container
3. Create AnimatedSprite2D child with sprite_frames from CharacterData
4. Create CinematicActor child component with actor_id
5. Position entity at grid coordinates (use GridManager.cell_to_world)
6. Set initial facing direction
7. Add entity to current scene tree (under a "spawned_actors" container)
8. CinematicActor auto-registers with CinematicsManager

**Spawned Entity Structure:**
```
SpawnedActor_{actor_id} (CharacterBody2D)
├── AnimatedSprite2D (sprite_frames from CharacterData)
└── CinematicActor (actor_id, auto-registers)
```

**Edge Cases:**
- No character_id: Create minimal Node2D with CinematicActor (for props)
- Actor ID already exists: Log warning, overwrite registration
- Invalid position: Default to (0, 0) with warning

### Phase 2: Add actors Array Support to CinematicsManager

**File:** `core/systems/cinematics_manager.gd`

**Changes to `play_cinematic_from_resource()`:**
1. Before executing commands, check for `actors` array in cinematic data
2. For each actor definition, call spawn_entity logic
3. Wait for all actors to register before proceeding

**New JSON Schema:**
```json
{
  "cinematic_id": "example",
  "actors": [
    {
      "actor_id": "hero",
      "character_id": "max",
      "position": [9, 13],
      "facing": "up"
    }
  ],
  "commands": [...]
}
```

**Changes to CinematicData resource:**
- Add `actors: Array[Dictionary]` property (optional)
- Actors spawn before first command executes

### Phase 3: Cleanup on Cinematic End

**File:** `core/systems/cinematics_manager.gd`

**Changes to `_end_cinematic()`:**
1. Track spawned actors in `_spawned_actor_nodes: Array[Node]`
2. On cinematic end, queue_free all spawned actor nodes
3. CinematicActor auto-unregisters on _exit_tree (already implemented)

### Phase 4: Update Editor UI

**File:** `addons/sparkling_editor/ui/cinematic_editor.gd`

**Add Actors Panel (collapsible section above Commands):**
- List of actors with columns: ID, Character, Position, Facing
- Add Actor button with character picker
- Position as two spinboxes (X, Y grid coords)
- Facing as dropdown
- Delete button per row

**Save/Load:**
- Read `actors` array from JSON
- Write `actors` array to JSON on save

## File Changes Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `core/systems/cinematic_commands/spawn_entity_executor.gd` | Rewrite | Full implementation |
| `core/systems/cinematics_manager.gd` | Modify | Add actors array pre-spawn, cleanup tracking |
| `core/resources/cinematic_data.gd` | Modify | Add actors property |
| `addons/sparkling_editor/ui/cinematic_editor.gd` | Modify | Add actors panel UI |

## Testing Checklist

- [x] spawn_entity with character_id spawns visible character
- [x] spawn_entity with no character_id spawns minimal actor
- [x] Spawned actors respond to move_entity commands
- [x] Spawned actors respond to set_facing commands
- [x] despawn_entity works on spawned actors
- [x] actors array spawns before fade_in
- [x] Spawned actors cleaned up on cinematic end
- [x] Spawned actors cleaned up on cinematic skip
- [x] Editor displays actors in list
- [x] Editor can add/remove actors
- [x] Editor saves/loads actors array

## Success Criteria

A modder can create a working cinematic by:
1. Opening Cinematics tab
2. Creating new cinematic
3. Adding actors via UI (no Godot scene needed)
4. Adding commands that reference those actors
5. Saving and testing in-game
