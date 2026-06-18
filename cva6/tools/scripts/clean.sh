#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

case "${1:-}" in
  build)
    rm -rf "$TOOLS_BUILD_DIR"
    ;;
  spike-build)
    rm -rf "$CVA6_ROOT/verif/core-v-verif/vendor/riscv/riscv-isa-sim/build"
    ;;
  all)
    rm -rf "$TOOLS_BUILD_DIR" "$TOOLS_SRC_DIR/verilator" "$TOOLS_SRC_DIR/riscv-pk" "$TOOLS_SRC_DIR/riscv-toolchain"
    rm -rf "$CVA6_ROOT/verif/core-v-verif/vendor/riscv/riscv-isa-sim/build"
    ;;
  *)
    echo "Usage: $0 {build|spike-build|all}" >&2
    exit 1
    ;;
esac
