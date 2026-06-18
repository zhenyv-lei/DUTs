#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$SCRIPT_DIR/versions.sh"

INSTALL_DIR="$TOOLS_INSTALL_DIR/riscv"
SRC_DIR="$TOOLS_SRC_DIR/riscv-toolchain"
BUILD_DIR="$TOOLS_BUILD_DIR/riscv-toolchain"
export INSTALL_DIR SRC_DIR BUILD_DIR NUM_JOBS

if [[ -x "$INSTALL_DIR/bin/riscv-none-elf-gcc" && "${FORCE_REBUILD:-0}" != "1" ]]; then
  echo "RISC-V toolchain already installed: $INSTALL_DIR"
  "$INSTALL_DIR/bin/riscv-none-elf-gcc" --version | head -1
  exit 0
fi

if [[ "${FORCE_REBUILD:-0}" == "1" ]]; then
  rm -rf "$INSTALL_DIR" "$BUILD_DIR"
fi

mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_DIR"
run_net bash "$CVA6_ROOT/util/toolchain-builder/get-toolchain.sh" "$RISCV_TOOLCHAIN_CONFIG"
bash "$CVA6_ROOT/util/toolchain-builder/build-toolchain.sh" "$RISCV_TOOLCHAIN_CONFIG" "$INSTALL_DIR"

"$INSTALL_DIR/bin/riscv-none-elf-gcc" --version | head -1
