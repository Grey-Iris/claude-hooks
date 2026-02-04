#!/bin/bash
# Compact session context for Claude Code startup
# Shows learnings, decisions, in-progress tasks, and top ready tasks

set -e

# Find tk executable (works on Mac and WSL)
if command -v tk &>/dev/null; then
    TK=tk
elif [ -x "$HOME/go/bin/tk" ]; then
    TK="$HOME/go/bin/tk"
else
    echo "TIP: Install tasuku for session context."
    exit 0
fi

# Learnings (filter out usage hints)
learnings=$($TK learning list 2>/dev/null | grep -v "^No learnings" | grep -v "^Use:" || true)
if [ -n "$learnings" ]; then
    echo "LEARNINGS:"
    echo "$learnings"
    echo ""
fi

# Decisions (filter out usage hints)
decisions=$($TK decision list 2>/dev/null | grep -v "^No decisions" | grep -v "^Use:" || true)
if [ -n "$decisions" ]; then
    echo "DECISIONS:"
    echo "$decisions"
    echo ""
fi

# In-progress tasks
in_progress=$($TK task list -s in_progress 2>/dev/null | grep -v "^No tasks" || true)
if [ -n "$in_progress" ]; then
    echo "IN PROGRESS:"
    echo "$in_progress"
    echo ""
fi

# Ready tasks (top 5)
ready_count=$($TK task list -s ready -f json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
if [ "$ready_count" -gt 0 ]; then
    echo "READY (showing up to 5 of $ready_count):"
    $TK task list -s ready 2>/dev/null | head -5
    echo ""
fi

# Quick stats if nothing else shown
if [ -z "$learnings" ] && [ -z "$decisions" ] && [ -z "$in_progress" ] && [ "$ready_count" -eq 0 ]; then
    echo "No active context. Run 'tk task list' to see all tasks."
fi

echo "TIP: Use /tasuku to manage tasks. Run 'tk context show' for full AI context."
