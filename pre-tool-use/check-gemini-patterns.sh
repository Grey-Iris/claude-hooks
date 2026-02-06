#!/bin/bash
# Block deprecated Gemini API patterns in Write, Edit, and Bash tool calls.
#
# Catches:
#   - google-generativeai (old SDK — use google-genai)
#   - gemini-1.5-*, gemini-2.0-*, gemini-2.5-* model IDs (use gemini-3-*)
#   - import google.generativeai (old import path)
#
# Exception: set ALLOW_LEGACY_GEMINI=1 to bypass all checks.
# You can set this in your shell, .env, or project settings.

INPUT=$(cat)

# --- Exception mechanism ---
if [ "${ALLOW_LEGACY_GEMINI:-}" = "1" ]; then
    exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

# Extract the text to scan based on tool type
case "$TOOL_NAME" in
    Bash)
        TEXT=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
        ;;
    Write)
        TEXT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
        ;;
    Edit)
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
    deny "Deprecated SDK: google-generativeai. Use google-genai instead. See library/apis/gemini.md. Set ALLOW_LEGACY_GEMINI=1 to bypass."
fi

# Old SDK import path
if echo "$TEXT" | grep -q 'google\.generativeai'; then
    deny "Deprecated import: google.generativeai. Use 'from google import genai'. See library/apis/gemini.md. Set ALLOW_LEGACY_GEMINI=1 to bypass."
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
    deny "Outdated model: Gemini 2.5 — standardize on Gemini 3. Use gemini-3-flash-preview or gemini-3-pro-preview. Set ALLOW_LEGACY_GEMINI=1 to bypass."
fi

exit 0
