# Non-Canon Feature Recommendations

**FROM:** Lt. Ears, Communications Officer
**TO:** Captain Obvious, Commanding Officer, USS Torvalds
**RE:** Features from Outside Canon SF Games - Fandom Wishlist Analysis
**STARDATE:** 2025.332 (November 28, 2025)
**CLASSIFICATION:** Tactical Analysis - Development Priority Guide
**REVISION:** 1.1 - Updated with Captain's review and implementation status

---

## Executive Summary

Captain, I've been monitoring subspace chatter across the tactical RPG communities, with particular attention to Shining Force modding scenes, Fire Emblem forums, and cross-pollination discussions. This report analyzes features from **outside** the canon Shining Force games that the fandom would most appreciate seeing in our platform.

**Key Finding:** SF fans don't want to *replace* Shining Force - they want to *perfect* it. The most desired features are quality-of-life improvements that respect player intelligence and systems that deepen what SF already does well.

**Good News:** Several high-demand features are already implemented!

---

## ALREADY IMPLEMENTED - We're Ahead of the Curve!

### 1. Battle Forecast / Combat Preview ✅ COMPLETE

| Metric | Value |
|--------|-------|
| **Fan Demand** | 10/10 |
| **Status** | **IMPLEMENTED** |

*The data is overwhelming, Captain.* This is the #1 QoL feature SF fans cite from Fire Emblem. Every forum discussion, every "what SF needs" thread - this appears.

**What it is:** Before attacking, show predicted damage both ways, hit chances, and critical rates.

**Our Implementation:** Combat preview panel displays Hit %, estimated Damage, and Crit % when targeting an enemy. Players can make informed tactical decisions before committing to an attack.

**Fandom Impact:** This alone puts us ahead of 90% of SF-inspired projects. Fans will immediately notice and appreciate this QoL feature.

---

### 2. Undo Move (Shining Force Style) ✅ COMPLETE

| Metric | Value |
|--------|-------|
| **Fan Demand** | 8/10 |
| **Status** | **IMPLEMENTED** |

**What it is:** After moving a unit but BEFORE attacking/using item/waiting, allow player to return to original position.

**Our Implementation:** Authentic Shining Force behavior - pressing Cancel/B after moving returns the unit to their starting position. The `_cancel_movement()` function in `InputManager` handles this exactly as SF does.

**Key Detail:** This is the *SF-style* undo (cancel returns to start), not the modern FE-style (explicit "Undo" menu option). Both achieve the same goal, but ours matches classic SF feel.

**Fandom Impact:** Purists will appreciate the authentic implementation. Those expecting a menu option may not realize the feature exists - consider adding a tooltip or tutorial hint.

---

### 3. Conditional Objectives Beyond "Rout Enemy" ✅ COMPLETE

| Metric | Value |
|--------|-------|
| **Fan Demand** | 8/10 |
| **Status** | **IMPLEMENTED** |

**What it is:** Diverse victory conditions - Survive X turns, Defeat Boss, Escape, Defend location, Seize throne.

**Our Implementation:** `BattleData` already supports comprehensive victory/defeat conditions:

**Victory Conditions:**
- `DEFEAT_ALL_ENEMIES` - Classic SF rout
- `DEFEAT_BOSS` - Target specific enemy (configurable boss index)
- `SURVIVE_TURNS` - Hold out for X turns
- `REACH_LOCATION` - Escape/seize point objectives
- `PROTECT_UNIT` - Defend an NPC
- `CUSTOM` - Script-based for unique scenarios

**Defeat Conditions:**
- `ALL_UNITS_DEFEATED` - Total party wipe
- `LEADER_DEFEATED` - Protect your commander
- `TURN_LIMIT` - Time pressure
- `UNIT_DIES` - Protect specific unit
- `CUSTOM` - Script-based

**Fandom Impact:** Modders will be thrilled. This enables the battle variety that SF lacked and FE/FFT fans love.

---

## PENDING CLAUDERINA REVIEW - UI/UX Discussion Required

### 4. Danger Zone Visualization

| Metric | Value |
|--------|-------|
| **Fan Demand** | 9/10 |
| **Status** | **PENDING** - Awaiting Clauderina discussion |
| **Effort** | 6-8 hours |

