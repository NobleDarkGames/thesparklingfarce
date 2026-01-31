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

## Bright white for available/castable items (spell menu, item menu)
const MENU_BRIGHT: Color = Color(0.9, 0.9, 0.9, 1.0)

# =============================================================================
# MAGIC/MP COLORS
# =============================================================================

## Blue for MP cost display (sufficient MP)
const MP_AVAILABLE: Color = Color(0.4, 0.7, 1.0, 1.0)

## Red for insufficient MP (reuses RESULT_ERROR for consistency)
## Use UIColors.RESULT_ERROR for insufficient MP

# =============================================================================
# TRANSACTION/FEEDBACK COLORS
# =============================================================================

## Green for successful operations
const RESULT_SUCCESS: Color = Color(0.4, 1.0, 0.4, 1.0)

## Red for errors/failures
const RESULT_ERROR: Color = Color(1.0, 0.4, 0.4, 1.0)

## Yellow for warnings/partial success
const RESULT_WARNING: Color = Color(1.0, 0.8, 0.3, 1.0)

## White for combat actions and general highlights
const TEXT_WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)

## Gray for missed/failed actions
const TEXT_MISS: Color = Color(0.6, 0.6, 0.6, 1.0)

## Orange for critical hits
const TEXT_CRITICAL: Color = Color(1.0, 0.6, 0.2, 1.0)

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

# =============================================================================
# SLOT/COMPONENT COLORS
# =============================================================================

## Border for normal item slots
const SLOT_BORDER_NORMAL: Color = Color(0.6, 0.6, 0.7, 1.0)

## Border for selected item slots (same as MENU_SELECTED)
const SLOT_BORDER_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)

## Border for cursed item slots
const SLOT_BORDER_CURSED: Color = Color(0.9, 0.2, 0.2, 1.0)

## Border for empty slots
const SLOT_BORDER_EMPTY: Color = Color(0.3, 0.3, 0.35, 1.0)

## Background for slots
const SLOT_BACKGROUND: Color = Color(0.1, 0.1, 0.15, 0.95)

## Background for cursed slots
const SLOT_BACKGROUND_CURSED: Color = Color(0.2, 0.1, 0.1, 0.95)

## Dimmed icon color for empty slots
const SLOT_ICON_EMPTY: Color = Color(0.3, 0.3, 0.35, 0.5)

## Tinted icon for cursed items
const SLOT_ICON_CURSED: Color = Color(1.0, 0.7, 0.7, 1.0)

# =============================================================================
# SETTINGS WIDGET COLORS
# =============================================================================

## Label color for settings widgets (normal)
const SETTINGS_LABEL: Color = Color(0.85, 0.85, 0.85, 1.0)

## Label color for selected settings widget
const SETTINGS_SELECTED: Color = Color(1.0, 0.95, 0.4, 1.0)

## Value color for OFF/inactive state
const SETTINGS_INACTIVE: Color = Color(0.5, 0.5, 0.5, 1.0)

## Bar segment filled color (same as SETTINGS_SELECTED)
const SETTINGS_FILLED: Color = Color(1.0, 0.95, 0.4, 1.0)

## Bar segment empty color
const SETTINGS_EMPTY: Color = Color(0.25, 0.25, 0.3, 1.0)

# =============================================================================
# DESCRIPTION/INFO COLORS
# =============================================================================

## Standard description text color
const DESC_TEXT: Color = Color(0.6, 0.6, 0.7, 1.0)

## Subdued/secondary text
const TEXT_SUBDUED: Color = Color(0.5, 0.5, 0.6, 1.0)

## Section header text
const SECTION_HEADER: Color = Color(0.7, 0.7, 0.8, 1.0)

## Character/item name highlight
const NAME_HIGHLIGHT: Color = Color(1.0, 1.0, 0.9, 1.0)

## Active instruction text
const INSTRUCTION_ACTIVE: Color = Color(1.0, 1.0, 0.5, 1.0)

## Inactive instruction text
const INSTRUCTION_INACTIVE: Color = Color(0.5, 0.5, 0.6, 0.8)
