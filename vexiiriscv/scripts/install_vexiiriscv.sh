#!/usr/bin/env sh
set -eu

if (set -o pipefail) >/dev/null 2>&1; then
  set -o pipefail
fi

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
VEXII_WRAPPER_ROOT=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)
DEFAULT_REPO_DIR="$VEXII_WRAPPER_ROOT/VexiiRiscv"
DEFAULT_INSTALL_ROOT="$VEXII_WRAPPER_ROOT"

REPO_URL="${REPO_URL:-https://github.com/SpinalHDL/VexiiRiscv.git}"
REPO_DIR="${REPO_DIR:-$DEFAULT_REPO_DIR}"
INSTALL_ROOT="${INSTALL_ROOT:-$DEFAULT_INSTALL_ROOT}"
JOBS="${JOBS:-}"
SPIKE_PREFIX="${SPIKE_PREFIX:-/tmp/vexiiriscv-riscv}"
USE_BOSC_PROXY="${USE_BOSC_PROXY:-auto}"
MILL_USE_PROXY="${MILL_USE_PROXY:-0}"
CHECK_PROXY="${CHECK_PROXY:-1}"
SKIP_RVLS="${SKIP_RVLS:-0}"
SKIP_SMOKE="${SKIP_SMOKE:-0}"
FETCH_ELFIO="${FETCH_ELFIO:-1}"
SMOKE_NAME="${SMOKE_NAME:-rv32ui-p-add-cosim}"
PROXY_WRAPPER="${PROXY_WRAPPER:-/nfs/home/leizhenyu/.codex/skills/bosc-ivp6-proxy-install/scripts/with_bosc_proxy.sh}"
ELFIO_INCLUDE="${ELFIO_INCLUDE:-}"
RUNS_DIR="${RUNS_DIR:-$VEXII_WRAPPER_ROOT/runs}"

usage() {
  cat <<'EOF'
Install/build VexiiRiscv locally and run a small simulator smoke test.

Run from bash, zsh, or any POSIX-like shell:
  scripts/install_vexiiriscv.sh

Useful environment variables:
  REPO_DIR=/path/to/VexiiRiscv       Existing or target checkout
  INSTALL_ROOT=/path/to/wrapper      Parent directory for a fresh clone
  RUNS_DIR=/path/to/logs             Log directory
  JOBS=8                             Parallel make jobs
  USE_BOSC_PROXY=auto|1|0            Use BOSC proxy wrapper for git/network fetches
  MILL_USE_PROXY=0|1                 Use proxy wrapper for Mill too; default 0
  SKIP_RVLS=1                        Skip Spike/RVLS build and run non-cosim smoke
  SKIP_SMOKE=1                       Build only, do not run the final simulation
  ELFIO_INCLUDE=/path/include        Directory containing elfio/elfio.hpp
  FETCH_ELFIO=0                      Do not auto-clone ELFIO if missing

Examples:
  scripts/install_vexiiriscv.sh
  JOBS=16 SKIP_SMOKE=1 scripts/install_vexiiriscv.sh
  USE_BOSC_PROXY=0 MILL_USE_PROXY=0 scripts/install_vexiiriscv.sh
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if [ -z "$JOBS" ]; then
  if command -v nproc >/dev/null 2>&1; then
    JOBS=$(nproc)
  else
    JOBS=8
  fi
fi

mkdir -p "$INSTALL_ROOT" "$RUNS_DIR"
LOG_FILE="${LOG_FILE:-$RUNS_DIR/vexiiriscv_install_$(date +%Y%m%d_%H%M%S).log}"

log() {
  printf '\n[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

die() {
  printf '\nERROR: %s\n' "$*" | tee -a "$LOG_FILE" >&2
  exit 1
}

print_cmd() {
  printf '+'
  for arg in "$@"; do
    printf ' %s' "$arg"
  done
  printf '\n'
}

run() {
  print_cmd "$@" | tee -a "$LOG_FILE"
  tmp_log="${TMPDIR:-/tmp}/vexiiriscv_cmd_$$.log"
  set +e
  "$@" > "$tmp_log" 2>&1
  status=$?
  set -e
  cat "$tmp_log"
  cat "$tmp_log" >> "$LOG_FILE"
  rm -f "$tmp_log"
  return "$status"
}

is_true() {
  case "$1" in
    1|yes|true) return 0 ;;
    *) return 1 ;;
  esac
}

proxy_enabled() {
  case "$USE_BOSC_PROXY" in
    1|yes|true)
      [ -x "$PROXY_WRAPPER" ] || die "PROXY_WRAPPER is not executable: $PROXY_WRAPPER"
      return 0
      ;;
    0|no|false)
      return 1
      ;;
    auto)
      [ -x "$PROXY_WRAPPER" ]
      return $?
      ;;
    *)
      die "Invalid USE_BOSC_PROXY=$USE_BOSC_PROXY; use auto, 1, or 0"
      ;;
  esac
}

run_net() {
  if proxy_enabled; then
    run "$PROXY_WRAPPER" -- "$@"
  else
    run "$@"
  fi
}

