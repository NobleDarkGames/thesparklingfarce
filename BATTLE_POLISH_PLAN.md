# Battle System Polish Plan
## Shining Force-Style Battle System Enhancement

This document outlines the implementation plan for polishing The Sparkling Farce's battle system to better match Shining Force's mechanics and UI.

---

## Progress Checklist

### High Priority (Core Polish)
- [x] **HP1: Combat Animation Screen** ✅ COMPLETED
  - [x] Create CombatAnimationScene with attacker/defender layout
  - [x] Implement sprite positioning (attacker right, defender left)
  - [x] Add HP bars for both combatants
  - [x] Create damage number display with animation
  - [x] Implement scene transitions (fade out/in)
  - [x] Add attack animation states (hit, critical, miss)
  - [x] Integrate with BattleManager._execute_attack()
  - [x] Create polished placeholder system (colored panels + initials)
  - [x] Add class-based color coding
  - [x] Implement CombatAnimationData resource for easy art replacement
  - [ ] Test with various unit combinations (READY FOR MANUAL TESTING)

- [x] **HP2: Movement/Attack Range Highlights** ✅ COMPLETED
  - [x] Add Highlights TileMapLayer to map template
  - [x] Create highlight tileset (blue, red, yellow tiles)
  - [x] Implement GridManager.show_movement_range()
  - [x] Implement GridManager.show_attack_range()
  - [x] Implement GridManager.clear_highlights()
  - [x] Connect to InputManager states
  - [x] Show blue tiles in EXPLORING_MOVEMENT state
  - [x] Show red tiles when entering Attack targeting
  - [x] Show yellow tiles for valid targets
  - [x] Fix z-index issue (highlights were rendering below ground)
  - [x] Test highlight visibility and clearing
  - [x] Remove debug print statements

- [x] **HP3: Active Unit Stats Display** ✅ COMPLETED
  - [x] Create ActiveUnitStatsPanel UI scene
  - [x] Add unit name, HP/MP bars with values, combat stats
  - [x] Position panel at top-right of screen
  - [x] Create TerrainInfoPanel UI scene
  - [x] Position terrain panel at top-left of screen
  - [x] Connect to TurnManager signals in test scene
  - [x] Update stats panel when unit's turn begins
  - [x] Display terrain name and effects
  - [x] Add smooth show/hide transitions with fade
  - [x] Fix tween conflicts to prevent stale state
  - [x] Test with different units and terrain types

### Medium Priority (User Experience)
- [ ] **MP1: Streamline Movement Confirmation**
  - [ ] Analyze current movement flow in InputManager
  - [ ] Remove intermediate path preview confirmation step
  - [ ] Make cell selection immediately move character
  - [ ] Keep ESC cancel functionality
  - [ ] Update GridCursor behavior
  - [ ] Test movement feel and responsiveness
  - [ ] Ensure action menu appears correctly after move

- [ ] **MP2: Enemy Inspection System**
  - [ ] Add INSPECTING state to InputManager
  - [ ] Create InspectionPanel UI scene
  - [ ] Add hotkey for toggling inspection mode (Tab or I)
  - [ ] Allow cursor to hover over any unit during inspection
  - [ ] Display full unit stats in panel
  - [ ] Show equipment and status effects
  - [ ] Add visual indicator when in inspection mode
  - [ ] Test during player and enemy turns

- [ ] **MP3: Camera Auto-Following**
  - [ ] Implement CameraController.follow_unit() method
  - [ ] Connect to TurnManager.player_turn_started signal
  - [ ] Connect to TurnManager.enemy_turn_started signal
  - [ ] Add smooth camera transition to active unit
  - [ ] Ensure camera respects map boundaries
  - [ ] Add configurable follow speed setting
  - [ ] Test with units at various map positions

- [ ] **MP4: Basic Sound Effects**
  - [ ] Create audio/ directory structure
  - [ ] Source or create cursor movement sound
  - [ ] Source or create menu select/cancel sounds
  - [ ] Source or create attack hit sound
  - [ ] Source or create attack miss sound
  - [ ] Source or create damage taken sound
  - [ ] Source or create critical hit sound
  - [ ] Add AudioStreamPlayer nodes to appropriate scenes
  - [ ] Integrate sounds with InputManager actions
  - [ ] Integrate sounds with combat resolution
  - [ ] Test audio levels and timing

### Low Priority (Nice-to-Have)
- [ ] **LP1: Cursor Animations and States**
  - [ ] Create animated cursor sprite with pulse/flash
  - [ ] Add color variants (white, red, green, yellow)
  - [ ] Update GridCursor to use AnimatedSprite2D
  - [ ] Implement state-based cursor appearance
  - [ ] Add cursor movement sound integration
  - [ ] Test cursor visibility on different terrain

- [ ] **LP2: Smart Menu Positioning**
  - [ ] Implement dynamic ActionMenu positioning algorithm
  - [ ] Detect screen edges and unit position
  - [ ] Prefer right side of unit, fall back to left
  - [ ] Ensure menu doesn't cover unit or key battlefield areas
  - [ ] Test with units at corners and edges of map

- [ ] **LP3: Turn Counter Display**
  - [ ] Add TurnCounterLabel to HUD
  - [ ] Position at top-left or top-right
  - [ ] Connect to TurnManager.turn_cycle_started signal
  - [ ] Update display with current turn number
  - [ ] Add simple styling

### Future Phase (Phase 4 Features)
- [ ] **Magic System**
  - [ ] Implement spell range visualization
  - [ ] Add MP cost and spell selection UI
  - [ ] Create spell animation effects
  - [ ] Add support spells (Heal, Boost, Shield)
  - [ ] Integrate with combat animation screen

- [ ] **Experience and Leveling**
  - [ ] Show XP gained popup after combat
  - [ ] Implement level-up detection
  - [ ] Create level-up animation and stat display
  - [ ] Grant XP for healing actions
  - [ ] Integrate with unit progression system

