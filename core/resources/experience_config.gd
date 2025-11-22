class_name ExperienceConfig
extends Resource

## Configuration resource for the experience and leveling system.
##
## This resource contains all tunable parameters for XP awards, level-up mechanics,
## and progression. Content creators can adjust these values to customize the
## difficulty and feel of their battles.

# ============================================================================
# COMBAT XP SETTINGS
# ============================================================================

## Enable participation-based XP for nearby allies.
@export var enable_participation_xp: bool = true

## Radius in grid cells for participation XP (allies within this distance get XP).
@export_range(1, 10) var participation_radius: int = 3

## Multiplier for participation XP (0.25 = 25% of base XP).
@export_range(0.0, 1.0) var participation_multiplier: float = 0.25

## Multiplier for kill bonus XP (0.5 = 50% of base XP added).
@export_range(0.0, 2.0) var kill_bonus_multiplier: float = 0.5

## Maximum XP that can be awarded per single action.
@export_range(1, 100) var max_xp_per_action: int = 49

# ============================================================================
# LEVEL DIFFERENCE XP TABLE (Shining Force Style)
# ============================================================================

## XP awarded based on level difference (Defender Level - Attacker Level).
## Uses Shining Force formula: values drop sharply when fighting weaker enemies.
## Key: level_difference, Value: base_xp
@export var level_diff_xp_table: Dictionary = {
	-20: 0,   # Far below player level: no XP
	-7: 0,    # 7+ levels below: no XP
	-6: 10,   # 6 levels below: minimal XP
	-5: 20,   # 5 levels below: low XP
	-4: 30,   # 4 levels below
	-3: 40,   # 3 levels below
	-2: 50,   # 2 levels below: standard XP
	-1: 50,   # 1 level below
	0: 50,    # Same level
	1: 50,    # 1 level above
	2: 50,    # 2 levels above
	20: 50    # Far above player level: still 50 (caps at standard)
}

# ============================================================================
# SUPPORT XP SETTINGS
# ============================================================================

## Enable enhanced XP for support actions (healing, buffs, debuffs).
@export var enable_enhanced_support_xp: bool = true

## Base XP awarded for healing (before HP ratio bonus).
@export_range(0, 50) var heal_base_xp: int = 10

## Multiplier for healing XP based on HP restored (25 * (HP restored / Max HP)).
@export_range(0, 50) var heal_ratio_multiplier: int = 25

## Base XP awarded for casting buff spells.
@export_range(0, 50) var buff_base_xp: int = 15

## Base XP awarded for casting debuff spells.
@export_range(0, 50) var debuff_base_xp: int = 15

# ============================================================================
# ANTI-SPAM SETTINGS
# ============================================================================

## Enable diminishing returns for repeated actions in same battle.
@export var anti_spam_enabled: bool = true

## Number of uses before XP reduction to 60%.
@export_range(1, 20) var spam_threshold_medium: int = 5

## Number of uses before XP reduction to 30%.
@export_range(1, 20) var spam_threshold_heavy: int = 8

# ============================================================================
# LEVELING SETTINGS
# ============================================================================

## Experience points required per level.
@export_range(1, 1000) var xp_per_level: int = 100

## Maximum level characters can reach.
@export_range(1, 99) var max_level: int = 20

## Level at which units can promote to advanced classes.
@export_range(1, 50) var promotion_level: int = 10

# ============================================================================
# ADJUTANT SYSTEM (Skeleton for Future Implementation)
# ============================================================================

## Enable adjutant system (units gain XP while not deployed).
@export var enable_adjutant_system: bool = false

## Percentage of XP shared with adjutants (0.5 = 50%).
@export_range(0.0, 1.0) var adjutant_xp_share: float = 0.5

## Maximum number of adjutants per deployed unit.
@export_range(1, 5) var max_adjutants: int = 3


# ============================================================================
# HELPER METHODS
# ============================================================================

## Get base XP from level difference using the lookup table.
##
## @param level_diff: Defender level - Attacker level
## @return: Base XP value for this level difference
func get_base_xp_from_level_diff(level_diff: int) -> int:
	# Clamp to table bounds
	if level_diff <= -7:
		return level_diff_xp_table[-7]
	elif level_diff >= 2:
		return level_diff_xp_table[2]
	else:
		return level_diff_xp_table.get(level_diff, 50)


## Calculate anti-spam XP multiplier based on usage count.
##
## @param usage_count: Number of times this action has been used this battle
## @return: Multiplier to apply to XP (1.0, 0.6, or 0.3)
func get_anti_spam_multiplier(usage_count: int) -> float:
	if not anti_spam_enabled:
		return 1.0

	if usage_count >= spam_threshold_heavy:
		return 0.3
	elif usage_count >= spam_threshold_medium:
		return 0.6
	else:
		return 1.0