run_mill() {
  if is_true "$MILL_USE_PROXY"; then
    run_net mill "$@"
  else
    run mill "$@"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

find_javac_dir() {
  if command -v javac >/dev/null 2>&1; then
    dirname "$(readlink -f "$(command -v javac)")"
    return 0
  fi

  if [ -d "$HOME/.cache/coursier" ]; then
    found=$(find "$HOME/.cache/coursier" -path '*/bin/javac' -print -quit 2>/dev/null || true)
    if [ -n "$found" ]; then
      dirname "$found"
      return 0
    fi
  fi

  return 1
}

find_elfio_include() {
  for candidate in \
    "$ELFIO_INCLUDE" \
    "$REPO_DIR/ext/ELFIO" \
    "$REPO_DIR/../../NaxRiscv/ext/riscv-isa-sim/include" \
    "$REPO_DIR/../NaxRiscv/ext/riscv-isa-sim/include" \
    "$INSTALL_ROOT/../NaxRiscv/ext/riscv-isa-sim/include" \
    "/usr/local/include" \
    "/usr/include"
  do
    if [ -n "$candidate" ] && [ -f "$candidate/elfio/elfio.hpp" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if is_true "$FETCH_ELFIO"; then
    if [ ! -d "$REPO_DIR/ext/ELFIO/.git" ]; then
      run_net git clone https://github.com/serge1/ELFIO.git "$REPO_DIR/ext/ELFIO" >&2
    fi
    if [ -f "$REPO_DIR/ext/ELFIO/elfio/elfio.hpp" ]; then
      printf '%s\n' "$REPO_DIR/ext/ELFIO"
      return 0
    fi
  fi

  return 1
}

log "Writing install log to $LOG_FILE"

log "Checking required host commands"
require_cmd git
require_cmd make
require_cmd mill
require_cmd c++
require_cmd curl
require_cmd verilator

if proxy_enabled && [ "$CHECK_PROXY" = "1" ]; then
  log "Checking BOSC proxy connectivity"
  run "$PROXY_WRAPPER" --check https://github.com
fi

log "Preparing VexiiRiscv checkout"
if [ -d "$REPO_DIR/.git" ]; then
  log "Using existing repository: $REPO_DIR"
elif [ -e "$REPO_DIR" ]; then
  die "REPO_DIR exists but is not a git checkout: $REPO_DIR"
else
  run mkdir -p "$INSTALL_ROOT"
  run_net git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

log "Repository HEAD"
run git rev-parse HEAD

log "Initializing/updating submodules"
run_net git submodule update --init --recursive

log "Compiling VexiiRiscv Mill target"
run_mill -i Test.2_12_18.compile

if ! is_true "$SKIP_RVLS"; then
  log "Building Spike with commit log support"
  SPIKE_DIR="$REPO_DIR/ext/riscv-isa-sim"
  [ -d "$SPIKE_DIR" ] || die "Missing Spike submodule: $SPIKE_DIR"

  if [ -f "$SPIKE_DIR/fesvr/device.h" ] && ! grep -q '#include <cstdint>' "$SPIKE_DIR/fesvr/device.h"; then
    log "Patching Spike fesvr/device.h to include cstdint"
    run sed -i '/#include <functional>/a #include <cstdint>' "$SPIKE_DIR/fesvr/device.h"
  fi

  run mkdir -p "$SPIKE_DIR/build"
  (
    cd "$SPIKE_DIR/build"
    run ../configure --prefix="$SPIKE_PREFIX" --enable-commitlog --without-boost --without-boost-asio --without-boost-regex
    run make -j "$JOBS"
  )

  log "Locating ELFIO include path"
  ELFIO_FOUND=$(find_elfio_include) || die "Cannot find elfio/elfio.hpp. Set ELFIO_INCLUDE=/path/that/contains/elfio or set FETCH_ELFIO=1."
  log "Using ELFIO include: $ELFIO_FOUND"

  log "Locating javac for RVLS JNI headers"
  JAVAC_BIN_DIR=$(find_javac_dir) || die "Cannot find javac. Install a JDK or run Mill once so Coursier downloads one."
  log "Using javac from: $JAVAC_BIN_DIR"

  log "Building RVLS JNI backend"
  RVLS_DIR="$REPO_DIR/ext/rvls"
  [ -d "$RVLS_DIR" ] || die "Missing RVLS submodule: $RVLS_DIR"
  RVLS_INCLUDE="-I$SPIKE_DIR/riscv -I$SPIKE_DIR/fesvr -I$SPIKE_DIR/softfloat -I$SPIKE_DIR/build -I$ELFIO_FOUND"
  (
    cd "$RVLS_DIR"
    run env PATH="$JAVAC_BIN_DIR:$PATH" make CXX=c++ LIBRARIES="-lpthread -ldl" INCLUDE="$RVLS_INCLUDE" -j "$JOBS"
  )

  [ -f "$REPO_DIR/ext/rvls/build/apps/rvls.so" ] || die "RVLS build did not produce ext/rvls/build/apps/rvls.so"
else
  log "Skipping Spike/RVLS build because SKIP_RVLS=$SKIP_RVLS"
fi

if ! is_true "$SKIP_SMOKE"; then
  log "Running simulator smoke test"
  if is_true "$SKIP_RVLS"; then
    run_mill -i Test.2_12_18.runMain vexiiriscv.tester.TestBench --with-mul --with-div --load-elf ext/NaxSoftware/riscv-tests/rv32ui-p-add --start-symbol test_2 --no-rvls-check --no-stdin --fail-after 100000 --name rv32ui-p-add
  else
    run_mill -i Test.2_12_18.runMain vexiiriscv.tester.TestBench --with-mul --with-div --load-elf ext/NaxSoftware/riscv-tests/rv32ui-p-add --start-symbol test_2 --with-rvls-log --with-spike-log --no-stdin --fail-after 100000 --name "$SMOKE_NAME"
    [ -f "$REPO_DIR/simWorkspace/VexiiRiscv/$SMOKE_NAME/tracer.log" ] || die "Missing RVLS tracer log"
    [ -f "$REPO_DIR/simWorkspace/VexiiRiscv/$SMOKE_NAME/spike.log" ] || die "Missing Spike log"
  fi
else
  log "Skipping smoke test because SKIP_SMOKE=$SKIP_SMOKE"
fi

log "Install/build flow completed"
log "Repository: $REPO_DIR"
log "Log file: $LOG_FILE"
