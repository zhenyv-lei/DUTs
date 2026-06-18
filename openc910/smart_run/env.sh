#!/usr/bin/env bash

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "This file must be sourced, not executed:" >&2
  echo "  source env.sh" >&2
  exit 1
fi

SMART_RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENC910_ROOT="$(cd "$SMART_RUN_DIR/.." && pwd)"

export CODE_BASE_PATH="$OPENC910_ROOT/C910_RTL_FACTORY"
export TOOL_EXTENSION="$OPENC910_ROOT/tools/build/xuantie-gcc/bin"
export VERILATOR_HOME="$OPENC910_ROOT/tools/build/verilator"

prepend_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

if [ -d "$TOOL_EXTENSION" ]; then
  prepend_path "$TOOL_EXTENSION"
else
  echo "[env] missing XuanTie toolchain: $TOOL_EXTENSION" >&2
  echo "[env] run: ../tools/scripts/install_xuantie_toolchain.sh" >&2
fi

if [ -d "$VERILATOR_HOME/bin" ]; then
  prepend_path "$VERILATOR_HOME/bin"
else
  echo "[env] local Verilator is not installed yet: $VERILATOR_HOME" >&2
  echo "[env] run: ../tools/scripts/install_verilator.sh" >&2
fi

echo "CODE_BASE_PATH=$CODE_BASE_PATH"
echo "TOOL_EXTENSION=$TOOL_EXTENSION"
if command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
  riscv64-unknown-elf-gcc --version | head -1
fi
if command -v verilator >/dev/null 2>&1; then
  verilator --version
fi
