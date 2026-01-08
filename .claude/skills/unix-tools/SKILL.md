---
name: unix-tools
description: Reference for preferred UNIX tools over LLM processing. Use when processing JSON, text, searching files, or doing batch operations.
---

## UNIX Tool Preferences

Prefer UNIX tools over LLM processing. Use the right tool for the task.

### JSON

| Tool | Use For | Example |
|------|---------|---------|
| `jq` | Query, filter, transform JSON | `jq '.load_priority' mod.json` |

### Text Processing

| Tool | Use For | Example |
|------|---------|---------|
| `awk` | Columnar data, calculations, conditional logic | `awk -F: '{print $1}' file` |
| `sed` | Stream editing, find/replace, extract line ranges | `sed -n '10,20p' file` |
| `cut` | Extract fields/columns by delimiter | `cut -d',' -f2 file.csv` |
| `sort` | Sort lines (use before `uniq`) | `sort -n numbers.txt` |
| `uniq` | Deduplicate adjacent lines | `sort file \| uniq -c` |
| `tr` | Translate/delete characters | `tr '[:upper:]' '[:lower:]'` |
| `head`/`tail` | First/last N lines of file | `head -20 file` |
| `rev` | Reverse strings | `echo "hello" \| rev` |

### Search & Batch

| Tool | Use For | Example |
|------|---------|---------|
| `find` | Locate files by name, type, date, size | `find . -name "*.gd" -mtime -1` |
| `xargs` | Pipe output as arguments to another command | `find . -name "*.gd" \| xargs wc -l` |

### Count & Compare

| Tool | Use For | Example |
|------|---------|---------|
| `wc` | Count lines (`-l`), words (`-w`), chars (`-c`) | `wc -l *.gd` |
| `diff` | Show differences between files | `diff old.gd new.gd` |
| `comm` | Compare sorted files (unique to each, common) | `comm -23 file1 file2` |

### Paths

| Tool | Use For | Example |
|------|---------|---------|
| `basename` | Extract filename from path | `basename /path/to/file.gd` |
| `dirname` | Extract directory from path | `dirname /path/to/file.gd` |
| `realpath` | Resolve to absolute path | `realpath ../relative/path` |

### File Info

| Tool | Use For | Example |
|------|---------|---------|
| `stat` | File metadata (size, timestamps, permissions) | `stat file.gd` |
| `file` | Detect file type by content | `file mystery_file` |
| `tree` | Visualize directory structure | `tree -L 2 core/` |
| `du` | Disk usage by directory | `du -sh mods/*` |

### Data Generation

| Tool | Use For | Example |
|------|---------|---------|
| `seq` | Generate number sequences | `seq 1 10` |
| `shuf` | Random selection/shuffle lines | `shuf -n 5 names.txt` |
| `bc` | Arbitrary precision calculator | `echo "scale=2; 22/7" \| bc` |
| `date` | Format dates, convert timestamps | `date +%Y-%m-%d` |

### Checksums & Encoding

| Tool | Use For | Example |
|------|---------|---------|
| `md5sum`/`sha256sum` | Compute/verify hashes | `sha256sum file.zip` |
| `base64` | Encode/decode base64 | `base64 -d encoded.txt` |
| `xxd` | Hex dump for binary inspection | `xxd binary_file \| head` |

### Key Principle

**Use UNIX tools for data processing, not LLM token consumption.** These tools are faster, deterministic, and won't hallucinate results.
