#!/usr/bin/env sh
set -eu
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

###############################################################################
# User configurable macros
###############################################################################

_SCRIPT_PATH=$0
case "$_SCRIPT_PATH" in
  */*) ;;
  *) _SCRIPT_PATH=$(command -v "$_SCRIPT_PATH" 2>/dev/null || printf '%s\n' "$_SCRIPT_PATH") ;;
esac
_SCRIPT_DIR=$(CDPATH= cd "$(dirname "$_SCRIPT_PATH")" && pwd -P)

DUTS_ROOT="${DUTS_ROOT:-$(CDPATH= cd "$_SCRIPT_DIR/../.." && pwd -P)}"
NAXRISCV_WORKSPACE="${NAXRISCV_WORKSPACE:-$(CDPATH= cd "$_SCRIPT_DIR/.." && pwd -P)}"

if [ -f "$NAXRISCV_WORKSPACE/Makefile" ] && [ -d "$NAXRISCV_WORKSPACE/ci" ]; then
  DEFAULT_NAXRISCV_DIR="$NAXRISCV_WORKSPACE"
else
  DEFAULT_NAXRISCV_DIR="$NAXRISCV_WORKSPACE/upstream"
fi
NAXRISCV_DIR="${NAXRISCV_DIR:-$DEFAULT_NAXRISCV_DIR}"

NAXRISCV_REPO_URL="${NAXRISCV_REPO_URL:-https://github.com/SpinalHDL/NaxRiscv.git}"
NAXRISCV_BRANCH="${NAXRISCV_BRANCH:-rvls-update}"
NAXRISCV_TARGET="${NAXRISCV_TARGET:-rv64imafdcsu}"

THREAD_COUNT="${THREAD_COUNT:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"

# Network controls. Proxy endpoint stays outside Git; set BOSC_PROXY_URL or
# BOSC_PROXY_HOST/BOSC_PROXY_PORT when USE_BOSC_PROXY=1.
USE_BOSC_PROXY="${USE_BOSC_PROXY:-0}"
BOSC_PROXY_SCRIPT="${BOSC_PROXY_SCRIPT:-$NAXRISCV_WORKSPACE/scripts/with_bosc_proxy.sh}"
BOSC_PROXY_CHECK_URL="${BOSC_PROXY_CHECK_URL:-https://github.com}"

# Setup stages.
UPDATE_EXISTING_REPO="${UPDATE_EXISTING_REPO:-0}"
CHECK_HOST_DEPS="${CHECK_HOST_DEPS:-1}"
APPLY_LOCAL_FIXES="${APPLY_LOCAL_FIXES:-1}"
RUN_SMOKE_TEST="${RUN_SMOKE_TEST:-1}"
RUN_TEST_FAST="${RUN_TEST_FAST:-1}"
RUN_TEST_ALL="${RUN_TEST_ALL:-0}"

# Smoke test.
SMOKE_TEST_NAME="${SMOKE_TEST_NAME:-rv64ui-p-addi}"
SMOKE_TEST_ELF="${SMOKE_TEST_ELF:-ext/NaxSoftware/riscv-tests/rv64ui-p-addi}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-100000}"

###############################################################################
# Implementation
###############################################################################

usage() {
  cat <<'EOF'
Usage:
  cd NaxRiscv
  ./scripts/setup_naxriscv.sh

Common overrides:
  NAXRISCV_DIR=/scratch/$USER/DUTs/NaxRiscv ./scripts/setup_naxriscv.sh
  THREAD_COUNT=16 RUN_TEST_FAST=0 ./scripts/setup_naxriscv.sh
  USE_BOSC_PROXY=1 BOSC_PROXY_URL=socks5h://HOST:PORT ./scripts/setup_naxriscv.sh

Default checkout location:
  - If NaxRiscv/ is already an upstream checkout, reuse NaxRiscv/.
  - Otherwise clone upstream into NaxRiscv/upstream/.

The script follows the upstream NaxRiscv README flow:
  1. clone and checkout rvls-update
  2. install initial toolchain and submodules
  3. install Verilator, Spike/ELFIO/SDL, and RVLS
  4. generate RTL
  5. build VNaxRiscv
  6. run a smoke test and optional regressions

This script uses POSIX-style shell syntax and is checked with sh, bash, and zsh.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

run() {
  printf '+' >&2
  for _arg in "$@"; do
    printf ' %s' "$_arg" >&2
  done
  printf '\n' >&2
  "$@"
}

net() {
  if [ "$USE_BOSC_PROXY" = "1" ]; then
    [ -x "$BOSC_PROXY_SCRIPT" ] || die "BOSC_PROXY_SCRIPT is not executable: $BOSC_PROXY_SCRIPT"
    run "$BOSC_PROXY_SCRIPT" -- "$@"
  else
    run "$@"
  fi
}

check_proxy() {
  [ "$USE_BOSC_PROXY" = "1" ] || return 0
  log "Checking BOSC proxy"
  run "$BOSC_PROXY_SCRIPT" --check "$BOSC_PROXY_CHECK_URL"
}

check_host_deps() {
  [ "$CHECK_HOST_DEPS" = "1" ] || return 0

  missing=""
  for cmd in git make gcc g++ autoconf flex bison curl tar sed grep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing="$missing $cmd"
    fi
  done

  if [ -n "$missing" ]; then
    printf 'Missing host commands:%s\n' "$missing" >&2
    printf 'Install them with your system package manager, then rerun this script.\n' >&2
    exit 1
  fi
}

prepare_checkout() {
  log "Preparing NaxRiscv checkout: $NAXRISCV_DIR"

  if [ -d "$NAXRISCV_DIR/.git" ]; then
    log "Existing checkout found"
    if [ "$UPDATE_EXISTING_REPO" = "1" ]; then
      net git -C "$NAXRISCV_DIR" fetch origin "$NAXRISCV_BRANCH"
      run git -C "$NAXRISCV_DIR" checkout -B "$NAXRISCV_BRANCH" "origin/$NAXRISCV_BRANCH"
    else
      log "Keeping existing checkout because UPDATE_EXISTING_REPO=0"
    fi
    return 0
  fi

  if [ -e "$NAXRISCV_DIR" ]; then
    die "$NAXRISCV_DIR exists but is not a Git checkout"
  fi

  run mkdir -p "$(dirname "$NAXRISCV_DIR")"
  net git clone "$NAXRISCV_REPO_URL" "$NAXRISCV_DIR"
  run git -C "$NAXRISCV_DIR" checkout -B "$NAXRISCV_BRANCH" "origin/$NAXRISCV_BRANCH"
}

setup_project_env() {
  log "Configuring repo-local caches"

  export NAXRISCV="$NAXRISCV_DIR"
  export JAVA_HOME="$NAXRISCV_DIR/toolchain/openjdk"
  export PATH="$JAVA_HOME/bin:$NAXRISCV_DIR/toolchain/verilator-v4.216/bin:$PATH"
  export HOME="$NAXRISCV_DIR/.home"
  export COURSIER_CACHE="$NAXRISCV_DIR/.cache/coursier"
  export CCACHE_DIR="$NAXRISCV_DIR/.cache/ccache"

  mkdir -p "$HOME" "$COURSIER_CACHE" "$CCACHE_DIR" \
    "$NAXRISCV_DIR/.sbt/boot" \
    "$NAXRISCV_DIR/.sbt/global" \
    "$NAXRISCV_DIR/.ivy2"

  export SBT_OPTS="${SBT_OPTS:-} \
-Dsbt.boot.directory=$NAXRISCV_DIR/.sbt/boot \
-Dsbt.global.base=$NAXRISCV_DIR/.sbt/global \
-Dsbt.ivy.home=$NAXRISCV_DIR/.ivy2 \
-Dsbt.coursier.home=$COURSIER_CACHE"
}

patch_upstream_installers() {
  [ "$APPLY_LOCAL_FIXES" = "1" ] || return 0

  log "Applying local installer compatibility fixes"

  sbt_installer="$NAXRISCV_DIR/ci/install-sbt.sh"
  jdk_installer="$NAXRISCV_DIR/ci/install-openjdk.sh"
  spike_installer="$NAXRISCV_DIR/ci/install-libsdl-elfio-spikespinalhdl.sh"
  verilator_installer="$NAXRISCV_DIR/ci/install-verilator.sh"

  # wget in this environment does not handle SOCKS proxies reliably; curl does.
  for file in "$sbt_installer" "$jdk_installer"; do
    if [ -f "$file" ] && grep -qE '^[[:space:]]*wget[[:space:]]+https?://' "$file"; then
      run sed -i -E 's#^([[:space:]]*)wget[[:space:]]+(https?://[^[:space:]]+)[[:space:]]*$#\1curl -L --fail -O \2#' "$file"
    fi
  done

  # Verilator v4.216 can need <memory> with newer host compilers.
  if [ -f "$verilator_installer" ] && ! grep -q 'DUTs local fix: add <memory>' "$verilator_installer"; then
    run sed -i '/git checkout \$VERILATOR_VERSION/a\
\
    # DUTs local fix: add <memory> for newer host compilers.\
    if [ -f src/V3Const.cpp ] && ! grep -q "^#include <memory>" src/V3Const.cpp; then\
        sed -i "/#include <algorithm>/a #include <memory>" src/V3Const.cpp\
    fi' "$verilator_installer"
  fi

  # Spike is configured without Boost, so package.so should not link Boost libs.
  if [ -f "$spike_installer" ]; then
    run sed -i -E 's/[[:space:]]*-lboost_regex//g; s/[[:space:]]*-lboost_system//g' "$spike_installer"
  fi
}

patch_local_link_flags() {
  [ "$APPLY_LOCAL_FIXES" = "1" ] || return 0

  rvls_makefile="$NAXRISCV_DIR/ext/rvls/Makefile"
  sim_makefile="$NAXRISCV_DIR/src/test/cpp/naxriscv/makefile"

  if [ -f "$rvls_makefile" ]; then
    run sed -i -E 's#^LIBRARIES[[:space:]]*\+=.*#LIBRARIES += -lpthread -ldl#' "$rvls_makefile"
  fi
  if [ -f "$sim_makefile" ]; then
    run sed -i -E 's#^LIBS[[:space:]]*\+=.*#LIBS +="-lpthread -ldl"#' "$sim_makefile"
  fi
}

install_initial_toolchain() {
  if [ -x "$NAXRISCV_DIR/toolchain/sbt/bin/sbt" ] && [ -x "$NAXRISCV_DIR/toolchain/openjdk/bin/java" ]; then
    log "Initial toolchain already installed"
    return 0
  fi

  log "Installing initial toolchain and submodules"
  patch_upstream_installers
  (cd "$NAXRISCV_DIR" && net make install-toolchain-initial)
}

install_remaining_toolchain() {
  log "Installing Verilator, Spike/ELFIO/SDL, and RVLS"

  patch_upstream_installers
  patch_local_link_flags

  spike_dir="$NAXRISCV_DIR/ext/riscv-isa-sim"
  rvls_dir="$NAXRISCV_DIR/ext/rvls"

  (cd "$NAXRISCV_DIR" && net ./ci/install-verilator.sh v4.216 "$NAXRISCV_DIR/toolchain")
  (cd "$NAXRISCV_DIR" && net ./ci/install-libsdl-elfio-spikespinalhdl.sh "$spike_dir" d251da09a07dff40af0b63b8f6c8ae71d2d1938d 60d1944e463da73f753661190d783961a9c5b764)
  patch_local_link_flags
  (cd "$NAXRISCV_DIR" && net ./ci/install-rvls.sh "$rvls_dir")
}

generate_rtl() {
  log "Generating RTL"
  (cd "$NAXRISCV_DIR" && net make "TARGET_NAX=$NAXRISCV_TARGET" NaxRiscv.v)
}

build_simulator() {
  log "Building VNaxRiscv"
  patch_local_link_flags
  run make -C "$NAXRISCV_DIR/src/test/cpp/naxriscv" compile "THREAD_COUNT=$THREAD_COUNT"
}

spike_ld_path() {
  printf '%s:%s' "$NAXRISCV_DIR/ext/riscv-isa-sim/lib" "$NAXRISCV_DIR/ext/riscv-isa-sim/build"
}

run_smoke() {
  [ "$RUN_SMOKE_TEST" = "1" ] || return 0

  log "Running smoke test: $SMOKE_TEST_NAME"
  run env LD_LIBRARY_PATH="$(spike_ld_path)" \
    "$NAXRISCV_DIR/src/test/cpp/naxriscv/obj_dir/VNaxRiscv" \
    --load-elf "$NAXRISCV_DIR/$SMOKE_TEST_ELF" \
    --pass-symbol pass \
    --fail-symbol fail \
    --timeout "$SMOKE_TIMEOUT" \
    --name "$SMOKE_TEST_NAME"
}

run_tests() {
  sim_dir="$NAXRISCV_DIR/src/test/cpp/naxriscv"

  if [ "$RUN_TEST_FAST" = "1" ]; then
    log "Running test-fast"
    (cd "$sim_dir" && run env LD_LIBRARY_PATH="$(spike_ld_path)" make test-fast -j"$THREAD_COUNT")
  fi

  if [ "$RUN_TEST_ALL" = "1" ]; then
    log "Running test-all"
    (cd "$sim_dir" && run env LD_LIBRARY_PATH="$(spike_ld_path)" make test-all -j"$THREAD_COUNT")
  fi

  if [ "$RUN_TEST_FAST" = "1" ] || [ "$RUN_TEST_ALL" = "1" ]; then
    log "Test summary"
    (cd "$sim_dir" && run find output -name PASS | wc -l)
    (cd "$sim_dir" && run find output -name FAIL | wc -l)
    (cd "$sim_dir" && run make test-report || true)
  fi
}

main() {
  log "NaxRiscv setup started"
  log "DUTS_ROOT=$DUTS_ROOT"
  log "NAXRISCV_WORKSPACE=$NAXRISCV_WORKSPACE"
  log "NAXRISCV_DIR=$NAXRISCV_DIR"
  log "NAXRISCV_BRANCH=$NAXRISCV_BRANCH"
  log "THREAD_COUNT=$THREAD_COUNT"

  check_host_deps
  check_proxy
  prepare_checkout
  setup_project_env
  install_initial_toolchain
  install_remaining_toolchain
  generate_rtl
  build_simulator
  run_smoke
  run_tests

  log "NaxRiscv setup completed"
}

main "$@"
