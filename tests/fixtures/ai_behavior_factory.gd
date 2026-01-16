## Shared test fixture for creating AIBehaviorData resources
##
## Provides preset behaviors for common AI test scenarios:
## - Aggressive (attacks nearest)
## - Opportunistic (prioritizes wounded)
## - Defensive (protects allies)
## - Support (healer prioritization)
## - Stationary (guard behavior)
## - Cautious (limited engagement range)
## - Retreat (flees when hurt)
## - Tactical (debuff focused)
## - AoE Mage (cluster targeting)
## - Terrain Seeker (defensive positioning)
## - Ranged (maintains distance)
##
## Dependencies: None (pure resource creation)
##
## This fixture is safe for both unit and integration tests.
##
## Usage:
##   const AIBehaviorFactoryScript = preload("res://tests/fixtures/ai_behavior_factory.gd")
##
##   var behavior: AIBehaviorData = AIBehaviorFactoryScript.create_aggressive()
##   var custom: AIBehaviorData = AIBehaviorFactoryScript.create_custom({
##       "behavior_id": "my_test",
##       "behavior_mode": "opportunistic",
##       "threat_weights": {"wounded_target": 2.0}
##   })
class_name AIBehaviorFactory
extends RefCounted


## Create an aggressive behavior (attacks nearest enemy, ignores defense)
static func create_aggressive(behavior_id: String = "test_aggressive") -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test Aggressive"
	behavior.role = "aggressive"
	behavior.behavior_mode = "aggressive"
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	return behavior


## Create an opportunistic behavior (prioritizes wounded targets)
static func create_opportunistic(behavior_id: String = "test_opportunistic") -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test Opportunistic"
	behavior.role = "aggressive"
	behavior.behavior_mode = "opportunistic"
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	behavior.threat_weights = {
		"wounded_target": 2.0,
		"proximity": 0.3
	}
	return behavior


## Create a defensive behavior (tank, protects VIPs)
static func create_defensive(behavior_id: String = "test_defensive") -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test Defensive Tank"
	behavior.role = "defensive"
	behavior.behavior_mode = "cautious"
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	return behavior


## Create a support behavior (healer prioritization)
static func create_support(behavior_id: String = "test_support") -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test Support"
	behavior.role = "support"
	behavior.behavior_mode = "cautious"
	behavior.retreat_enabled = true
	behavior.use_healing_items = true
	behavior.use_attack_items = false
	behavior.conserve_mp_on_heals = false
	behavior.prioritize_boss_heals = false
	return behavior


## Create a stationary guard behavior (doesn't move, attacks in range only)
## Uses minimal alert_range and engagement_range to stay in place
static func create_stationary_guard(behavior_id: String = "test_stationary_guard") -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test Stationary Guard"
	behavior.role = "defensive"
	behavior.behavior_mode = "cautious"
	behavior.alert_range = 1
	behavior.engagement_range = 1
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	return behavior


## Create a retreat behavior (flees when HP drops below threshold)
static func create_retreat_when_hurt(
	behavior_id: String = "test_retreater",
	retreat_threshold: int = 60
) -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test Retreater"
	behavior.role = "aggressive"
	behavior.behavior_mode = "opportunistic"
	behavior.retreat_enabled = true
	behavior.retreat_hp_threshold = retreat_threshold
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	return behavior


## Create a cautious behavior (respects alert_range and engagement_range)
static func create_cautious(
	behavior_id: String = "test_cautious",
	alert_range: int = 6,
	engagement_range: int = 3
) -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test Cautious"
	behavior.role = "aggressive"
	behavior.behavior_mode = "cautious"
	behavior.alert_range = alert_range
	behavior.engagement_range = engagement_range
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	return behavior


## Create a tactical behavior (prioritizes debuffs on high-threat targets)
static func create_tactical(behavior_id: String = "test_tactical") -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test Tactical"
	behavior.role = "tactical"
	behavior.behavior_mode = "cautious"
	behavior.use_status_effects = true
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	behavior.threat_weights = {
		"damage_dealer": 2.0,
		"high_attack": 1.5
	}
	return behavior


## Create an AoE mage behavior (prioritizes clustered targets)
static func create_aoe_mage(
	behavior_id: String = "test_aoe_mage",
	minimum_targets: int = 2
) -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test AoE Mage"
	behavior.role = "aggressive"
	behavior.behavior_mode = "aggressive"
	behavior.aoe_minimum_targets = minimum_targets
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	return behavior


