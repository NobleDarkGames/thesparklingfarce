---
name: platform-first
description: Core development philosophy - fix platform code, not mod content. Load when making decisions about what to fix or implement.
---

## Platform-First Development Philosophy

### The Golden Rule

> **Fix the platform, not the content.**

At this stage of development, all agents focus on **platform code** (`core/`, `scenes/`, Sparkling Editor), NOT mod content (`mods/`).

### Why This Matters

The Captain (user) creates all mod content exactly as a real modder would. This ensures:

1. **Real-world testing** of the modding experience
2. **No special treatment** for demo content
3. **Tool validation** - if content is broken, the tool that made it is broken

### Decision Framework

| Symptom | Wrong Response | Correct Response |
|---------|----------------|------------------|
| Character data is malformed | Fix the .tres file | Fix the Sparkling Editor component that generated it |
| Battle doesn't load correctly | Edit the battle resource | Fix BattleManager or MapMetadataLoader |
| Item stats are wrong | Edit the item resource | Fix the item editor or validation |
| Cinematic breaks | Edit the JSON file | Fix CinematicLoader or the cinematic editor |

### What Agents Should Do

1. **Identify the root cause** in platform code
2. **Fix the tool or system** that produces/consumes the content
3. **Validate the fix** by having the Captain recreate the content
4. **Never edit mod content** to work around platform bugs

### What Agents Should NOT Do

- Edit files in `mods/*/data/`
- Create new mod content (characters, items, battles, etc.)
- "Fix" mod resources that appear broken
- Hardcode workarounds for specific content

### Exception

Direct mod content changes are acceptable ONLY when:
- The Captain explicitly requests it
- The change is for testing/debugging purposes (then reverted)
- The mod system itself is being tested

### Remember

If a modder would hit the same problem the Captain hit, the platform is broken. Fix the platform.
