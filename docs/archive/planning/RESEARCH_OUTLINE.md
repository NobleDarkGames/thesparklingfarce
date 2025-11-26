# Research Outline: The Sparkling Farce Platform

## 1. Godot 4.5 Best Practices & Architecture

### Key Principles
- Modular design with the assumption that components can be replaced and improved
- Use GDScript addons and @tool scripts for editor extensions
- Leverage GDExtension for performance-critical or closed-source components
- Follow isolation principles to reduce merge conflicts
- Use layered architecture: start simple with GDScript, escalate to native extensions only when needed

### For Tactical RPGs
- Separate data from logic using Resources for character stats, abilities, items
- Structure code around core systems: Grid, Units, Input, Pathfinding, Visual Feedback
- Use signal-driven architecture for decoupling systems
- Implement component-based patterns for extensibility

## 2. Tactical RPG Systems

### Grid-Based Movement
- Flood fill algorithm for calculating valid movement ranges
- Cursor navigation with keyboard/mouse input
- Unit selection and pathfinding integration
- Visual feedback for movement ranges and paths
- Terrain effects on movement costs

### Combat Mechanics
- Phase-based turn system (Player Phase → Enemy Phase) like Fire Emblem
- OR character-by-character turns based on agility/speed like Shining Force
- Attack ranges based on weapon types
- Positioning effects (flanking, elevation bonuses)
- Weapon triangle or similar rock-paper-scissors systems

## 3. GDScript Strict Typing Best Practices

### Core Requirements
- Always use explicit type annotations for function parameters and return types
- Type all class properties/member variables
- Use `class_name` for custom nodes to enable autocomplete
- Enable "Add Type Hints" in editor settings
- Set untyped variable warnings to ERROR in project settings

### Syntax
- Use `:` for type hints: `var health: int = 100`
- Function syntax: `func attack(target: Unit) -> int:`
- Avoid walrus operator (`:=`) as per project requirements
- Dictionary checks: Use `if 'key' in dict` NOT `if dict.has('key')`

### Performance
- Static typing provides up to ~47% performance improvement
- Critical for performance-sensitive systems (pathfinding, combat calculations)
- Enables better compile-time optimization

## 4. Extensible/Modular Architecture

### Component-Based Design
- Use composition over inheritance
- Create attachable components for entities
- Separate behaviors (systems) from data (components)
- Enable easy addition/removal of features without modifying core

### Plugin System Approach
- Design systems as independent modules
- Use clear interfaces/APIs between systems
- Signal-based communication for loose coupling
- Resource-based data for easy modding (JSON, custom Resource files)

### For The Sparkling Farce Platform
- Character definitions → Custom Resources
- Battle mechanics → Modular systems with clear interfaces
- Items/Equipment → Data-driven Resource files
- Abilities/Skills → Component-based with stackable effects

## 5. Shining Force Specifics

### Key Mechanics to Support
- Large-scale battles with many units
- Experience from both combat AND movement
- Character revival/forgiving difficulty
- Elevation-based combat bonuses
- Multiple character classes with different movement types (walking, flying)

## Recommended Architecture for The Sparkling Farce

### Core Systems (scripts in `res://systems/`)
- GridManager: Handle grid logic, pathfinding, flood fill
- TurnManager: Manage turn order, phase transitions
- BattleManager: Orchestrate combat interactions
- InputManager: Handle player input and cursor

### Data Layer (Resources in `res://data/`)
- CharacterData (Resource): Stats, movement, class
- ItemData (Resource): Equipment, consumables
- AbilityData (Resource): Skills, spells
- BattleData (Resource): Map layouts, enemy formations

### Components (scenes/scripts in `res://components/`)
- Unit (Node2D): Base character with attachable components
- MovementComponent: Handle unit movement
- CombatComponent: Handle attack/defense calculations
- InventoryComponent: Manage items/equipment

### Extensibility
- Plugin folder structure for user-added content
- Clear API documentation for modders
- Resource templates for creating new content
- Signal system for hooking into game events
