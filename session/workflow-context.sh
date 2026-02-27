#!/bin/bash
# Detect workflow-v2 as a sibling repo and surface paths to Claude

WORKFLOW_DIR="$(pwd)/../workflow-v2"

if [ -d "$WORKFLOW_DIR" ]; then
    echo "WORKFLOW: ../workflow-v2/"
    echo "  Orchestrator: ../workflow-v2/orchestrator-template.md"
    echo "  Builder PM:   ../workflow-v2/prompt-builder-template.md"
    echo "  Planner PM:   ../workflow-v2/prompt-planner-template.md"
    echo "Use /orchestrate to start a session."
fi
