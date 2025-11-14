# Shining Force Combat System Research

## Key Finding: Individual Turn Order (NOT Phase-Based)

**Critical Discovery**: Shining Force does NOT use separate "Player Phase" and "Enemy Phase" like Fire Emblem. Instead, it uses an **individual unit turn order system** where player and enemy units are intermixed in the turn queue based on their agility stats.

---

## Turn Order System

### How It Works

1. **Agility-Based**: Each unit's turn position is determined by their AGI stat
2. **Randomization**: AGI is randomized each turn for variety
3. **Mixed Queue**: Player units and enemy units take turns in order of (randomized) agility
4. **Fastest First**: Highest AGI acts first, lowest acts last
5. **Per-Unit**: Each unit gets ONE action per turn cycle

### Turn Order Formula (Shining Force II)

```
Randomized AGI = (Base AGI * Random(0.875 to 1.125)) + Random(-1, 0, +1)
```

**Result**: AGI can vary from ~75% to ~112% of base value each turn

**Example Turn Order**:
```
Turn 1:
1. Enemy Mage (AGI 15, rolled high)
2. Hero (AGI 12, rolled high)
3. Ally Knight (AGI 10, rolled average)
4. Enemy Goblin (AGI 8, rolled low)
5. Ally Healer (AGI 7, rolled average)
...

Turn 2:
1. Hero (AGI 12, rolled high this time)
2. Enemy Mage (AGI 15, rolled low this time)
3. Ally Healer (AGI 7, rolled high!)
...
```

### Special Rules

1. **Boss Priority**: Bosses with AGI > 128 get multiple turns
2. **Tie-Breaking**: When AGI values match, player units go first
3. **Dynamic Cheating**: When players take damage, enemies get priority boosts (programmed behavior)

---

## Turn Structure (Per Unit)

When a unit's turn begins:

### 1. Turn Start
- Unit stats displayed
- Movement range highlights (flashing squares)
- Terrain effects shown

### 2. Movement Phase
- Player moves unit within highlighted area using D-pad
- Can't move through occupied squares
- Movement range varies by class (MOV stat)

### 3. Action Selection (After movement)
Player presses A or C to open action menu:
- **Attack** - If enemy in range, show attack range grid
- **Magic** - Cast spells (spellcasters only)
- **Item** - Use item on nearby character
- **Stay** - End turn without acting

### 4. Target Selection (If attacking/casting)
- White cursor appears on valid targets
- Player moves cursor to select target
- Confirm to execute action

### 5. Turn End
- Unit becomes inactive (grayed out)
- Next unit in turn order becomes active
- Cycle continues until all units have acted

### 6. Turn Cycle Complete
- When all units (player + enemy) have acted, turn counter increments
- Turn order recalculated with new AGI randomization
- Repeat from step 1

---

## Key Differences from Fire Emblem

| Feature | Fire Emblem | Shining Force |
|---------|-------------|---------------|
| **Turn Structure** | Separate Player/Enemy phases | Mixed individual turn order |
| **Turn Order** | All players act, then all enemies | Based on AGI, mixed queue |
| **Predictability** | Fully predictable | Semi-random (AGI variance) |
| **Unit Activation** | Select any unit during your phase | Active unit is determined by AGI |
| **Movement/Action** | Separate (can move all, then act all) | Per-unit (move then act immediately) |
| **Back-to-Back Turns** | Impossible | Possible with AGI variance |

---

## Combat Actions (After Movement)

### Attack
- Available if enemy within weapon range
- Shows attack range grid
- Select target from attackable enemies
- **Cannot move after attacking** (attack ends turn)

### Magic
- Spellcasters only
- Show spell range
- Select target
- Costs MP

### Item
- Use consumable items
- Can target nearby allies or self
- Healing, buffs, etc.

### Stay
- End turn without acting
- Use when no good action available

### Special Commands (Button B, outside turn)
- **Map**: View full battlefield
- **Stats**: Check enemy stats
- **Message**: View battle log
- **Speed**: Adjust animation speed
- **Quit**: Escape battle (Egress spell)

---

## Victory/Defeat Conditions

### Victory (Player Wins)
- Defeat all enemies
- Defeat enemy leader/boss
- Reach specific location (town/landmark)

### Defeat (Player Loses)
- Leader (Max/Bowie) dies
- Player casts Egress to escape
- Special scenario conditions

