#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <ChipyardConfig> [program.elf] [extra make args...]" >&2
  exit 2
fi

CONFIG="$1"
shift

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOOM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CHIPYARD_ROOT="$BOOM_ROOT/chipyard"
LOCAL_CONDA_BIN="$BOOM_ROOT/tools/conda/bin"
RUN_ROOT="$BOOM_ROOT/runs/$CONFIG"
LOG_DIR="$RUN_ROOT/logs"
JOBS="${JOBS:-48}"

if [ ! -f "$CHIPYARD_ROOT/env.sh" ]; then
  echo "Missing Chipyard environment: $CHIPYARD_ROOT/env.sh" >&2
  echo "Run: $BOOM_ROOT/scripts/install_chipyard.sh" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
if ! command -v conda >/dev/null 2>&1 && [ -x "$LOCAL_CONDA_BIN/conda" ]; then
  export PATH="$LOCAL_CONDA_BIN:$PATH"
fi

# Chipyard's conda activation may read unset variables under `set -u`.
# shellcheck disable=SC1091
set +u
source "$CHIPYARD_ROOT/env.sh"
set -u

cd "$CHIPYARD_ROOT/sims/verilator"
make -j"$JOBS" CONFIG="$CONFIG" 2>&1 | tee "$LOG_DIR/build.log"

if [ "$#" -gt 0 ]; then
  BINARY="$1"
  shift
  make -j"$JOBS" CONFIG="$CONFIG" BINARY="$BINARY" run-binary "$@" 2>&1 | tee "$LOG_DIR/run.log"
fi