- [ ] **Item System**
  - [ ] Implement item usage in battle
  - [ ] Add item inventory UI during battle
  - [ ] Create item effect animations
  - [ ] Allow item transfer between adjacent units

---

## Detailed Implementation Plans

### HP1: Combat Animation Screen

**Objective**: Create a dedicated combat screen that displays when attacks occur, showing attacker vs defender with animations, damage numbers, and HP bar updates.

**Files to Create**:
- `/scenes/ui/combat_animation_scene.tscn` - Main combat display scene
- `/scenes/ui/combat_animation_scene.gd` - Script controlling animation flow

**Files to Modify**:
- `/core/systems/battle_manager.gd` - Integrate combat scene transitions

**Scene Structure**:
```
CombatAnimationScene (Control, fullscreen)
├── Background (ColorRect) - Solid color or gradient backdrop
├── AttackerContainer (Control) - Right side positioning
│   ├── AttackerSprite (Sprite2D or AnimatedSprite2D)
│   ├── AttackerNameLabel (Label)
│   └── AttackerHPBar (ProgressBar)
├── DefenderContainer (Control) - Left side positioning
│   ├── DefenderSprite (Sprite2D or AnimatedSprite2D)
│   ├── DefenderNameLabel (Label)
│   └── DefenderHPBar (ProgressBar)
├── DamageLabel (Label) - Centered, appears above defender
├── CombatLog (Label) - Bottom center, shows "Hit!", "Critical!", "Miss!"
└── AnimationPlayer (AnimationPlayer) - Controls sequence
```

**Implementation Steps**:

1. **Create the Scene**:
   - Build UI layout with attacker on right, defender on left
   - Use Control nodes with anchor positioning for responsive layout
   - AttackerSprite at position ~75% screen width
   - DefenderSprite at position ~25% screen width
   - Both sprites scaled appropriately (consider 3-4x unit sprite size)

2. **Script the Animation Flow**:
```gdscript
class_name CombatAnimationScene
extends Control

signal animation_complete

@onready var attacker_sprite: Sprite2D = $AttackerContainer/AttackerSprite
@onready var defender_sprite: Sprite2D = $DefenderContainer/DefenderSprite
@onready var attacker_hp_bar: ProgressBar = $AttackerContainer/AttackerHPBar
@onready var defender_hp_bar: ProgressBar = $DefenderContainer/DefenderHPBar
@onready var damage_label: Label = $DamageLabel
@onready var combat_log: Label = $CombatLog
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func play_combat_animation(
    attacker: Node2D,
    defender: Node2D,
    damage: int,
    was_critical: bool,
    was_miss: bool
) -> void:
    # Set up sprites and stats
    _setup_combatant(attacker, attacker_sprite, attacker_hp_bar)
    _setup_combatant(defender, defender_sprite, defender_hp_bar)

    # Hide damage label initially
    damage_label.visible = false

    # Play appropriate animation
    if was_miss:
        anim_player.play("attack_miss")
        combat_log.text = "Miss!"
    elif was_critical:
        anim_player.play("attack_critical")
        combat_log.text = "Critical Hit!"
        await _show_damage(damage)
    else:
        anim_player.play("attack_hit")
        combat_log.text = "Hit!"
        await _show_damage(damage)

    # Wait for animation to complete
    await anim_player.animation_finished

    # Signal completion
    animation_complete.emit()

func _setup_combatant(unit: Node2D, sprite: Sprite2D, hp_bar: ProgressBar) -> void:
    # Copy unit's sprite texture
    sprite.texture = unit.get_node("Sprite2D").texture

    # Set HP bar
    hp_bar.max_value = unit.stats.max_hp
    hp_bar.value = unit.stats.current_hp

func _show_damage(damage: int) -> void:
    damage_label.text = str(damage)
    damage_label.visible = true

    # Animate damage number (float up and fade)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(damage_label, "position:y", damage_label.position.y - 50, 0.8)
    tween.tween_property(damage_label, "modulate:a", 0.0, 0.8)

    await tween.finished
```

3. **Create AnimationPlayer Animations**:
   - **attack_hit**:
     - 0.0s: Start
     - 0.2s: Attacker moves forward slightly
     - 0.4s: Attacker returns to position
     - 0.5s: Defender flashes red (hit effect)
     - 0.5s: Show damage label
     - 1.3s: Tween defender HP bar down
     - 2.0s: End

   - **attack_critical**:
     - Similar to attack_hit but with more dramatic movements
     - Add screen shake effect
     - Different timing (faster, more impactful)

   - **attack_miss**:
     - Attacker moves forward
     - Defender sidesteps or dodges
     - No damage display
     - Show "Miss!" text

4. **Integrate with BattleManager**:
```gdscript
# In battle_manager.gd

@onready var combat_anim_scene: PackedScene = preload("res://scenes/ui/combat_animation_scene.tscn")
var combat_anim_instance: CombatAnimationScene = null

func _execute_attack(attacker: Node2D, defender: Node2D) -> void:
    # Calculate hit/damage (existing code)
    var hit_roll: float = randf() * 100.0
    var hit_chance: float = CombatCalculator.calculate_hit_chance(attacker, defender)

    var was_miss: bool = hit_roll > hit_chance
    var damage: int = 0
    var was_critical: bool = false

    if not was_miss:
        # Calculate damage (existing code)
        var crit_roll: float = randf() * 100.0
        var crit_chance: float = CombatCalculator.calculate_crit_chance(attacker, defender)
        was_critical = crit_roll <= crit_chance

        damage = CombatCalculator.calculate_physical_damage(attacker, defender)
        if was_critical:
            damage = int(damage * CombatCalculator.CRITICAL_DAMAGE_MULTIPLIER)

    # Show combat animation
    await _show_combat_animation(attacker, defender, damage, was_critical, was_miss)

    # Apply damage after animation
    if not was_miss:
        var defender_died: bool = defender.stats.take_damage(damage)
        if defender_died:
            _on_unit_died(defender)

    # Emit combat resolved signal
    combat_resolved.emit(attacker, defender, damage, was_miss, was_critical)

    # End turn
    TurnManager.end_unit_turn(attacker)

func _show_combat_animation(
    attacker: Node2D,
    defender: Node2D,
    damage: int,
    was_critical: bool,
    was_miss: bool
) -> void:
    # Instantiate combat animation scene
    combat_anim_instance = combat_anim_scene.instantiate()
    battle_scene.add_child(combat_anim_instance)

    # Fade out battle field
    var tween := create_tween()
    tween.tween_property(battle_scene.get_node("Map"), "modulate:a", 0.0, 0.2)
    tween.tween_property(battle_scene.get_node("Units"), "modulate:a", 0.0, 0.2)
    await tween.finished

    # Play combat animation
    combat_anim_instance.play_combat_animation(attacker, defender, damage, was_critical, was_miss)
    await combat_anim_instance.animation_complete

    # Fade back to battle field
    tween = create_tween()
    tween.tween_property(battle_scene.get_node("Map"), "modulate:a", 1.0, 0.2)
    tween.tween_property(battle_scene.get_node("Units"), "modulate:a", 1.0, 0.2)
    await tween.finished

    # Clean up
    combat_anim_instance.queue_free()
    combat_anim_instance = null
```

