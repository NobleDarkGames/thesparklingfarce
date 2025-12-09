# Shop UX Refactor Status

## Current Issue
Shop UI changes not taking effect in-game despite code changes. Need to verify Godot is reloading the script.

## What Was Done

### 1. Gold System Connected (COMPLETE)
- Added `SaveManager.current_save` to track active save
- Fixed `ShopManager._get_gold()/_set_gold()` to use proper autoload access
- Connected debug console gold commands (`hero.gold`, `hero.give_gold`, `hero.set_gold`)
- Added `SaveManager.set_current_save()` calls in `save_slot_selector.gd` for new/load game

### 2. Shop UX Refactor (CODE COMPLETE, NOT VERIFIED WORKING)
File: `scenes/ui/shops/shop_interface.gd`

**New Flow:**
1. Select Item (left column)
2. Select Destination - click character name OR "STORE IN CARAVAN" to HIGHLIGHT (not buy)
3. Click BUY button to confirm - shows "BUY FOR 15G" when ready

**Key Changes Made:**
- Renamed `selected_character_uid` → `selected_destination`
- Added `_selected_destination_button` for highlight tracking
- Added `COLOR_SELECTED` constant for blue highlight
- Changed `_on_character_selected()` → `_on_destination_selected()` - now just highlights
- Added `_clear_destination_selection()` helper
- Added `_update_buy_button_state()` - enables BUY when item+dest selected, updates text
- Modified `_on_buy_pressed()` to execute purchase when ready
- Caravan integrated as selectable destination (Option A)

**Debug prints added** at lines 449, 524, etc. - look for `[SHOP]` in console

## Files Changed (All Staged)
1. `core/systems/save_manager.gd` - current_save tracking
2. `core/systems/shop_manager.gd` - fixed autoload access
3. `core/systems/debug_console.gd` - gold commands
4. `mods/_base_game/scenes/ui/save_slot_selector.gd` - set current_save on game start
5. `scenes/ui/shops/shop_interface.gd` - UX refactor

## Next Steps
1. Verify script is reloading (check for [SHOP] debug output)
2. If no output: force reload via Project → Reload Current Project
3. Remove debug prints once working
4. Test full buy flow: item → destination → BUY button
5. Commit all changes

## Test Commands
```
# Debug console commands to test gold:
debug.create_test_save
hero.gold
hero.give_gold 500
hero.set_gold 1000
```