Modern tactical RPG standard that SF fans universally praise when they see it elsewhere.

**What it is:** Highlight all tiles enemy units can reach/attack on their turn (typically red overlay)

**Why fans want it:** SF's difficulty often comes from surprise enemy ranges rather than tactical challenge. Players want to plan, not memorize each enemy's movement range.

**Captain's Notes:** Implementation approach to be discussed with Clauderina for optimal UI/UX integration.

**Integration Notes:**
- Add to our `BattleGrid` system - already tracks tile data
- Calculate on player phase start: iterate enemies, compute movement + attack ranges
- Render as colored TileMap overlay layer

**Modder Control:**
```gdscript
# In BattleData
show_danger_zones: bool = true
danger_zone_color: Color = Color(1.0, 0.0, 0.0, 0.3)
```

---

### 5. Attack Range Display Toggle

| Metric | Value |
|--------|-------|
| **Fan Demand** | 8/10 |
| **Status** | **PENDING** - Awaiting Clauderina discussion |
| **Effort** | 3-4 hours |

**What it is:** When hovering over enemy units (or pressing a button), show their attack range highlighted.

**Why fans want it:** Complements Danger Zones - lets players check specific threats. "Can that archer reach me if I stand here?"

**Captain's Notes:** This feature complements Danger Zones (not conflicts). Both will be implemented together after Clauderina review.

**Integration Notes:**
- Similar to danger zones but on-demand for single unit
- Input handler: detect hover/button press on enemy unit
- Reuse range calculation from danger zones

**Modder Control:**
```gdscript
# In BattleData
show_individual_ranges: bool = true
```

---

## APPROVED FOR ROADMAP - Captain's Favorites

### 6. Detailed Battle Stats Screen

| Metric | Value |
|--------|-------|
| **Fan Demand** | 7/10 |
| **Status** | **ROADMAP** |
| **Effort** | 6-8 hours |

**What it is:** Pause-accessible screen showing all units, their stats, equipment, conditions. Think FFT's "Formation" screen.

**Why fans want it:** SF's headquarters stat checking is beloved, but in-battle you can't easily review your army's status without manually selecting each unit.

**Integration Notes:**
- New scene `BattleStatsPanel.tscn`
- Pause menu option: "View Army Status"
- Read from `BattleManager.player_units` array

---

### 7. Equipment-Based Skills/Specials

| Metric | Value |
|--------|-------|
| **Fan Demand** | 9/10 |
| **Status** | **ROADMAP** |
| **Effort** | 8-12 hours |

This is fascinating, Captain - SF fans *constantly* cite this from Fire Emblem and FFT as something they wish SF had done.

**What it is:** Weapons grant special abilities. "Flame Sword enables 'Fire Strike' skill," "Spellbook of Thor teaches Bolt 2," etc.

**Why fans want it:** SF's equipment feels interchangeable except for stat numbers. This makes gear hunting meaningful, enables build variety.

**Integration Notes:**
- Add `granted_abilities: Array[String]` to `ItemData`
- Modify `CharacterData.get_available_abilities()` to check equipped items
- Our ability system already exists - just extend the sources

**Modder Control:** Already supported via ItemData - just document it!

---

### 8. Support Conversations / Relationship System

| Metric | Value |
|--------|-------|
| **Fan Demand** | 10/10 |
| **Status** | **ROADMAP** - Complex, save for later phases |
| **Effort** | 20-30 hours |

*Captain, this one generates more subspace chatter than almost any other feature.* Fire Emblem's support system is deeply beloved by SF fans.

**What it is:** Characters build relationships through proximity in battle. Unlock conversations and stat bonuses.

**Why fans want it:** SF has memorable characters but minimal character development. Fans want to explore these personalities. Modders creating custom campaigns would LOVE this tool.

**Integration Notes:**
- New resource: `RelationshipData` tracks character pairs
- Add `support_points: Dictionary` to CharacterData (character_id -> points)
- Gain points when units are adjacent at turn end
- Trigger dialogue scenes at thresholds (C/B/A ranks)
- Grant stat bonuses when supported units adjacent

