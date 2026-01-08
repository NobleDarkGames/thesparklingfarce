---
name: sns
description: View the newest screenshot(s) from the user's Screenshots folder. Use when user says SNS, SNS2, SNS3, or asks to see a screenshot.
---

## Screenshot Viewer Commands

The user uses `SNS` (Screenshot Navigation System) to share screenshots with you.

### Commands

| Command | Action |
|---------|--------|
| `SNS` | View the 1 newest screenshot |
| `SNS2` | View the 2 newest screenshots |
| `SNS3` | View the 3 newest screenshots |

### How to Execute

1. Find the newest screenshot(s) in `~/Pictures/Screenshots/`
2. Use the Read tool to view the image file(s)

```bash
# Find newest screenshot
ls -t ~/Pictures/Screenshots/*.png | head -1

# Find 2 newest
ls -t ~/Pictures/Screenshots/*.png | head -2

# Find 3 newest  
ls -t ~/Pictures/Screenshots/*.png | head -3
```

### Notes

- Screenshots are typically PNG files
- Sort by modification time (`-t`) to get newest first
- The user is showing you what they see on screen - analyze the image content
- Common uses: showing UI state, error dialogs, visual bugs, design references
