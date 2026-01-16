# Godot Testing Reference (GdUnit4)

Agent reference for automated testing in The Sparkling Farce. Optimized for quick lookup.

---

## Test Categories

| Type | Scope | Dependencies | Location |
|------|-------|--------------|----------|
| **Unit** | Single class/function | None (no autoloads, no scenes) | `tests/unit/` |
| **Integration** | Multiple systems together | Autoloads, scenes, signals | `tests/integration/` |
| **Functional** | Full user workflows | Complete game environment | `tests/functional/` |

### Decision Matrix: Where Does This Test Belong?

```
Does it access an autoload singleton? (SaveManager, PartyManager, etc.)
  YES → Integration test
  NO  ↓

Does it instantiate a scene (.tscn)?
  YES → Integration test
  NO  ↓

Does it test a single class in isolation?
  YES → Unit test
  NO  → Integration test
```

---

## GdUnit4 Test Structure

### Basic Template

```gdscript
class_name TestMyFeature
extends GdUnitTestSuite

# Lifecycle: before() → [before_test() → test_X() → after_test()]* → after()

func before() -> void:
    # Runs ONCE before all tests in this file
    pass

func after() -> void:
    # Runs ONCE after all tests complete
    pass

func before_test() -> void:
    # Runs before EACH test function
    pass

func after_test() -> void:
    # Runs after EACH test function
    pass

func test_something() -> void:
    # Test functions MUST start with "test_"
    assert_bool(true).is_true()
```

### Memory Management

```gdscript
# auto_free() - freed when test scope ends
var obj: Node = auto_free(Node.new())

# Nodes in scene tree: queue_free + await
func after_test() -> void:
    if _node and is_instance_valid(_node):
        _node.queue_free()
        await _node.tree_exited
    _node = null

# Nodes NOT in tree (orphans): free() directly
func after_test() -> void:
    if _mock and is_instance_valid(_mock):
        _mock.free()
    _mock = null
```

### Orphan Prevention

**Rule**: Always `add_child()` immediately after `.new()`. Hide with `visible = false` if needed.

| Node Type | Cleanup Method |
|-----------|----------------|
| In scene tree | `queue_free()` + `await tree_exited` |
| Not in tree (mocks) | `free()` directly |
| auto_free() wrapped | Automatic |

---

## Unit Tests

### Characteristics
- Test ONE class/function in isolation
- NO autoload access (SaveManager, GameState, etc.)
- NO scene instantiation
- Create all test data inline
- Fast execution (<100ms per test)

### Correct Pattern

```gdscript
class_name TestGrid
extends GdUnitTestSuite

func test_manhattan_distance() -> void:
    # Create test data inline - no external dependencies
    var grid: Grid = Grid.new()
    grid.grid_size = Vector2i(10, 10)
    grid.cell_size = 32

    var distance: int = grid.get_manhattan_distance(Vector2i(0, 0), Vector2i(3, 4))

    assert_int(distance).is_equal(7)
```

### Anti-Patterns (DO NOT)

```gdscript
# WRONG: Accessing autoload in unit test
func test_bad_unit_test() -> void:
    SaveManager.current_save = SaveData.new()  # NO - use integration test

# WRONG: Loading from mod directories
func test_another_bad_test() -> void:
    var item: ItemData = load("res://mods/_base_game/data/items/sword.tres")  # NO

# WRONG: Silent pass on missing resources
func test_silent_fail() -> void:
    var resource = load("res://might/not/exist.tres")
    if resource:  # This silently passes if file missing
        assert_object(resource).is_not_null()
```

---

## Integration Tests

### Characteristics
- Test multiple systems working together
- MAY access autoloads
- MAY instantiate scenes
- Should use GdUnitTestSuite (not Node2D)
- Save/restore global state

### Correct Pattern

```gdscript
class_name TestShopIntegration
extends GdUnitTestSuite

var _original_gold: int

func before_test() -> void:
    # Save global state
    _original_gold = StorageManager.get_gold()

func after_test() -> void:
    # Restore global state
    StorageManager.set_gold(_original_gold)

func test_purchase_reduces_gold() -> void:
    StorageManager.set_gold(1000)

    ShopManager.purchase_item("healing_herb", 10)

    assert_int(StorageManager.get_gold()).is_equal(990)
```

### Scene Testing with scene_runner()

```gdscript
func test_button_click() -> void:
    var runner: GdUnitSceneRunner = scene_runner("res://scenes/ui/menu.tscn")

    # Simulate input
    await runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)

    # Wait for signal
    await runner.await_signal("button_pressed", [], 2000)

    # Assert scene state
    var scene: Node = runner.scene()
    assert_bool(scene.is_menu_open).is_true()
```

---

## Waiting and Async

### Preferred Methods (Fast)

```gdscript
# Wait for signal (best)
await await_signal_on(emitter, "signal_name", [], 2000)

# Wait single frame
await await_idle_frame()

# Wait specific milliseconds (use sparingly)
await await_millis(100)
```

### Anti-Pattern (Slow)

```gdscript
# WRONG: Creating timers in tests
await get_tree().create_timer(1.0).timeout  # NO - use await_millis() or signals

# WRONG: Timer in _process()
func _process(_delta: float) -> void:
    await get_tree().create_timer(5.0).timeout  # NEVER do this
```

