# Campaign Creation Tutorial

## Overview

A **Campaign** is a structured progression of nodes (battles, scenes, cutscenes, choices) that tell your mod's story. The Campaign Editor provides a visual graph-based interface for designing this flow.

## Getting Started

1. **Open Sparkling Editor** in Godot
2. Navigate to the **Campaign** tab
3. Click **New** to create a new campaign, or select an existing one from the list

## Campaign Metadata

At the top of the editor, configure:

| Field | Description |
|-------|-------------|
| **ID** | Unique identifier in format `mod_id:campaign_id` (e.g., `my_mod:main_story`) |
| **Name** | Display name shown to players |
| **Version** | For tracking changes (e.g., `1.0.0`) |
| **Start** | Which node the campaign begins at |
| **Default Hub** | Where players return after egress or defeats (usually a town) |

## Node Types

Campaigns consist of four node types, color-coded in the graph:

| Type | Color | Purpose |
|------|-------|---------|
| **battle** | Red | Tactical combat (references a BattleData) |
| **scene** | Blue | Explorable areas (towns, dungeons) |
| **cutscene** | Yellow | Story cinematics (references a CinematicData) |
| **choice** | Purple | Branching decision points |

## Creating Nodes

1. Click **+ Add Node** to create a new node
2. Select the node in the graph to edit its properties in the **Node Inspector**
3. Set:
   - **Node ID**: Internal identifier (e.g., `battle_1`, `town_hub`)
   - **Name**: Display name
   - **Type**: battle/scene/cutscene/choice

## Conditional Branching: Victory/Defeat

This is the core Shining Force mechanic - different paths based on battle outcomes.

### Setting Up Battle Branching

1. Create a **battle** node
2. Select a **Battle** from the dropdown (your BattleData resources)
3. Set transitions:
   - **On Victory** -> node to go to when player wins
   - **On Defeat** -> node to go to when player loses

**Example Flow:**
```
[Battle: First Encounter]
    |
    +-- Victory -> [Cutscene: Victory Speech] -> [Town: Castle]
    |
    +-- Defeat -> [Town: Hub] (player returns to retry)
```

### Visual Connections

In the graph, battle nodes show two output ports:
- **Green** (top): Victory path
- **Red** (bottom): Defeat path

Drag connections from these ports to target nodes, or use the dropdowns in the inspector.

## Scene Nodes

For explorable areas (towns, dungeons):

| Field | Description |
|-------|-------------|
| **Scene Path** | Path to the .tscn file |
| **Completion Trigger** | How the node "completes" |
| **Is Hub** | Mark as hub for egress returns |
| **Allow Egress** | Whether Egress spell works here |

### Completion Triggers

| Trigger | When it completes |
|---------|-------------------|
| `exit_trigger` | Player steps on an exit trigger |
| `flag_set` | A specific flag becomes true |
| `npc_interaction` | Player talks to specific NPC |
| `manual` | Code explicitly completes it |

## Choice Nodes

For branching story decisions:

1. Create a **choice** node
2. Click **+ Add Branch** for each option
3. For each branch:
   - **Label**: Text shown to player (e.g., "Accept the quest")
   - **Value**: Internal ID (e.g., `accept`)
   - **Target**: Which node this choice leads to

**Example:**
```
[Choice: Join the Rebellion?]
    |
    +-- "Yes, I'll fight!" -> [Battle: Rebel's First Strike]
    |
    +-- "No, I refuse" -> [Cutscene: Coward's Path]
```

## Pre/Post Cinematics

Any node can have cinematics that play before or after:

- **Pre-Cinematic**: Plays when entering the node
- **Post-Cinematic**: Plays after completion, before transitioning

Use these for story moments without creating separate cutscene nodes.

## Battle Node Options

| Option | Description |
|--------|-------------|
| **Retain XP on Defeat** | Players keep earned XP even if they lose (SF authentic) |
| **Defeat Gold Penalty** | Percentage of gold lost on defeat (0.5 = 50%) |
| **Repeatable** | Can this battle be replayed for grinding? |

## Flags for Advanced Branching

Beyond victory/defeat, you can use flags for complex story logic:

### Node-Level Flags
- **required_flags**: Must be true to access this node
- **forbidden_flags**: Must be false to access this node
- **on_enter_flags**: Set these flags when entering
- **on_complete_flags**: Set these flags when completing

### Branch-Level Flags (in choice nodes)
Each branch can have:
- `required_flags`: Array of flags that must be true
- `forbidden_flags`: Array of flags that must be false
- `priority`: Higher priority branches checked first

**Example: Secret Path**
```json
{
  "trigger": "flag",
  "required_flag": "found_secret_key",
  "target": "secret_dungeon",
  "priority": 10
}
```

## Typical Campaign Structure

```
Start -> [Cutscene: Opening] -> [Town: Hub]
                                   |
                                   v
                         [Battle: First Battle]
                              |         |
                         Victory     Defeat
                              |         |
                              v         v
                    [Town: Castle]  [Town: Hub] (retry)
                              |
                              v
                    [Choice: Which path?]
                        |         |
                    Path A    Path B
                        |         |
                        v         v
                   [Battle]   [Battle]
                        v         v
                         \       /
                          \     /
                           \   /
                            v v
                    [Cutscene: Ending]
```

## Saving & Testing

1. Click **Save Campaign** when done
2. Ensure your campaign has:
   - A valid **starting node**
   - All **battle nodes** reference valid BattleData
   - All **transitions** point to existing nodes
3. The editor validates and shows errors in the red panel

## Tips

- **Start simple**: Create a linear path first, then add branches
- **Use hubs**: Mark town nodes as hubs so egress works properly
- **Test defeat paths**: Make sure losing a battle doesn't softlock the player
- **Chapter boundaries**: Mark significant story beats for save prompts
- **Pre-cinematics**: Great for "entering battle" speeches
- **Post-cinematics**: Perfect for victory celebrations or plot reveals
