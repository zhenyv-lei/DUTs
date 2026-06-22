#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOOM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CHIPYARD_ROOT="$BOOM_ROOT/chipyard"
LOCAL_CONDA="$BOOM_ROOT/tools/conda/bin/conda"
JOBS="${JOBS:-48}"
CHIPYARD_REPO="${CHIPYARD_REPO:-https://github.com/ucb-bar/chipyard.git}"
CHIPYARD_REF="${CHIPYARD_REF:-0acc1e1de2d3284bcd4d876956932a013ffe1949}"

if ! command -v conda >/dev/null 2>&1; then
  if [ -x "$LOCAL_CONDA" ]; then
    export PATH="$BOOM_ROOT/tools/conda/bin:$PATH"
  else
    "$BOOM_ROOT/scripts/install_conda.sh"
    export PATH="$BOOM_ROOT/tools/conda/bin:$PATH"
  fi
fi

if [ ! -d "$CHIPYARD_ROOT/.git" ]; then
  git clone "$CHIPYARD_REPO" "$CHIPYARD_ROOT"
fi

cd "$CHIPYARD_ROOT"
git fetch --tags origin
git checkout "$CHIPYARD_REF"

# Keep the setup focused on software RTL simulation. FireSim/Marshal can be
# installed later if those workflows become necessary.
export MAKEFLAGS="${MAKEFLAGS:--j$JOBS}"
./build-setup.sh riscv-tools --use-lean-conda --skip-firesim --skip-marshal
