# Debug Console Implementation Plan

**Status**: Approved - Awaiting Implementation
**Approach**: Hybrid (Match + Dictionary Extension)
**Estimated Scope**: ~300 lines, 1 script + 1 scene

---

## Overview

A quake-style dropdown debug console for developer testing. Allows manipulation of game state without replaying battles/events.

### Core Requirements

1. **F12 toggle** - Dropdown from top of screen
2. **Namespaced commands** - `hero.give_gold 1000`, `campaign.set_flag name true`
3. **Quoted argument support** - `party.grant_xp "Mr. Big Hero Face" 1000`
4. **Command history** - Up/down arrow navigation
5. **Mod extensibility** - Simple API for mods to register custom commands

---

## Architecture Decision

### The Hybrid Approach

After review by Commander Claudius (scope), Lt. Claudbrain (planning), Chief Engineer O'Brien (engineering), and Modro (mod architecture), the team reached consensus:

**Core commands use match statements** (readable, fast, explicit)
**Mod commands use dictionary lookup** (simple extension point)

This balances:
- Platform philosophy ("the game is just a mod")
- Engineering simplicity (no heavy registry infrastructure)
- Maintainability (core commands visible in code)

### Why Not Pure Match Statements (~250 lines)

- Inconsistent with platform philosophy
- Total conversion mods cannot debug their custom content
- Would require breaking refactor later when mods need commands

### Why Not Full Registry (~500+ lines)

- Overkill for developer tooling
- Commands don't need mod.json discovery, categories, or display names
- Simple dictionary is sufficient for registration

### The Hybrid Sweet Spot (~300 lines)

```gdscript
# Core commands: Match statement
match command:
    "hero": return _cmd_hero(args)
    "party": return _cmd_party(args)
    "campaign": return _cmd_campaign(args)

# Mod commands: Dictionary lookup
if command in mod_commands:
    return mod_commands[command].callback.call(args)
```

---

## File Structure

```
core/
  systems/
    debug_console.gd      # All logic in one file (~300 lines)
    debug_console.tscn    # Simple UI scene
```

Register as autoload in `project.godot`:
```ini
[autoload]
DebugConsole="*res://core/systems/debug_console.tscn"
```

---

## Extension API

### Registration (~25 lines of infrastructure)

```gdscript
## Mod-registered commands: {command_name: {callback: Callable, help: String, mod_id: String}}
var mod_commands: Dictionary = {}

## Register a command from a mod
func register_command(command_name: String, callback: Callable, help_text: String, mod_id: String = "") -> void:
    var name_lower: String = command_name.to_lower()
    if name_lower in mod_commands:
        push_warning("DebugConsole: Command '%s' overridden by mod '%s'" % [command_name, mod_id])
    mod_commands[name_lower] = {
        "callback": callback,
        "help": help_text,
        "mod_id": mod_id
    }

## Unregister all commands from a mod (for hot-reload)
func unregister_mod_commands(mod_id: String) -> void:
    var to_remove: Array[String] = []
    for cmd: String in mod_commands:
        if mod_commands[cmd].get("mod_id", "") == mod_id:
            to_remove.append(cmd)
    for cmd: String in to_remove:
        mod_commands.erase(cmd)
```

### Mod Usage Example

```gdscript
# In a mod's autoload script:
func _ready() -> void:
    if Engine.is_editor_hint():
        return
    DebugConsole.register_command(
        "weather",
        _cmd_weather,
        "Set weather: weather <type>",
        "my_weather_mod"
    )

func _cmd_weather(args: Array[String]) -> String:
    if args.is_empty():
        return "Usage: weather <type>"
    # Implementation...
    return "Weather set to: %s" % args[0]
```

### What We're NOT Building

- ❌ Separate `CommandRegistry` class
- ❌ `mod.json` command discovery
- ❌ `ConsoleCommand` base class
- ❌ Categories, display names, or rich metadata
- ❌ Autocomplete (deferred to future enhancement)

---

## UI Design

### Layout

```
┌─────────────────────────────────────────────────────────┐
│ DEBUG CONSOLE                                    [F12]  │  ← Header
├─────────────────────────────────────────────────────────┤
│ > hero.give_gold 1000                                   │  ← Output
│ [OK] Added 1000 gold                                    │     (scrollable)
│ > party.grant_xp "Mr. Big" 500                          │
│ [ERROR] Character not found: Mr. Big                    │
├─────────────────────────────────────────────────────────┤
│ > █                                                     │  ← Input
└─────────────────────────────────────────────────────────┘
```

### Visual Style

- **Background**: `Color(0.05, 0.05, 0.1, 0.95)` - Dark, semi-transparent
- **Text**: Monogram font, 16px
- **Height**: 40% of screen
- **Animation**: Simple slide down (0.2s tween)

### Output Colors

