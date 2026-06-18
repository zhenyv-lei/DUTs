#!/usr/bin/env bash
set -euo pipefail

CVA6_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CVA6_ROOT/env.sh"

usage() {
  cat <<USAGE
Usage:
  ./run_helloworld.sh
  ./run_helloworld.sh baremetal-cosim

Runs the known-good CVA6 hello_world bare-metal cosim:
  Spike + CVA6 Verilator testharness, then trace comparison.

Environment overrides:
  DV_SIMULATORS  Default: veri-testharness,spike
USAGE
}

ensure_python_env() {
  if [[ ! -x "$VIRTUAL_ENV/bin/python" && ! -x "$VIRTUAL_ENV/bin/python3" ]]; then
    "$CVA6_ROOT/tools/setup-python-env.sh"
    source "$CVA6_ROOT/env.sh"
  fi

  PYTHON="$VIRTUAL_ENV/bin/python"
  if [[ ! -x "$PYTHON" ]]; then
    PYTHON="$VIRTUAL_ENV/bin/python3"
  fi
  export PYTHON
}

require_executable() {
  local exe
  for exe in "$@"; do
    if [[ ! -x "$exe" ]]; then
      echo "Missing executable: $exe" >&2
      exit 1
    fi
  done
}

run_baremetal_cosim() {
  echo "== Spike + CVA6 Verilator bare-metal hello_world trace compare =="

  cd "$CVA6_ROOT"
  set +u
  source "$CVA6_ROOT/verif/sim/setup-env.sh"
  set -u

  export DV_SIMULATORS="${DV_SIMULATORS:-veri-testharness,spike}"

  cd "$CVA6_ROOT/verif/sim"
  "$PYTHON" cva6.py \
    --target cv32a60x \
    --iss="$DV_SIMULATORS" \
    --iss_yaml=cva6.yaml \
    --c_tests ../tests/custom/hello_world/hello_world.c \
    --linker=../../config/gen_from_riscv_config/linker/link.ld \
    --gcc_opts="-static -mcmodel=medany -fvisibility=hidden -nostdlib \
    -nostartfiles -g ../tests/custom/common/syscalls.c \
    ../tests/custom/common/crt.S -lgcc \
    -I../tests/custom/env -I../tests/custom/common"
}

main() {
  local mode="${1:-baremetal-cosim}"

  case "$mode" in
    baremetal-cosim)
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown mode: $mode" >&2
      usage >&2
      exit 1
      ;;
  esac

  ensure_python_env
  require_executable \
    "$RISCV_CC" \
    "$RISCV_OBJCOPY" \
    "$SPIKE_PATH/spike" \
    "$VERILATOR_INSTALL_DIR/bin/verilator"

  run_baremetal_cosim
}

main "$@"
