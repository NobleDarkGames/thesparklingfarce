class_name UIColors
extends RefCounted

## Shared UI color constants for consistent styling across all screens.
##
## Usage: Replace local COLOR_ constants with UIColors.MENU_NORMAL, etc.
## This centralizes color definitions and enables future theming support.

# =============================================================================
# MENU NAVIGATION COLORS (Most commonly used)
# =============================================================================

## Standard text color for menu items
const MENU_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)

## Bright yellow for selected/focused items (SF2 style)
const MENU_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)

## Grayed out for disabled/unavailable options
const MENU_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)

## Subtle highlight for mouse hover
const MENU_HOVER: Color = Color(0.95, 0.95, 0.85, 1.0)

# =============================================================================
# TRANSACTION/FEEDBACK COLORS
# =============================================================================

## Green for successful operations
const RESULT_SUCCESS: Color = Color(0.4, 1.0, 0.4, 1.0)

## Red for errors/failures
const RESULT_ERROR: Color = Color(1.0, 0.4, 0.4, 1.0)

## Yellow for warnings/partial success
const RESULT_WARNING: Color = Color(1.0, 0.8, 0.3, 1.0)

# =============================================================================
# ITEM STATE COLORS
# =============================================================================

## Dimmed color for empty slots
const ITEM_EMPTY: Color = Color(0.5, 0.5, 0.6, 1.0)

## Red tint for cursed items
const ITEM_CURSED: Color = Color(1.0, 0.3, 0.3, 1.0)

## Gold color for currency/value display
const ITEM_GOLD: Color = Color(0.8, 0.8, 0.2, 1.0)

## Red for missing materials/requirements
const ITEM_MISSING: Color = Color(0.8, 0.3, 0.3, 1.0)

## Green tint for queued/selected items
const ITEM_QUEUED: Color = Color(0.5, 0.8, 0.5, 1.0)

# =============================================================================
# PANEL/CONTAINER COLORS
# =============================================================================

## Standard panel background
const PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.95)

## Panel border/frame color
const PANEL_BORDER: Color = Color(0.4, 0.35, 0.25, 1.0)

## High-contrast border
const PANEL_BORDER_LIGHT: Color = Color(0.6, 0.6, 0.7, 1.0)

# =============================================================================
# FACTION/TEAM COLORS (Battle UI)
# =============================================================================

## Blue for player/ally units
const FACTION_ALLY: Color = Color(0.3, 0.6, 1.0, 1.0)

## Red for enemy units
const FACTION_ENEMY: Color = Color(1.0, 0.3, 0.3, 1.0)

## Yellow for neutral units
const FACTION_NEUTRAL: Color = Color(1.0, 0.9, 0.3, 1.0)

# =============================================================================
# XP/PROGRESSION COLORS (Combat Results)
# =============================================================================

## Soft gold for combat XP
const XP_DAMAGE: Color = Color(0.85, 0.85, 0.4)

## Brighter gold for kill XP
const XP_KILL: Color = Color(1.0, 0.85, 0.3)

## Soft blue for formation bonuses
const XP_FORMATION: Color = Color(0.5, 0.7, 0.9)

# =============================================================================
# CURSOR COLORS (Battle Grid)
# =============================================================================

## Yellow-gold for active unit indicator
const CURSOR_ACTIVE_UNIT: Color = Color(1.0, 1.0, 0.5, 1.0)

## White for action selection mode
const CURSOR_READY_TO_ACT: Color = Color(1.0, 1.0, 1.0, 1.0)

## Red for enemy targeting
const CURSOR_TARGET_ENEMY: Color = Color(1.0, 0.4, 0.4, 1.0)

## Green for ally targeting
const CURSOR_TARGET_ALLY: Color = Color(0.4, 1.0, 0.4, 1.0)