## Create a terrain-seeker behavior (seeks advantageous terrain for defense bonuses)
static func create_terrain_seeker(behavior_id: String = "test_terrain_seeker") -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test Terrain Seeker"
	behavior.role = "aggressive"
	behavior.behavior_mode = "aggressive"
	behavior.seek_terrain_advantage = true
	behavior.retreat_enabled = false
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	return behavior


## Create a ranged/archer behavior (maintains distance, opportunistic targeting)
static func create_ranged(behavior_id: String = "test_ranged") -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()
	behavior.behavior_id = behavior_id
	behavior.display_name = "Test Ranged"
	behavior.role = "aggressive"
	behavior.behavior_mode = "opportunistic"
	behavior.retreat_enabled = true
	behavior.retreat_hp_threshold = 40
	behavior.use_healing_items = false
	behavior.use_attack_items = false
	behavior.threat_weights = {
		"wounded_target": 1.5,
		"proximity": 0.5
	}
	return behavior


## Create a custom behavior with specified options
## Options can include any AIBehaviorData property:
##   - behavior_id: String (default: "test_custom")
##   - display_name: String (default: "Test Custom")
##   - role: String (default: "aggressive")
##   - behavior_mode: String (default: "aggressive")
##   - retreat_enabled: bool
##   - retreat_hp_threshold: int
##   - retreat_when_outnumbered: bool
##   - seek_healer_when_wounded: bool
##   - use_healing_items: bool
##   - use_attack_items: bool
##   - use_buff_items: bool
##   - use_status_effects: bool
##   - preferred_status_effects: Array[String]
##   - alert_range: int
##   - engagement_range: int
##   - aoe_minimum_targets: int
##   - conserve_mp_on_heals: bool
##   - prioritize_boss_heals: bool
##   - seek_terrain_advantage: bool
##   - max_idle_turns: int
##   - ignore_protagonist_priority: bool
##   - threat_weights: Dictionary
##   - behavior_phases: Array[Dictionary]
static func create_custom(options: Dictionary) -> AIBehaviorData:
	var behavior: AIBehaviorData = AIBehaviorData.new()

	# Required fields with defaults
	behavior.behavior_id = options.get("behavior_id", "test_custom")
	behavior.display_name = options.get("display_name", "Test Custom")
	behavior.role = options.get("role", "aggressive")
	behavior.behavior_mode = options.get("behavior_mode", "aggressive")

	# Retreat options
	if "retreat_enabled" in options:
		behavior.retreat_enabled = options.retreat_enabled
	if "retreat_hp_threshold" in options:
		behavior.retreat_hp_threshold = options.retreat_hp_threshold
	if "retreat_when_outnumbered" in options:
		behavior.retreat_when_outnumbered = options.retreat_when_outnumbered
	if "seek_healer_when_wounded" in options:
		behavior.seek_healer_when_wounded = options.seek_healer_when_wounded

	# Item usage options
	if "use_healing_items" in options:
		behavior.use_healing_items = options.use_healing_items
	if "use_attack_items" in options:
		behavior.use_attack_items = options.use_attack_items
	if "use_buff_items" in options:
		behavior.use_buff_items = options.use_buff_items

	# Ability usage options
	if "use_status_effects" in options:
		behavior.use_status_effects = options.use_status_effects
	if "preferred_status_effects" in options:
		behavior.preferred_status_effects = options.preferred_status_effects
	if "aoe_minimum_targets" in options:
		behavior.aoe_minimum_targets = options.aoe_minimum_targets
	if "conserve_mp_on_heals" in options:
		behavior.conserve_mp_on_heals = options.conserve_mp_on_heals
	if "prioritize_boss_heals" in options:
		behavior.prioritize_boss_heals = options.prioritize_boss_heals

	# Engagement options
	if "alert_range" in options:
		behavior.alert_range = options.alert_range
	if "engagement_range" in options:
		behavior.engagement_range = options.engagement_range
	if "seek_terrain_advantage" in options:
		behavior.seek_terrain_advantage = options.seek_terrain_advantage
	if "max_idle_turns" in options:
		behavior.max_idle_turns = options.max_idle_turns

	# Targeting options
	if "ignore_protagonist_priority" in options:
		behavior.ignore_protagonist_priority = options.ignore_protagonist_priority
	if "threat_weights" in options:
		behavior.threat_weights = options.threat_weights

	# Phase system
	if "behavior_phases" in options:
		behavior.behavior_phases = options.behavior_phases

	return behavior
