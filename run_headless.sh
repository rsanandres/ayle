#!/usr/bin/env bash
# Run Ayle in headless simulation mode (no rendering).
# Usage: ./run_headless.sh [agent_count] [speed]
#   agent_count: number of agents to spawn (default: 10)
#   speed: game speed 1-3 (default: 3)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="$SCRIPT_DIR/project.godot"
AGENTS="${1:-10}"
SPEED="${2:-3}"

# Backup original main scene
ORIGINAL_SCENE=$(grep 'run/main_scene=' "$PROJECT_FILE" | head -1)

# Swap main scene to headless sim
sed -i.bak 's|run/main_scene=.*|run/main_scene="res://scenes/main/headless_sim.tscn"|' "$PROJECT_FILE"

# Restore on exit (even on Ctrl+C)
cleanup() {
    sed -i.bak "s|run/main_scene=.*|${ORIGINAL_SCENE}|" "$PROJECT_FILE"
    rm -f "${PROJECT_FILE}.bak"
    echo ""
    echo "[SIM] Simulation stopped. Main scene restored."
}
trap cleanup EXIT

echo "Starting headless simulation: $AGENTS agents at ${SPEED}x speed..."
echo ""

# Run Godot headless
godot --headless --path "$SCRIPT_DIR" -- --agents="$AGENTS" --speed="$SPEED"
