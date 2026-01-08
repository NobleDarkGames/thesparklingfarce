# Debug Console Commands

**Toggle Keys**: F1, F12, or tilde (~)
**Close**: ESC or toggle key again

## Command Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Fully implemented |
| ⚠️ | Partial/conditional |
| 🔸 | Stub (not yet implemented) |

---

## Hero Commands (`hero.*`)

| Command | Arguments | Status | Description |
|---------|-----------|--------|-------------|
| `hero.give_gold` | `<amount>` | ✅ | Add gold to party via SaveManager. |
| `hero.set_level` | `<level>` | 🔸 | Set hero level directly. Level system doesn't support direct setting. |
| `hero.heal` | (none) | ✅ | Fully heal hero's HP and MP via CharacterSaveData. |
| `hero.give_item` | `<item_id> [count]` | ✅ | Add item(s) to hero's inventory. Validates item exists in registry. |

---

## Party Commands (`party.*`)

| Command | Arguments | Status | Description |
|---------|-----------|--------|-------------|
| `party.grant_xp` | `<name> <amount>` | ✅ | Grant XP to character by name. Uses CharacterSaveData. |
| `party.add` | `<character_id>` | ✅ | Add character to party by registry ID. |
| `party.remove` | `<name>` | ✅ | Remove character from party by name. Cannot remove hero. |
| `party.list` | (none) | ✅ | List all party members with level and hero marker. |
| `party.heal_all` | (none) | ✅ | Fully heal all party members' HP and MP. |

---

## Campaign Commands (`campaign.*`)

| Command | Arguments | Status | Description |
|---------|-----------|--------|-------------|
| `campaign.set_flag` | `<name> [value]` | ✅ | Set story flag via GameState. Default value is `true`. |
| `campaign.clear_flag` | `<name>` | ✅ | Remove/clear story flag via GameState. |
| `campaign.list_flags` | (none) | ✅ | Show all story flags sorted alphabetically with colored values. |
| `campaign.trigger` | `<trigger_id>` | ⚠️ | Fire trigger manually. Depends on TriggerManager.fire_trigger() being available. |

---

## Battle Commands (`battle.*`)

| Command | Arguments | Status | Description |
|---------|-----------|--------|-------------|
| `battle.win` | (none) | ✅ | Force victory by killing all enemy units. Requires active battle. |
| `battle.lose` | (none) | ✅ | Force defeat by killing all player units. Requires active battle. |
| `battle.spawn` | `<unit_id> <x> <y>` | 🔸 | Spawn unit at grid position. Mid-battle spawning not implemented. |
| `battle.kill` | `<name>` | ✅ | Kill specific unit by display name. Searches all units. |

---

## Debug Commands (`debug.*`)

| Command | Arguments | Status | Description |
|---------|-----------|--------|-------------|
| `debug.clear` | (none) | ✅ | Clear console output. |
| `debug.fps` | `<value>` | ✅ | Set Engine.max_fps to specified value. |
| `debug.reload_mods` | (none) | ✅ | Reload mod registry via ModLoader.reload_mods(). |
| `debug.scene` | `<path>` | ✅ | Change to scene. Auto-prepends `res://` and `.tscn` if missing. |

---

## General Commands

| Command | Arguments | Status | Description |
|---------|-----------|--------|-------------|
| `help` | (none) | ✅ | Display all available commands including mod-registered ones. |
| `clear` | (none) | ✅ | Alias for `debug.clear`. |

---

## Mod Extension API

Mods can register custom commands using the following API:

```gdscript
# Register a command
DebugConsole.register_command(
    "weather",                    # Command name
    _cmd_weather,                 # Callable(args: Array) -> String
    "Set weather: weather <type>", # Help text
    "my_weather_mod"              # Mod ID (optional)
)

# Unregister all commands from a mod (for hot-reload)
DebugConsole.unregister_mod_commands("my_weather_mod")
```

Mod commands appear in the help output under "--- Mod Commands ---" with their mod ID shown in brackets.

---

## Features

- **Quote-aware parsing**: Arguments with spaces can be quoted
  Example: `party.grant_xp "Mr. Big Hero Face" 1000`

- **Type coercion**: Arguments auto-convert to int, float, bool, or string
  Example: `campaign.set_flag my_flag true` → sets boolean `true`

- **Command history**: Use Up/Down arrows to navigate previous commands

- **Output colors**:
  - Cyan: Info messages
  - Green: Success messages
  - Red: Error messages
  - Gray: Command echo
