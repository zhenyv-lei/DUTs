#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$SCRIPT_DIR/versions.sh"

SPIKE_SRC_DIR="$CVA6_ROOT/$SPIKE_SOURCE_REL"
SPIKE_INSTALL_DIR="$TOOLS_BUILD_DIR/spike"
BOOST_INSTALL_DIR="${BOOST_INSTALL_DIR:-}"
export SPIKE_SRC_DIR SPIKE_INSTALL_DIR BOOST_INSTALL_DIR NUM_JOBS

if [[ ! -d "$SPIKE_SRC_DIR" ]]; then
  echo "Missing CVA6 vendored Spike source: $SPIKE_SRC_DIR" >&2
  echo "Run git submodule update --init --recursive first if core-v-verif is missing." >&2
  exit 1
fi

if [[ -x "$SPIKE_INSTALL_DIR/bin/spike" && "${FORCE_REBUILD:-0}" != "1" ]]; then
  echo "Spike already installed: $SPIKE_INSTALL_DIR/bin/spike"
  "$SPIKE_INSTALL_DIR/bin/spike" -v || true
  exit 0
fi

if [[ "${FORCE_REBUILD:-0}" == "1" ]]; then
  rm -rf "$SPIKE_INSTALL_DIR" "$SPIKE_SRC_DIR/build"
fi

mkdir -p "$SPIKE_INSTALL_DIR"
# Use the CVA6-provided installer so the build follows core-v-verif vendor logic.
source "$CVA6_ROOT/verif/regress/install-spike.sh"

"$SPIKE_INSTALL_DIR/bin/spike" -v || true
