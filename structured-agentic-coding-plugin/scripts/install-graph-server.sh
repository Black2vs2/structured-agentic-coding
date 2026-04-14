#!/usr/bin/env bash
# Install graph server dependencies in a venv.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GRAPH_DIR="$(dirname "$SCRIPT_DIR")/graph-server"

# Check Python
PYTHON=""
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
        version=$("$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        major=$("$cmd" -c "import sys; print(sys.version_info.major)")
        minor=$("$cmd" -c "import sys; print(sys.version_info.minor)")
        if [[ "$major" -ge 3 && "$minor" -ge 10 ]]; then
            PYTHON="$cmd"
            break
        fi
    fi
done

if [[ -z "$PYTHON" ]]; then
    echo "WARNING: Python 3.10+ not found. Graph server will not be available."
    echo "Agents will use grep-only navigation (graph tools disabled)."
    echo "Install Python 3.10+ and re-run this script to enable graph features."
    exit 0
fi

echo "Using $PYTHON ($version)"

# Create venv if not exists
VENV_DIR="$GRAPH_DIR/.venv"
if [[ ! -d "$VENV_DIR" ]]; then
    echo "Creating virtual environment..."
    "$PYTHON" -m venv "$VENV_DIR"
fi

# Install dependencies
echo "Installing dependencies..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet -e "$GRAPH_DIR"

# Verify
if "$VENV_DIR/bin/python" -m sac_graph.cli --help >/dev/null 2>&1; then
    echo "Graph CLI installed successfully."
else
    echo "WARNING: Graph CLI installation failed."
    echo "Agents will use grep-only navigation."
    exit 0
fi
