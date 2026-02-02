#!/bin/bash
# Install claude-hooks by symlinking to ~/.claude/hooks/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/hooks"

mkdir -p "$TARGET_DIR"

# Symlink session hooks
if [ -d "$SCRIPT_DIR/session" ]; then
    ln -sfn "$SCRIPT_DIR/session" "$TARGET_DIR/session"
    echo "Linked: session/ -> $TARGET_DIR/session"
fi

echo ""
echo "Add to ~/.claude/settings.json:"
echo ""
cat << 'EOF'
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
EOF