| Type | Color | BBCode |
|------|-------|--------|
| Default | White | (none) |
| Success | Green | `[color=#66E680]` |
| Error | Red | `[color=#FF6666]` |
| Info | Cyan | `[color=#80D9FF]` |
| Command echo | Muted | `[color=#B3B3D9]` |

---

## Command Parsing

### Tokenizer (Quote-Aware)

Splits input on spaces while preserving quoted strings:

```
Input:  party.grant_xp "Mr. Big Hero Face" 1000
Tokens: ["party.grant_xp", "Mr. Big Hero Face", "1000"]
```

Implementation (~20 lines):

```gdscript
func _tokenize(text: String) -> Array[String]:
    var tokens: Array[String] = []
    var current: String = ""
    var in_quotes: bool = false
    var quote_char: String = ""

    for i: int in range(text.length()):
        var c: String = text[i]
        if not in_quotes and (c == '"' or c == "'"):
            in_quotes = true
            quote_char = c
        elif in_quotes and c == quote_char:
            in_quotes = false
            quote_char = ""
        elif not in_quotes and c == " ":
            if not current.is_empty():
                tokens.append(current)
                current = ""
        else:
            current += c

    if not current.is_empty():
        tokens.append(current)
    return tokens
```

### Type Coercion

```gdscript
func _convert_arg(arg: String) -> Variant:
    if arg.to_lower() == "true": return true
    if arg.to_lower() == "false": return false
    if arg.is_valid_int(): return arg.to_int()
    if arg.is_valid_float(): return arg.to_float()
    return arg
```

---

## Core Command Namespaces

### `hero.*` - Player/Leader Commands

| Command | Args | Description |
|---------|------|-------------|
| `hero.give_gold` | `<amount>` | Add gold to party |
| `hero.set_level` | `<level>` | Set hero level |
| `hero.heal` | (none) | Full heal hero |
| `hero.give_item` | `<item_id> [count]` | Add item to inventory |

### `party.*` - Party Management

| Command | Args | Description |
|---------|------|-------------|
| `party.grant_xp` | `<name> <amount>` | Grant XP to character |
| `party.add` | `<character_id>` | Add character to party |
| `party.remove` | `<name>` | Remove from party |
| `party.list` | (none) | List party members |
| `party.heal_all` | (none) | Full heal entire party |

### `campaign.*` - Story Flags & Progression

| Command | Args | Description |
|---------|------|-------------|
| `campaign.set_flag` | `<name> [value]` | Set story flag (default: true) |
| `campaign.clear_flag` | `<name>` | Remove story flag |
| `campaign.list_flags` | (none) | Show all flags |
| `campaign.trigger` | `<trigger_id>` | Fire a trigger manually |

### `battle.*` - Battle Testing

| Command | Args | Description |
|---------|------|-------------|
| `battle.win` | (none) | Instant victory |
| `battle.lose` | (none) | Instant defeat |
| `battle.spawn` | `<unit_id> <x> <y>` | Spawn unit at position |
| `battle.kill` | `<name>` | Kill unit |

### `debug.*` - System Commands

| Command | Args | Description |
|---------|------|-------------|
| `debug.clear` | (none) | Clear console output |
| `debug.fps` | `<value>` | Set max FPS |
| `debug.reload_mods` | (none) | Reload mod registry |
| `debug.scene` | `<path>` | Change to scene |

### `help` - Show Commands

Shows both core commands and mod-registered commands:

```
> help
=== Core Commands ===
hero.give_gold <amount> - Add gold to party
hero.set_level <level> - Set hero level
...

=== Mod Commands ===
weather <type> - Set weather type [my_weather_mod]
```

---

## Command Processing Flow

```gdscript
func _execute_command(raw_input: String) -> void:
    var tokens: Array[String] = _tokenize(raw_input.strip_edges())
    if tokens.is_empty():
        return

    var full_command: String = tokens[0].to_lower()
    var args: Array = []
    for i: int in range(1, tokens.size()):
        args.append(_convert_arg(tokens[i]))

    # Split namespace.command
    var parts: PackedStringArray = full_command.split(".", true, 1)
    var namespace: String = parts[0] if parts.size() == 2 else ""
    var command: String = parts[1] if parts.size() == 2 else parts[0]

    # Priority 1: Core commands (match statement)
    match namespace:
        "hero":
            _execute_hero_command(command, args)
            return
        "party":
            _execute_party_command(command, args)
            return
        "campaign":
            _execute_campaign_command(command, args)
            return
        "battle":
            _execute_battle_command(command, args)
            return
        "debug":
            _execute_debug_command(command, args)
            return
        "":
            if command == "help":
                _print_help()
                return

    # Priority 2: Mod-registered commands
    if full_command in mod_commands:
        var cmd_data: Dictionary = mod_commands[full_command]
        var result: String = cmd_data.callback.call(args)
        _print_line(result)
        return

    _print_error("Unknown command: %s. Type 'help' for available commands." % full_command)
```

