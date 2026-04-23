#!/usr/bin/env bash

# This script sets up the environment for ForensiCollect

set -u

echo "Setting up environment for ForensiCollect..."

# Load environment variables from .env file (if it exists)
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

# Export API keys for child processes
export AI_API_KEY="${AI_API_KEY:-}"
export AI_MODEL="${AI_MODEL:-}"
export prompt="${prompt:-}"

ForensiCollect="$SCRIPT_DIR/forensic_collect.sh"
chmod +x "$ForensiCollect"

ai_explainer="$SCRIPT_DIR/ai_explainer.sh"
chmod +x "$ai_explainer"

modules_dir="$SCRIPT_DIR/modules"
if [[ -d "$modules_dir" ]]; then
    for module in "$modules_dir"/*; do
        if [[ -x "$module" ]]; then
            echo "Found executable module: $module"
            chmod +x "$module"
        fi
    done
fi
