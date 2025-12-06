# Campaign Progression System Design

**Status:** ✅ COMPLETE (Core + Polish)
**Priority:** High
**Dependencies:** Phase 2.5 complete, SceneManager, TriggerManager, GameState, SaveManager
**Target:** Before Phase 3
**Estimated Effort:** 24-32 hours (Core: ~20 hours completed)
**Author:** Lt. Claudbrain
**Date:** November 28, 2025
**Revision:** 3.1 (Chapter UI Complete - December 5, 2025)

---

## Executive Summary

The Sparkling Farce currently has no central system to manage story progression. The game hardcodes "Battle of Noobs" to launch after the main menu. This document proposes a **CampaignManager** system that tracks player progress through a data-driven storyline, enabling modders to define custom campaigns with linear, branching, or hub-based structures.

**Key Design Principles (YAGNI-Compliant):**
- Only 2 Resource types: CampaignData and CampaignNode
- String-based types with registry pattern for extensibility
- Simplified transitions: on_victory, on_defeat, on_complete + branches array
- Shining Force authentic mechanics (XP persist, gold penalty, battle replay)

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Shining Force Research Summary](#shining-force-research-summary)
3. [System Overview](#system-overview)
4. [Data Structures](#data-structures)
5. [Registry Pattern](#registry-pattern)
6. [Flow Examples](#flow-examples)
7. [Scene Lifecycle](#scene-lifecycle)
8. [Mod Integration](#mod-integration)
9. [Implementation Plan](#implementation-plan)
10. [Integration Points](#integration-points)
11. [Testing Strategy](#testing-strategy)
12. [Risk Assessment](#risk-assessment)

---

## Problem Statement

### Current State

The current game flow is hardcoded in `/home/user/dev/sparklingfarce/mods/_base_game/scenes/ui/save_slot_selector.gd`:

```gdscript
func _new_game(slot_num: int) -> void:
    # ... create save ...
    # Go to first battle (Battle of Noobs from sandbox mod)
    TriggerManager.start_battle("battle_1763763677")  # HARDCODED!
```

This approach has critical limitations:

1. **No progression tracking** - The game does not know what comes after the first battle
2. **No chapter management** - No way to organize battles into narrative chapters
3. **No victory consequences** - After winning a battle, there is no system to determine the next scene
4. **No hub/town support** - No way to return to a headquarters between battles
5. **No branching support** - No way to create non-linear storylines
6. **Not mod-friendly** - Modders cannot define their own campaign structures

### Desired State

A data-driven campaign system where:

1. Campaign structure is defined in resources, not code
2. Modders can create entirely new campaigns
3. The system supports linear, branching, and hub-based progressions
4. Victory/defeat outcomes trigger appropriate next steps
5. The system integrates seamlessly with existing GameState and SaveManager

---

## Shining Force Research Summary

### Campaign Flow Analysis (Commander Claudius Consultation)

Based on research of Shining Force 1 and 2, here are the key campaign mechanics:

#### Shining Force 1: Linear Chapter Structure

**Chapter System:**
- 8 chapters, each with a title and narrative arc
- Chapters contain 3-5 battles on average
- Chapter transitions include summary and save prompt
- Example: Chapter 2 "Spirit of the Holy Spring" contains Battles 5-8

**Town-Battle-Town Loop:**
```
Town (shops, dialogue, headquarters)
  |
  v
Exit town via single exit
  |
  v
Battle (on cleared battlefield)
  |
  v
Victory -> Continue through cleared area
  |
  v
Next town or next battle
```

**Key Observations:**
- No overworld map - battles and towns are directly connected
- Leaving a town via its exit places you directly into the next battle
- After battle victory, you can traverse cleared battlefields freely
- Towns contain shops, headquarters, and story-advancing NPCs
- Headquarters is where you manage party composition

**No Game Over Design (Critical SF Mechanics):**
- XP gained persists even on defeat (retain_xp_on_defeat)
- Max (hero) death = lose 50% gold, retry battle (defeat_gold_penalty)
- Player army gets stronger even upon defeat
- Battles can be replayed for grinding (repeatable)
- Egress spell warps party back to HQ from exploration (allow_egress)

#### Shining Force 2: Free-Roaming Structure

**Differences from SF1:**
- No chapter system - continuous world
- World map with free movement between areas
- Can return to previously visited locations
- Longer game with more flexible exploration

**Key Observations:**
- More JRPG-like exploration mode
- Battles still trigger at specific story points
- Towns function similarly but with more revisit potential

### Fire Emblem Comparison

**Chapter-Based With Preparation:**
- Each chapter has a "preparation" phase before battle
- Pre-battle menu for equipping, organizing party
- Story cutscenes between chapters
- Route splits create branching campaigns

### Design Implications for Sparkling Farce

1. **Support both linear and free-roaming** - Use node-based structure that can represent either
2. **Headquarters as hub** - Central location for party management
3. **Battle-to-town transitions** - Clear connection between combat and exploration
4. **Save points at chapter boundaries** - Natural pause points
5. **XP persistence on defeat** - Shining Force style encouragement
6. **Battle replay support** - Allow grinding without breaking story

---

## System Overview

### CampaignManager Autoload

A new autoload singleton (`CampaignManager`) that:

1. Loads and tracks campaign data from mods
2. Knows the current position in the campaign
3. Provides methods to advance the campaign based on events
4. Uses registry pattern for extensible node/trigger processing
5. Integrates with GameState for flag-based branching
6. Integrates with SaveManager for persistence

### Core Concepts (Simplified)

```
Campaign (CampaignData Resource)
  |
  +-- chapters: Array[Dictionary]  (inline, optional grouping)
  |
  +-- nodes: Array[CampaignNode]
        |
        +-- node_type: String  (registered processor handles it)
        +-- on_victory: String  (target node ID)
        +-- on_defeat: String   (target node ID)
        +-- on_complete: String (target node ID)
        +-- branches: Array[Dictionary]  (for complex conditionals)
```

### Node Types (String-Based with Registry)

| Type String | Description | Example |
|-------------|-------------|---------|
| `"battle"` | Tactical battle scene | "Battle of Noobs", "Chapter 1 Boss" |
| `"scene"` | Town/dungeon/hub exploration | "Guardiana Town", "Headquarters" |
| `"cutscene"` | Story cinematic | "Opening Cinematic", "Victory Celebration" |
| `"choice"` | Branching decision point | "Choose your path" |
| `"custom:*"` | Mod-defined type | "custom:minigame", "custom:puzzle" |

**Note:** HUB and EXPLORATION are consolidated into a single "scene" type. The distinction is made via the `is_hub` boolean on the node for behavior like egress return points.

---

## Data Structures

### CampaignData Resource

```gdscript
# /home/user/dev/sparklingfarce/core/resources/campaign_data.gd
@tool
class_name CampaignData
extends Resource

## Unique identifier for this campaign (namespaced: "mod_id:campaign_id")
@export var campaign_id: String = ""

## Display name for campaign selection
@export var campaign_name: String = ""

## Description shown in campaign selector
@export_multiline var campaign_description: String = ""

## Version string for compatibility checking
@export var campaign_version: String = "1.0.0"

## Starting node ID (where new games begin)
@export var starting_node_id: String = ""

## All campaign nodes (battles, towns, cutscenes, etc.)
@export var nodes: Array[CampaignNode] = []

## Default hub node ID (where player returns after battles/egress if not specified)
@export var default_hub_id: String = ""

## Campaign-specific story flags to initialize on new game
@export var initial_flags: Dictionary = {}

## Optional chapter organization (inline as Dictionary array for simplicity)
## Each entry: {"id": String, "name": String, "description": String, "number": int, "node_ids": Array[String]}
@export var chapters: Array[Dictionary] = []

# ---- Node Lookup Cache for O(1) Access ----
var _node_cache: Dictionary = {}  # node_id -> CampaignNode
var _cache_built: bool = false


## Build the node lookup cache
func _build_cache() -> void:
    _node_cache.clear()
    for node: CampaignNode in nodes:
        if node.node_id in _node_cache:
            push_warning("CampaignData: Duplicate node_id '%s' - later definition wins" % node.node_id)
        _node_cache[node.node_id] = node
    _cache_built = true


## Validation
func validate() -> Array[String]:
    var errors: Array[String] = []

    if campaign_id.is_empty():
        errors.append("campaign_id is required")
    if campaign_name.is_empty():
        errors.append("campaign_name is required")
    if starting_node_id.is_empty():
        errors.append("starting_node_id is required")

    # Build cache if needed
    if not _cache_built:
        _build_cache()

    if not starting_node_id.is_empty() and starting_node_id not in _node_cache:
        errors.append("starting_node_id '%s' not found in nodes" % starting_node_id)

    if not default_hub_id.is_empty() and default_hub_id not in _node_cache:
        errors.append("default_hub_id '%s' not found in nodes" % default_hub_id)

    # Validate all nodes and check for circular transitions
    var visited_transitions: Dictionary = {}
    for node: CampaignNode in nodes:
        var node_errors: Array[String] = node.validate()
        for error: String in node_errors:
            errors.append("Node '%s': %s" % [node.node_id, error])

        # Check transition targets exist
        for target_id: String in _get_all_transition_targets(node):
            if not target_id.is_empty() and target_id not in _node_cache:
                errors.append("Node '%s': transition target '%s' not found" % [node.node_id, target_id])

    # Circular transition detection
    var circular_errors: Array[String] = _detect_circular_transitions()
    errors.append_array(circular_errors)

    return errors


## Get all transition target IDs from a node
func _get_all_transition_targets(node: CampaignNode) -> Array[String]:
    var targets: Array[String] = []
    if not node.on_victory.is_empty():
        targets.append(node.on_victory)
    if not node.on_defeat.is_empty():
        targets.append(node.on_defeat)
    if not node.on_complete.is_empty():
        targets.append(node.on_complete)
    for branch: Dictionary in node.branches:
        if "target" in branch and not branch["target"].is_empty():
            targets.append(branch["target"])
    return targets


## Detect circular immediate transitions (A->B->A without player action)
func _detect_circular_transitions() -> Array[String]:
    var errors: Array[String] = []
    # Only check for immediate loops (cutscene->cutscene chains that could infinite loop)
    for node: CampaignNode in nodes:
        if node.node_type == "cutscene":
            var visited: Array[String] = [node.node_id]
            var current_target: String = node.on_complete
            var depth: int = 0
            while not current_target.is_empty() and depth < 100:
                depth += 1
                if current_target in visited:
                    errors.append("Circular transition detected: %s" % " -> ".join(visited + [current_target]))
                    break
                visited.append(current_target)
                if current_target in _node_cache:
                    var target_node: CampaignNode = _node_cache[current_target]
                    if target_node.node_type == "cutscene":
                        current_target = target_node.on_complete
                    else:
                        break  # Non-cutscene nodes require player action
                else:
                    break
    return errors


func get_node(node_id: String) -> CampaignNode:
    if not _cache_built:
        _build_cache()
    if node_id in _node_cache:
        return _node_cache[node_id]
    return null


func has_node(node_id: String) -> bool:
    if not _cache_built:
        _build_cache()
    return node_id in _node_cache


## Get chapter data for a node
func get_chapter_for_node(node_id: String) -> Dictionary:
    for chapter: Dictionary in chapters:
        if "node_ids" in chapter:
            var node_ids: Array = chapter["node_ids"]
            if node_id in node_ids:
                return chapter
    return {}
```

### CampaignNode Resource

```gdscript
# /home/user/dev/sparklingfarce/core/resources/campaign_node.gd
@tool
class_name CampaignNode
extends Resource

## Unique identifier for this node (within campaign)
@export var node_id: String = ""

## Display name for save files and UI
@export var display_name: String = ""

## Type of this node (String for registry extensibility)
## Built-in types: "battle", "scene", "cutscene", "choice"
## Custom types: "custom:minigame", "custom:puzzle", etc.
@export var node_type: String = "scene"

## Resource reference based on type:
## - battle: BattleData resource ID
## - scene: Scene path
## - cutscene: CinematicData resource ID or inline commands
## - choice: Not used (choices defined in branches)
## - custom:*: Custom data as needed
@export var resource_id: String = ""

## Direct scene path (for scene type, alternative to resource_id)
@export var scene_path: String = ""

# ---- Simplified Transitions ----
## Target node on battle victory
@export var on_victory: String = ""

## Target node on battle defeat
@export var on_defeat: String = ""

## Target node on non-battle completion (cutscene ends, player exits scene)
@export var on_complete: String = ""

## Complex branching for choices and flag-based paths
## Each entry: {"trigger": String, "target": String, "priority": int,
##              "required_flags": Array, "forbidden_flags": Array, "choice_value": String}
## Trigger types (String): "choice", "flag", "always"
@export var branches: Array[Dictionary] = []

# ---- Shining Force Authentic Mechanics ----
## For battle nodes: XP gained persists even on defeat
@export var retain_xp_on_defeat: bool = true

## For battle nodes: Gold penalty on defeat (0.5 = lose 50% gold, SF default)
@export var defeat_gold_penalty: float = 0.5

## For battle nodes: Can this battle be replayed for grinding?
@export var repeatable: bool = false

## For battle nodes: Does replaying this battle advance the story?
@export var replay_advances_story: bool = false

## For scene nodes: Can player use Egress to warp back to hub?
@export var allow_egress: bool = true

## Is this node a hub (affects egress return point)?
@export var is_hub: bool = false

## Is this a chapter boundary? Triggers save prompt and chapter transition UI
@export var is_chapter_boundary: bool = false

# ---- Cinematics ----
## Pre-node cinematic (plays before node starts)
@export var pre_cinematic_id: String = ""

## Post-node cinematic (plays after node completes, before transition)
@export var post_cinematic_id: String = ""

# ---- Flags ----
## Flags to set when this node is entered
@export var on_enter_flags: Dictionary = {}

## Flags to set when this node is completed
@export var on_complete_flags: Dictionary = {}

## Required flags to access this node (gating)
@export var required_flags: Array[String] = []

## Forbidden flags that prevent access to this node
@export var forbidden_flags: Array[String] = []

# ---- Completion Triggers for Scene Nodes ----
## How scene nodes complete: "exit_trigger", "flag_set", "npc_interaction", "manual"
@export var completion_trigger: String = "exit_trigger"

## For flag_set completion: which flag triggers completion
@export var completion_flag: String = ""

## For npc_interaction completion: which NPC ID triggers completion
@export var completion_npc_id: String = ""


## Validation
func validate() -> Array[String]:
    var errors: Array[String] = []

    if node_id.is_empty():
        errors.append("node_id is required")
    if display_name.is_empty():
        errors.append("display_name is required")
    if node_type.is_empty():
        errors.append("node_type is required")

    # Type-specific validation
    if node_type == "battle":
        if resource_id.is_empty():
            errors.append("battle nodes require resource_id")
    elif node_type == "scene":
        if resource_id.is_empty() and scene_path.is_empty():
            errors.append("scene nodes require resource_id or scene_path")
    elif node_type == "cutscene":
        if resource_id.is_empty():
            errors.append("cutscene nodes require resource_id")

    # Validate defeat_gold_penalty range
    if defeat_gold_penalty < 0.0 or defeat_gold_penalty > 1.0:
        errors.append("defeat_gold_penalty must be between 0.0 and 1.0")

    # Validate branches structure
    for i: int in range(branches.size()):
        var branch: Dictionary = branches[i]
        if "target" not in branch:
            errors.append("branch[%d] missing 'target'" % i)
        if "trigger" not in branch:
            errors.append("branch[%d] missing 'trigger'" % i)

    return errors


## Get the appropriate transition target based on outcome
func get_transition_target(outcome: Dictionary, game_state_checker: Callable) -> String:
    # Check simple transitions first based on outcome type
    if "victory" in outcome:
        if outcome["victory"] and not on_victory.is_empty():
            return on_victory
        elif not outcome["victory"] and not on_defeat.is_empty():
            return on_defeat

    # For non-battle nodes or when simple transitions not defined
    if "choice" in outcome or not branches.is_empty():
        # Sort branches by priority (higher first)
        var sorted_branches: Array[Dictionary] = branches.duplicate()
        sorted_branches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            var a_priority: int = a.get("priority", 0)
            var b_priority: int = b.get("priority", 0)
            return a_priority > b_priority
        )

        for branch: Dictionary in sorted_branches:
            if _branch_matches(branch, outcome, game_state_checker):
                return branch.get("target", "")

    # Fallback to on_complete
    return on_complete


## Check if a branch matches the given outcome and game state
func _branch_matches(branch: Dictionary, outcome: Dictionary, game_state_checker: Callable) -> bool:
    var trigger: String = branch.get("trigger", "always")

    match trigger:
        "choice":
            var choice_value: String = branch.get("choice_value", "")
            if outcome.get("choice", "") != choice_value:
                return false
        "flag":
            var required_flag: String = branch.get("required_flag", "")
            if not required_flag.is_empty() and not game_state_checker.call(required_flag):
                return false
        "always":
            pass  # Always matches
        _:
            push_warning("CampaignNode: Unknown trigger type '%s'" % trigger)
            return false

    # Check additional required flags
    var required_flags_list: Array = branch.get("required_flags", [])
    for flag: String in required_flags_list:
        if not game_state_checker.call(flag):
            return false

    # Check forbidden flags
    var forbidden_flags_list: Array = branch.get("forbidden_flags", [])
    for flag: String in forbidden_flags_list:
        if game_state_checker.call(flag):
            return false

    return true
```

### CampaignManager Autoload

```gdscript
# /home/user/dev/sparklingfarce/core/systems/campaign_manager.gd
extends Node

## CampaignManager - Tracks and manages player progress through storylines
##
## Responsibilities:
## - Load campaign data from mods
## - Track current campaign and node position
## - Handle node transitions based on outcomes
## - Use registry pattern for extensible node/transition processing
## - Integrate with GameState for flags and SaveManager for persistence
## - Provide methods for UI to query available campaigns

## Signals
signal campaign_started(campaign: CampaignData)
signal campaign_ended(campaign: CampaignData, completed: bool)
signal node_entered(node: CampaignNode)
signal node_completed(node: CampaignNode, outcome: Dictionary)
signal transition_started(from_node: CampaignNode, to_node: CampaignNode)
signal chapter_started(chapter: Dictionary)
signal egress_requested()

## Currently active campaign
var current_campaign: CampaignData = null

## Current campaign node
var current_node: CampaignNode = null

## History of visited nodes (for back-tracking if needed)
var node_history: Array[String] = []

## Last hub visited (for egress return)
var last_hub_id: String = ""

## Registered campaigns (from all mods)
var _campaigns: Dictionary = {}  # campaign_id -> CampaignData

# ---- Registry Pattern: Node Processors ----
## Registered node type processors: node_type -> Callable
## Callable signature: func(node: CampaignNode) -> void
var _node_processors: Dictionary = {}

# ---- Registry Pattern: Transition Trigger Evaluators ----
## Registered trigger evaluators: trigger_type -> Callable
## Callable signature: func(branch: Dictionary, outcome: Dictionary) -> bool
var _trigger_evaluators: Dictionary = {}

# ---- Registry Pattern: Custom Node Handlers ----
## For "custom:*" node types, modders register handlers here
## custom_type (without "custom:" prefix) -> Callable
var _custom_handlers: Dictionary = {}


func _ready() -> void:
    print("CampaignManager: Initializing...")
    _register_built_in_processors()
    _register_built_in_evaluators()

    # Wait for ModLoader to finish
    if ModLoader._is_loading:
        await ModLoader.mods_loaded
    _discover_campaigns()
    print("CampaignManager: Found %d campaigns" % _campaigns.size())


## Register built-in node type processors
func _register_built_in_processors() -> void:
    register_node_processor("battle", _process_battle_node)
    register_node_processor("scene", _process_scene_node)
    register_node_processor("cutscene", _process_cutscene_node)
    register_node_processor("choice", _process_choice_node)


## Register built-in trigger evaluators
func _register_built_in_evaluators() -> void:
    register_trigger_evaluator("choice", _evaluate_choice_trigger)
    register_trigger_evaluator("flag", _evaluate_flag_trigger)
    register_trigger_evaluator("always", _evaluate_always_trigger)


# ---- Registry API ----

## Register a processor for a node type
## Callable signature: func(node: CampaignNode) -> void
func register_node_processor(node_type: String, processor: Callable) -> void:
    _node_processors[node_type] = processor
    print("CampaignManager: Registered processor for node type '%s'" % node_type)


## Register an evaluator for a transition trigger type
## Callable signature: func(branch: Dictionary, outcome: Dictionary) -> bool
func register_trigger_evaluator(trigger_type: String, evaluator: Callable) -> void:
    _trigger_evaluators[trigger_type] = evaluator
    print("CampaignManager: Registered evaluator for trigger '%s'" % trigger_type)


## Register a handler for custom node types (modders use this)
## Handler signature: func(node: CampaignNode, manager: CampaignManager) -> void
func register_custom_handler(custom_type: String, handler: Callable) -> void:
    _custom_handlers[custom_type] = handler
    print("CampaignManager: Registered custom handler for 'custom:%s'" % custom_type)


## Discover all campaigns from loaded mods
func _discover_campaigns() -> void:
    var campaigns: Array[Resource] = ModLoader.registry.get_all_resources("campaign")
    for campaign_resource: Resource in campaigns:
        var campaign: CampaignData = campaign_resource as CampaignData
        if campaign:
            var errors: Array[String] = campaign.validate()
            if errors.is_empty():
                if campaign.campaign_id in _campaigns:
                    push_warning("CampaignManager: Campaign ID '%s' collision - overwriting previous definition" % campaign.campaign_id)
                _campaigns[campaign.campaign_id] = campaign
                print("CampaignManager: Registered campaign '%s'" % campaign.campaign_name)
            else:
                push_error("CampaignManager: Campaign '%s' validation failed:" % campaign.campaign_id)
                for error: String in errors:
                    push_error("  - %s" % error)


## Get all available campaigns (respecting hidden_campaigns from mods)
func get_available_campaigns() -> Array[CampaignData]:
    var result: Array[CampaignData] = []
    var hidden_patterns: Array[String] = _get_hidden_campaign_patterns()

    for campaign_id: String in _campaigns:
        var campaign: CampaignData = _campaigns[campaign_id]
        if not _is_campaign_hidden(campaign_id, hidden_patterns):
            result.append(campaign)
    return result


## Get hidden campaign patterns from all mods
func _get_hidden_campaign_patterns() -> Array[String]:
    var patterns: Array[String] = []
    # Mods can declare hidden_campaigns in mod.json
    # This would be loaded via ModLoader and stored somewhere accessible
    # For now, this is a placeholder for the mechanism
    return patterns


## Check if a campaign matches any hidden pattern
func _is_campaign_hidden(campaign_id: String, patterns: Array[String]) -> bool:
    for pattern: String in patterns:
        if pattern.ends_with("*"):
            var prefix: String = pattern.substr(0, pattern.length() - 1)
            if campaign_id.begins_with(prefix):
                return true
        elif pattern == campaign_id:
            return true
    return false


## Get a specific campaign by ID
func get_campaign(campaign_id: String) -> CampaignData:
    if campaign_id in _campaigns:
        return _campaigns[campaign_id]
    return null


## Start a new campaign
func start_campaign(campaign_id: String) -> bool:
    var campaign: CampaignData = get_campaign(campaign_id)
    if not campaign:
        push_error("CampaignManager: Campaign '%s' not found" % campaign_id)
        return false

    current_campaign = campaign
    node_history.clear()
    last_hub_id = campaign.default_hub_id

    # Initialize campaign flags
    for flag_name: String in campaign.initial_flags:
        GameState.set_flag(flag_name, campaign.initial_flags[flag_name])

    # Set current campaign in GameState for saves
    GameState.set_campaign_data("current_campaign_id", campaign_id)
    GameState.set_campaign_data("current_node_id", "")

    campaign_started.emit(campaign)
    print("CampaignManager: Started campaign '%s'" % campaign.campaign_name)

    # Enter starting node
    return enter_node(campaign.starting_node_id)


## Resume a campaign from save data
func resume_campaign(campaign_id: String, node_id: String) -> bool:
    var campaign: CampaignData = get_campaign(campaign_id)
    if not campaign:
        push_error("CampaignManager: Campaign '%s' not found" % campaign_id)
        return false

    current_campaign = campaign

    # Enter the saved node
    return enter_node(node_id)


## Enter a campaign node
func enter_node(node_id: String) -> bool:
    if not current_campaign:
        push_error("CampaignManager: No active campaign")
        return false

    var node: CampaignNode = current_campaign.get_node(node_id)
    if not node:
        push_error("CampaignManager: Node '%s' not found in campaign" % node_id)
        _handle_missing_node_error(node_id)
        return false

    # Check access requirements
    if not _can_access_node(node):
        push_error("CampaignManager: Cannot access node '%s' - requirements not met" % node_id)
        return false

    # Track history
    if current_node:
        node_history.append(current_node.node_id)

    current_node = node

    # Update last hub if this is a hub
    if node.is_hub:
        last_hub_id = node.node_id

    # Update GameState
    GameState.set_campaign_data("current_node_id", node_id)

    # Set on_enter flags
    for flag_name: String in node.on_enter_flags:
        GameState.set_flag(flag_name, node.on_enter_flags[flag_name])

    # Check for chapter change
    _check_chapter_transition(node)

    node_entered.emit(node)
    print("CampaignManager: Entered node '%s' (%s)" % [node.display_name, node.node_type])

    # Play pre-cinematic if present
    if not node.pre_cinematic_id.is_empty():
        await _play_cinematic(node.pre_cinematic_id)

    # Handle chapter boundary save prompt
    if node.is_chapter_boundary:
        await _show_chapter_boundary_save_prompt()

    # Process node based on type
    _process_node(node)

    return true


## Handle error when a node cannot be found (error recovery)
func _handle_missing_node_error(node_id: String) -> void:
    push_error("CampaignManager: Attempting recovery from missing node '%s'" % node_id)
    # Try to return to last hub or default hub
    var recovery_target: String = last_hub_id if not last_hub_id.is_empty() else current_campaign.default_hub_id
    if not recovery_target.is_empty() and current_campaign.has_node(recovery_target):
        push_warning("CampaignManager: Recovering to hub '%s'" % recovery_target)
        enter_node(recovery_target)
    else:
        push_error("CampaignManager: No valid recovery target found - campaign may be in invalid state")


## Check if a node can be accessed
func _can_access_node(node: CampaignNode) -> bool:
    # Check required flags
    for flag: String in node.required_flags:
        if not GameState.has_flag(flag):
            return false

    # Check forbidden flags
    for flag: String in node.forbidden_flags:
        if GameState.has_flag(flag):
            return false

    return true


## Process a node based on its type using registry
func _process_node(node: CampaignNode) -> void:
    var node_type: String = node.node_type

    # Handle custom:* types
    if node_type.begins_with("custom:"):
        var custom_type: String = node_type.substr(7)  # Remove "custom:" prefix
        if custom_type in _custom_handlers:
            _custom_handlers[custom_type].call(node, self)
        else:
            push_error("CampaignManager: No handler registered for '%s'" % node_type)
            push_error("CampaignManager: Register with CampaignManager.register_custom_handler('%s', your_callable)" % custom_type)
        return

    # Handle built-in types via registry
    if node_type in _node_processors:
        _node_processors[node_type].call(node)
    else:
        push_error("CampaignManager: No processor registered for node type '%s'" % node_type)
        push_error("CampaignManager: Register with CampaignManager.register_node_processor('%s', your_callable)" % node_type)


## Process a battle node
func _process_battle_node(node: CampaignNode) -> void:
    # Look up battle data from registry
    var battle_data: Resource = ModLoader.registry.get_resource("battle", node.resource_id)
    if not battle_data:
        push_error("CampaignManager: Battle '%s' not found" % node.resource_id)
        _handle_missing_node_error(node.node_id)
        return

    # Store campaign context in GameState for battle return
    GameState.set_campaign_data("battle_node_id", node.node_id)
    GameState.set_campaign_data("retain_xp_on_defeat", node.retain_xp_on_defeat)
    GameState.set_campaign_data("defeat_gold_penalty", node.defeat_gold_penalty)
    GameState.set_campaign_data("battle_repeatable", node.repeatable)
    GameState.set_campaign_data("replay_advances_story", node.replay_advances_story)

    # Start battle via TriggerManager
    TriggerManager.start_battle_with_data(battle_data)


## Process a scene node (town, hub, exploration, dungeon)
func _process_scene_node(node: CampaignNode) -> void:
    var target_scene_path: String = node.scene_path
    if target_scene_path.is_empty() and not node.resource_id.is_empty():
        # Look up scene from registry
        target_scene_path = ModLoader.registry.get_scene_path(node.resource_id)

    if target_scene_path.is_empty():
        push_error("CampaignManager: No scene for node '%s'" % node.node_id)
        _handle_missing_node_error(node.node_id)
        return

    SceneManager.change_scene(target_scene_path)


## Process a cutscene node
func _process_cutscene_node(node: CampaignNode) -> void:
    if not _has_cinematics_manager():
        push_warning("CampaignManager: CinematicsManager not available, skipping cutscene")
        complete_current_node({})
        return

    await _play_cinematic(node.resource_id)
    # Auto-complete after cutscene
    complete_current_node({})


## Process a choice node
func _process_choice_node(node: CampaignNode) -> void:
    # Emit signal for UI to show choice dialog
    # The UI should call on_choice_made() when player selects
    push_warning("CampaignManager: Choice nodes emit signals for UI handling")
    # TODO: Emit signal with choice options extracted from branches


## Check if CinematicsManager is available
func _has_cinematics_manager() -> bool:
    return Engine.has_singleton("CinematicsManager") or has_node("/root/CinematicsManager")


## Complete the current node with an outcome
func complete_current_node(outcome: Dictionary) -> void:
    if not current_node:
        push_error("CampaignManager: No current node to complete")
        return

    # Set on_complete flags
    for flag_name: String in current_node.on_complete_flags:
        GameState.set_flag(flag_name, current_node.on_complete_flags[flag_name])

    # Play post-cinematic if present
    if not current_node.post_cinematic_id.is_empty():
        await _play_cinematic(current_node.post_cinematic_id)

    node_completed.emit(current_node, outcome)
    print("CampaignManager: Completed node '%s'" % current_node.display_name)

    # Find and execute transition
    _execute_transition(outcome)


## Handle battle completion (called by BattleManager)
func on_battle_completed(victory: bool) -> void:
    if not current_node or current_node.node_type != "battle":
        push_warning("CampaignManager: Battle completed but not in battle node")
        return

    # Handle defeat mechanics
    if not victory:
        # Apply gold penalty if configured
        var gold_penalty: float = current_node.defeat_gold_penalty
        if gold_penalty > 0.0:
            var current_gold: int = GameState.get_gold()
            var penalty_amount: int = int(current_gold * gold_penalty)
            GameState.set_gold(current_gold - penalty_amount)
            print("CampaignManager: Applied defeat gold penalty: -%d gold" % penalty_amount)

        # XP is retained by default (retain_xp_on_defeat)
        # The BattleManager should check this flag before resetting XP

    complete_current_node({"victory": victory})


## Handle player choice (called by choice UI)
func on_choice_made(choice_value: String) -> void:
    if not current_node or current_node.node_type != "choice":
        push_warning("CampaignManager: Choice made but not in choice node")
        return

    complete_current_node({"choice": choice_value})


## Handle egress (warp back to hub)
func request_egress() -> bool:
    if not current_node:
        return false

    if not current_node.allow_egress:
        push_warning("CampaignManager: Egress not allowed from current node")
        return false

    var egress_target: String = last_hub_id if not last_hub_id.is_empty() else current_campaign.default_hub_id
    if egress_target.is_empty():
        push_warning("CampaignManager: No hub available for egress")
        return false

    egress_requested.emit()
    enter_node(egress_target)
    return true


## Find and execute the appropriate transition
func _execute_transition(outcome: Dictionary) -> void:
    if not current_node:
        return

    # Use the node's transition logic with our flag checker
    var target_id: String = current_node.get_transition_target(outcome, GameState.has_flag)

    if target_id.is_empty():
        # No transition found - stay at current node or go to default hub
        if current_campaign.default_hub_id and current_node.node_type == "battle":
            print("CampaignManager: No transition found, returning to default hub")
            enter_node(current_campaign.default_hub_id)
        else:
            push_warning("CampaignManager: No valid transition from node '%s'" % current_node.node_id)
        return

    var to_node: CampaignNode = current_campaign.get_node(target_id)
    if not to_node:
        push_error("CampaignManager: Transition target '%s' not found" % target_id)
        _handle_missing_node_error(target_id)
        return

    transition_started.emit(current_node, to_node)
    enter_node(target_id)


## Play a cinematic by ID
func _play_cinematic(cinematic_id: String) -> void:
    if not _has_cinematics_manager():
        push_warning("CampaignManager: CinematicsManager not available")
        return

    var cinematic: Resource = ModLoader.registry.get_resource("cinematic", cinematic_id)
    if cinematic:
        await CinematicsManager.play_cinematic(cinematic)
    else:
        push_warning("CampaignManager: Cinematic '%s' not found" % cinematic_id)


## Show chapter boundary save prompt
func _show_chapter_boundary_save_prompt() -> void:
    # TODO: Implement save prompt UI
    print("CampaignManager: Chapter boundary reached - save prompt would appear here")


## Check for chapter transitions
func _check_chapter_transition(node: CampaignNode) -> void:
    var chapter: Dictionary = current_campaign.get_chapter_for_node(node.node_id)
    if chapter.is_empty():
        return

    var chapter_id: String = chapter.get("id", "")
    var current_chapter_id: String = GameState.get_campaign_data("current_chapter_id", "")

    if chapter_id != current_chapter_id:
        GameState.set_campaign_data("current_chapter_id", chapter_id)
        chapter_started.emit(chapter)
        var chapter_num: int = chapter.get("number", 0)
        var chapter_name: String = chapter.get("name", "")
        print("CampaignManager: === CHAPTER %d: %s ===" % [chapter_num, chapter_name])


# ---- Built-in Trigger Evaluators ----

func _evaluate_choice_trigger(branch: Dictionary, outcome: Dictionary) -> bool:
    var choice_value: String = branch.get("choice_value", "")
    return outcome.get("choice", "") == choice_value


func _evaluate_flag_trigger(branch: Dictionary, outcome: Dictionary) -> bool:
    var required_flag: String = branch.get("required_flag", "")
    return required_flag.is_empty() or GameState.has_flag(required_flag)


func _evaluate_always_trigger(_branch: Dictionary, _outcome: Dictionary) -> bool:
    return true


## Export campaign state for saves
func export_state() -> Dictionary:
    return {
        "current_campaign_id": current_campaign.campaign_id if current_campaign else "",
        "current_node_id": current_node.node_id if current_node else "",
        "node_history": node_history.duplicate(),
        "last_hub_id": last_hub_id
    }


## Import campaign state from saves
func import_state(state: Dictionary) -> void:
    node_history = state.get("node_history", [])
    last_hub_id = state.get("last_hub_id", "")
    var campaign_id: String = state.get("current_campaign_id", "")
    var node_id: String = state.get("current_node_id", "")

    if not campaign_id.is_empty() and not node_id.is_empty():
        resume_campaign(campaign_id, node_id)
```

---

## Registry Pattern

### Overview

The CampaignManager uses a registry pattern for extensibility, following the same model as CinematicCommandExecutor. This allows modders to add new node types and trigger evaluators without modifying core code.

### Registering Custom Node Types

Modders can add custom node types by registering a processor:

```gdscript
# In your mod's autoload or initialization script
func _ready() -> void:
    # Register a minigame processor
    CampaignManager.register_node_processor("minigame", _process_minigame)

    # Or for custom:* types (recommended for mods)
    CampaignManager.register_custom_handler("fishing", _process_fishing_minigame)


func _process_minigame(node: CampaignNode) -> void:
    var minigame_id: String = node.resource_id
    # Load and start your minigame
    MinigameManager.start_minigame(minigame_id)


func _process_fishing_minigame(node: CampaignNode, manager: CampaignManager) -> void:
    # Custom handlers receive the manager for completion callbacks
    FishingGame.start(node.resource_id)
    await FishingGame.completed
    manager.complete_current_node({"fish_caught": FishingGame.last_catch})
```

### Registering Custom Trigger Evaluators

Modders can add custom branching logic:

```gdscript
func _ready() -> void:
    CampaignManager.register_trigger_evaluator("time_of_day", _evaluate_time_trigger)


func _evaluate_time_trigger(branch: Dictionary, outcome: Dictionary) -> bool:
    var required_time: String = branch.get("time", "day")
    return TimeManager.get_time_of_day() == required_time
```

### Custom Handler Contract

When implementing a custom handler:

1. **Handler receives:** `(node: CampaignNode, manager: CampaignManager)`
2. **Handler must:** Call `manager.complete_current_node(outcome)` when finished
3. **Outcome dictionary:** Should contain relevant data for transition logic
4. **Error handling:** Handler should use `push_error()` and call completion even on failure

---

## Scene Lifecycle

### What Persists During Scene Changes

| Data | Persists? | Storage |
|------|-----------|---------|
| Campaign position | Yes | GameState.campaign_data |
| Story flags | Yes | GameState.story_flags |
| Party state | Yes | GameState.party |
| Gold/resources | Yes | GameState.resources |
| Node history | Yes | CampaignManager.node_history |
| Battle state | No | Cleared after battle ends |
| Scene-specific state | No | Unloaded with scene |

### Scene Unloading

When transitioning between nodes:

1. Current scene's `_exit_tree()` is called
2. SceneManager queues the scene for unloading
3. New scene is loaded and added to tree
4. New scene's `_ready()` is called
5. CampaignManager.node_entered signal is emitted

### Exploration Node Completion Triggers

Scene nodes complete based on their `completion_trigger` setting:

| Trigger Type | Description | Example |
|--------------|-------------|---------|
| `exit_trigger` | Player exits via designated exit | Walking off map edge |
| `flag_set` | Story flag is set | Talking to quest NPC |
| `npc_interaction` | Specific NPC interaction | Talking to the king |
| `manual` | Script calls complete_current_node() | Puzzle solved |

Example scene script integration:

```gdscript
# In a town scene
func _on_exit_area_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        CampaignManager.complete_current_node({})


func _on_quest_npc_dialogue_finished() -> void:
    GameState.set_flag("spoke_to_king", true)
    # If completion_trigger is "flag_set" with completion_flag = "spoke_to_king"
    # CampaignManager will detect this and complete the node
```

---

## Mod Integration

### Campaign Discovery

ModLoader will be extended to discover campaigns:

```gdscript
# In mod_loader.gd RESOURCE_TYPE_DIRS
const RESOURCE_TYPE_DIRS: Dictionary = {
    # ... existing types ...
    "campaigns": "campaign"  # NEW
}
```

### Mod Folder Structure

```
mods/my_campaign/
  mod.json
  data/
    campaigns/
      main_story.tres      # CampaignData resource
    battles/
      battle_001.tres
      battle_002.tres
    cinematics/
      opening.json
      ending.json
  scenes/
    towns/
      starting_town.tscn
      headquarters.tscn
    exploration/
      forest_map.tscn
```

### Mod.json Declaration

```json
{
  "id": "my_campaign",
  "name": "My Custom Campaign",
  "version": "1.0.0",
  "provides": {
    "campaigns": ["main_story"],
    "battles": ["battle_001", "battle_002"],
    "cinematics": ["opening", "ending"]
  },
  "default_campaign": "my_campaign:main_story",
  "hidden_campaigns": ["base_game:*"]
}
```

### Namespace Considerations

Campaign IDs follow the pattern: `mod_id:campaign_id`

Examples:
- `base_game:main_story` - The official main story
- `sandbox:test_campaign` - Development test campaign
- `my_mod:custom_adventure` - A mod's custom campaign

This prevents collisions when multiple mods define campaigns.

### Hidden Campaigns Mechanism

Mods can hide other campaigns via the `hidden_campaigns` array in mod.json:

- Exact match: `"hidden_campaigns": ["base_game:tutorial"]`
- Wildcard: `"hidden_campaigns": ["base_game:*"]` hides all base_game campaigns
- Multiple patterns: `["base_game:*", "other_mod:deprecated_*"]`

This is useful for total conversion mods that want to replace the base game entirely.

### JSON Campaign Definitions (Future)

For modders who prefer JSON over .tres files, a future enhancement could support:

```json
{
  "campaign_id": "my_mod:adventure",
  "campaign_name": "My Adventure",
  "starting_node_id": "start",
  "nodes": [
    {
      "node_id": "start",
      "display_name": "Opening",
      "node_type": "cutscene",
      "resource_id": "opening",
      "on_complete": "town_1"
    }
  ]
}
```

This would be loaded by a CampaignJsonLoader utility. **Not in initial scope** - add if modders request it.

---

## Implementation Plan

### Phase 1: Core Infrastructure (10-12 hours) ✅ COMPLETE

**1.1 Create Resource Classes (3-4 hours)** ✅
- [x] CampaignData resource with validation and caching (`core/resources/campaign_data.gd`)
- [x] CampaignNode resource with SF mechanics (`core/resources/campaign_node.gd`)
- [ ] Unit tests for validation logic

**1.2 Create CampaignManager Autoload (5-6 hours)** ✅
- [x] Registry pattern for node processors
- [x] Registry pattern for trigger evaluators
- [x] Campaign discovery and loading
- [x] Node entry and processing
- [x] Transition logic with error recovery
- [x] GameState integration
- [x] Battle completion handling with SF mechanics (XP persist, gold penalty)
- [x] Egress support

**1.3 ModLoader Integration (2 hours)** ✅
- [x] Add "campaigns" to RESOURCE_TYPE_DIRS
- [x] Campaign discovery in mod loading pipeline (JSON + .tres)
- [ ] Hidden campaigns support (TODO in code)

### Phase 2: Integration (6-8 hours) ✅ COMPLETE

**2.1 SaveManager Integration (2-3 hours)** ✅
- [x] Add campaign state to SaveData (`current_campaign_id`, `current_node_id`)
- [x] Save current campaign, node, and hub
- [x] Load and resume campaigns
- [x] Node history persistence

**2.2 Scene Flow Integration (3-4 hours)** ✅
- [x] Update save_slot_selector.gd to use CampaignManager
- [x] Connect BattleManager.battle_ended to CampaignManager
- [x] Handle exploration scene completion triggers
- [x] Implement egress in exploration scenes

**2.3 CinematicsManager Guard (1 hour)** ✅
- [x] Add null checks for missing CinematicsManager
- [x] Graceful degradation when cinematics unavailable

### Phase 3: Base Content (4-6 hours) ✅ COMPLETE

**3.1 Create Test Campaign (4-6 hours)** ✅
- [x] Define test campaign (`mods/_sandbox/data/campaigns/test_campaign.json`)
- [x] Create map scene with hub functionality (`mods/_sandbox/maps/opening_game_map.tscn`)
- [x] Update existing battle to work with campaign
- [x] SF mechanics implemented (defeat -> XP kept, gold penalty)
- [x] Full flow works: New Game -> Campaign Start -> Battle -> Return
- [x] Battle replay configured (repeatable: true)

### Phase 4: Polish (4-6 hours) ✅ COMPLETE

**4.1 Chapter Boundary UI (2-3 hours)** ✅
- [x] Save prompt at chapter boundaries (ChapterTransitionUI)
- [x] Chapter transition display (animated title cards)

**4.2 Error Recovery (Already Implemented)**
- [x] Missing resource recovery (`_handle_missing_node_error()` in campaign_manager.gd)
- [x] Circular transition detection (`_detect_circular_transitions()` in campaign_data.gd)
- [x] Campaign ID collision warnings (in `_discover_campaigns()`)

**Total Estimated Hours: 24-32 hours**
**Actual Hours (Core): ~20 hours**
**Remaining (Polish): ~4-6 hours**

---

## Integration Points

### Existing Systems

| System | Integration | Notes |
|--------|-------------|-------|
| **GameState** | Store current_campaign_id, current_node_id, flags | Already has campaign_data dictionary |
| **SaveManager** | Add campaign state to SaveData | Export/import methods |
| **TriggerManager** | start_battle_with_data() | Already exists |
| **BattleManager** | Connect battle_ended signal, check retain_xp_on_defeat | Already emits victory/defeat |
| **SceneManager** | Change scenes for exploration | Already functional |
| **CinematicsManager** | Play cinematics (with null guard) | Already functional |
| **ModLoader** | Discover campaign resources | Add new resource type |

### Signal Connections

```gdscript
# In CampaignManager._ready()
BattleManager.battle_ended.connect(_on_battle_ended)

func _on_battle_ended(victory: bool) -> void:
    on_battle_completed(victory)
```

### SaveData Extensions

Add to `/home/user/dev/sparklingfarce/core/resources/save_data.gd`:

```gdscript
## Campaign Progress
@export var current_campaign_id: String = ""
@export var current_node_id: String = ""
@export var campaign_node_history: Array[String] = []
@export var last_hub_id: String = ""
```

---

## Testing Strategy

### Headless Tests

**Test 1: Campaign Loading and Validation**
```gdscript
func test_campaign_discovery() -> void:
    assert(CampaignManager.get_available_campaigns().size() > 0)
    var campaign: CampaignData = CampaignManager.get_campaign("base_game:test_campaign")
    assert(campaign != null)
    assert(campaign.validate().is_empty())


func test_node_cache_o1_lookup() -> void:
    var campaign: CampaignData = CampaignManager.get_campaign("base_game:test_campaign")
    var start_time: int = Time.get_ticks_usec()
    for i: int in range(1000):
        var _node: CampaignNode = campaign.get_node("battle_1")
    var elapsed: int = Time.get_ticks_usec() - start_time
    assert(elapsed < 1000)  # Should be very fast with O(1) cache
```

**Test 2: Node Transitions**
```gdscript
func test_node_transitions() -> void:
    CampaignManager.start_campaign("base_game:test_campaign")
    assert(CampaignManager.current_node.node_id == "start")
    CampaignManager.complete_current_node({})
    assert(CampaignManager.current_node.node_id == "second_node")


func test_battle_victory_transition() -> void:
    # Navigate to battle node
    CampaignManager.on_battle_completed(true)
    assert(CampaignManager.current_node.node_id == "post_battle_hub")


func test_battle_defeat_transition() -> void:
    # Navigate to battle node
    CampaignManager.on_battle_completed(false)
    assert(CampaignManager.current_node.node_id == "headquarters")
```

**Test 3: Shining Force Mechanics**
```gdscript
func test_defeat_gold_penalty() -> void:
    GameState.set_gold(1000)
    # Enter battle with 50% defeat penalty
    CampaignManager.on_battle_completed(false)
    assert(GameState.get_gold() == 500)


func test_egress_returns_to_hub() -> void:
    CampaignManager.enter_node("exploration_area")
    assert(CampaignManager.request_egress())
    assert(CampaignManager.current_node.node_id == "headquarters")
```

**Test 4: Registry Pattern**
```gdscript
func test_custom_node_processor() -> void:
    var processed: bool = false
    CampaignManager.register_node_processor("test_type", func(_node: CampaignNode) -> void:
        processed = true
    )
    CampaignManager.enter_node("test_node_with_custom_type")
    assert(processed)
```

**Test 5: Circular Transition Detection**
```gdscript
func test_circular_transition_detected() -> void:
    var campaign: CampaignData = _create_circular_campaign()
    var errors: Array[String] = campaign.validate()
    assert(errors.size() > 0)
    assert(errors[0].contains("Circular"))
```

### Manual Tests

1. **New Game Flow**
   - Start new game
   - Verify campaign starts at correct node
   - Verify pre-cinematics play (or skip gracefully if missing)
   - Verify hub scene loads

2. **Battle Return Flow**
   - Enter battle from campaign
   - Win battle -> Verify return to correct hub/town
   - Lose battle -> Verify XP kept, gold reduced by 50%
   - Verify flags are set

3. **Egress Flow**
   - Enter exploration area
   - Use egress -> Verify return to last hub
   - Verify egress blocked where allow_egress = false

4. **Battle Replay Flow**
   - Complete a repeatable battle
   - Return and replay -> Verify XP/gold gained
   - Verify story does not advance if replay_advances_story = false

5. **Save/Load Flow**
   - Progress through multiple nodes
   - Save game at chapter boundary
   - Load game
   - Verify campaign resumes at correct node

6. **Branching Flow**
   - Reach choice node
   - Make choice
   - Verify correct branch taken
   - Verify flags set correctly

7. **Error Recovery**
   - Manually corrupt a campaign file to reference missing node
   - Verify graceful recovery to hub

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Campaign data bloat | Low | Medium | Keep nodes lightweight, reference external resources |
| Circular transitions | Medium | High | Validation during load with detection algorithm |
| Save compatibility | Medium | High | Version migrations, graceful fallbacks |
| Performance with large campaigns | Low | Low | O(1) node cache, lazy loading |
| Mod conflicts | Medium | Medium | Namespacing, priority system, collision warnings |
| Missing CinematicsManager | Medium | Low | Null guards, graceful degradation |
| Missing resources | Medium | Medium | Error recovery to hub |

---

## Success Metrics

**Before Implementation:**
- Moddability for campaigns: 0/10 (hardcoded)
- Story flexibility: None (single linear path)
- Save integration: Partial (no campaign tracking)

**After Implementation:**
- Moddability for campaigns: 9/10 (fully data-driven with registry extensibility)
- Story flexibility: Full (linear, branching, hub-based)
- Save integration: Complete (full campaign state persistence)
- SF Authenticity: High (XP persist, gold penalty, egress, replay)

---

## Appendix A: Example Campaign Resource

```gdscript
# mods/_base_game/data/campaigns/main_story.tres
[gd_resource type="Resource" script_class="CampaignData"]

[resource]
script = ExtResource("res://core/resources/campaign_data.gd")
campaign_id = "base_game:main_story"
campaign_name = "The Sparkling Farce"
campaign_description = "The official story campaign."
campaign_version = "1.0.0"
starting_node_id = "opening_cinematic"
default_hub_id = "headquarters"

chapters = [
    {"id": "ch1", "name": "The Beginning", "number": 1, "node_ids": ["opening_cinematic", "headquarters", "battle_1"]}
]

nodes = [
    # Opening Cutscene
    SubResource("node_opening"),
    # Headquarters Hub
    SubResource("node_hq"),
    # First Battle
    SubResource("node_battle1")
]

[sub_resource type="Resource" id="node_opening"]
script = ExtResource("res://core/resources/campaign_node.gd")
node_id = "opening_cinematic"
display_name = "Opening"
node_type = "cutscene"
resource_id = "game_opening"
on_complete = "headquarters"
is_chapter_boundary = true

[sub_resource type="Resource" id="node_hq"]
script = ExtResource("res://core/resources/campaign_node.gd")
node_id = "headquarters"
display_name = "Headquarters"
node_type = "scene"
scene_path = "res://mods/_base_game/scenes/headquarters.tscn"
is_hub = true
allow_egress = false
completion_trigger = "exit_trigger"
on_complete = "battle_1"

[sub_resource type="Resource" id="node_battle1"]
script = ExtResource("res://core/resources/campaign_node.gd")
node_id = "battle_1"
display_name = "Battle of Noobs"
node_type = "battle"
resource_id = "battle_1763763677"
retain_xp_on_defeat = true
defeat_gold_penalty = 0.5
repeatable = true
replay_advances_story = false
on_victory = "headquarters"
on_defeat = "headquarters"
on_complete_flags = {"completed_battle_1": true}
```

---

## Appendix B: Migration Path

### Step 1: Create CampaignManager (No Breaking Changes)

Add CampaignManager as new autoload without modifying existing code.

### Step 2: Create Test Campaign Resource

Create a simple test campaign with existing battle.

### Step 3: Update Save Slot Selector

Modify to use CampaignManager instead of direct TriggerManager call:

```gdscript
# Before
TriggerManager.start_battle("battle_1763763677")

# After
CampaignManager.start_campaign("base_game:main_story")
```

### Step 4: Connect Battle Completion

Wire BattleManager.battle_ended to CampaignManager.

---

## Revision History

### Revision 2.0 - November 28, 2025 (Senior Staff Review)

**Changes based on Commander Claudius feedback:**
- Added `retain_xp_on_defeat: bool` to CampaignNode (default: true, SF authentic)
- Added `defeat_gold_penalty: float` to CampaignNode (default: 0.5 = 50%, SF authentic)
- Added `repeatable: bool` for battle grinding support
- Added `replay_advances_story: bool` to distinguish story vs grind replays
- Added `allow_egress: bool` for Egress spell support
- Added `is_chapter_boundary: bool` for save prompts at chapter ends
- Added `completion_trigger` system for exploration node completion
- Documented scene lifecycle (persistence, unloading)
- Updated time estimate to 24-32 hours

**Changes based on Lt. Claudette feedback:**
- Added explicit type declarations to ALL loop variables (`: Type`)
- Moved transition evaluation logic FROM CampaignTransition TO CampaignNode.get_transition_target()
- Added `_node_cache: Dictionary` to CampaignData for O(1) node lookup
- Added `_has_cinematics_manager()` guard for missing CinematicsManager
- Added `_detect_circular_transitions()` in validation
- Added `_handle_missing_node_error()` for error recovery

**Changes based on Modro feedback (P0 fixes):**
- Replaced `NodeType` enum with `node_type: String` + registry pattern
- Replaced `TransitionTrigger` enum with `trigger: String` + registered evaluators
- Added `register_node_processor()`, `register_trigger_evaluator()`, `register_custom_handler()` APIs
- Documented explicit custom node handling contract
- Added collision warning when campaign IDs are overwritten
- Documented `hidden_campaigns` mechanism with wildcard support
- Noted JSON support as future enhancement if modders request

**Changes based on Commander Clean feedback (Simplification):**
- Inlined ChapterData as `Dictionary` array in CampaignData (removed separate Resource)
- Inlined transitions: `on_victory`, `on_defeat`, `on_complete` + `branches[]` (removed CampaignTransition Resource)
- Consolidated HUB and EXPLORATION into single "scene" type with `is_hub` boolean
- Reduced from 4 Resources to 2 Resources (CampaignData, CampaignNode)
- Applied YAGNI principle throughout

**Resource Count:** 2 (down from 4)
**Estimated Hours:** 24-32 (up from 16-24 to account for additional SF mechanics and registry pattern)
**Target Moddability:** 9/10

### Revision 3.0 - December 1, 2025 (Implementation Complete)

**Core implementation complete.** All Phase 1-3 items implemented:
- CampaignManager autoload with registry pattern
- CampaignData and CampaignNode resources
- CampaignLoader for JSON campaign definitions
- ModLoader integration (campaigns in RESOURCE_TYPE_DIRS, JSON support)
- SaveData integration (current_campaign_id, current_node_id)
- BattleManager signal connection
- Test campaign in `mods/_sandbox/data/campaigns/test_campaign.json`

**Remaining polish items (Phase 4):**
- Chapter boundary save prompt UI
- Chapter transition display
- Error recovery testing

**Implementation files:**
- `core/systems/campaign_manager.gd`
- `core/systems/campaign_loader.gd`
- `core/resources/campaign_data.gd`
- `core/resources/campaign_node.gd`
- `mods/_sandbox/data/campaigns/test_campaign.json`
- `scenes/ui/chapter_transition_ui.gd` (NEW - Phase 4.1)

---

**Plan Created:** November 28, 2025
**Last Revised:** December 1, 2025
**Author:** Lt. Claudbrain, USS Torvalds
**Research Sources:** Shining Force Central, GameFAQs, Wikipedia
**Reviewers:** Commander Claudius, Lt. Claudette, Modro, Commander Clean
**Status:** ✅ APPROVED & IMPLEMENTED (Polish phase remaining)