5. **Testing Checklist**:
   - [ ] Scene displays correctly in fullscreen
   - [ ] Attacker and defender sprites load properly
   - [ ] HP bars show correct values
   - [ ] Damage number appears and animates
   - [ ] Hit animation plays smoothly
   - [ ] Critical animation is more dramatic
   - [ ] Miss animation shows correctly
   - [ ] Scene transitions don't cause flicker
   - [ ] Combat resolves and returns to battlefield
   - [ ] Works with AI enemy attacks

**Edge Cases to Handle**:
- Units without sprites (use default placeholder)
- Very high damage numbers (ensure label is large enough)
- Defender dies (add death animation variant)
- Multiple attacks in quick succession (queue animations)

---

### HP2: Movement/Attack Range Highlights

**Objective**: Add visual tile highlights to show movement range (blue), attack range (red), and selected targets (yellow), providing clear feedback about available actions.

**Files to Create**:
- `/assets/tilesets/highlight_tileset.tres` - Tileset for colored highlight tiles
- `/assets/tiles/highlight_blue.png` - Blue tile for movement range
- `/assets/tiles/highlight_red.png` - Red tile for attack range
- `/assets/tiles/highlight_yellow.png` - Yellow tile for targets

**Files to Modify**:
- `/core/systems/grid_manager.gd` - Add highlight management methods
- `/core/systems/input_manager.gd` - Call highlight methods based on state
- Map scene templates - Add Highlights layer

**Implementation Steps**:

