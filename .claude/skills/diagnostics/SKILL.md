---
name: diagnostics
description: Run the project test suite. Use when user mentions "diagnostics", "run level 1 diagnostics", or asks to run tests.
---

## Diagnostics - Test Suite Runner

When the user requests "diagnostics" or uses Star Trek terminology like "run level 1 diagnostics", they want you to run the test suite.

### Quick Reference

| Diagnostic Level | Command | Description |
|------------------|---------|-------------|
| Level 1 (Full) | `./test_headless.sh` | Complete test suite (unit + integration) |
| Parser Check | `godot --headless --check-only` | Syntax/type validation only |
| Unit Tests Only | `godot --headless res://tests/test_runner_scene.tscn` | Unit tests without integration |

### Primary Command

```bash
./test_headless.sh
```

This runs the comprehensive automated test suite including:
- Unit tests for all core systems
- Integration tests for battle flow, AI, cinematics
- Resource validation tests

### Timeout

Tests should complete within 2-3 minutes. Use a timeout if needed:

```bash
timeout 180 ./test_headless.sh
```

### Interpreting Results

- **PASSED**: All tests passed
- **FAILED**: Check output for specific test failures
- **TIMEOUT**: Tests hung - may indicate infinite loop or async issue
- **CRASHED**: Check for null references or scene loading errors

### Common Issues

1. **Missing Godot binary**: Ensure `godot` is in PATH or set `GODOT_BIN`
2. **Display errors**: Tests run headless, no display server needed
3. **Import errors**: Run `godot --headless --import` first if resources changed

### After Diagnostics

Report:
1. Total tests run
2. Pass/fail count
3. Any specific failures with file:line references
4. Recommended fixes if failures found
