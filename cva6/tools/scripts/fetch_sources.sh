#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$SCRIPT_DIR/versions.sh"

clone_or_fetch "$VERILATOR_REPO" "$TOOLS_SRC_DIR/verilator"
run_net git -C "$TOOLS_SRC_DIR/verilator" checkout "$VERILATOR_VERSION"
clone_or_fetch "$RISCV_PK_REPO" "$TOOLS_SRC_DIR/riscv-pk"
run_net git -C "$TOOLS_SRC_DIR/riscv-pk" fetch origin
if [[ -n "$RISCV_PK_REF" ]]; then
  run_net git -C "$TOOLS_SRC_DIR/riscv-pk" checkout "$RISCV_PK_REF"
fi

export SRC_DIR="$TOOLS_SRC_DIR/riscv-toolchain"
export BUILD_DIR="$TOOLS_BUILD_DIR/riscv-toolchain"
run_net bash "$CVA6_ROOT/util/toolchain-builder/get-toolchain.sh" "$RISCV_TOOLCHAIN_CONFIG"

echo "Pinned/constrained external sources fetched under $TOOLS_SRC_DIR"
