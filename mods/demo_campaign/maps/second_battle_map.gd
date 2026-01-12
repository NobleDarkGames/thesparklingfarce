extends Node2D

## Battle map - minimal script for BattleLoader compatibility
## Battle maps don't need exploration features (party followers, camera, etc.)
## The BattleLoader handles all battle-specific setup

@export var map_id: String = "demo_campaign:second_battle_map"
@export_enum("TOWN", "OVERWORLD", "DUNGEON", "INTERIOR", "BATTLE") var map_type: String = "BATTLE"
@export var display_name: String = "Second Battle Map"
