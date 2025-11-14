# Phase 3 Plan - Runtime Systems & Tactical Gameplay

## Overview

Phase 3 transforms The Sparkling Farce from a content creation tool into a playable tactical RPG. This phase implements the core runtime systems needed for turn-based tactical battles: grid management, pathfinding, turn order, unit representation, and player input.

**Status**: Planning
**Priority**: Critical (Foundation for actual gameplay)
**Philosophy**: "Start simple, make it work, then make it good"

---

## What We Already Have

### ✅ Existing Foundation
1. **Resource System**: All 6 data types complete (Character, Class, Item, Ability, Battle, Dialogue)
2. **Mod System**: ModLoader, ModRegistry, base game as mod
3. **Editor Tools**: 6 functional editors for content creation
4. **Camera System**: CameraController with smooth scrolling and follow modes
5. **Grid Resource**: Coordinate conversion, bounds checking, distance calculations
6. **Battle Scene**: Basic scene structure with layers (Map, Units, Effects, UI)
7. **Viewport**: Pixel-perfect 640×360 with 2x integer scaling

### ⚠️ What's Missing
- Grid/pathfinding implementation (A* navigation)
- Turn management system
- Unit scene/component architecture
- Combat calculation logic
- Player input handling
- BattleData loading and instantiation
- AI behavior system
- Animation system

---

## Phase 3 Goals

### Priority 1: Core Grid & Pathfinding System
**Goal**: Units can move on a tactical grid with pathfinding

### Priority 2: Unit Representation & Management
**Goal**: Units exist in the scene with stats from CharacterData

### Priority 3: Turn System
**Goal**: Player and enemy turns alternate, with action selection

### Priority 4: Basic Combat
**Goal**: Units can attack each other using simple damage formulas

### Priority 5: Battle Loading
**Goal**: Load BattleData and spawn units at correct positions

---

## Implementation Plan

### Step 1: GridManager System (Week 1, Part 1)

**Purpose**: Central system for grid-based tactical movement and pathfinding

**Files to Create**:
1. `core/systems/grid_manager.gd` - Autoload singleton
   - Integrates Grid resource with TileMapLayer
   - A* pathfinding using AStarGrid2D
   - Movement range calculation
   - Obstacle detection (terrain cost system)
   - Cell highlighting (visual feedback)

**Key Features**:
- `setup_grid(grid: Grid, tilemap: TileMapLayer)` - Initialize pathfinding
- `get_walkable_cells(from: Vector2i, movement: int, unit_type: MovementType)` - Get reachable cells
- `find_path(from: Vector2i, to: Vector2i, unit_type: MovementType)` - A* pathfinding
- `is_cell_occupied(cell: Vector2i)` - Unit collision detection
- `get_unit_at_cell(cell: Vector2i)` - Query which unit is at a position
- `highlight_cells(cells: Array[Vector2i], color: Color)` - Visual feedback

**Technical Details**:
```gdscript
# Use Godot's built-in AStarGrid2D
var _astar: AStarGrid2D = AStarGrid2D.new()

# Terrain costs by movement type
const TERRAIN_COSTS: Dictionary = {
	MovementType.WALKING: {"plains": 1, "forest": 2, "mountain": 3},
	MovementType.FLYING: {"plains": 1, "forest": 1, "mountain": 1},
	MovementType.FLOATING: {"plains": 1, "forest": 1, "mountain": 2}
}
```

**Testing**:
- Unit tests for pathfinding with obstacles
- Visual test: Click to highlight walkable cells
- Performance test: 20×11 grid pathfinding < 1ms

---

### Step 2: Unit Scene & Components (Week 1, Part 2)

**Purpose**: Represent units on the battlefield with stats and behavior

**Files to Create**:
1. `scenes/unit.tscn` - Unit scene (Node2D base)
2. `core/components/unit.gd` - Main unit script
3. `core/components/unit_stats.gd` - Runtime stat tracking
4. `core/components/unit_visual.gd` - Sprite and animation (Phase 3.5)

**Unit Architecture** (Component-based):
```
Unit (Node2D)
├── Sprite2D (battle sprite)
├── SelectionIndicator (visual feedback)
├── HealthBar (UI element)
└── Script: unit.gd
    ├── character_data: CharacterData (source data)
    ├── stats: UnitStats (runtime stats)
    ├── grid_position: Vector2i (current cell)
    ├── has_moved: bool (turn state)
    ├── has_acted: bool (turn state)
```

