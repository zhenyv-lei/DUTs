#!/usr/bin/env bash
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source this file: source scripts/env.sh" >&2
  exit 2
fi

TOOOBA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOOBA_TOOLS="$TOOOBA_ROOT/tools"
TOOOBA_VERILATOR="$TOOOBA_TOOLS/verilator-3.922"

export TOOOBA_ROOT
export TOOOBA_TOOLS
export TOOOBA_VERILATOR
export VERILATOR_ROOT="$TOOOBA_VERILATOR"
export PATH="$TOOOBA_VERILATOR/bin:$PATH"

