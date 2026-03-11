# CLI Reference

This document describes the command interface for YOLO Battle.

## `yolo`

Launches the interactive tool picker (if stdin is a TTY) or shows usage otherwise.

```
yolo
```

## `yolo <tool>`

Directly launch a single tool.

```
yolo claude [args...]
yolo gemini [args...]
yolo codex [args...]
```

## `yolo battle`

Starts multi-agent battle mode.

```
yolo battle "prompt"
yolo battle -p "prompt"   # parallel
yolo battle -s "prompt"   # sequential
yolo battle -c "prompt"   # collaborative (co-op)
```

## Command Center (Battle Mode)

Common commands:

- `/status` show AI status
- `/diff` show diffs captured from each AI
- `/save` capture pane output and context files
- `/ctx` view context files
- `/prompt X` update the current prompt
- `/focus N` focus pane N
- `/mode X` switch mode (p/s/c)
- `/help` show help
- `/quit` end session

### Parallel mode

- `/compare` compare outputs and diffs
- `/pick N` choose AI N as the winner

### Sequential mode

- `/next [message]` advance round-robin turn, optionally relay a message
- `/skip` skip current turn
- `/order N..` change order (e.g. `/order 2 1 3`)

### Collaborative (co-op) mode

- `/board` show the shared board
- `/merge` merge co-op branches into the main workdir
- `/roles` show current role assignments
- `/role N X` set role for AI N
- `/swap N M` swap roles between AI N and M
