#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$SCRIPT_DIR/versions.sh"

SRC_DIR="$TOOLS_SRC_DIR/riscv-pk"
BUILD_DIR="$TOOLS_BUILD_DIR/riscv-pk-rv32"
INSTALL_DIR="$TOOLS_INSTALL_DIR/riscv-pk-rv32"
RISCV_INSTALL="$TOOLS_INSTALL_DIR/riscv"

if [[ ! -x "$RISCV_INSTALL/bin/riscv-none-elf-gcc" ]]; then
  echo "Missing RISC-V toolchain. Run tools/scripts/build_riscv_toolchain.sh first." >&2
  exit 1
fi

if [[ -x "$INSTALL_DIR/riscv32-unknown-elf/bin/pk" && "${FORCE_REBUILD:-0}" != "1" ]]; then
  echo "riscv-pk rv32 already installed: $INSTALL_DIR"
  exit 0
fi

clone_or_fetch "$RISCV_PK_REPO" "$SRC_DIR"
run_net git -C "$SRC_DIR" fetch origin
if [[ -n "$RISCV_PK_REF" ]]; then
  run_net git -C "$SRC_DIR" checkout "$RISCV_PK_REF"
else
  default_branch="$(git -C "$SRC_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  if [[ -n "$default_branch" ]]; then
    run_net git -C "$SRC_DIR" checkout "$default_branch"
    run_net git -C "$SRC_DIR" pull --ff-only origin "$default_branch"
  fi
fi

rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"
cd "$BUILD_DIR"

export PATH="$RISCV_INSTALL/bin:$PATH"
"$SRC_DIR/configure" \
  --prefix="$INSTALL_DIR" \
  --host=riscv32-unknown-elf \
  --with-arch=rv32imac_zicsr_zifencei \
  --with-abi=ilp32
make -j"$NUM_JOBS"
make install
