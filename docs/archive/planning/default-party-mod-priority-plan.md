# Default Party Mod Priority System

**Status:** Planning
**Priority:** High (blocks proper mod testing)
**Created:** December 3, 2025

---

## Problem Statement

Currently, `save_slot_selector.gd` hardcodes the default party path:
```gdscript
var default_party: PartyData = load("res://mods/_base_game/data/parties/default_party.tres")
```

This violates the "game is just a mod" principle because:
1. Higher-priority mods (like `_sandbox` at priority 100) cannot override the starting party
2. Total conversion mods cannot define their own hero or starting companions
3. The hero character from `_sandbox` ("Mr Big Hero Face") is never used despite being the active test mod

---

## Proposed Solution

### Core Concept: Dynamic Default Party Resolution

The default party should be determined by the mod system, not hardcoded. The resolution order:

1. **Find the Hero:** Look for a character with `is_hero = true` from the highest-priority mod
2. **Find Default Party Members:** Look for characters with `is_default_party_member = true` from any loaded mod
3. **Build Party:** Hero first, then default party members sorted by mod priority

### New CharacterData Field

Add to `core/resources/character_data.gd`:
```gdscript
## If true, this character is included in the default starting party
## Only applies to player-category characters
## The hero is always included regardless of this flag
@export var is_default_party_member: bool = false
```

### New ModLoader Method

Add to `core/mod_system/mod_loader.gd`:
```gdscript
## Get the default party composition based on loaded mods
## Returns: Array of CharacterData in party order (hero first)
func get_default_party() -> Array[CharacterData]:
    var party: Array[CharacterData] = []

    # 1. Find the hero (highest priority mod wins)
    var hero: CharacterData = _find_hero_character()
    if hero:
        party.append(hero)

    # 2. Find default party members
    var members: Array[CharacterData] = _find_default_party_members()
    for member in members:
        if member != hero:  # Don't duplicate hero
            party.append(member)

    return party

func _find_hero_character() -> CharacterData:
    # Search all characters, highest priority mod first
    var all_characters: Array[Resource] = registry.get_all_resources("character")
    for character: CharacterData in all_characters:
        if character.is_hero and character.unit_category == "player":
            return character
    return null

func _find_default_party_members() -> Array[CharacterData]:
    var members: Array[CharacterData] = []
    var all_characters: Array[Resource] = registry.get_all_resources("character")
    for character: CharacterData in all_characters:
        if character.is_default_party_member and character.unit_category == "player":
            members.append(character)
    return members
```

### Updated save_slot_selector.gd

Replace hardcoded party loading:
```gdscript
# OLD (hardcoded):
var default_party: PartyData = load("res://mods/_base_game/data/parties/default_party.tres")

# NEW (mod-aware):
var default_characters: Array[CharacterData] = ModLoader.get_default_party()
if default_characters.is_empty():
    push_error("No hero character found in any loaded mod!")
    return

for character: CharacterData in default_characters:
    var char_save: CharacterSaveData = CharacterSaveData.new()
    char_save.populate_from_character_data(character)
    save_data.party_members.append(char_save)
```

---

## Implementation Steps

### Step 1: Add CharacterData Field
- [ ] Add `is_default_party_member: bool = false` to `core/resources/character_data.gd`
- [ ] Place it in the "Battle Configuration" export group near `is_hero`

### Step 2: Add ModLoader Method
- [ ] Add `get_default_party()` method to `core/mod_system/mod_loader.gd`
- [ ] Add helper methods `_find_hero_character()` and `_find_default_party_members()`

### Step 3: Update save_slot_selector.gd
- [ ] Remove hardcoded `default_party.tres` loading
- [ ] Use `ModLoader.get_default_party()` instead
- [ ] Add error handling for "no hero found" case

### Step 4: Update Test Characters
- [ ] Set `is_hero = true` on `_sandbox` hero ("Mr Big Hero Face")
- [ ] Optionally set `is_default_party_member = true` on other sandbox characters
- [ ] Ensure `_base_game` Max has `is_hero = true` (already done)

### Step 5: Update Tests
- [ ] Add test for `ModLoader.get_default_party()`
- [ ] Verify hero from highest-priority mod is selected
- [ ] Verify default party members are collected correctly

---

## Edge Cases

### No Hero Found
If no character has `is_hero = true`:
- Log error
- Optionally: Use first player-category character as fallback
- Or: Prevent new game creation with clear error message

### Multiple Heroes
If multiple mods define heroes:
- Highest priority mod's hero wins (standard override behavior)
- Other heroes become regular party members if `is_default_party_member = true`

### Empty Default Party
If hero exists but no default party members:
- Party starts with just the hero (valid for some game designs)
- This is acceptable - SF1 technically starts with just Max

### Mod Removal
If a save file references characters from a removed mod:
- Existing `_resolve_character_from_save()` handles this with fallback data
- No change needed

---

## Alternative Considered: Default Party Resource in mod.json

Could add to mod.json:
```json
{
  "default_party": ["max", "mae", "luke"]
}
```

**Rejected because:**
- Requires maintaining parallel data (character IDs in mod.json AND character resources)
- The `is_default_party_member` flag keeps all party config in the character resource
- Simpler for modders - just check a box in the editor

---

## Migration Path

### For _base_game
1. Set `is_hero = true` on Max (already done)
2. Set `is_default_party_member = true` on Warrioso and Maggie
3. `default_party.tres` becomes optional/deprecated

### For _sandbox
1. Set `is_hero = true` on Mr Big Hero Face (already done)
2. Optionally add other sandbox characters to default party
3. When testing, `_sandbox` hero will be used instead of Max

---

## Success Criteria

- [ ] Starting a new game uses the hero from the highest-priority mod
- [ ] `_sandbox` with priority 100 provides "Mr Big Hero Face" as hero
- [ ] `_base_game` with priority 0 provides "Max" as hero (when _sandbox not loaded)
- [ ] Default party members are collected from all loaded mods
- [ ] Total conversion mods can completely replace the starting party
- [ ] Existing saves continue to work (no migration needed)

---

## Estimated Effort

- CharacterData field: 5 minutes
- ModLoader methods: 30 minutes
- save_slot_selector update: 15 minutes
- Character updates: 10 minutes
- Testing: 30 minutes

**Total: ~1.5 hours**
