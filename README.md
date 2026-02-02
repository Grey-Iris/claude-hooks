# Claude Hooks

Shared Claude Code hooks for Grey Iris.

## Installation

```bash
./install.sh
```

This symlinks hooks to `~/.claude/hooks/` and shows the settings.json config to add.

## Hooks

### session/tk-session-context.sh

Compact session context for Claude Code startup. Shows:
- Learnings (insights recorded with `tk learning add`)
- Decisions (choices recorded with `tk decision add`)
- In-progress tasks
- Top 5 ready tasks

Requires: [tasuku](https://github.com/Grey-Iris/tasuku) (`tk` CLI)

**Settings.json config:**
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "resume",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/session/tk-session-context.sh 2>/dev/null || true",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```
