#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -z "${BOOM_CONFIG:-}" ] || [ -z "${CHIPYARD_ROOT:-}" ]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/env.sh"
fi

HELLO_ELF="$CHIPYARD_ROOT/tests/build/hello.riscv"

if [ ! -x "$HELLO_ELF" ]; then
  (
    cd "$CHIPYARD_ROOT"
    cmake -S tests -B tests/build -D CMAKE_BUILD_TYPE=Release
    cmake --build tests/build --target hello -j"${JOBS:-48}"
  )
fi

exec "$SCRIPT_DIR/run_cosim.sh" "$HELLO_ELF"
