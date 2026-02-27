#!/bin/bash
# Detect workflow-v2 as a sibling repo and surface dispatch instructions to Claude

WORKFLOW_DIR="$(pwd)/../workflow-v2"

if [ -d "$WORKFLOW_DIR" ]; then
    echo "WORKFLOW: This project uses a multi-agent build workflow."
    echo "When asked to build, plan, or manage work — read ../workflow-v2/orchestrator-template.md"
    echo "for dispatch patterns. Do not implement code directly. Dispatch to Claude PM."
fi