---

## Mocking

### When to Mock
- External services (network, file I/O)
- Complex dependencies that are slow to set up
- Isolating the unit under test

### Creating Mocks

```gdscript
func test_with_mock() -> void:
    # Create mock of a class
    var mock_service = mock(MyService)

    # Configure return values
    do_return(42).on(mock_service).get_value()

    # Use mock in test
    var result: int = mock_service.get_value()
    assert_int(result).is_equal(42)

    # Verify method was called
    verify(mock_service, 1).get_value()
```

### Creating Spies

```gdscript
func test_with_spy() -> void:
    var real_object: MyClass = MyClass.new()
    var spy_object = spy(real_object)

    # Calls go to real implementation but are tracked
    spy_object.do_something()

    # Verify call happened
    verify(spy_object, 1).do_something()
```

---

## Assertions Reference

### Common Assertions

```gdscript
# Boolean
assert_bool(value).is_true()
assert_bool(value).is_false()

# Numbers
assert_int(value).is_equal(expected)
assert_int(value).is_greater(min)
assert_int(value).is_between(min, max)
assert_float(value).is_equal_approx(expected, tolerance)

# Strings
assert_str(value).is_equal("expected")
assert_str(value).starts_with("prefix")
assert_str(value).contains("substring")

# Objects
assert_object(obj).is_not_null()
assert_object(obj).is_instanceof(MyClass)

# Arrays
assert_array(arr).has_size(3)
assert_array(arr).contains([item1, item2])

# Signals
assert_signal(emitter).is_emitted("signal_name")
```

---

## Test Fixtures

### Shared Fixtures Pattern

Create reusable test data factories in `tests/fixtures/`:

```gdscript
# tests/fixtures/character_factory.gd
class_name CharacterFactory
extends RefCounted

static func create_test_character(
    name: String = "TestChar",
    hp: int = 100,
    strength: int = 10
) -> CharacterData:
    var char: CharacterData = CharacterData.new()
    char.character_name = name
    char.base_hp = hp
    char.base_strength = strength
    return char
```

### Signal Tracking Helper

```gdscript
# tests/fixtures/signal_tracker.gd
class_name SignalTracker
extends RefCounted

var _connections: Array[Dictionary] = []
var received_signals: Array[Dictionary] = []

func track(sig: Signal, callable: Callable) -> void:
    sig.connect(callable)
    _connections.append({"signal": sig, "callable": callable})

func disconnect_all() -> void:
    for conn in _connections:
        if conn.signal.is_connected(conn.callable):
            conn.signal.disconnect(conn.callable)
    _connections.clear()
```

---

## Testing Autoload-Dependent Code

### Option 1: Move to Integration Tests (Preferred)

If code requires autoloads, test it as integration test.

### Option 2: Dependency Injection

Refactor code to accept dependencies:

```gdscript
# BEFORE (hard to test)
class MyClass:
    func do_thing() -> void:
        var gold: int = StorageManager.get_gold()  # Autoload dependency

# AFTER (testable)
class MyClass:
    var _storage: StorageInterface

    func _init(storage: StorageInterface = null) -> void:
        _storage = storage if storage else StorageManager

    func do_thing() -> void:
        var gold: int = _storage.get_gold()
```

### Option 3: State Save/Restore

```gdscript
var _original_state: Dictionary

func before_test() -> void:
    _original_state = {
        "gold": StorageManager.get_gold(),
        "flags": GameState.get_all_flags().duplicate()
    }

func after_test() -> void:
    StorageManager.set_gold(_original_state.gold)
    GameState.clear_all_flags()
    for flag in _original_state.flags:
        GameState.set_flag(flag, _original_state.flags[flag])
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `if resource:` silent pass | Fail explicitly if missing |
| Timer in `_process()` | Use signals or elapsed time |
| Loading from `mods/` in unit test | Create data inline |
| Missing `is_instance_valid()` | Check before `queue_free()` |
| Node `.new()` without `add_child()` | Add to tree immediately, hide if needed |
| `queue_free()` on orphan | Use `free()` for nodes not in tree |
| Missing `await tree_exited` | Add after `queue_free()` |

---

## CI/CD Command Line

```bash
# Run all tests
./addons/gdUnit4/runtest.sh --add "res://tests"

# Run specific directory
./addons/gdUnit4/runtest.sh --add "res://tests/unit/combat"

# With headless mode (required for CI)
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode --add "res://tests/unit"

# Generate reports
# HTML: reports/report_*/index.html
# XML:  reports/report_*/results.xml
```

---

## Quick Reference: Test Lifecycle

```
Test Suite Load
    ↓
before()                    [once per file]
    ↓
┌─► before_test()           [before each test]
│       ↓
│   test_function()         [the actual test]
│       ↓
│   after_test()            [after each test]
│       ↓
└── [next test]
    ↓
after()                     [once per file]
    ↓
Test Suite Unload
```

---

## Sources

- [GdUnit4 GitHub](https://github.com/MikeSchulze/gdUnit4)
- [GdUnit4 Documentation](https://godot-gdunit-labs.github.io/gdUnit4/latest/)
- [Godot Autoloads Best Practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_internal_nodes.html)
- [Software Testing Types - Atlassian](https://www.atlassian.com/continuous-delivery/software-testing/types-of-software-testing)