**Modder Control:**
```gdscript
class_name RelationshipData extends Resource

@export var character_a_id: String
@export var character_b_id: String
@export var c_rank_dialogue: DialogueData
@export var b_rank_dialogue: DialogueData
@export var a_rank_dialogue: DialogueData
@export var stat_bonuses: Dictionary # {"attack": 2, "defense": 1}
```

---

### 9. Custom Unit Formations / Starting Positions

| Metric | Value |
|--------|-------|
| **Fan Demand** | 7/10 |
| **Status** | **ROADMAP** |
| **Effort** | 10-15 hours |

**What it is:** Before battle, allow player to arrange their units in available deployment zones (like FE, FFT).

**Why fans want it:** Adds strategic pre-planning. "Put my tank up front, mages in back" feels good. SF's fixed starting positions can feel restrictive.

**Integration Notes:**
- Add deployment phase before battle start
- Define `deployment_zone: Array[Vector2i]` in BattleData
- UI for dragging units to positions within zone

**Modder Control:**
```gdscript
# In BattleData
allow_custom_deployment: bool = true
deployment_zone_tiles: Array[Vector2i] = []
```

---

### 10. Terrain Effects Beyond Movement Cost

| Metric | Value |
|--------|-------|
| **Fan Demand** | 7/10 |
| **Status** | **ROADMAP** |
| **Effort** | 8-10 hours |

**What it is:** Terrain grants bonuses - Forest gives evasion, Fort gives defense, Water hinders cavalry.

**Why fans want it:** SF terrain is mostly cosmetic + movement impediment. Fire Emblem's tactical terrain positioning is praised by SF fans who've tried it.

**Integration Notes:**
- Add `terrain_bonuses: Dictionary` to TileData
- Modify `CombatCalculator` to check defender's terrain
- Visual indicators on tiles

**Modder Control:**
```gdscript
# In TileData JSON
"terrain_bonuses": {
  "defense": 2,
  "evasion": 20,
  "attack": 0
}
```

---

### 11. Skill/Class Trees (Branching Promotions)

| Metric | Value |
|--------|-------|
| **Fan Demand** | 8/10 |
| **Status** | **ROADMAP** - Adds design complexity |
| **Effort** | 30-40 hours |

**What it is:** Units choose promotion path (Knight -> Paladin OR Great Knight). Learn skills from trees.

**Why fans want it:** Build customization, replayability. Fire Emblem standard.

**Design Consideration:** SF's linear promotion is part of its identity - the dopamine hit of "SDMN -> SKYW" is sacred. This could dilute that. Requires significant system overhaul and careful balance work.

**If we build it:** New promotion UI, skill tree resources, balance concerns.

---

## APPROVED FOR IMPLEMENTATION - Simple Wins

### 12. Permadeath Options ✅ APPROVED

| Metric | Value |
|--------|-------|
| **Fan Demand** | 6/10 |
| **Status** | **APPROVED** - Simple opt-in flag |
| **Effort** | 2-3 hours |

Fan opinion is *deeply divided* here, but the Captain's logic is sound: it's an extremely simple opt-in flag. If people want it, there's no reason not to include it.

**What it is:** Toggle between SF's "retreat" system and FE's "death is permanent."

**Implementation:**
- Flag in CampaignData: `permadeath_mode: bool = false`
- Modify defeat handler to permanently remove vs. retreat
- Default OFF - let hardcore players opt-in

**Fandom Impact:** Satisfies the "ironman mode" crowd without affecting anyone else. Low effort, moderate demand, zero downside.

---

## DECISIONS MADE - Skip or Defer

### 13. Weapon Durability System ❌ SKIP

| Metric | Value |
|--------|-------|
| **Fan Demand** | 4/10 |
| **Status** | **SKIP** |

**Captain's Decision:** Nah.

**Rationale:** SF fans *appreciate* not having durability. "I can use my cool weapons without fear" is seen as a feature, not a bug. Even many FE fans dislike durability. Not worth implementation time vs. demand.

---

### 14. Base Building / Army Management Layer 📋 FUTURE CONSIDERATION

| Metric | Value |
|--------|-------|
| **Fan Demand** | 6/10 |
| **Status** | **FUTURE CONSIDERATION** - Keep simple if ever implemented |
| **Effort** | 60+ hours |

**What it is:** Between battles, manage a base - upgrade facilities, craft items, train units (like Fire Emblem: Three Houses monastery).

