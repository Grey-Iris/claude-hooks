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

### pre-tool-use/check-gemini-patterns.sh

Blocks deprecated Gemini API patterns in code — not in docs. Fires on `Write`, `Edit`, and `Bash` tool calls.

**Catches:**
- `google-generativeai` (old SDK) — use `google-genai`
- `gemini-1.5-*`, `gemini-2.0-*`, `gemini-2.5-*` model IDs — use `gemini-3-*`
- `import google.generativeai` (old import) — use `from google import genai`

**Does not block:**
- Documentation files (`.md`, `.txt`, `.rst`, `.html`, `.csv`, `.log`) — you can write about deprecated APIs
- Non-install bash commands (`git commit`, `echo`, `grep`) — you can mention deprecated patterns in commits, searches, etc.

**Smart behavior:**
- For `Edit`, only scans `new_string` — replacing deprecated patterns with correct ones won't be blocked
- For `Bash`, only scans install commands (`pip install`, `npm install`, etc.) — not every command that mentions a model name

**Exception:** Set `ALLOW_LEGACY_GEMINI=1` to bypass all checks when you need to work with older models:
```bash
# In your shell
export ALLOW_LEGACY_GEMINI=1

# Or in .claude/settings.json env
{ "env": { "ALLOW_LEGACY_GEMINI": "1" } }

# Or per-project in .claude/settings.local.json
{ "env": { "ALLOW_LEGACY_GEMINI": "1" } }
```

### post-tool-use/check-package-versions.py

Detects npm/yarn/pip install commands and warns about major version differences. Auto-researches breaking changes and caches results.

- Compares installed version (from package.json/requirements.txt) to latest
- Only warns on major version differences
- Spawns research for breaking changes summary
- Caches research to avoid repeated lookups

## Settings.json Config

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
    "PreToolUse": [
      {
        "matcher": "Bash|Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/pre-tool-use/check-gemini-patterns.sh",
            "timeout": 10
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
