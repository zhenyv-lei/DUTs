#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

"$SCRIPT_DIR/setup_python_env.sh"
"$SCRIPT_DIR/build_riscv_toolchain.sh"
"$SCRIPT_DIR/build_verilator.sh"
"$SCRIPT_DIR/build_spike.sh"
"$SCRIPT_DIR/build_pk_rv32.sh"

echo "All CVA6 tools are built. Run: source ./env.sh"