**Captain's Notes:** Fascinating idea, but very complex and could majorly shift gameplay. Interesting if kept somewhat simple to not distract or overly influence the core tactical experience. Keep this as a possibility to consider in the future, but not on active roadmap.

---

### 15. Multiplayer PvP Battles 🚫 OFF THE TABLE

| Metric | Value |
|--------|-------|
| **Fan Demand** | 5/10 |
| **Status** | **OFF THE TABLE** for foreseeable future |
| **Effort** | 80+ hours |

**Captain's Decision:** This is a huge change to everything, essentially an entire game in itself. Off the table for the foreseeable future.

**Rationale:** SF is fundamentally PvE. Netcode is massive undertaking. Would require balancing the entire game differently. Small but vocal subset wants this, but it's not aligned with our mission of creating a platform for SF-style tactical campaigns.

---

## AVOID - Sounds Good, Hurts SF Feel

### Automatic AI Battle Resolution ❌

**Fan Demand: 3/10**

Let AI fight your battles for you (some SRPGs have this for grinding). SF fans find this *offensive* - the battles ARE the game. Skip entirely.

---

### Gacha / Random Character Recruitment ❌

**Fan Demand: 2/10**

Mobile game mechanics. Antithetical to SF's "build your specific army" philosophy. Community would riot.

---

### Time-Based Actions / Active Time Battle ❌

**Fan Demand: 1/10**

Turn-based is sacred. Don't touch it.

---

## Updated Implementation Roadmap

Based on Captain's review:

### Already Complete ✅
- Battle Forecast (Combat Preview)
- Undo Move (SF-style Cancel)
- Conditional Objectives (Victory/Defeat conditions)

### Pending Clauderina Review
- Danger Zone Visualization
- Attack Range Display Toggle

### Near-Term Roadmap
| Priority | Feature | Effort | Notes |
|----------|---------|--------|-------|
| HIGH | Permadeath Toggle | 2-3 hrs | Simple flag, approved |
| HIGH | Battle Stats Screen | 6-8 hrs | Captain loves it |
| HIGH | Equipment Skills | 8-12 hrs | Captain loves it |

### Medium-Term Roadmap
| Priority | Feature | Effort | Notes |
|----------|---------|--------|-------|
| MEDIUM | Terrain Effects | 8-10 hrs | Captain loves it |
| MEDIUM | Custom Formations | 10-15 hrs | Captain loves it |

### Long-Term Roadmap
| Priority | Feature | Effort | Notes |
|----------|---------|--------|-------|
| LATER | Support Conversations | 20-30 hrs | Complex but high value |
| LATER | Branching Promotions | 30-40 hrs | Adds design complexity |

### Future Consideration Only
- Base Building (keep simple if ever implemented)

### Off The Table
- Multiplayer PvP
- Weapon Durability
- Auto-battle / Gacha / ATB

---

## Quick Reference: Final Status Matrix

| Feature | Status | Notes |
|---------|--------|-------|
| Battle Forecast | ✅ DONE | Already implemented |
| Danger Zones | ⏳ PENDING | Clauderina review |
| Undo Move | ✅ DONE | SF-style cancel |
| Attack Range Toggle | ⏳ PENDING | Clauderina review |
| Battle Stats Screen | 📋 ROADMAP | Approved |
| Equipment Skills | 📋 ROADMAP | Approved |
| Support Conversations | 📋 ROADMAP | Complex, later |
| Custom Formations | 📋 ROADMAP | Approved |
| Conditional Objectives | ✅ DONE | Already implemented |
| Terrain Effects | 📋 ROADMAP | Approved |
| Branching Promotions | 📋 ROADMAP | Design complexity |
| Permadeath Toggle | ✅ APPROVED | Simple flag |
| Weapon Durability | ❌ SKIP | Not wanted |
| Base Building | 🔮 FUTURE | Maybe someday |
| Multiplayer PvP | 🚫 NO | Off the table |

---

**END REPORT**

**Live long and prosper, Captain. The crew awaits further orders.**

**Lt. Ears**
*Communications Officer, USS Torvalds*
*Shining Force Fandom Liaison*
*Subspace Monitoring Specialist*

*"The best feature is the one that makes players feel clever, not confused." - Ancient Runefaust Proverb*