**UnitStats Class**:
```gdscript
class_name UnitStats
extends RefCounted

# Runtime stats (base + equipment + buffs)
var current_hp: int
var max_hp: int
var current_mp: int
var max_mp: int
var strength: int
var defense: int
var agility: int
var intelligence: int
var luck: int
var level: int

# Status effects
var status_effects: Array[Dictionary] = []

# Calculate from CharacterData + equipped items
func calculate_from_character(character: CharacterData) -> void:
	# Base stats
	max_hp = character.base_hp
	current_hp = max_hp
	# ... etc

	# Apply equipment bonuses
	for item in character.starting_equipment:
		apply_equipment_bonus(item)
```

**Unit Signals**:
- `moved(from: Vector2i, to: Vector2i)`
- `attacked(target: Unit, damage: int)`
- `damaged(amount: int)`
- `died()`
- `turn_started()`
- `turn_ended()`

**Testing**:
- Create unit from CharacterData
- Display stats in debug label
- Position unit on grid
- Move unit to new cell (with animation placeholder)

---

### Step 3: TurnManager System (Week 2, Part 1) - SHINING FORCE STYLE

**Purpose**: Manage individual turn order based on AGI (Shining Force system)

**IMPORTANT**: Shining Force does NOT use Fire Emblem-style phases. Instead, units take turns individually in an AGI-based queue, with player and enemy units intermixed.

**Files to Create**:
1. `core/systems/turn_manager.gd` - AGI-based turn queue management

**Turn System Design** (Individual Turn Order like Shining Force):
```
Turn Structure:
1. Calculate turn order for ALL units (player + enemy) based on AGI
2. Sort into turn queue (highest AGI first)
3. Pop next unit from queue:
   - If player unit: Wait for player input
   - If enemy unit: Run AI immediately
4. After unit acts: Next unit's turn
5. When queue empty: Start new turn cycle (recalculate AGI)

Example Turn Queue:
1. Enemy Mage (AGI 15, rolled high)     ← AI acts
2. Player Hero (AGI 12, rolled high)    ← Player controls
3. Player Knight (AGI 10, average)      ← Player controls (must wait)
4. Enemy Goblin (AGI 8, rolled low)     ← AI acts
5. Player Healer (AGI 7, rolled low)    ← Player controls (must wait)
...queue empties → recalculate → new turn cycle
```

**Turn Manager Features**:
- `start_battle(all_units: Array[Unit])` - Initialize with ALL units
- `calculate_turn_order()` - Sort units by randomized AGI
- `get_next_unit()` - Pop next unit from queue
- `start_unit_turn(unit: Unit)` - Begin unit's turn
- `end_unit_turn(unit: Unit)` - Finish unit's turn, advance queue
- `is_turn_cycle_complete()` - Check if queue is empty
- `start_new_turn_cycle()` - Increment turn counter, recalculate order
- `check_victory_conditions()` - Check battle end
- `check_defeat_conditions()` - Check battle loss

**AGI-Based Turn Priority** (Shining Force II formula):
```gdscript
func calculate_turn_priority(unit: Unit) -> float:
	var base_agi: float = unit.stats.agility
	# Randomize AGI: 87.5% to 112.5% of base value
	var random_mult: float = randf_range(0.875, 1.125)
	# Add small random offset: -1, 0, or +1
	var random_offset: float = randi_range(-1, 1)
	return (base_agi * random_mult) + random_offset

func calculate_turn_order() -> void:
	turn_queue.clear()

	# Calculate priority for each unit
	for unit in all_units:
		if not unit.is_alive():
			continue
		unit.turn_priority = calculate_turn_priority(unit)

	# Sort by priority (highest first)
	turn_queue = all_units.duplicate()
	turn_queue.sort_custom(func(a, b): return a.turn_priority > b.turn_priority)

	# Tie-breaker: Player units go first if AGI equal
	# (handled automatically by stable sort)
```