---

## Scene Structure

```
DebugConsole (CanvasLayer, layer=100)
  └─ Panel (Control, anchors=top-wide)
      └─ MarginContainer (4px margins)
          └─ VBoxContainer
              ├─ HBoxContainer (header)
              │   ├─ Label ("DEBUG CONSOLE")
              │   └─ Label ("[F12]", right-aligned)
              ├─ HSeparator
              ├─ ScrollContainer (expand vertical)
              │   └─ RichTextLabel (bbcode=true, scroll_following=true)
              ├─ HSeparator
              └─ HBoxContainer
                  ├─ Label (">")
                  └─ LineEdit (expand horizontal)
```

---

## Input Action

Add to `project.godot`:

```ini
[input]
toggle_debug_console={
"events": [
    InputEventKey(keycode=KEY_F12),
    InputEventKey(keycode=KEY_QUOTELEFT)
]
}
```

---

## Integration Points

The debug console reads from existing singletons:

| Command | Singleton | Method |
|---------|-----------|--------|
| `campaign.set_flag` | `GameState` | `set_flag()` |
| `campaign.list_flags` | `GameState` | `story_flags` property |
| `party.grant_xp` | `PartyManager` | TBD |
| `hero.give_gold` | `PartyManager` | TBD |
| `battle.*` | `BattleManager` | Various |

---

## Implementation Order

1. Create `debug_console.tscn` with UI structure
2. Create `debug_console.gd` with:
   - Toggle and animation
   - Tokenizer with quote support
   - Type coercion
   - Extension API (register_command)
3. Add input action to project settings
4. Register as autoload
5. Implement `campaign.*` commands first (most useful for testing)
6. Implement remaining core command namespaces
7. Update `help` to show both core and mod commands
8. Test with actual game systems

---

## Testing Checklist

- [ ] F12 toggles console
- [ ] Tilde (~) also toggles
- [ ] ESC closes console
- [ ] Quoted arguments work: `"Mr. Big Hero Face"`
- [ ] Type coercion works (int, float, bool, string)
- [ ] Up/down arrow navigates history
- [ ] Error messages display in red
- [ ] Success messages display in green
- [ ] `help` shows all commands
- [ ] Mod command registration works
- [ ] Mod commands appear in help with attribution
- [ ] Console doesn't block game when hidden

---

---

# Appendix A: Full Registry Pattern (Deferred)

**Status**: Not implementing. Documented for reference if future needs require it.

### When to Consider Upgrading

- Command count exceeds 50+ and organization becomes unwieldy
- Need rich metadata (categories, argument schemas, validation)
- Need mod.json-based command discovery

### Architecture Overview

If we ever need to upgrade, follow the existing patterns:

```
core/
  systems/
    debug_console/
      debug_console.gd           # UI only
      debug_command_registry.gd  # Separate registry class
      console_command.gd         # Base class for commands
```

This would mirror `AIBrainRegistry` and `EditorTabRegistry` patterns.

---

# Appendix B: UI Polish (Deferred)

### Future Enhancement Queue

1. Tab completion with dropdown suggestions
2. Syntax highlighting for command parts
3. Draggable resize handle
4. Command aliases (`gg` → `hero.give_gold`)
5. Output filtering by namespace
6. `help <namespace>` for namespace-specific help
7. Persistent history between sessions

### Extended Color Palette

| Element | Color |
|---------|-------|
| Console Background | `Color(0.05, 0.05, 0.1, 0.98)` |
| Border | `Color(0.6, 0.6, 0.7, 1)` |
| Header Background | `Color(0.08, 0.08, 0.13, 1)` |
| Input Background | `Color(0.12, 0.12, 0.18, 1)` |
| Text Warning | `Color(1, 0.8, 0.3, 1)` |

### Animation Specifications

**Show**: 0.25s, `TRANS_CUBIC`, `EASE_OUT`
**Hide**: 0.2s, `TRANS_CUBIC`, `EASE_IN`

---

# Appendix C: Design Rationale

## Why Hybrid Over Pure Registry

| Aspect | Pure Registry | Hybrid |
|--------|---------------|--------|
| Core command visibility | Hidden in registration | Visible in match statement |
| New contributor clarity | Must trace registration | Can read match cases |
| Performance | Dictionary lookup always | Match first (faster) |
| Extension mechanism | Same for all | Dictionary for mods only |

## Why Match + Dictionary Over Match-Only

| Aspect | Match-Only | Match + Dictionary |
|--------|------------|-------------------|
| Platform philosophy | Violates "game is mod" | Respects it |
| Total conversion support | Cannot debug custom content | Full support |
| Future refactor risk | High (breaking change) | None |
| Extra code | 0 lines | ~25 lines |

The 25-line extension API is worth the platform consistency.
