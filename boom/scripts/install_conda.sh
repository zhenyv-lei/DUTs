#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOOM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CONDA_PREFIX="$BOOM_ROOT/tools/conda"
DOWNLOAD_DIR="$BOOM_ROOT/tools/downloads"
INSTALLER="$DOWNLOAD_DIR/Miniforge3-Linux-x86_64.sh"
MINIFORGE_URL="${MINIFORGE_URL:-https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh}"

if command -v conda >/dev/null 2>&1; then
  echo "Using existing conda: $(command -v conda)"
  exit 0
fi

if [ -x "$CONDA_PREFIX/bin/conda" ]; then
  echo "Using local conda: $CONDA_PREFIX/bin/conda"
  exit 0
fi

mkdir -p "$DOWNLOAD_DIR"
if [ ! -f "$INSTALLER" ]; then
  curl -L --fail --retry 3 -o "$INSTALLER" "$MINIFORGE_URL"
fi

bash "$INSTALLER" -b -p "$CONDA_PREFIX"
"$CONDA_PREFIX/bin/conda" config --set auto_activate_base false
