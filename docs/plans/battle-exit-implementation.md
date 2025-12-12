# Battle Exit System - Implementation Plan (Phase A)

**Author**: Lt. Claudbrain
**Date**: 2025-12-12
**Status**: ✅ COMPLETE (2025-12-12)
**Scope**: Egress spell, Angel Wing item, defeat handling, safe location tracking

---

## Executive Summary

This plan covers the minimum viable implementation for exiting battles:
1. **Egress spell** - ✅ Ability that exits battle and returns to last safe location
2. **Angel Wing item** - ✅ Consumable with same effect as Egress
3. **Battle loss handling** - ✅ Hero death triggers auto-exit with free revival
4. **Safe location tracking** - ✅ GameState knows where to return players

**NOT in scope (Phase B)**: Church NPCs, paid resurrection, complex status effects.

---

## Implementation Notes (Post-Completion)

### Simplification from Original Plan

The original plan included separate handling for "hero death" vs "party wipe". This was **simplified** on 2025-12-12:

- **Hero death = immediate defeat** regardless of party composition
- No separate "party wipe" check needed (hero must die for party wipe anyway)
- Simplified `TurnManager.check_battle_end()` to only check hero alive status

### SF2-Authentic Defeat Screen

The defeat screen was redesigned to match SF2's automatic flow:
- No menu choices (SF2 didn't have them)
- "[Hero] has fallen!" / "The force retreats..." text
- "Press any key... (ESC to quit)" subtle hint
- Full party restoration (HP + MP) on defeat
- Egress/Angel Wing do NOT restore HP/MP (you keep current state)

### Key Commits
- `609002f` - feat: Battle exit system (Egress, Angel Wing, hero death)
- `4776d6d` - fix: Battle state desync prevention and Egress safety guards
- `ec26fe5` - feat: SF2-authentic defeat screen with simplified battle end logic

---

## System Analysis Summary

### Existing Infrastructure

| System | File | Relevant Features |
|--------|------|-------------------|
| BattleManager | `core/systems/battle_manager.gd` | Has `_on_battle_ended()`, handles `_show_defeat_screen()`, calls `TriggerManager.return_to_map()` |
| TurnManager | `core/systems/turn_manager.gd` | Emits `battle_ended(victory: bool)` signal, has `_check_battle_end()` |
| TransitionContext | `core/resources/transition_context.gd` | Already has `BattleOutcome` enum with `RETREAT` value |
| GameState | `core/systems/game_state.gd` | Has `set_transition_context()`, `get_transition_context()`, `campaign_data` dictionary |
| AbilityData | `core/resources/ability_data.gd` | Has `SPECIAL` ability type, can extend for new effect types |
| ItemData | `core/resources/item_data.gd` | Has `effect: Resource` field that links to AbilityData |
| PartyManager | `core/systems/party_manager.gd` | Has `_member_save_data` dictionary with CharacterSaveData per character |
| CharacterSaveData | `core/resources/character_save_data.gd` | Has `current_hp`, `max_hp`, `is_alive` fields |
| DefeatScreen | `scenes/ui/defeat_screen.gd` | SF2-authentic auto-flow with `continue_requested` and `quit_requested` signals |

### Key Discovery: TransitionContext Already Has RETREAT

```gdscript
# core/resources/transition_context.gd line 47
enum BattleOutcome { NONE, VICTORY, DEFEAT, RETREAT }
```

This means the architecture already anticipates a retreat/escape mechanism.

---

## Implementation Plan

### Step 1: Add "last_safe_location" to GameState

**File**: `/home/user/dev/sparklingfarce/core/systems/game_state.gd`

**Changes**: Add a simple string to track the last safe location (town scene path).

```gdscript
# Add near line 50 (after campaign_data definition)
## Last safe location for retreat/defeat returns
## Updated when entering a town map; used by battle exit systems
var last_safe_location: String = ""

## Update the last safe location (call from MapTemplate when entering towns)
func set_last_safe_location(scene_path: String) -> void:
    if scene_path.is_empty():
        push_warning("GameState: set_last_safe_location called with empty path")
        return
    last_safe_location = scene_path

## Get the last safe location (returns current return_scene_path as fallback)
func get_last_safe_location() -> String:
    if not last_safe_location.is_empty():
        return last_safe_location
    # Fallback to transition context's return path
    if _transition_context and _transition_context.is_valid():
        return _transition_context.return_scene_path
    return ""
```

**Also add to `export_state()` and `import_state()` for save persistence:**
```gdscript
# In export_state() add:
"last_safe_location": last_safe_location,

# In import_state() add:
if "last_safe_location" in state:
    last_safe_location = state.last_safe_location
```

---

### Step 2: Create Egress AbilityData Resource

**File**: `/home/user/dev/sparklingfarce/mods/_base_game/data/abilities/egress.tres`

**Content**:
```tres
[gd_resource type="Resource" script_class="AbilityData" load_steps=2 format=3]

[ext_resource type="Script" path="res://core/resources/ability_data.gd" id="1_ability"]

[resource]
script = ExtResource("1_ability")
ability_name = "Egress"
ability_id = "egress"
ability_type = 7
target_type = 2
min_range = 0
max_range = 0
area_of_effect = 0
mp_cost = 8
hp_cost = 0
power = 0
accuracy = 100
status_effects = Array[String]([])
effect_duration = 0
effect_chance = 100
description = "Escape from battle and return to the last town. All party members are revived."
```

**Notes**:
- `ability_type = 7` is `SPECIAL`
- `target_type = 2` is `SELF` (no targeting needed)
- MP cost of 8 is SF2-authentic

---

### Step 3: Create Angel Wing ItemData Resource

**File**: `/home/user/dev/sparklingfarce/mods/_base_game/data/items/angel_wing.tres`

**Content**:
```tres
[gd_resource type="Resource" script_class="ItemData" load_steps=3 format=3]

[ext_resource type="Script" path="res://core/resources/item_data.gd" id="1_item"]
[ext_resource type="Resource" path="res://mods/_base_game/data/abilities/egress.tres" id="2_effect"]

[resource]
script = ExtResource("1_item")
item_name = "Angel Wing"
item_type = 3
usable_in_battle = true
usable_on_field = false
effect = ExtResource("2_effect")
buy_price = 40
sell_price = 20
description = "A feather from a divine bird. Escape from battle and return to the last town."
can_be_dropped = true
confirm_on_drop = true
```

**Notes**:
- `item_type = 3` is `CONSUMABLE`
- Links to the Egress ability as its effect
- Usable only in battle (not on field)

---

### Step 4: Handle SPECIAL Ability Type in BattleManager

**File**: `/home/user/dev/sparklingfarce/core/systems/battle_manager.gd`

**Changes**: Add handling for SPECIAL abilities in `_on_spell_cast_requested()`.

**Location**: After line 752 (after the `AbilityData.AbilityType.STATUS` case)

```gdscript
# Add new case in the match statement (around line 743-752)
AbilityData.AbilityType.SPECIAL:
    # Handle special abilities like Egress
    if ability.ability_id == "egress":
        await _execute_battle_exit(caster, BattleExitReason.EGRESS)
        return  # Early return - battle is over
    else:
        push_warning("BattleManager: Unknown SPECIAL ability: %s" % ability.ability_id)
```

**Also add a new enum and method near the end of the file (before `end_battle()`):**

```gdscript
## Reasons for exiting battle early
enum BattleExitReason {
    EGRESS,      ## Player cast Egress spell
    ANGEL_WING,  ## Player used Angel Wing item
    HERO_DEATH,  ## Hero (is_hero character) died
    PARTY_WIPE   ## All player units dead
}

## Execute battle exit - revive all, return to safe location
## @param initiator: The unit that triggered the exit (for Egress/Angel Wing) or null (for death)
## @param reason: Why we're exiting the battle
func _execute_battle_exit(initiator: Node2D, reason: BattleExitReason) -> void:
    # 1. Revive all party members (set HP to max)
    _revive_all_party_members()

    # 2. Set battle outcome to RETREAT
    var context: RefCounted = GameState.get_transition_context()
    if context:
        var TransitionContextScript: GDScript = context.get_script()
        context.battle_outcome = TransitionContextScript.BattleOutcome.RETREAT

    # 3. End the battle (skip normal victory/defeat screens)
    battle_active = false

    # 4. Determine return location
    var return_path: String = GameState.get_last_safe_location()
    if return_path.is_empty():
        push_warning("BattleManager: No safe location set, using transition context")
        if context and context.is_valid():
            return_path = context.return_scene_path

    if return_path.is_empty():
        push_error("BattleManager: Cannot exit battle - no return location available")
        return

    # 5. Show brief exit message (skip in headless mode)
    if not TurnManager.is_headless:
        await _show_exit_message(reason)

    # 6. Emit battle_ended signal with victory=false (but RETREAT outcome)
    battle_ended.emit(false)

    # 7. Clear battle state
    GridManager.clear_grid()

    # 8. Transition to safe location
    await SceneManager.change_scene(return_path)
    TriggerManager.returned_from_battle.emit()


## Revive all party members to full HP
func _revive_all_party_members() -> void:
    for character: CharacterData in PartyManager.party_members:
        var uid: String = character.character_uid
        var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
        if save_data:
            save_data.current_hp = save_data.max_hp
            save_data.is_alive = true


## Show a brief exit message before transitioning
func _show_exit_message(reason: BattleExitReason) -> void:
    # Create simple message overlay
    var message: String = ""
    match reason:
        BattleExitReason.EGRESS:
            message = "Egress!"
        BattleExitReason.ANGEL_WING:
            message = "Angel Wing!"
        BattleExitReason.HERO_DEATH:
            message = "The hero has fallen..."
        BattleExitReason.PARTY_WIPE:
            message = "All forces defeated..."

    # Create temporary label
    var label: Label = Label.new()
    label.text = message
    label.add_theme_font_size_override("font_size", 32)
    label.add_theme_color_override("font_color", Color.WHITE)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.set_anchors_preset(Control.PRESET_CENTER)

    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.layer = 100
    canvas.add_child(label)
    battle_scene_root.add_child(canvas)

    # Brief pause
    await get_tree().create_timer(1.5).timeout

    canvas.queue_free()
```

---

### Step 5: Handle Angel Wing Item Use

**File**: `/home/user/dev/sparklingfarce/core/systems/battle_manager.gd`

**Changes**: Modify `_on_item_use_requested()` to check for Egress effect.

**Location**: Around line 463-478, before the `match ability.ability_type` block

```gdscript
# Add check for Egress effect (insert before line 484)
# Check if this is a battle exit item (Egress effect)
if ability.ability_id == "egress":
    # Consume the item first
    _consume_item_from_inventory(unit, item_id)
    # Execute battle exit
    await _execute_battle_exit(unit, BattleExitReason.ANGEL_WING)
    return  # Early return - battle is over
```

---

### Step 6: Handle Hero Death and Party Wipe

**File**: `/home/user/dev/sparklingfarce/core/systems/turn_manager.gd`

**Changes**: Modify `_check_battle_end()` to detect hero death specifically.

**Location**: Around line 216-243

```gdscript
## Check if battle has ended (victory or defeat)
func _check_battle_end() -> bool:
    if not battle_active:
        return true

    # Count living units by faction and check for hero
    var player_count: int = 0
    var enemy_count: int = 0
    var hero_alive: bool = false

    for unit in all_units:
        if not unit.is_alive():
            continue

        if unit.is_player_unit():
            player_count += 1
            # Check if this is the hero
            if unit.character_data and unit.character_data.is_hero:
                hero_alive = true
        elif unit.is_enemy_unit():
            enemy_count += 1

    # Check for hero death (triggers immediate battle exit)
    if not hero_alive and player_count > 0:
        # Hero died but others survive - trigger auto-exit
        _end_battle_with_hero_death()
        return true

    # Check defeat (all player units dead)
    if player_count == 0:
        _end_battle(false)
        return true

    # Check victory (all enemy units dead)
    if enemy_count == 0:
        _end_battle(true)
        return true

    return false


## End battle due to hero death (SF2-authentic auto-exit with revival)
func _end_battle_with_hero_death() -> void:
    battle_active = false
    active_unit = null
    turn_queue.clear()

    # Emit special signal for BattleManager to handle
    hero_died_in_battle.emit()
```

**Also add a new signal near line 22:**
```gdscript
signal hero_died_in_battle()
```

---

### Step 7: Connect Hero Death Signal in BattleManager

**File**: `/home/user/dev/sparklingfarce/core/systems/battle_manager.gd`

**Changes**: Connect to the new signal in `_connect_signals()`.

**Location**: Around line 396-423

```gdscript
# Add in _connect_signals() method
if not TurnManager.hero_died_in_battle.is_connected(_on_hero_died_in_battle):
    TurnManager.hero_died_in_battle.connect(_on_hero_died_in_battle)
```

**Add handler method:**
```gdscript
## Handle hero death - auto-exit battle with revival
func _on_hero_died_in_battle() -> void:
    await _execute_battle_exit(null, BattleExitReason.HERO_DEATH)
```

---

### Step 8: Update MapTemplate to Track Safe Locations

**File**: Needs identification - likely `core/templates/map_template.gd` or similar

**Search for the file:**
```bash
find . -name "*map_template*" -o -name "*MapTemplate*"
```

**Changes**: When the player enters a town map, call `GameState.set_last_safe_location()`.

```gdscript
# In _ready() or when map loads, check if this is a town
func _ready() -> void:
    # ... existing code ...

    # If this is a town map, mark it as safe location
    if _is_town_map():
        GameState.set_last_safe_location(scene_file_path)


func _is_town_map() -> bool:
    # Check map metadata if available
    # For now, simple heuristic based on scene name or map_type
    var scene_name: String = scene_file_path.get_file().get_basename().to_lower()
    return "town" in scene_name or "village" in scene_name or "headquarters" in scene_name
```

**Alternative approach**: Use MapMetadata's `map_type` field if it exists.

---

## Files to Modify

| File | Changes |
|------|---------|
| `core/systems/game_state.gd` | Add `last_safe_location`, getter/setter, save/load support |
| `core/systems/battle_manager.gd` | Add `_execute_battle_exit()`, handle SPECIAL abilities, handle item Egress effect |
| `core/systems/turn_manager.gd` | Add `hero_died_in_battle` signal, detect hero death in `_check_battle_end()` |

## New Files to Create

| File | Purpose |
|------|---------|
| `mods/_base_game/data/abilities/egress.tres` | Egress ability definition |
| `mods/_base_game/data/items/angel_wing.tres` | Angel Wing consumable item |

---

## Testing Strategy

### Headless Tests (gdUnit4)

1. **test_egress_ability_exists**: Verify ability loads from registry
2. **test_angel_wing_item_exists**: Verify item loads and has correct effect
3. **test_safe_location_tracking**: Set/get safe location in GameState
4. **test_party_revival**: Call `_revive_all_party_members()` and verify HP restoration

### Manual Tests

1. **Egress spell in battle**: Cast Egress, verify exit and return to town
2. **Angel Wing item in battle**: Use Angel Wing, verify exit and return
3. **Hero death**: Let hero die, verify auto-exit and revival
4. **Party wipe**: Let all units die, verify exit and revival
5. **No safe location**: Start battle without entering town first, verify fallback

---

## Edge Cases and Considerations

1. **No safe location set**: Falls back to `TransitionContext.return_scene_path`
2. **Egress with 0 MP**: Normal MP check prevents casting (handled by SpellMenu)
3. **Angel Wing not in inventory**: Normal item system prevents use
4. **Battle triggered from overworld**: Safe location might be previous town or overworld
5. **Nested battles**: Not a concern - battles always return to exploration maps

---

## Future Work (Phase B - NOT THIS PHASE)

- Church NPCs with paid resurrection service
- Gold penalty on defeat (SF1 style: lose half gold)
- Revive spell (in-battle resurrection)
- Death status tracking between battles (permadeath option)
- Retry battle option from defeat screen

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Breaking existing defeat flow | Keep existing `_show_defeat_screen()` for non-hero-death defeats |
| Save/load corruption | Safe location is optional; empty string is valid fallback |
| Race condition on exit | Use `await` for all transitions |
| Missing transition context | Multiple fallbacks in `get_last_safe_location()` |

---

## Implementation Order

1. Add `last_safe_location` to GameState (foundation)
2. Create `egress.tres` ability resource
3. Create `angel_wing.tres` item resource
4. Add `_execute_battle_exit()` to BattleManager
5. Handle SPECIAL ability type in spell casting
6. Handle Egress effect in item usage
7. Add hero death detection to TurnManager
8. Connect hero death signal in BattleManager
9. Update map templates to track safe locations
10. Test all paths

**Estimated implementation time**: 2-3 hours for code, 1 hour for testing

---

*Live long and retreat wisely, Captain.*
