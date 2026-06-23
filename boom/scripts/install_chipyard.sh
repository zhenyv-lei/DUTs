#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOOM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CHIPYARD_ROOT="$BOOM_ROOT/chipyard"
LOCAL_CONDA="$BOOM_ROOT/tools/conda/bin/conda"
JOBS="${JOBS:-48}"
CHIPYARD_REPO="${CHIPYARD_REPO:-https://github.com/ucb-bar/chipyard.git}"
CHIPYARD_REF="${CHIPYARD_REF:-0acc1e1de2d3284bcd4d876956932a013ffe1949}"

if [ ! -x "$LOCAL_CONDA" ]; then
  "$BOOM_ROOT/scripts/install_conda.sh"
fi
export PATH="$BOOM_ROOT/tools/conda/bin:$PATH"

if [ ! -d "$CHIPYARD_ROOT/.git" ]; then
  git clone "$CHIPYARD_REPO" "$CHIPYARD_ROOT"
fi

cd "$CHIPYARD_ROOT"

if ! git rev-parse --verify --quiet "$CHIPYARD_REF^{commit}" >/dev/null; then
  git fetch --tags origin
fi
git checkout "$CHIPYARD_REF"

# The DUTs overlay patches files in Chipyard submodules such as testchipip.
# Initialize the non-toolchain submodules before applying local overlays.
./scripts/init-submodules-no-riscv-tools.sh
"$BOOM_ROOT/scripts/apply_chipyard_overlays.sh"

if [ -f "$CHIPYARD_ROOT/env.sh" ] && [ -d "$CHIPYARD_ROOT/.conda-env" ]; then
  echo "Using existing Chipyard conda environment: $CHIPYARD_ROOT/.conda-env"
  exit 0
fi

# Keep the setup focused on software RTL simulation. FireSim/Marshal can be
# installed later if those workflows become necessary.
export MAKEFLAGS="${MAKEFLAGS:--j$JOBS}"
./build-setup.sh riscv-tools --use-lean-conda --skip-submodules --skip-firesim --skip-marshal
