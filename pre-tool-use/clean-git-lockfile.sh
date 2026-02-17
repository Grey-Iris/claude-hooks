#!/bin/bash
# Remove stale .git/index.lock before git commands.
#
# WSL2 on DrvFs (/mnt/*) is notorious for leaving stale lock files
# when processes crash or get killed. This hook cleans them up
# before git operations so agents don't get stuck.
#
# Safety: only removes the lock if no git process is currently running.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

# Only act on git commands
echo "$COMMAND" | grep -qE '\bgit\b' || exit 0

# Find the repo root from the working directory
WORK_DIR=$(echo "$INPUT" | jq -r '.tool_input.working_directory // empty')
if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    LOCK_FILE="$WORK_DIR/.git/index.lock"
else
    # Fall back to finding .git from cwd
    LOCK_FILE=".git/index.lock"
fi

[ -f "$LOCK_FILE" ] || exit 0

# Only remove if no git process is running (stale lock)
if pgrep -x git > /dev/null 2>&1; then
    exit 0
fi

rm -f "$LOCK_FILE"

exit 0