**Turn Flow**:
```gdscript
func start_unit_turn(unit: Unit) -> void:
	active_unit = unit
	unit.start_turn()

	if unit.is_player_unit():
		# Wait for player input through InputManager
		emit_signal("player_turn_started", unit)
		InputManager.set_state(InputState.MOVING_UNIT)
	else:
		# Run AI immediately
		emit_signal("enemy_turn_started", unit)
		await AIController.process_enemy_turn(unit)
		end_unit_turn(unit)

func end_unit_turn(unit: Unit) -> void:
	unit.end_turn()
	unit.has_moved = false  # Reset for next turn cycle
	unit.has_acted = false

	emit_signal("unit_turn_ended", unit)

	# Get next unit
	if turn_queue.is_empty():
		start_new_turn_cycle()
	else:
		var next_unit: Unit = turn_queue.pop_front()
		start_unit_turn(next_unit)

func start_new_turn_cycle() -> void:
	turn_number += 1
	emit_signal("turn_cycle_started", turn_number)

	# Recalculate turn order with new AGI randomization
	calculate_turn_order()

	# Start first unit's turn
	if not turn_queue.is_empty():
		var first_unit: Unit = turn_queue.pop_front()
		start_unit_turn(first_unit)
```

**Key Properties**:
```gdscript
var all_units: Array[Unit] = []        # All units in battle
var turn_queue: Array[Unit] = []       # Current turn order
var active_unit: Unit = null           # Unit currently acting
var turn_number: int = 1               # Overall turn counter
```

**Turn Manager Signals**:
- `turn_cycle_started(turn_number: int)` - New turn cycle begins
- `player_turn_started(unit: Unit)` - Player unit's turn
- `enemy_turn_started(unit: Unit)` - Enemy unit's turn
- `unit_turn_ended(unit: Unit)` - Unit finished acting
- `battle_ended(victory: bool)` - Battle concluded

**Special Rules** (Shining Force mechanics):
- Boss units with AGI > 128 can act multiple times per cycle (Phase 4)
- Tie-breaking: Player units go first when AGI values match
- Turn order recalculates every cycle (creates variety)

**Testing**:
- Create battle with mixed AGI values (player AGI 5,7,12 / enemy AGI 6,8,10)
- Verify turn order is AGI-based, not faction-based
- Check player/enemy units intermix in queue
- Test turn cycle completion and recalculation
- Verify AGI randomization creates variance

---

### Step 4: InputManager & Player Control (Week 2, Part 2) - SHINING FORCE STYLE

**Purpose**: Handle player input for the ACTIVE unit only (Shining Force model)

**IMPORTANT**: In Shining Force, you can ONLY control the unit whose turn it is. No selecting from all units - TurnManager decides which unit acts next.

**Files to Create**:
1. `core/systems/input_manager.gd` - Input handling for active unit
2. `scenes/ui/cursor.tscn` - Grid cursor visual
3. `scenes/ui/action_menu.tscn` - Action selection menu

**Input Manager Features**:
- Control ONLY the active unit (provided by TurnManager)
- Grid cursor with keyboard/gamepad movement
- Mouse click support for cell selection
- Menu navigation (action menu, targeting)
- Input state machine (MoveUnit → SelectAction → SelectTarget → Execute)

**Input States**:
```gdscript
enum InputState {
	WAITING,           # Not player's turn (enemy/AI acting)
	MOVING_UNIT,       # Show movement range, choose destination for ACTIVE unit
	SELECTING_ACTION,  # Attack, Magic, Item, Stay menu
	TARGETING,         # Choose target for attack/spell
	CONFIRMING,        # Confirm action before executing (optional)
	ANIMATING          # Wait for animations to finish
}
```

**Shining Force Turn Flow** (Per Active Unit):
```gdscript
# When TurnManager activates a player unit:
signal player_turn_started(unit: Unit)

func on_player_turn_started(unit: Unit) -> void:
	active_unit = unit
	set_state(InputState.MOVING_UNIT)

	# 1. MOVING_UNIT state
	# - Show movement range highlights
	# - Show unit stats in UI
	# - Cursor automatically positioned on unit
	# - Player moves cursor to select destination
	# - Click/confirm to move unit
	# - Unit moves → transition to SELECTING_ACTION

	# 2. SELECTING_ACTION state
	# - Open action menu at unit position
	# - Options: Attack, Magic, Item, Stay
	# - Attack only shown if enemies in range
	# - Select action → transition to TARGETING (or execute Stay)

	# 3. TARGETING state (if Attack/Magic selected)
	# - Show attack/spell range
	# - Cursor on valid targets
	# - Select target
	# - Execute action → transition to WAITING

	# 4. WAITING state
	# - Turn complete, TurnManager advances to next unit
	# - If next unit is player: repeat from step 1
	# - If next unit is enemy: AI acts automatically
```