1. **Create Highlight Tiles**:
   - Create 32x32 pixel PNG images:
     - `highlight_blue.png`: Semi-transparent blue (#3498DB with 50% opacity)
     - `highlight_red.png`: Semi-transparent red (#E74C3C with 50% opacity)
     - `highlight_yellow.png`: Semi-transparent yellow (#F1C40F with 50% opacity)
   - Alternative: Use ColorRect with modulate in tileset
   - Ensure tiles are visually distinct but don't obscure terrain

2. **Create Tileset**:
```gdscript
# Configure in Godot editor:
# - Create new TileSet resource
# - Add highlight tiles as atlas
# - Assign IDs: 0=blue, 1=red, 2=yellow
# - Save as highlight_tileset.tres
```

3. **Add Highlights Layer to Maps**:
   - Open map scene template
   - Add new TileMapLayer as child of Map node
   - Name it "Highlights"
   - Assign highlight_tileset.tres
   - Set z_index to 1 (above ground, below units)
   - Set visibility to true

4. **Implement GridManager Highlight Methods**:
```gdscript
# In grid_manager.gd

const HIGHLIGHT_BLUE: int = 0
const HIGHLIGHT_RED: int = 1
const HIGHLIGHT_YELLOW: int = 2

var highlights_layer: TileMapLayer = null

func set_highlights_layer(layer: TileMapLayer) -> void:
    highlights_layer = layer

func show_movement_range(from: Vector2i, movement_range: int, movement_type: int) -> void:
    """Show blue highlights for all walkable cells from a position."""
    if not highlights_layer:
        push_warning("No highlights layer set")
        return

    clear_highlights()

    var walkable_cells: Array[Vector2i] = get_walkable_cells(from, movement_range, movement_type)
    for cell in walkable_cells:
        highlights_layer.set_cell(cell, 0, Vector2i(HIGHLIGHT_BLUE, 0))

func show_attack_range(from: Vector2i, weapon_range: int) -> void:
    """Show red highlights for all cells within attack range from a position."""
    if not highlights_layer:
        push_warning("No highlights layer set")
        return

    clear_highlights()

    # Calculate attack range (using grid resource's get_cells_in_range)
    var attack_cells: Array[Vector2i] = []
    for x in range(-weapon_range, weapon_range + 1):
        for y in range(-weapon_range, weapon_range + 1):
            var target_cell := Vector2i(from.x + x, from.y + y)
            var distance := abs(x) + abs(y)  # Manhattan distance
            if distance > 0 and distance <= weapon_range and grid.is_within_bounds(target_cell):
                attack_cells.append(target_cell)

    for cell in attack_cells:
        highlights_layer.set_cell(cell, 0, Vector2i(HIGHLIGHT_RED, 0))

func highlight_targets(target_cells: Array[Vector2i]) -> void:
    """Show yellow highlights for specific target cells."""
    if not highlights_layer:
        push_warning("No highlights layer set")
        return

    for cell in target_cells:
        highlights_layer.set_cell(cell, 0, Vector2i(HIGHLIGHT_YELLOW, 0))

func clear_highlights() -> void:
    """Remove all highlight tiles."""
    if not highlights_layer:
        return

    highlights_layer.clear()
```

5. **Integrate with InputManager States**:
```gdscript
# In input_manager.gd

func start_player_turn(unit: Node2D) -> void:
    # ... existing code ...

    # Show movement range highlights
    var unit_cell: Vector2i = GridManager.world_to_cell(unit.global_position)
    var movement_range: int = unit.character_data.character_class.movement_range
    var movement_type: int = unit.character_data.character_class.movement_type
    GridManager.show_movement_range(unit_cell, movement_range, movement_type)

    # ... rest of existing code ...

func _on_action_selected(action: String) -> void:
    match action:
        "Attack":
            # Show attack range when entering targeting mode
            var unit_cell: Vector2i = GridManager.world_to_cell(active_unit.global_position)

            # Get weapon range (default to 1 for melee)
            var weapon_range: int = 1
            # TODO: Get from equipped weapon when equipment system is implemented

            GridManager.show_attack_range(unit_cell, weapon_range)

            # Calculate valid targets
            var targets: Array[Node2D] = _get_units_in_attack_range(active_unit, weapon_range)

            # Highlight target positions in yellow
            var target_cells: Array[Vector2i] = []
            for target in targets:
                target_cells.append(GridManager.world_to_cell(target.global_position))
            GridManager.highlight_targets(target_cells)

            # ... rest of existing targeting code ...

        "Stay":
            GridManager.clear_highlights()
            # ... existing code ...

func cleanup_turn() -> void:
    # ... existing code ...
    GridManager.clear_highlights()
```

6. **Update BattleManager Initialization**:
```gdscript
# In battle_manager.gd

func start_battle(battle_data: BattleData) -> void:
    # ... existing map loading code ...

    # Find and set highlights layer
    var highlights_layer: TileMapLayer = map_instance.find_child("Highlights")
    if highlights_layer:
        GridManager.set_highlights_layer(highlights_layer)
    else:
        push_warning("Map scene missing Highlights layer - range visualization disabled")

    # ... rest of existing code ...
```

7. **Testing Checklist**:
   - [ ] Highlights layer appears in map scene
   - [ ] Blue tiles show movement range at turn start
   - [ ] Movement range respects terrain costs
   - [ ] Movement range updates as cursor moves
   - [ ] Red tiles show attack range when Attack selected
   - [ ] Yellow tiles highlight valid targets
   - [ ] Highlights clear when action completes
   - [ ] Highlights don't obscure important terrain features
   - [ ] Highlights work with different map sizes
   - [ ] Opacity allows seeing terrain underneath

**Edge Cases to Handle**:
- Map without Highlights layer (graceful degradation)
- Very large movement ranges (performance)
- Overlapping highlights (attack range over movement range)
- Flying units (different terrain costs)

---

### HP3: Active Unit Stats Display

**Objective**: Display the active unit's stats in a dedicated panel when their turn begins, along with terrain effect information, providing clear context for decision-making.

**Files to Create**:
- `/scenes/ui/active_unit_stats_panel.tscn` - Stats display panel
- `/scenes/ui/active_unit_stats_panel.gd` - Script for stats panel
- `/scenes/ui/terrain_info_panel.tscn` - Terrain effects panel
- `/scenes/ui/terrain_info_panel.gd` - Script for terrain panel

**Files to Modify**:
- `/scenes/battle_scene.tscn` - Add panels to HUD
- `/core/systems/turn_manager.gd` - Connect signals to update panels

**Scene Structure for ActiveUnitStatsPanel**:
```
ActiveUnitStatsPanel (PanelContainer)
├── MarginContainer
│   └── VBoxContainer
│       ├── UnitNameLabel (Label) - Bold, larger font
│       ├── HPContainer (HBoxContainer)
│       │   ├── HPLabel (Label) - "HP:"
│       │   ├── HPBar (ProgressBar) - Visual bar
│       │   └── HPValue (Label) - "25/30"
│       ├── MPContainer (HBoxContainer)
│       │   ├── MPLabel (Label) - "MP:"
│       │   ├── MPBar (ProgressBar) - Visual bar
│       │   └── MPValue (Label) - "10/15"
│       ├── HSeparator
│       └── QuickStats (GridContainer - 2 columns)
│           ├── STRLabel (Label) - "STR:"
│           ├── STRValue (Label) - "12"
│           ├── DEFLabel (Label) - "DEF:"
│           ├── DEFValue (Label) - "10"
│           ├── AGILabel (Label) - "AGI:"
│           ├── AGIValue (Label) - "15"
│           └── ... (other stats as needed)
```

**Scene Structure for TerrainInfoPanel**:
```
TerrainInfoPanel (PanelContainer)
├── MarginContainer
│   └── VBoxContainer
│       ├── TerrainNameLabel (Label) - "Plains"
│       └── TerrainEffectLabel (Label) - "No effect" or "DEF +1"
```

**Implementation Steps**:

1. **Create ActiveUnitStatsPanel Scene and Script**:
```gdscript
# active_unit_stats_panel.gd
class_name ActiveUnitStatsPanel
extends PanelContainer

@onready var unit_name_label: Label = %UnitNameLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_value: Label = %HPValue
@onready var mp_bar: ProgressBar = %MPBar
@onready var mp_value: Label = %MPValue
@onready var str_value: Label = %STRValue
@onready var def_value: Label = %DEFValue
@onready var agi_value: Label = %AGIValue
@onready var int_value: Label = %INTValue
@onready var luk_value: Label = %LUKValue

func show_unit_stats(unit: Node2D) -> void:
    """Display stats for the given unit."""
    if not unit or not unit.stats:
        hide()
        return

    # Update name
    unit_name_label.text = unit.character_data.character_name

    # Update HP
    hp_bar.max_value = unit.stats.max_hp
    hp_bar.value = unit.stats.current_hp
    hp_value.text = "%d/%d" % [unit.stats.current_hp, unit.stats.max_hp]

    # Update MP
    mp_bar.max_value = unit.stats.max_mp
    mp_bar.value = unit.stats.current_mp
    mp_value.text = "%d/%d" % [unit.stats.current_mp, unit.stats.max_mp]

    # Update combat stats
    str_value.text = str(unit.stats.strength)
    def_value.text = str(unit.stats.defense)
    agi_value.text = str(unit.stats.agility)
    int_value.text = str(unit.stats.intelligence)
    luk_value.text = str(unit.stats.luck)

    # Animate in
    show()
    modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_stats() -> void:
    """Hide the stats panel with animation."""
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.tween_callback(hide)
```

2. **Create TerrainInfoPanel Scene and Script**:
```gdscript
# terrain_info_panel.gd
class_name TerrainInfoPanel
extends PanelContainer

@onready var terrain_name_label: Label = %TerrainNameLabel
@onready var terrain_effect_label: Label = %TerrainEffectLabel

# Terrain type to name mapping
const TERRAIN_NAMES: Dictionary = {
    0: "Plains",
    1: "Forest",
    2: "Mountain",
    3: "Water",
    4: "Road",
    # Add more terrain types as needed
}

# Terrain effects (placeholder - will be expanded with actual terrain system)
const TERRAIN_EFFECTS: Dictionary = {
    0: "No effect",
    1: "DEF +1",
    2: "DEF +2, AGI -1",
    3: "Impassable (ground units)",
    4: "MOV cost reduced",
}

func show_terrain_info(unit_cell: Vector2i) -> void:
    """Display terrain information for the given cell."""
    # Get terrain type from TileMapLayer
    var terrain_type: int = _get_terrain_type_at_cell(unit_cell)

    # Update labels
    terrain_name_label.text = TERRAIN_NAMES.get(terrain_type, "Unknown")
    terrain_effect_label.text = TERRAIN_EFFECTS.get(terrain_type, "No data")

    # Animate in
    show()
    modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_terrain_info() -> void:
    """Hide the terrain panel with animation."""
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.tween_callback(hide)

func _get_terrain_type_at_cell(cell: Vector2i) -> int:
    """Get the terrain type ID at the specified cell."""
    # This needs access to the TileMapLayer
    # For now, return default terrain (0)
    # TODO: Integrate with GridManager's terrain system
    if GridManager.tile_map_layer:
        var tile_data: TileData = GridManager.tile_map_layer.get_cell_tile_data(cell)
        if tile_data:
            # Assuming terrain type is stored in custom data layer "terrain_type"
            return tile_data.get_custom_data("terrain_type") if tile_data.get_custom_data("terrain_type") else 0
    return 0
```

3. **Add Panels to BattleScene**:
   - Open `/scenes/battle_scene.tscn`
   - In UI/HUD, add:
     - `ActiveUnitStatsPanel` instance
       - Anchor: Top-Right
       - Position: Offset from top-right corner by margin
     - `TerrainInfoPanel` instance
       - Anchor: Top-Left
       - Position: Offset from top-left corner by margin

4. **Connect to TurnManager**:
```gdscript
# In battle_manager.gd (or create a UI manager)

@onready var stats_panel: ActiveUnitStatsPanel = $UI/HUD/ActiveUnitStatsPanel
@onready var terrain_panel: TerrainInfoPanel = $UI/HUD/TerrainInfoPanel

func _ready() -> void:
    # ... existing code ...

    # Connect turn signals
    TurnManager.player_turn_started.connect(_on_player_turn_started)
    TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
    TurnManager.unit_turn_ended.connect(_on_unit_turn_ended)

func _on_player_turn_started(unit: Node2D) -> void:
    """Show stats when player's turn starts."""
    stats_panel.show_unit_stats(unit)

    var unit_cell: Vector2i = GridManager.world_to_cell(unit.global_position)
    terrain_panel.show_terrain_info(unit_cell)

func _on_enemy_turn_started(unit: Node2D) -> void:
    """Show stats when enemy's turn starts (optional)."""
    # Optionally show enemy stats, or hide panels during enemy turns
    stats_panel.show_unit_stats(unit)

    var unit_cell: Vector2i = GridManager.world_to_cell(unit.global_position)
    terrain_panel.show_terrain_info(unit_cell)

func _on_unit_turn_ended(unit: Node2D) -> void:
    """Hide stats when turn ends."""
    stats_panel.hide_stats()
    terrain_panel.hide_terrain_info()
```

5. **Styling Recommendations**:
   - Use a semi-transparent dark background for panels (80% opacity)
   - HP bar: Red/Green gradient
   - MP bar: Blue gradient
   - Font: Monospace or clear sans-serif, size 14-16
   - Padding: 8-12 pixels margin inside panels
   - Panel corners: Slight rounding (4-8 pixels)

6. **Testing Checklist**:
   - [ ] Stats panel appears at top-right when turn starts
   - [ ] All stats display correct values
   - [ ] HP/MP bars show correct proportions
   - [ ] Terrain panel appears at top-left
   - [ ] Terrain name and effects display correctly
   - [ ] Panels animate in smoothly
   - [ ] Panels hide at end of turn
   - [ ] Panels don't obscure important battlefield areas
   - [ ] Stats update if unit takes damage during turn (if applicable)
   - [ ] Works for both player and enemy units

**Edge Cases to Handle**:
- Units with very long names (truncate or resize)
- Units with 0 MP (hide MP bar or show as N/A)
- Invalid terrain types (show "Unknown")
- Stats changing mid-turn due to buffs/debuffs

---

### MP1: Streamline Movement Confirmation

**Objective**: Remove the intermediate "confirm movement" step to match Shining Force's flow where selecting a cell immediately moves the character.

**Files to Modify**:
- `/core/systems/input_manager.gd` - Simplify movement flow
- `/scenes/ui/grid_cursor.gd` - Update cursor behavior

**Current Flow**:
1. Cursor shows movement range
2. Player selects destination → path preview shows
3. Player confirms movement → character moves
4. Action menu appears

**Target Flow (Shining Force-style)**:
1. Cursor shows movement range
2. Player selects destination → character moves immediately
3. Action menu appears
4. ESC in action menu returns to movement (character moves back)

**Implementation Steps**:

1. **Analyze Current Movement Logic**:
   - Review `InputManager._handle_exploring_movement()`
   - Identify where confirmation wait occurs
   - Understand path preview system

2. **Modify InputManager**:
```gdscript
# In input_manager.gd

# Remove or simplify this method
func _handle_exploring_movement(event: InputEvent) -> void:
    # ... existing cursor movement code ...

    # OLD: Wait for Enter key to confirm
    # if event.is_action_pressed("ui_accept"):
    #     _confirm_movement()

    # NEW: Click/Enter immediately confirms
    if event.is_action_pressed("ui_accept") or event is InputEventMouseButton:
        var target_cell: Vector2i = GridManager.world_to_cell(grid_cursor.global_position)

        # Check if cell is walkable
        var walkable_cells: Array[Vector2i] = GridManager.get_walkable_cells(
            GridManager.world_to_cell(active_unit.global_position),
            active_unit.character_data.character_class.movement_range,
            active_unit.character_data.character_class.movement_type
        )

        if target_cell in walkable_cells:
            _move_unit_to_cell(target_cell)
        else:
            # Play error sound or show invalid indicator
            push_warning("Cannot move to that cell")

func _move_unit_to_cell(target_cell: Vector2i) -> void:
    """Immediately move the unit to the target cell."""
    # Store original position for undo functionality
    original_position = active_unit.global_position

    # Calculate path
    var start_cell: Vector2i = GridManager.world_to_cell(active_unit.global_position)
    var path: Array[Vector2i] = GridManager.find_path(
        start_cell,
        target_cell,
        active_unit.character_data.character_class.movement_type
    )

    # Clear movement highlights
    GridManager.clear_highlights()

    # Animate movement along path
    await _animate_unit_movement(path)

    # Update grid occupation
    GridManager.clear_cell_occupied(start_cell)
    GridManager.set_cell_occupied(target_cell, active_unit)

    # Transition to action selection
    _transition_to_action_selection()

func _animate_unit_movement(path: Array[Vector2i]) -> void:
    """Animate the unit moving along the path."""
    for cell in path:
        var world_pos: Vector2 = GridManager.cell_to_world(cell)
        var tween := create_tween()
        tween.tween_property(active_unit, "global_position", world_pos, 0.15)
        await tween.finished

func _transition_to_action_selection() -> void:
    """Show action menu after movement."""
    state = InputState.SELECTING_ACTION
    grid_cursor.hide()

    # Show action menu
    action_menu.global_position = active_unit.global_position + Vector2(40, -20)
    action_menu.show()

    # Update available actions
    var available_actions: Array[String] = _get_available_actions()
    action_menu.set_available_actions(available_actions)
```

3. **Update Cancel Behavior**:
```gdscript
# In input_manager.gd

func _handle_action_selection(event: InputEvent) -> void:
    # When ESC is pressed in action menu, return to movement
    if event.is_action_pressed("ui_cancel"):
        _cancel_to_movement()

func _cancel_to_movement() -> void:
    """Return unit to original position and re-enter movement mode."""
    # Hide action menu
    action_menu.hide()

    # Move unit back to original position
    var original_cell: Vector2i = GridManager.world_to_cell(original_position)
    var current_cell: Vector2i = GridManager.world_to_cell(active_unit.global_position)

    # Update occupation
    GridManager.clear_cell_occupied(current_cell)
    GridManager.set_cell_occupied(original_cell, active_unit)

    # Animate back
    var tween := create_tween()
    tween.tween_property(active_unit, "global_position", original_position, 0.15)
    await tween.finished

    # Return to exploring movement
    state = InputState.EXPLORING_MOVEMENT
    grid_cursor.show()
    grid_cursor.global_position = GridManager.cell_to_world(original_cell)

    # Re-show movement highlights
    GridManager.show_movement_range(
        original_cell,
        active_unit.character_data.character_class.movement_range,
        active_unit.character_data.character_class.movement_type
    )
```

4. **Remove Path Preview System** (Optional):
   - If path preview is no longer needed, remove related code
   - Or keep it as a hover effect (shows path but doesn't require confirmation)

5. **Testing Checklist**:
   - [ ] Clicking a cell immediately moves the character
   - [ ] Enter key on a cell immediately moves the character
   - [ ] Action menu appears right after movement
   - [ ] ESC in action menu returns unit to start position
   - [ ] Movement animation is smooth and quick
   - [ ] Can't move to invalid cells (shows error or does nothing)
   - [ ] Highlights clear after movement
   - [ ] Occupation tracking updates correctly
   - [ ] Multiple move-cancel cycles work correctly

**Edge Cases to Handle**:
- Clicking outside movement range (ignore or show feedback)
- Clicking on occupied cell (treat as attack initiation?)
- Very fast double-clicks (debounce input)

---

## Notes for Implementation

### General Principles
- **Test after each feature**: Complete and test each high-priority item before moving to the next
- **Maintain backwards compatibility**: Ensure existing test scenes continue to work
- **Follow Godot best practices**: Strict typing, proper node lifecycle, signal-based communication
- **Document as you go**: Add comments to complex logic, update this document with actual implementation notes

### Testing Strategy
- Use `/mods/_sandbox/scenes/test_full_battle.gd` as primary test scene
- Test with both player and AI units
- Test edge cases (corners of map, units with different stats, etc.)
- Run headless AI tests to ensure no regressions

### Performance Considerations
- Highlights: Only update when necessary, clear efficiently
- Combat animations: Ensure tweens are properly cleaned up
- Stats panels: Cache node references, avoid redundant updates

### Future Expansion Hooks
- Combat animation system should support magic effects (Phase 4)
- Stats panel should accommodate status effect icons (Phase 4)
- Highlight system should support AOE spell ranges (Phase 4)

---

## Timeline Estimate

**High Priority (HP1-HP3)**: 8-12 hours
- HP1 (Combat Animation): 4-5 hours
- HP2 (Highlights): 2-3 hours
- HP3 (Stats Display): 2-3 hours
- Testing/Polish: 1-2 hours

**Medium Priority (MP1-MP4)**: 6-8 hours
- MP1 (Movement Flow): 1-2 hours
- MP2 (Inspection): 2-3 hours
- MP3 (Camera): 1 hour
- MP4 (Sound Effects): 2-3 hours

**Low Priority (LP1-LP3)**: 3-4 hours
- LP1 (Cursor Animation): 1-2 hours
- LP2 (Menu Positioning): 1 hour
- LP3 (Turn Counter): 30 minutes

**Total Estimated Time**: 17-24 hours

---

## Customization Notes

This plan follows standard Shining Force conventions, but here are areas you may want to customize:

1. **Combat Animation Screen**:
   - Duration of animations
   - Camera angles or zoom
   - Particle effects for hits/crits
   - Background imagery vs solid colors

2. **Highlight Colors**:
   - Opacity levels
   - Color choices (colorblind-friendly options?)
   - Animation (pulsing, flashing, static)

3. **Stats Panel**:
   - Which stats to show (all vs. essential only)
   - Layout (vertical vs horizontal)
   - Position (top-right vs other corners)
   - Show for enemy turns or player only

4. **Movement Flow**:
   - Immediate movement vs. path preview
   - Movement animation speed
   - Whether to allow "undo" after action selection

5. **Sound Effects**:
   - 8-bit retro vs modern sound design
   - Volume levels and mixing
   - Music integration

Let me know which features you want to customize before we begin implementation!

---

## Next Steps

1. Review this plan and provide feedback on:
   - Priority order (want to change the sequence?)
   - Implementation details (any features to modify or skip?)
   - Customization preferences (see Customization Notes above)

2. Once approved, we'll begin with **HP1: Combat Animation Screen**

3. After each feature is complete, we'll:
   - Update the checklist
   - Test thoroughly
   - Commit changes (with your approval)
   - Move to next feature

Ready to begin when you are!

---

## Testing Notes

### HP1: Combat Animation Screen - ✅ COMPLETED & TESTED

**Implementation Date:** November 20, 2025

**Files Created:**
- `core/resources/combat_animation_data.gd` - Resource for defining combat visuals
- `scenes/ui/combat_animation_scene.tscn` - Combat display scene (CanvasLayer-based)
- `scenes/ui/combat_animation_scene.gd` - Combat animation logic

**Files Modified:**
- `core/resources/character_data.gd` - Added `combat_animation_data` field
- `core/systems/battle_manager.gd` - Integrated full-screen combat display

**Key Implementation Details:**

1. **Full-Screen Replacement (Shining Force Style)**
   - Uses CanvasLayer with layer=100 for proper z-ordering
   - Completely hides battlefield during combat (not an overlay)
   - Dark background covers entire viewport
   - Smooth fade in/out transitions

2. **Polished Placeholder System**
   - 180x180 colored panels with character initials (96pt font)
   - Class-based color coding:
     - Warriors/Knights/Fighters: Red
     - Mages/Wizards/Sorcerers: Blue
     - Healers/Priests/Clerics: Green
     - Archers/Rangers: Brown
     - Thieves/Rogues/Ninjas: Purple
     - Default/Unknown: Gray
   - Simple ASCII faces for personality
   - White borders, rounded corners, drop shadows

3. **Animation Timings (Tuned for Visibility)**
   - Fade in: 0.4s
   - Attack movement: 0.3s each direction
   - Impact pause: 0.2s
   - Flash duration: 0.15s
   - HP bar drain: 0.6s (normal), 0.8s (critical)
   - Damage float: 1.2s
   - Result pause: 1.5s
   - Fade out: 0.4s
   - **Total duration**: ~4-5 seconds per attack

4. **Three Animation Variants**
   - **Hit**: Standard attack with red flash
   - **Critical Hit**: Screen shake, yellow flash, larger damage number
   - **Miss**: Defender dodge movement, "MISS" text, no damage

**How to Test:**
1. Run scene: `mods/_sandbox/scenes/test_unit.tscn`
2. Move Hero next to Goblin
3. Select "Attack" from action menu
4. Watch the full-screen combat animation!

**What You Should See:**
- Battlefield disappears completely
- Full-screen dark background appears (fade in)
- Large character portraits on left (Defender) and right (Attacker)
- Character names and HP bars
- Attacker slides forward → Impact → Returns
- Damage number floats up and fades
- "Hit!" / "Critical Hit!" / "Miss!" message at bottom
- HP bar drains smoothly
- 1.5 second pause to see results
- Everything fades out, battlefield returns

**Moddability - Adding Real Art:**
```gdscript
# Create combat animation data resource:
var combat_anim := CombatAnimationData.new()

# Option 1: Static sprite
combat_anim.battle_sprite = preload("res://sprites/hero_battle.png")
combat_anim.sprite_scale = 4.0

# Option 2: Animated sprite (advanced)
combat_anim.battle_sprite_frames = preload("res://sprites/hero_battle_anims.res")
combat_anim.idle_animation = "idle"
combat_anim.attack_animation = "sword_slash"
combat_anim.critical_animation = "power_strike"

# Assign to character
character_data.combat_animation_data = combat_anim
```

The system automatically uses custom art if provided, otherwise falls back to polished placeholders.

**Known Issues Resolved:**
- ✅ Fixed: CanvasLayer not disappearing after combat (added `visible = false`)
- ✅ Fixed: Animations too fast (doubled/tripled most durations)
- ✅ Fixed: Reserved keywords `static` and `class` in variable names
- ✅ Fixed: StyleBoxFlat properties (individual border widths instead of `_all`)
- ✅ Fixed: CanvasLayer doesn't have `modulate` or `position` (use child nodes and `offset`)

**Testing Results:**
- ✅ Full-screen overlay works correctly
- ✅ Battlefield properly hidden during combat
- ✅ Animations smooth and readable
- ✅ All three variants (hit/critical/miss) functional
- ✅ Screen properly cleans up and returns to battlefield
- ✅ HP bars update correctly
- ✅ Placeholder graphics look intentional and polished

---

### HP2: Movement/Attack Range Highlights - ✅ COMPLETED & TESTED

**Implementation Date:** November 20-21, 2025

**Files Created:**
- `assets/tiles/highlight_blue.png` - Semi-transparent blue tile (32x32)
- `assets/tiles/highlight_red.png` - Semi-transparent red/coral tile (32x32)
- `assets/tiles/highlight_yellow.png` - Semi-transparent yellow tile (32x32)
- `assets/tilesets/highlight_tileset.tres` - TileSet with three color sources

**Files Modified:**
- `core/systems/grid_manager.gd` - Added highlight methods and constants
- `core/systems/input_manager.gd` - Integrated highlights with state machine
- `mods/_sandbox/scenes/test_unit.tscn` - Added HighlightLayer with z_index=1
- `mods/_sandbox/scenes/test_unit.gd` - Removed old ColorRect-based highlight system

**Key Implementation Details:**

1. **Three-Color Highlight System**
   - Blue (source_id=0): Movement range
   - Red/Coral (source_id=1): Attack range
   - Yellow/Orange (source_id=2): Valid targets
   - Semi-transparent (50% opacity) to show terrain underneath

2. **GridManager Methods Added**
   ```gdscript
   const HIGHLIGHT_BLUE: int = 0
   const HIGHLIGHT_RED: int = 1
   const HIGHLIGHT_YELLOW: int = 2

   func show_movement_range(from: Vector2i, movement_range: int, movement_type: int)
   func show_attack_range(from: Vector2i, weapon_range: int)
   func highlight_targets(target_cells: Array[Vector2i])
   func clear_highlights()
   ```

3. **InputManager Integration**
   - `_on_enter_exploring_movement()`: Shows blue movement range
   - `_on_enter_selecting_action()`: Clears highlights (action menu open)
   - `_on_enter_targeting()`: Shows red attack range + yellow targets
   - `_get_valid_target_cells()`: Filters enemy units in weapon range

**Bug Found & Fixed:**
- **Issue:** Red and yellow highlights were being set in the TileMapLayer but not visible
- **Root Cause:** HighlightLayer had no z_index set, defaulting to 0, causing rendering order issues
- **Solution:** Added `z_index = 1` to HighlightLayer in test_unit.tscn
- **Debug Process:** Added comprehensive debug logging to trace execution flow and confirm cells were being set correctly

**Testing Results:**
- ✅ Blue movement highlights display correctly at turn start
- ✅ Red attack range highlights display when "Attack" is selected
- ✅ Yellow target highlights overlay red tiles on valid enemy positions
- ✅ Highlights clear properly when returning to action menu or ending turn
- ✅ Highlights respect grid bounds and don't appear on invalid cells
- ✅ System works with melee range (1 cell Manhattan distance)

**How to Test:**
1. Run scene: `mods/_sandbox/scenes/test_unit.tscn`
2. Movement: Blue highlights show walkable range automatically
3. Move next to enemy and select "Attack"
4. Observe: Red tiles show attack range, yellow tile highlights the enemy

---

### HP3: Active Unit Stats Display - ✅ COMPLETED & TESTED

**Implementation Date:** November 21, 2025

**Files Created:**
- `scenes/ui/active_unit_stats_panel.tscn` - Stats display panel UI
- `scenes/ui/active_unit_stats_panel.gd` - Stats panel script
- `scenes/ui/terrain_info_panel.tscn` - Terrain info panel UI
- `scenes/ui/terrain_info_panel.gd` - Terrain panel script

**Files Modified:**
- `mods/_sandbox/scenes/test_unit.tscn` - Added both panels to HUD
- `mods/_sandbox/scenes/test_unit.gd` - Connected panels to turn signals

**Key Implementation Details:**

1. **ActiveUnitStatsPanel (Top-Right)**
   - Shows unit name (bold, 20pt)
   - HP bar with value (red gradient, "25/30" format)
   - MP bar with value (blue gradient, "10/15" format)
   - Combat stats grid (STR, DEF, AGI, INT, LUK)
   - Semi-transparent dark background with border
   - Fade in/out animations (0.2s duration)

2. **TerrainInfoPanel (Top-Left)**
   - Shows terrain name ("Plains", "Forest", etc.)
   - Shows terrain effects ("No effect", "DEF +1", etc.)
   - Matching visual style to stats panel
   - Fade in/out animations (0.2s duration)

3. **Signal Integration**
   - Connected to `TurnManager.player_turn_started` signal
   - Connected to `TurnManager.enemy_turn_started` signal
   - Connected to `TurnManager.unit_turn_ended` signal
   - Panels show for both player and enemy turns
   - Automatically hide when turn ends

**Bug Fixed:**
- **Issue:** Panels sometimes didn't appear on player turns (stale tween state)
- **Root Cause:** Multiple tweens running simultaneously without cleanup
- **Solution:** Added `_current_tween` tracking and kill existing tweens before starting new ones
- **Result:** Panels now reliably appear on every turn

**Testing Results:**
- ✅ Stats panel appears at top-right when turn starts
- ✅ All stats display correct values (name, HP, MP, STR, DEF, AGI, INT, LUK)
- ✅ HP bar shows red gradient with correct fill proportion
- ✅ MP bar shows blue gradient with correct fill proportion
- ✅ Terrain panel appears at top-left
- ✅ Terrain shows "Plains" with "No effect" (default terrain)
- ✅ Panels fade in smoothly (0.2s animation)
- ✅ Panels fade out smoothly when turn ends
- ✅ Panels work correctly for both Hero and Goblin
- ✅ No tween conflicts across multiple turns
- ✅ Stats update correctly when unit takes damage

**How to Test:**
1. Run scene: `mods/_sandbox/scenes/test_unit.tscn`
2. Observe top-right: Hero's stats panel appears with full information
3. Observe top-left: "Plains / No effect" terrain panel appears
4. Complete turn: Panels fade out
5. Next turn: Panels reappear with updated stats (if damage was taken)