---

## Stats That Matter for Combat

### Agility (AGI)
- Determines turn order position
- Affects hit rate and dodge rate
- High AGI = act more frequently in favorable positions

### Movement (MOV)
- Determines movement range per turn
- Fixed per class (e.g., Knights = 5, Mages = 4)
- Affected by terrain

### Attack/Defense
- Standard damage calculation
- Varies by equipped weapon

---

## Implementation Implications for The Sparkling Farce

### What We Need to Change

Our current PHASE_3_PLAN.md proposes Fire Emblem-style phases:
```gdscript
# CURRENT PLAN (WRONG FOR SHINING FORCE):
enum Phase {
    PLAYER_TURN,   # ❌ Not how Shining Force works
    ENEMY_TURN,    # ❌ Not how Shining Force works
}
```

### What We Should Build Instead

```gdscript
# SHINING FORCE-STYLE SYSTEM:
class TurnManager:
    var turn_queue: Array[Unit]  # Sorted by AGI + randomization
    var active_unit: Unit        # Current unit taking turn
    var turn_number: int         # Overall turn counter

    func calculate_turn_order() -> void:
        # Sort all units by randomized AGI
        for unit in all_units:
            unit.turn_priority = calculate_turn_priority(unit)
        turn_queue = all_units.sort_by_priority()

    func calculate_turn_priority(unit: Unit) -> float:
        var base_agi: float = unit.stats.agility
        var random_mult: float = randf_range(0.875, 1.125)
        var random_offset: float = randi_range(-1, 1)
        return (base_agi * random_mult) + random_offset

    func start_turn() -> void:
        active_unit = turn_queue.pop_front()
        if active_unit.is_player_unit():
            # Wait for player input
            InputManager.set_state(InputState.SELECTING_ACTION)
        else:
            # Run AI
            AIController.process_enemy_turn(active_unit)

    func end_unit_turn() -> void:
        if turn_queue.is_empty():
            # All units acted, start new turn cycle
            turn_number += 1
            calculate_turn_order()
        start_turn()
```

### Core Differences

1. **No Player/Enemy Phases**: One continuous turn queue
2. **Active Unit**: Only ONE unit acts at a time
3. **AGI-Based**: Turn order recalculated each cycle with randomization
4. **Mixed Queue**: Players and enemies intermixed
5. **Immediate Action**: Move → Act → End (no "move all then act all")

---

## Battle Flow Example

### Setup
- Hero (AGI 12)
- Knight (AGI 10)
- Mage (AGI 8)
- Goblin A (AGI 9)
- Goblin B (AGI 7)

### Turn Cycle 1

1. **Hero's Turn** (AGI rolled 14)
   - Player controls
   - Move 5 squares
   - Attack Goblin A
   - Turn ends

2. **Knight's Turn** (AGI rolled 11)
   - Player controls
   - Move 4 squares
   - Stay (no enemies in range)
   - Turn ends

3. **Goblin A's Turn** (AGI rolled 10)
   - AI controls
   - Move toward player
   - Can't reach, ends turn

4. **Mage's Turn** (AGI rolled 9)
   - Player controls
   - Move 3 squares
   - Cast Blaze on Goblin B
   - Turn ends

5. **Goblin B's Turn** (AGI rolled 8)
   - AI controls
   - Move and attack Knight
   - Turn ends

**Turn Cycle 1 Complete** → Recalculate AGI, start Turn Cycle 2

---

## Priority for Implementation

### Phase 3, Week 2 Goals (Revised)

**Step 3: TurnManager (Shining Force Style)**
- Individual turn queue (not phases)
- AGI-based turn order calculation
- Active unit system
- Turn cycle management
- Victory/defeat detection

**Step 4: InputManager**
- Wait for active unit to be player-controlled
- Move → Action menu → Target selection → Execute
- Can only control ONE unit at a time (the active unit)
- Enemy turns are fully automated (AI)

---

## Next Steps

1. **Update PHASE_3_PLAN.md**: Revise TurnManager section to match Shining Force
2. **Implement AGI-based turn queue**
3. **Test with mixed player/enemy turn order**
4. **Build single-unit control input system**

---

**Research Date**: November 14, 2025
**Sources**: Shining Force Central, GameFAQs, community forums
**Conclusion**: Individual turn order system, NOT phase-based
