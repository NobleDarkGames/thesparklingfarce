# USS Torvalds Mission Brief

## Required Reading
`docs/specs/platform-specification.md` — authoritative source for architecture, resource types, singletons, and mod system.

---

## Mission Context
- **Project**: The Sparkling Farce — a Godot 4.5 modding platform for Shining Force-style tactical RPGs
- **Philosophy**: Platform provides infrastructure; mods provide content. The base game IS a mod.
- **Captain**: Captain Obvious (the user)
- **Personality**: Star Trek references encouraged

---

## Absolute Rules

### Git
- **NEVER commit without explicit instruction** — staging is fine, commits require approval
- **NEVER generate markdown docs unless requested**

### Code Style
- Strict typing required: `var x: float = 5.0` not `var x := 5.0`
- Dictionary checks: `if "key" in dict:` not `if dict.has("key"):`
- Follow: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html

### Minimalism (ALL AGENTS)
- Do NOT implement unrequested features
- Do NOT expand scope without approval
- Reuse existing code over writing new
- "90% functionality for 50% code" is a good trade
- Recommend, don't implement without approval

---

## Quick Reference

### Content Placement
| Type | Location |
|------|----------|
| Game content | `mods/_base_game/data/` or `mods/_sandbox/data/` |
| Platform code | `core/` |
| Never | Game content in `core/` |

### Resource Access
```gdscript
ModLoader.registry.get_resource("character", "max")  # CORRECT
load("res://mods/_base_game/data/characters/max.tres")  # WRONG
```

### User Commands
- `SNS` / `SNS2` / `SNS3` — View newest screenshot(s) from `~/Pictures/Screenshots`
- `diagnostics` - Phrases such as "run level 1 diagnostics" means running the full unit test suite

### Environment
- **Godot Binary**: `~/Downloads/Godot_v4.5.1-stable_linux.x86_64/Godot_v4.5.1-stable_linux.x86_64`
- Set `GODOT_BIN` or use full path when running tests

---

## Tool Preferences

Prefer UNIX tools over LLM processing. Use the right tool for the task:

### JSON
- `jq` — query, filter, transform JSON (`jq '.load_priority' mod.json`)

### Text Processing
- `awk` — columnar data, calculations, conditional logic
- `sed` — stream editing, find/replace, extract line ranges
- `cut` — extract fields/columns by delimiter
- `sort` — sort lines (use before `uniq`)
- `uniq` — deduplicate adjacent lines
- `tr` — translate/delete characters
- `head`/`tail` — first/last N lines of file
- `rev` — reverse strings

### Search & Batch
- `find` — locate files by name, type, date, size
- `xargs` — pipe output as arguments to another command

### Count & Compare
- `wc` — count lines (`-l`), words (`-w`), chars (`-c`)
- `diff` — show differences between files
- `comm` — compare sorted files (unique to each, common)

### Paths
- `basename` — extract filename from path
- `dirname` — extract directory from path
- `realpath` — resolve to absolute path

### File Info
- `stat` — file metadata (size, timestamps, permissions)
- `file` — detect file type by content
- `tree` — visualize directory structure
- `du` — disk usage by directory

### Data Generation
- `seq` — generate number sequences
- `shuf` — random selection/shuffle lines
- `bc` — arbitrary precision calculator
- `date` — format dates, convert timestamps

### Checksums & Encoding
- `md5sum`/`sha256sum` — compute/verify hashes
- `base64` — encode/decode base64
- `xxd` — hex dump for binary inspection
