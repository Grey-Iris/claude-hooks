#!/bin/bash
# Block deprecated Gemini API patterns in code files and install commands.
#
# Catches:
#   - google-generativeai (old SDK — use google-genai)
#   - gemini-1.5-*, gemini-2.0-*, gemini-2.5-* model IDs (use gemini-3-*)
#   - import google.generativeai (old import path)
#
# Does NOT block:
#   - Documentation files (.md, .txt, .rst) — you can write about deprecated APIs
#   - Non-install bash commands (git commit, echo, grep) — you can mention them
#
# Exception: set ALLOW_LEGACY_GEMINI=1 to bypass all checks.

INPUT=$(cat)

# --- Exception mechanism ---
if [ "${ALLOW_LEGACY_GEMINI:-}" = "1" ]; then
    exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

# Extract text to scan, with context-appropriate filtering
case "$TOOL_NAME" in
    Bash)
        TEXT=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
        # Only check install commands — not git, echo, grep, etc.
        # This lets you write commit messages, search for patterns, etc.
        if ! echo "$TEXT" | grep -qiE '\b(pip|pip3|uv|npm|yarn|pnpm|bun)\b.*(install|add)\b'; then
            exit 0
        fi
        ;;
    Write)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
        # Skip documentation files — you can write about deprecated APIs
        if echo "$FILE_PATH" | grep -qiE '\.(md|mdx|txt|rst|log|csv|html)$'; then
            exit 0
        fi
        TEXT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
        ;;
    Edit)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
        if echo "$FILE_PATH" | grep -qiE '\.(md|mdx|txt|rst|log|csv|html)$'; then
            exit 0
        fi
        # Only scan new_string — don't block removal of deprecated patterns
        TEXT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
        ;;
    *)
        exit 0
        ;;
esac

[ -z "$TEXT" ] && exit 0

# --- Checks ---

deny() {
    local reason="$1"
    cat <<EOJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$reason"
  }
}
EOJSON
    exit 0
}

# Old SDK package name
if echo "$TEXT" | grep -q 'google-generativeai'; then
    deny "Deprecated SDK. Use google-genai instead. See library/apis/gemini.md. Set ALLOW_LEGACY_GEMINI=1 to bypass."
fi

# Old SDK import path
if echo "$TEXT" | grep -q 'google\.generativeai'; then
    deny "Deprecated import. Use 'from google import genai'. See library/apis/gemini.md. Set ALLOW_LEGACY_GEMINI=1 to bypass."
fi

# Gemini 1.5 models
if echo "$TEXT" | grep -qi 'gemini-1\.5'; then
    deny "Deprecated model: Gemini 1.5 is EOL. Use gemini-3-flash-preview or gemini-3-pro-preview. Set ALLOW_LEGACY_GEMINI=1 to bypass."
fi

# Gemini 2.0 models
if echo "$TEXT" | grep -qi 'gemini-2\.0'; then
    deny "Deprecated model: Gemini 2.0 shuts down March 31, 2026. Use gemini-3-flash-preview or gemini-3-pro-preview. Set ALLOW_LEGACY_GEMINI=1 to bypass."
fi

# Gemini 2.5 models
if echo "$TEXT" | grep -qi 'gemini-2\.5'; then
    deny "Outdated model: Gemini 2.5. Standardize on Gemini 3. Use gemini-3-flash-preview or gemini-3-pro-preview. Set ALLOW_LEGACY_GEMINI=1 to bypass."
fi

exit 0
