#!/bin/bash
# Detect workflow-v2 as a sibling repo and surface dispatch instructions to Claude

WORKFLOW_DIR="$(pwd)/../workflow-v2"

if [ -d "$WORKFLOW_DIR" ]; then
    echo "WORKFLOW: This project uses a multi-agent build workflow."
    echo ""
    echo "You are the orchestrator. Your job is talking to the human and dispatching work."
    echo "Read ../workflow-v2/orchestrator-template.md for dispatch patterns and PM templates."
    echo ""
    echo "Build work goes through mcp-agents (ask_agent) — this spawns a Claude PM session"
    echo "that manages the implementation. Quick research tasks can use the built-in Task tool."
fi
