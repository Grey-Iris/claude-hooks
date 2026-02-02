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

### post-tool-use/check-package-versions.py

Detects npm/yarn/pip install commands and warns about major version differences. Auto-researches breaking changes and caches results.

- Compares installed version (from package.json/requirements.txt) to latest
- Only warns on major version differences
- Spawns research for breaking changes summary
- Caches research to avoid repeated lookups

**Settings.json config:**
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/session/tk-session-context.sh 2>/dev/null || true",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/post-tool-use/check-package-versions.py",
            "timeout": 600
          }
        ]
      }
    ]
  }
}
```
