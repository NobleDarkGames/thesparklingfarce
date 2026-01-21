# Contributing to The Sparkling Farce

Thank you for your interest in contributing to The Sparkling Farce! This project thrives on community involvement, whether you're reporting bugs, suggesting features, improving documentation, or contributing code.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Ways to Contribute](#ways-to-contribute)
- [Development Setup](#development-setup)
- [Code Standards](#code-standards)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Commit Messages](#commit-messages)

---

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold a welcoming and respectful environment for everyone.

---

## Ways to Contribute

### Report Bugs

Found something broken? [Open an issue](https://github.com/[PLACEHOLDER]/sparklingfarce/issues) with:

- **Summary**: Brief description of the problem
- **Steps to reproduce**: Numbered list to recreate the issue
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happens
- **Environment**: Godot version, OS, and any relevant mod configuration
- **Minimal reproduction project**: If possible, a small project demonstrating the issue

### Suggest Features

Have an idea? Check [existing issues](https://github.com/[PLACEHOLDER]/sparklingfarce/issues) first, then open a new one describing:

- **Use case**: What problem does this solve?
- **Proposed solution**: How might it work?
- **SF2 context**: How does this fit Shining Force-style gameplay?
- **Alternatives considered**: Other approaches you thought about

### Improve Documentation

Documentation contributions are valuable:

- Fix typos or clarify confusing sections
- Add examples to modding tutorials
- Improve API documentation in code comments
- Translate documentation (future)

### Create Content

Not a programmer? You can still contribute:

- Create sprites, portraits, or icons for the starter kit
- Design sample battles or maps for tutorials
- Write demo campaign content
- Test mods and report issues

### Contribute Code

Ready to code? See [Development Setup](#development-setup) and [Pull Request Process](#pull-request-process).

---

## Development Setup

### Prerequisites

- [Godot 4.5+](https://godotengine.org/download/) (standard build, not .NET)
- Git
- A code editor (VS Code with Godot extensions recommended)

### Getting Started

```bash
# Clone the repository
git clone https://github.com/[PLACEHOLDER]/sparklingfarce.git
cd sparklingfarce

# Open in Godot
# Either double-click project.godot or:
godot --editor project.godot
```

### Project Structure

Understanding the architecture is essential:

```
core/           # Platform code ONLY - never game content
mods/           # ALL game content lives here
  demo_campaign/  # The demo content (uses same systems as your mods)
  _starter_kit/   # Core defaults and fallbacks
scenes/         # UI and gameplay scenes
addons/         # Sparkling Editor plugin (20+ visual editors)
tests/          # Automated test suite (GdUnit4)
```

**Key principle**: The platform provides infrastructure; the game is a mod. Code changes go in `core/`, content changes go in `mods/`.

For full details, see [Platform Specification](docs/specs/platform-specification.md).

---

## Code Standards

### GDScript Style

We follow the [official GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) with these mandatory requirements:

| Rule | Correct | Wrong |
|------|---------|-------|
| Strict typing required | `var speed: float = 5.0` | `var speed = 5.0` |
| No walrus operator | `var x: int = calc()` | `var x := calc()` |
| Dictionary key checks | `if "key" in dict:` | `if dict.has("key"):` |
| Typed loop variables | `for item: ItemData in items:` | `for item in items:` |
| Modern signal syntax | `my_signal.emit(value)` | `emit_signal("my_signal", value)` |

The project enforces `untyped_declaration = Error` and `infer_on_variant = Error`.

### Resource Access

Always use the registry pattern:

```gdscript
# Correct - uses mod system
var character: CharacterData = ModLoader.registry.get_resource("character", "max")

# Wrong - bypasses mod system, breaks overrides
var character: CharacterData = load("res://mods/_base_game/data/characters/max.tres")
```

### Keep It Simple

- Only implement what's requested
- Reuse existing code over writing new
- Don't add features "while you're in there"
- Prefer clarity over cleverness

---

## Testing

### Running Tests

The project uses [GdUnit4](https://github.com/MikeSchulze/gdUnit4) for testing.

```bash
# Run all tests (headless)
./test_headless.sh

# Or manually:
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd

# Run specific test file
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/unit/test_example.gd
```

### Test Requirements

- All new platform code should include tests
- Tests go in `tests/unit/` (isolated) or `tests/integration/` (multi-system)
- Use existing fixtures from `tests/fixtures/` when possible
- Tests must pass before merging

### Writing Tests

```gdscript
extends GdUnitTestSuite

func test_example() -> void:
    var result: int = some_function()
    assert_int(result).is_equal(42)
```

---

## Pull Request Process

### Before You Start

1. **Check existing issues** - Someone may already be working on it
2. **Open an issue first** for significant changes to discuss the approach
3. **Keep PRs focused** - One feature or fix per PR

### Creating a PR

1. **Fork** the repository
2. **Create a branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** following [Code Standards](#code-standards)
4. **Test your changes** - Run the test suite
5. **Commit** with clear messages (see [Commit Messages](#commit-messages))
6. **Push** to your fork
7. **Open a PR** against `main`

### PR Description

Include:

- **Summary**: What does this PR do?
- **Related issue**: Link to the issue if applicable
- **Testing done**: How did you verify this works?
- **Screenshots**: If there are visual changes

### Review Process

- All PRs require review before merging
- Address review feedback with new commits (don't force-push during review)
- Maintainers may request changes or suggest alternatives
- Be patient - reviews take time

---

## Commit Messages

### Format

```
type: Brief description (max 50 chars)

Optional longer description explaining the "why" behind the change.
Wrap at 72 characters.

Closes #123
```

### Types

| Type | Use for |
|------|---------|
| `feat` | New features |
| `fix` | Bug fixes |
| `docs` | Documentation changes |
| `style` | Code style (formatting, not CSS) |
| `refactor` | Code changes that neither fix bugs nor add features |
| `test` | Adding or updating tests |
| `chore` | Build process, dependencies, tooling |

### Examples

```
feat: Add terrain defense bonus to combat calculator

fix: Prevent crash when loading save with missing character

docs: Clarify mod priority in README

refactor: Extract spell damage calculation to separate function
```

---

## Questions?

- **Issues**: For bugs and feature requests
- **Discussions**: For questions and ideas (if enabled)
- Community links coming soon

---

Thank you for helping make The Sparkling Farce better!
