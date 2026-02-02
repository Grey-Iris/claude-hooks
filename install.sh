#!/bin/bash
# Install claude-hooks by symlinking to ~/.claude/hooks/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/hooks"

mkdir -p "$TARGET_DIR"

# Symlink hook directories
for dir in session post-tool-use; do
    if [ -d "$SCRIPT_DIR/$dir" ]; then
        ln -sfn "$SCRIPT_DIR/$dir" "$TARGET_DIR/$dir"
        echo "Linked: $dir/ -> $TARGET_DIR/$dir"
    fi
done

echo ""
echo "Add to ~/.claude/settings.json:"
echo ""
cat << 'EOF'
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
EOF
