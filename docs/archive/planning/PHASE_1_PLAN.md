# The Sparkling Farce Platform - Phase 1 Plan
## "Foundation & Editor Infrastructure"

---

## Architecture Overview

This is essentially a **game creation tool** that happens to produce tactical RPG content. Think of it as your own custom RPG Maker for Shining Force-style games.

### Core Philosophy
1. **Data-Driven Everything**: All game content (characters, items, battles, maps) stored as Resources
2. **Editor-First**: Build in-engine tools before runtime systems
3. **Template-Based**: Provide templates that users duplicate and customize
4. **No Code Required**: Users should create content through UI, not GDScript

---

## Phase 1: Foundation Layer

### 1. Project Structure
```
sparklingfarce/
├── addons/
│   └── sparkling_editor/          # Main editor plugin
│       ├── plugin.cfg
│       ├── editor_plugin.gd
│       └── ui/                     # Editor UI components
│           ├── character_editor.gd
│           ├── item_editor.gd
│           ├── battle_editor.gd
│           └── class_editor.gd
├── core/
│   ├── resources/                  # Base Resource definitions
│   │   ├── character_data.gd
│   │   ├── class_data.gd
│   │   ├── item_data.gd
│   │   ├── ability_data.gd
│   │   ├── battle_data.gd
│   │   └── dialogue_data.gd
│   ├── systems/                    # Runtime systems (Phase 2+)
│   └── components/                 # Reusable components (Phase 2+)
├── assets/
│   ├── sprites/                    # Character and unit sprites
│   ├── portraits/                  # Character portraits
│   ├── icons/                      # Item/ability icons
│   ├── tilesets/                   # Map tiles
│   ├── ui/                         # UI elements
│   ├── music/                      # Background music tracks
│   └── sfx/                        # Sound effects
├── data/                           # User-created content
│   ├── characters/
│   ├── classes/
│   ├── items/
│   ├── abilities/
│   ├── battles/
│   └── dialogues/
├── templates/                      # Templates for users to duplicate
│   ├── character_template.tres
│   ├── class_template.tres
│   ├── item_template.tres
│   └── battle_template.tres
├── user_content/                   # User plugins/mods
│   └── README.md                   # Instructions for adding custom content
└── project.godot
```

### 2. Resource Layer (Data Model)

Each Resource type represents a game entity with strict typing:

**CharacterData** (Resource)
- `character_name: String`
- `character_class: ClassData`
- `base_stats: Dictionary` (HP, STR, DEF, AGI, etc.)
- `growth_rates: Dictionary` (stat growth per level)
- `portrait: Texture2D`
- `battle_sprite: Texture2D`
- `starting_level: int`
- `starting_equipment: Array[ItemData]`

**ClassData** (Resource)
- `class_name: String`
- `movement_type: String` (walking, flying, floating)
- `movement_range: int`
- `equippable_weapon_types: Array[String]`
- `learnable_abilities: Array[AbilityData]`
- `promotion_class: ClassData` (optional)

**ItemData** (Resource)
- `item_name: String`
- `item_type: String` (weapon, armor, consumable)
- `stats_modifier: Dictionary`
- `usable_in_battle: bool`
- `effect: AbilityData` (if usable)
- `icon: Texture2D`

**AbilityData** (Resource)
- `ability_name: String`
- `ability_type: String` (attack, heal, support)
- `range: int`
- `area_of_effect: int`
- `mp_cost: int`
- `power: int`
- `effects: Array[String]` (poison, buff, etc.)

**BattleData** (Resource)
- `battle_name: String`
- `map_scene: PackedScene`
- `grid_width: int`
- `grid_height: int`
- `player_units: Array[CharacterData]`
- `player_positions: Array[Vector2i]`
- `enemy_units: Array[CharacterData]`
- `enemy_positions: Array[Vector2i]`
- `victory_conditions: Dictionary`
- `defeat_conditions: Dictionary`
- `background_music: AudioStream`

**DialogueData** (Resource)
- `dialogue_id: String`
- `speakers: Array[String]`
- `lines: Array[Dictionary]` (speaker, text, portrait)
- `choices: Array[Dictionary]` (optional branching)

### 3. Editor Plugin System

**Main Editor Plugin** (`addons/sparkling_editor/editor_plugin.gd`)
- Adds custom dock panels to Godot editor
- Registers custom Resource types
- Provides menu items: "Create Character", "Create Battle", etc.
- Handles asset validation

**Editor UI Components**:

1. **Character Editor**
   - Form-based UI for all CharacterData fields
   - Drag-and-drop for sprites/portraits
   - Class dropdown (populated from available ClassData)
   - Stats editor with sliders/spinboxes
   - Preview pane showing character appearance

2. **Class Editor**
   - Define class properties
   - Movement type selector
   - Weapon type multi-select
   - Ability learning progression (level → ability)

3. **Item Editor**
   - Item type selector
   - Stats modifier grid
   - Icon picker
   - Effect configuration

4. **Battle Editor**
   - Grid size configurator
   - Unit placement tool (drag characters onto grid)
   - Victory/defeat condition builder
   - Pre-battle dialogue assignment
   - Background music selector

5. **Dialogue Editor**
   - Speaker list
   - Line-by-line editor
   - Portrait preview
   - Branching logic (for later phases)

### 4. Template System

Provide pre-configured templates in `templates/` folder:
- Empty but properly structured Resources
- Example Resources with sample data
- Users duplicate and modify these

### 5. Extensibility Interface

**Plugin Folder** (`user_content/`)
- README with instructions on structure
- Example plugin with custom character/class
- Users can drop in their own Resources here
- Editor scans this folder and integrates content

**Signal System** (for Phase 2+)
- Define core signals that modders can connect to
- Example: `battle_started`, `unit_moved`, `damage_dealt`
- Allows custom scripts to hook into game events

---

## Phase 1 Deliverables

### What We'll Build:
1. Complete folder structure
2. All base Resource classes with strict typing and documentation
3. Editor plugin with basic UI for creating/editing:
   - Characters
   - Classes
   - Items
4. Template Resources for each type
5. Project settings configured for strict typing
6. Basic validation (ensure required fields are filled)

### What We'll Defer to Phase 2:
- Battle editor (more complex, needs grid visualization)
- Dialogue editor (can start with JSON/text for now)
- Runtime systems (grid manager, turn manager, etc.)
- Actual battle gameplay

### Success Criteria:

**Manual Tests:**
- Open Godot editor
- See "Sparkling Editor" dock panel
- Click "Create New Character"
- Fill in character details using the UI
- Save as Resource in `data/characters/`
- Repeat for Classes and Items
- Verify saved Resources can be reopened and edited

**Headless Tests:**
- Validate all Resources can be instantiated
- Validate strict typing is enforced
- Validate required fields throw errors when missing
- Validate Resource serialization/deserialization
