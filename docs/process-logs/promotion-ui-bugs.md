# Promotion UI Bugs - Remaining Issues

**Date**: 2026-01-07  
**Status**: Church promotion system is functional but has three UI bugs

## Context

After a full day of debugging and fixing platform issues with NPC/shop interactions and resource ID handling, the church promotion system is now working end-to-end. The priest can be interacted with, the shop opens, and promotions can be completed. However, there are three remaining polish issues in the promotion UI flow.

---

## Bug 1: Base Class Name Not Displaying

**Symptom**: In the promotion path selection screen, the character's current base class shows as blank/empty instead of "Warrior" (or whatever the class name is).

**Screenshot**: See Screenshot from 2026-01-07 20-05-00.png

**Location**: `scenes/ui/shops/screens/church_promote_select.gd`

**Likely Cause**: The `_get_character_class_name()` helper function or similar method is not correctly retrieving the character's current class name for display.

**Investigation Needed**:
- Check how church_char_select.gd:169 gets class name (it works there)
- Compare with church_promote_select.gd implementation
- Verify CharacterSaveData.get_current_class() is working correctly
- Check if ClassData.display_name vs class_name property issue

---

## Bug 2: Promotion Result Screen Flashes By Too Quickly

**Symptom**: After selecting a promotion path and confirming, the "Kurt has been promoted!" result screen appears and disappears instantly - too fast to read.

**Location**: `scenes/ui/shops/screens/transaction_result.gd` or promotion ceremony flow

**Likely Cause**: 
- Missing input wait before auto-closing the screen
- Missing "press button to continue" prompt
- Timer-based auto-close that's too short
- Not waiting for player confirmation

**Investigation Needed**:
- Check if transaction_result.gd has proper input handling
- Look for auto-close timer or missing await for user input
- Compare with other result screens that work correctly
- Check if ModalManager should be managing input focus

**Expected Behavior**: Screen should stay visible until player presses a button (like confirm/cancel)

---

## Bug 3: No Input on Priest Menu After Promotion Closes

**Symptom**: After the promotion flow completes and returns to the church action menu, the menu is visible but doesn't respond to any input (buttons don't work, can't navigate).

**Location**: Shop screen navigation and modal system

**User Note**: "we do have a modal manager helper for controlling input for that stuff"

**Likely Causes**:
- ModalManager not being notified when promotion flow completes
- Input focus not being restored to church_action_select screen
- Screen stack corruption after promotion ceremony
- Missing call to grab_focus() on returning to menu

**Investigation Needed**:
- Check if ModalManager exists and how it should be used
- Verify shop_controller's screen stack management
- Look at how other shop flows (heal, revive) handle returning to menu
- Check if church_promote_select properly cleans up input state
- Verify ceremony dismissal properly returns control to shop

**Files to Check**:
- `scenes/ui/shops/shop_controller.gd` - Screen stack management
- `scenes/ui/shops/screens/church_promote_select.gd` - Cleanup after promotion
- `scenes/ui/promotion_ceremony.gd` - Input handling during ceremony
- Core modal manager system (search for ModalManager)

---

## Testing Steps to Reproduce

1. Start game, walk to priest NPC
2. Interact with priest (confirm button)
3. Select "Promote" from church menu
4. Select a character (e.g., Kurt)
5. **Bug 1**: Note class name is blank on promotion path screen
6. Select a promotion path
7. **Bug 2**: Note the "Kurt has been promoted!" screen flashes by instantly
8. **Bug 3**: After returning to church menu, buttons don't respond to input

---

## Priority

**Medium** - The core functionality works (promotion succeeds), but the UX is poor:
- Bug 1: Cosmetic - missing display information
- Bug 2: UX issue - player can't read the result message
- Bug 3: Critical UX - player is soft-locked and must cancel/escape out

**Recommended fix order**: Bug 3 (soft-lock), Bug 2 (readability), Bug 1 (cosmetic)

---

## Related Systems

- Modal/Input Manager (mentioned by user as existing helper)
- Shop screen stack navigation
- Promotion ceremony flow
- Transaction result screen timing
- Character class name resolution