**Key Constraint**: You can ONLY control the active unit. You cannot:
- Select a different player unit
- Move multiple units before committing
- "Undo" movement (commitment is immediate in Shining Force)

**Cursor Features**:
- Sprite at grid position (32×32, pixel-perfect)
- Smooth interpolation between cells
- Hover info (show unit stats when over unit/enemy)
- Visual feedback (color change for valid/invalid cells)
- Auto-centers on active unit at turn start

**Action Menu** (Shining Force style):
- Appears AFTER movement
- Simple vertical list: Attack, Magic, Item, Stay
- Context-aware:
  - Attack only if enemies in weapon range
  - Magic only for spellcasters
  - Item always available
  - Stay always available (ends turn)
- Keyboard/gamepad navigation (up/down, confirm/cancel)
- Cancel returns to previous state (can re-move if haven't acted)

**Movement/Action Separation**:
- In Shining Force, movement happens FIRST, then action menu
- Cannot attack without moving first (even if staying in place)
- This is different from Fire Emblem (which allows attack-only)

**Testing**:
- Start battle, wait for player unit's turn
- Verify only active unit is controllable
- Move unit, confirm action menu appears
- Select "Attack", verify targeting works
- Select "Stay", verify turn ends and next unit activates
- Verify enemy turns happen automatically (AI)

---

### Step 5: BattleManager & Scene Orchestration (Week 3, Part 1)

**Purpose**: Load BattleData and orchestrate all battle systems

**Files to Create**:
1. `core/systems/battle_manager.gd` - High-level battle orchestrator
2. `scenes/battle_controller.gd` - Script for battle_scene.tscn

**BattleManager Responsibilities**:
- Load BattleData resource
- Instantiate map scene
- Spawn units from BattleData
- Initialize GridManager, TurnManager, InputManager
- Monitor victory/defeat conditions
- Handle battle end (rewards, dialogue)

**Battle Loading Flow**:
```gdscript
func start_battle(battle_data: BattleData) -> void:
	# 1. Validate BattleData
	if not battle_data.validate():
		push_error("Invalid BattleData")
		return

	# 2. Load map scene
	var map_instance: Node2D = battle_data.map_scene.instantiate()
	add_child(map_instance)

	# 3. Initialize GridManager with tilemap
	var tilemap: TileMapLayer = map_instance.get_node("GroundLayer")
	GridManager.setup_grid(battle_data.grid, tilemap)

	# 4. Spawn player units (from player party, Phase 4)
	var player_units: Array[Unit] = []
	# TODO: Get player party from game state

	# 5. Spawn enemy units
	var enemy_units: Array[Unit] = _spawn_units(battle_data.enemies, "enemy")

	# 6. Spawn neutral units
	var neutral_units: Array[Unit] = _spawn_units(battle_data.neutrals, "neutral")

	# 7. Initialize TurnManager
	TurnManager.start_battle(player_units, enemy_units, neutral_units)

	# 8. Show pre-battle dialogue (if any)
	if battle_data.pre_battle_dialogue:
		await _show_dialogue(battle_data.pre_battle_dialogue)

	# 9. Start first turn
	TurnManager.start_phase(TurnManager.Phase.PLAYER_TURN)

func _spawn_units(unit_data: Array[Dictionary], faction: String) -> Array[Unit]:
	var units: Array[Unit] = []
	for data in unit_data:
		var character: CharacterData = data.character
		var position: Vector2i = data.position

		var unit: Unit = UnitScene.instantiate()
		unit.initialize(character)
		unit.grid_position = position
		unit.world_position = GridManager.grid.map_to_local(position)
		unit.faction = faction

		$Units.add_child(unit)
		units.append(unit)

	return units
```

**Victory/Defeat Checking**:
```gdscript
func _check_battle_conditions() -> void:
	# Check defeat first (higher priority)
	if _check_defeat_condition(battle_data.defeat_condition):
		_end_battle(false)
		return

	# Check victory
	if _check_victory_condition(battle_data.victory_condition):
		_end_battle(true)

func _check_victory_condition(condition: BattleData.VictoryCondition) -> bool:
	match condition:
		BattleData.VictoryCondition.DEFEAT_ALL_ENEMIES:
			return _all_enemies_defeated()
		BattleData.VictoryCondition.DEFEAT_BOSS:
			var boss: Unit = enemy_units[battle_data.victory_boss_index]
			return boss.is_dead()
		# ... other conditions
```

**Testing**:
- Load test BattleData
- Verify units spawn at correct positions
- Verify turn system starts correctly
- Verify camera focuses on battle area

---

### Step 6: Combat System (Week 3, Part 2)

**Purpose**: Calculate damage, apply effects, resolve attacks

**Files to Create**:
1. `core/systems/combat_calculator.gd` - Damage formulas and calculations

**Combat Formulas** (Inspired by Shining Force):
```gdscript
class_name CombatCalculator
extends RefCounted

## Calculate physical attack damage
static func calculate_physical_damage(attacker: UnitStats, defender: UnitStats) -> int:
	var base_damage: int = attacker.strength - defender.defense

	# Apply variance (±10%)
	var variance: float = randf_range(0.9, 1.1)
	var damage: int = int(base_damage * variance)

	# Minimum damage is 1
	return maxi(damage, 1)

## Calculate magic attack damage
static func calculate_magic_damage(attacker: UnitStats, defender: UnitStats, ability: AbilityData) -> int:
	var base_damage: int = ability.base_power + attacker.intelligence - defender.intelligence / 2
	var variance: float = randf_range(0.9, 1.1)
	return maxi(int(base_damage * variance), 1)

## Calculate hit chance (percentage)
static func calculate_hit_chance(attacker: UnitStats, defender: UnitStats) -> int:
	var base_hit: int = 80
	var hit_modifier: int = (attacker.agility - defender.agility) * 2
	return clampi(base_hit + hit_modifier, 10, 99)

## Calculate critical hit chance
static func calculate_crit_chance(attacker: UnitStats, defender: UnitStats) -> int:
	var base_crit: int = 5
	var crit_modifier: int = attacker.luck - defender.luck
	return clampi(base_crit + crit_modifier, 0, 50)

## Check if attack hits
static func roll_hit(hit_chance: int) -> bool:
	return randi_range(1, 100) <= hit_chance

## Check if attack crits
static func roll_crit(crit_chance: int) -> bool:
	return randi_range(1, 100) <= crit_chance
```

**Combat Resolution**:
```gdscript
# In BattleManager or TurnManager
func execute_attack(attacker: Unit, defender: Unit) -> void:
	var attacker_stats: UnitStats = attacker.stats
	var defender_stats: UnitStats = defender.stats

	# Calculate hit chance
	var hit_chance: int = CombatCalculator.calculate_hit_chance(attacker_stats, defender_stats)

	# Roll to hit
	if not CombatCalculator.roll_hit(hit_chance):
		_show_combat_text(defender, "Miss!")
		return

	# Calculate damage
	var damage: int = CombatCalculator.calculate_physical_damage(attacker_stats, defender_stats)

	# Check for crit
	var crit_chance: int = CombatCalculator.calculate_crit_chance(attacker_stats, defender_stats)
	if CombatCalculator.roll_crit(crit_chance):
		damage *= 2
		_show_combat_text(defender, "Critical!")

	# Apply damage
	defender_stats.current_hp -= damage
	defender.emit_signal("damaged", damage)
	_show_combat_text(defender, str(-damage))

	# Check if defender died
	if defender_stats.current_hp <= 0:
		defender_stats.current_hp = 0
		_handle_unit_death(defender)
```

**Testing**:
- Unit attacks another unit
- Verify damage calculation is reasonable
- Test hit/miss mechanics
- Test critical hits
- Test unit death

---

### Step 7: Basic AI System (Week 4, Part 1)

**Purpose**: Enemy units take actions during their turn

**Files to Create**:
1. `core/systems/ai_controller.gd` - Simple AI behavior

**AI Behaviors** (From BattleData):
- **Aggressive**: Move toward nearest player unit and attack
- **Defensive**: Only move/attack if player in range
- **Patrol**: Move along predefined path (Phase 4)
- **Stationary**: Never move, attack if in range
- **Support**: Prioritize healing/buffing allies (Phase 4)

**Simple AI Logic** (Phase 3):
```gdscript
func process_enemy_turn(enemy_units: Array[Unit]) -> void:
	for enemy in enemy_units:
		if enemy.is_dead():
			continue

		match enemy.ai_behavior:
			"aggressive":
				_ai_aggressive(enemy)
			"defensive":
				_ai_defensive(enemy)
			"stationary":
				_ai_stationary(enemy)
			_:
				push_warning("Unknown AI behavior: %s" % enemy.ai_behavior)

func _ai_aggressive(enemy: Unit) -> void:
	# Find nearest player unit
	var target: Unit = _find_nearest_player_unit(enemy)
	if not target:
		return

	# Try to move closer
	var path: Array[Vector2i] = GridManager.find_path(
		enemy.grid_position,
		target.grid_position,
		enemy.character_data.character_class.movement_type
	)

	# Move as close as possible within movement range
	var movement_range: int = enemy.character_data.character_class.movement_range
	if path.size() > 1:
		var destination: Vector2i = path[mini(movement_range, path.size() - 1)]
		_move_unit(enemy, destination)

	# Attack if in range (Phase 3: melee only, range 1)
	if GridManager.grid.get_manhattan_distance(enemy.grid_position, target.grid_position) == 1:
		execute_attack(enemy, target)
```

**Testing**:
- Enemy unit moves toward player
- Enemy attacks when adjacent
- Stationary enemy doesn't move
- Defensive enemy waits for player

---

### Step 8: Polish & Integration (Week 4, Part 2)

**Purpose**: Connect all systems and create a playable demo battle

**Tasks**:
1. Create demo BattleData in editor
2. Test full battle flow from start to end
3. Add basic UI for turn display, unit stats
4. Add placeholder combat animations (fade, shake)
5. Add victory/defeat screens
6. Performance optimization
7. Bug fixing

**Demo Battle**:
- 3 player units vs 3 enemy units
- Simple 10×8 map with no obstacles
- Victory: Defeat all enemies
- Defeat: All player units defeated

**Basic Combat Animation** (Placeholder):
```gdscript
func _play_attack_animation(attacker: Unit, defender: Unit) -> void:
	# Attacker moves slightly toward defender
	var tween: Tween = create_tween()
	var direction: Vector2 = (defender.position - attacker.position).normalized()
	var attack_offset: Vector2 = direction * 8  # 8 pixels

	tween.tween_property(attacker, "position", attacker.position + attack_offset, 0.1)
	tween.tween_property(attacker, "position", attacker.position, 0.1)

	# Defender shakes
	var shake_tween: Tween = create_tween()
	shake_tween.tween_property(defender, "position:x", defender.position.x + 2, 0.05)
	shake_tween.tween_property(defender, "position:x", defender.position.x - 2, 0.05)
	shake_tween.tween_property(defender, "position:x", defender.position.x, 0.05)

	await tween.finished
```

**Testing**:
- Play through complete battle
- Verify all systems work together
- Check for crashes or edge cases
- Performance profiling (maintain 60 FPS)

---

## Technical Architecture

### System Communication (Signals & Direct Calls)

```
BattleManager (Orchestrator)
├── GridManager (Singleton) - Grid state, pathfinding
├── TurnManager (Singleton) - Turn order, phases
├── InputManager (Singleton) - Player input
└── CameraController (Node) - Camera following

Units (Scene Instances)
├── Emit signals for events (moved, attacked, damaged, died)
├── BattleManager listens to signals
└── BattleManager updates systems accordingly
```

**Why Autoloads?**
- GridManager, TurnManager, InputManager are autoloads because:
  - Single instance per battle
  - Accessed frequently by many systems
  - State must persist across scene changes (future)
- BattleManager is NOT an autoload:
  - Different per battle
  - Attached to battle_scene.tscn
  - Initialized per BattleData

### Data Flow Example (Player Attacks Enemy)

```
1. Player clicks enemy unit (InputManager)
   ↓
2. InputManager.emit_signal("action_selected", "attack", enemy)
   ↓
3. BattleManager.on_action_selected() receives signal
   ↓
4. BattleManager.execute_attack(active_unit, enemy)
   ↓
5. CombatCalculator.calculate_damage()
   ↓
6. enemy.take_damage(damage)
   ↓
7. enemy.emit_signal("damaged", damage)
   ↓
8. BattleManager.on_unit_damaged() shows damage numbers
   ↓
9. If enemy.hp == 0: enemy.emit_signal("died")
   ↓
10. BattleManager.on_unit_died() removes unit
   ↓
11. BattleManager._check_battle_conditions()
   ↓
12. If victory: end_battle(true)
```

---

## Success Criteria

Phase 3 will be considered complete when:

✅ GridManager with A* pathfinding working
✅ Units can be spawned from CharacterData
✅ Units display stats and visual representation
✅ Turn system alternates between player and enemy phases
✅ Player can select units, see movement range, and move units
✅ Player can attack adjacent enemies
✅ Damage calculation using stats works correctly
✅ Enemies use simple AI (aggressive behavior minimum)
✅ Victory/defeat conditions trigger correctly
✅ Demo battle is fully playable from start to finish
✅ No major bugs or crashes
✅ Performance is acceptable (60 FPS on target hardware)

---

## What's Deferred to Phase 4

**Not in Phase 3**:
- Item usage during battle
- Ability/spell system
- Counterattacks (when attacked, attack back)
- Experience gain and leveling up
- Equipment swapping mid-battle
- Status effects (poison, sleep, etc.)
- Terrain effects (movement cost, defense bonus)
- Advanced AI (patrol paths, support behavior)
- Battle animations (full sprite animation)
- Sound effects and music
- Dialogue system integration
- Save/load battle state

**Why defer these?**
- Phase 3 focuses on core tactical gameplay loop
- Get movement, turns, and basic combat working first
- Validate core architecture before adding complexity
- Test with simple mechanics before layering on features

---

## Testing Strategy

### Unit Tests
1. GridManager pathfinding with obstacles
2. Combat damage calculations
3. Hit/crit chance formulas
4. Unit stat calculations from CharacterData

### Integration Tests
1. Spawn units from BattleData
2. Complete turn cycle (player → enemy → player)
3. Unit movement with pathfinding
4. Combat resolution (attack, damage, death)
5. Victory/defeat condition triggering

### Manual Playtesting
1. Play demo battle from start to finish
2. Test edge cases (corner map movement, etc.)
3. Verify UI shows correct information
4. Check visual feedback is clear
5. Ensure controls feel responsive

### Performance Testing
1. Profile pathfinding performance (100 calls/sec?)
2. Check memory usage with 20+ units
3. Verify 60 FPS maintained during combat
4. Test on target platforms (Linux confirmed, Windows/Mac?)

---

## Implementation Timeline

### Week 1: Grid & Units
- **Days 1-2**: GridManager with A* pathfinding
- **Days 3-4**: Unit scene and component architecture
- **Day 5**: Testing and debugging

### Week 2: Turns & Input
- **Days 1-2**: TurnManager system
- **Days 3-4**: InputManager and player controls
- **Day 5**: Testing and debugging

### Week 3: Combat & AI
- **Days 1-2**: BattleManager and scene orchestration
- **Days 3-4**: Combat system and calculations
- **Day 5**: Testing and debugging

### Week 4: AI & Polish
- **Days 1-2**: Basic AI system
- **Days 3-5**: Demo battle, polish, bug fixing

**Total Estimate**: 4 weeks of focused development

---

## Risks & Mitigation

### Risk 1: Pathfinding Performance
**Risk**: A* too slow on large maps
**Mitigation**: Use AStarGrid2D (optimized), cache paths, limit max path length

### Risk 2: System Complexity
**Risk**: Too many interconnected systems become hard to debug
**Mitigation**: Build incrementally, test each system in isolation first

### Risk 3: Input State Machine
**Risk**: Input states become tangled and buggy
**Mitigation**: Clear state diagram, comprehensive logging, unit tests

### Risk 4: Animation Timing
**Risk**: Async animations cause race conditions
**Mitigation**: Use `await` properly, animation queue system

### Risk 5: Scope Creep
**Risk**: Try to add abilities, items, etc. before core works
**Mitigation**: Strict adherence to Phase 3 scope, defer features to Phase 4

---

## Next Steps

1. ✅ Create PHASE_3_PLAN.md (this document)
2. ⏳ Review and approve plan
3. ⏳ Create `core/systems/grid_manager.gd`
4. ⏳ Implement A* pathfinding with AStarGrid2D
5. ⏳ Test pathfinding with visual debug overlay
6. ⏳ Create Unit scene and component architecture
7. ⏳ Continue with remaining steps...

---

**Created**: November 14, 2025
**Status**: Awaiting Approval
**Next Review**: After approval and before implementation begins
