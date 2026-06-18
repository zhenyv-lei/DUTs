#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ./env.sh
mkdir -p work

verilator_version="$(verilator --version 2>/dev/null || true)"
echo "[run_helloworld] $verilator_version"

make_args=(
  SHELL=/bin/bash
  runcase
  CASE=hello_world
  SIM=verilator
  DUMP=off
)

if [[ "$verilator_version" == Verilator\ 5.* ]]; then
  make_args+=(
    THREADS="${THREADS:-1}"
    'SIMULATOR_OPT=-O3 -x-assign 0 -Wno-fatal --timing --threads 1'
  )
elif [ -n "${THREADS:-}" ]; then
  make_args+=("THREADS=$THREADS")
fi

make "${make_args[@]}"
