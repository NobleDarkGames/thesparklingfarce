# AGENTS.md - Development Guide for The Sparkling Farce

## Build/Test/Lint Commands

### Testing
- **Full test suite**: `./test_headless.sh` - Comprehensive automated testing (unit + integration)
- **Unit tests only**: `godot --headless res://tests/test_runner_scene.tscn`
- **Parser error check**: `godot --headless --check-only`
- **Map exploration test**: `./test_map_exploration.sh` - Interactive testing
- **Single test**: No specific single test command - use test runner scene

### Export/Build
- **Export presets**: Configured in `export_presets.cfg` for Linux/Windows/macOS
- **Export path**: `../build/farce/The Sparkling Farce.x86_64`

### Code Quality
- **Strict typing**: Enforced via project.godot debug settings
- **Parser validation**: `godot --headless --check-only`
- **No dedicated linter**: Use Godot's built-in warnings and static analysis

---

## Code Style Guidelines

### Core Requirements (ABSOLUTE)
1. **Strict typing required**: `var x: float = 5.0` not `var x := 5.0`
2. **Dictionary checks**: `if "key" in dict:` not `if dict.has("key"):`
3. **Follow Godot Style Guide**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html

### Type System
- **All variables must have explicit types**: No type inference allowed
- **Function parameters typed**: `func do_something(param: String) -> void:`
- **Return types required**: `-> void`, `-> int`, `-> Array[String]`, etc.
- **Generic types for collections**: `Array[String]`, `Dictionary[String, int]`

### Naming Conventions
- **Classes**: PascalCase (e.g., `CharacterData`, `BattleManager`)
- **Variables/Functions**: snake_case (e.g., `character_data`, `load_character()`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HP`, `DEFAULT_SPEED`)
- **Private members**: Prefix with underscore (e.g., `_internal_state`)
- **Singletons**: PascalCase (e.g., `GameState`, `BattleManager`)

### File Organization
- **Platform code**: `core/` directory only
- **Game content**: `mods/` directory only
- **Resources**: `core/resources/` for platform, `mods/*/data/` for content
- **Systems**: `core/systems/` for autoload singletons
- **Components**: `core/components/` for reusable nodes

### Import Style
- **Preload resources**: `const ResourceClass = preload("res://path/to/resource.gd")`
- **Group imports**: Keep related imports together
- **Avoid wildcards**: Never use `*` imports
- **Order**: Constants → Classes → Functions → Variables

### Documentation
- **Class headers**: Comprehensive with purpose, integration notes, examples
- **Public functions**: Document parameters, return values, usage
- **Complex algorithms**: Inline comments explaining logic
- **Mod integration**: Document mod safety and namespacing requirements

### Error Handling
- **Guard clauses**: Early returns for invalid conditions
- **Type checking**: Use `is` operator for type validation
- **Null safety**: Check for null before accessing object members
- **Assert usage**: Use `assert()` for developer-time validation
- **Graceful degradation**: Provide fallbacks for missing resources

### Resource Access Patterns
```gdscript
# CORRECT - Use registry for all game content
ModLoader.registry.get_resource("character", "max")

# WRONG - Never direct load game content
load("res://mods/_base_game/data/characters/max.tres")

# OK - Core resources can be preloaded
const CharacterDataScript = preload("res://core/resources/character_data.gd")
```

### Mod Safety
- **Namespaced flags**: Use `"mod_id:flag_name"` pattern
- **Resource validation**: Check resource existence before use
- **Fallback behavior**: Provide defaults when mods missing
- **No hard dependencies**: Platform should work without any mods

### Performance Guidelines
- **Preload heavy resources**: Use constants for frequently accessed resources
- **Avoid expensive loops**: Cache results, use efficient algorithms
- **Memory management**: Free temporary resources when done
- **Batch operations**: Group similar operations to reduce overhead

### Architecture Patterns
- **Singleton managers**: 30+ autoload singletons handle game systems
- **Resource registry**: Centralized resource access via ModLoader
- **Event-driven communication**: Use GameEventBus for decoupled messaging
- **Component composition**: Build complex behavior from simple components

### Debugging
- **Debug console**: Available via backtick key in-game
- **Comprehensive logging**: Use structured logging with context
- **Headless testing**: All tests run without display server
- **Integration tests**: AI, battle flow, and system integration validated

---

## Project Structure

### Core Platform (`core/`)
- **mod_system/**: ModLoader, ModRegistry (platform infrastructure)
- **systems/**: 30+ autoload singletons (game managers)
- **resources/**: Platform resource classes and data structures
- **components/**: Reusable node components
- **registries/**: Type registries for resource management

### Game Content (`mods/`)
- **demo_campaign/**: Demo content (priority 100)
- **_platform_defaults/**: Core components (priority -1)
- **_starter_kit/**: Development assets and templates

### Testing (`tests/`)
- **test_runner_scene.gd**: Custom test runner system
- **integration/**: System integration tests
- **gdUnit4**: Unit testing framework integration

### Configuration
- **project.godot**: Main project configuration with strict typing enabled
- **export_presets.cfg**: Build/export configurations
- **CLAUDE.md**: AI assistant rules and guidelines

---

## Critical Rules

1. **NEVER commit without explicit instruction**
2. **NEVER place game content in `core/`**
3. **NEVER use type inference (`:=`)**
4. **ALWAYS use registry for game content access**
5. **ALWAYS follow strict typing requirements**
6. **REUSE existing code over writing new**
7. **RECOMMEND don't implement without approval**

### Git Rules (ADDED)
- **NEVER commit without explicit instruction** — staging is fine, commits require approval
- **NEVER generate markdown docs unless requested**

### Minimalism (ALL AGENTS) (ADDED)
- Do NOT implement unrequested features
- Do NOT expand scope without approval
- Reuse existing code over writing new
- "90% functionality for 50% code" is a good trade
- Recommend, don't implement without approval

---

## Testing Philosophy

- **Comprehensive automation**: Full test suite runs headless
- **Integration focus**: Test system interactions, not just units
- **AI validation**: Battle AI and decision making tested
- **Performance validation**: Tests complete within timeouts
- **Regression prevention**: All tests must pass for changes

---

## Tool Preferences

Prefer UNIX tools over LLM processing:
- **JSON**: `jq` for querying/filtering
- **Text**: `awk`, `sed`, `cut`, `sort`, `uniq`
- **Search**: `find`, `grep`, `xargs`
- **Files**: `stat`, `diff`, `wc`, `head`/`tail`

See CLAUDE.md for comprehensive tool reference.

---

## Architecture Philosophy

- **Stack simple systems**: Build complex behavior from simple, composable parts
- **Expose existing functionality**: UI gaps before new mechanics  
- **Leverage proven patterns**: Use existing solutions vs custom implementations
- **Avoid overengineering**: Prefer data stacking over complex systems
- **Platform-first**: Design tools for modders, not specific content

**Example:** Character abilities already stack (class + unique), so missing UI is just exposure, not new mechanics.

**Implementation Approach:**
- Identify actual gaps vs perceived ones
- Use existing ResourcePicker and FormBuilder patterns
- Add UI exposure before mechanical changes
- Validate through stacking and testing, not complex theory