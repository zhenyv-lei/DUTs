#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# User configurable macros
###############################################################################

# Workspace and checkout locations.
DUTS_ROOT="${DUTS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NAXRISCV_DIR="${NAXRISCV_DIR:-$DUTS_ROOT/NaxRiscv}"

# Upstream source selection.
NAXRISCV_REPO_URL="${NAXRISCV_REPO_URL:-https://github.com/SpinalHDL/NaxRiscv.git}"
NAXRISCV_BRANCH="${NAXRISCV_BRANCH:-rvls-update}"
NAXRISCV_TARGET="${NAXRISCV_TARGET:-rv64imafdcsu}"

# Tool versions used by the NaxRiscv Makefile at the validated revision.
VERILATOR_VERSION_NAX="${VERILATOR_VERSION_NAX:-v4.216}"
ELFIO_VERSION="${ELFIO_VERSION:-d251da09a07dff40af0b63b8f6c8ae71d2d1938d}"
LIBSDL_VERSION="${LIBSDL_VERSION:-60d1944e463da73f753661190d783961a9c5b764}"

# Local build/cache paths.
LOCAL_HOME="${LOCAL_HOME:-$NAXRISCV_DIR/.home}"
COURSIER_CACHE_DIR="${COURSIER_CACHE_DIR:-$NAXRISCV_DIR/.cache/coursier}"
CCACHE_DIR_LOCAL="${CCACHE_DIR_LOCAL:-$NAXRISCV_DIR/.cache/ccache}"
SBT_BOOT_DIR="${SBT_BOOT_DIR:-$NAXRISCV_DIR/.sbt/boot}"
SBT_GLOBAL_DIR="${SBT_GLOBAL_DIR:-$NAXRISCV_DIR/.sbt/global}"
IVY_HOME_DIR="${IVY_HOME_DIR:-$NAXRISCV_DIR/.ivy2}"

# Execution switches.
THREAD_COUNT="${THREAD_COUNT:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"
CHECK_HOST_DEPS="${CHECK_HOST_DEPS:-1}"
UPDATE_EXISTING_REPO="${UPDATE_EXISTING_REPO:-0}"
INSTALL_TOOLCHAIN="${INSTALL_TOOLCHAIN:-1}"
GENERATE_RTL="${GENERATE_RTL:-1}"
BUILD_SIMULATOR="${BUILD_SIMULATOR:-1}"
RUN_SMOKE_TEST="${RUN_SMOKE_TEST:-1}"
RUN_TEST_FAST="${RUN_TEST_FAST:-1}"
RUN_TEST_ALL="${RUN_TEST_ALL:-0}"
APPLY_HOST_FIXES="${APPLY_HOST_FIXES:-1}"
PATCH_WGET_TO_CURL="${PATCH_WGET_TO_CURL:-1}"
PATCH_BOOST_LINKS="${PATCH_BOOST_LINKS:-1}"

# Network/proxy controls. Keep site-specific endpoints out of this file.
USE_BOSC_PROXY="${USE_BOSC_PROXY:-0}"
BOSC_PROXY_WRAPPER="${BOSC_PROXY_WRAPPER:-}"
BOSC_PROXY_URL="${BOSC_PROXY_URL:-}"
JAVA_SOCKS_PROXY_HOST="${JAVA_SOCKS_PROXY_HOST:-}"
JAVA_SOCKS_PROXY_PORT="${JAVA_SOCKS_PROXY_PORT:-}"

# Test selection.
SMOKE_TEST_NAME="${SMOKE_TEST_NAME:-rv64ui-p-addi}"
SMOKE_TEST_ELF="${SMOKE_TEST_ELF:-ext/NaxSoftware/riscv-tests/rv64ui-p-addi}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-100000}"

###############################################################################
# Implementation
###############################################################################

usage() {
  cat <<'EOF'
Usage:
  scripts/setup_naxriscv.sh

Common overrides:
  NAXRISCV_DIR=/scratch/DUTs/NaxRiscv scripts/setup_naxriscv.sh
  THREAD_COUNT=16 RUN_TEST_FAST=0 scripts/setup_naxriscv.sh
  USE_BOSC_PROXY=1 BOSC_PROXY_WRAPPER=/path/to/with_bosc_proxy.sh scripts/setup_naxriscv.sh

All portable path and behavior settings are defined as macros at the top of
this script and can be overridden through environment variables.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

run() {
  {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  } >&2
  "$@"
}

run_network() {
  if [[ "$USE_BOSC_PROXY" == "1" ]]; then
    [[ -n "$BOSC_PROXY_WRAPPER" ]] || die "USE_BOSC_PROXY=1 requires BOSC_PROXY_WRAPPER=/path/to/with_bosc_proxy.sh"
    [[ -x "$BOSC_PROXY_WRAPPER" ]] || die "BOSC_PROXY_WRAPPER is not executable: $BOSC_PROXY_WRAPPER"
    if [[ -n "$BOSC_PROXY_URL" ]]; then
      {
        printf '+ BOSC_PROXY_URL=%q %q --' "$BOSC_PROXY_URL" "$BOSC_PROXY_WRAPPER"
        printf ' %q' "$@"
        printf '\n'
      } >&2
      BOSC_PROXY_URL="$BOSC_PROXY_URL" "$BOSC_PROXY_WRAPPER" -- "$@"
    else
      {
        printf '+ %q --' "$BOSC_PROXY_WRAPPER"
        printf ' %q' "$@"
        printf '\n'
      } >&2
      "$BOSC_PROXY_WRAPPER" -- "$@"
    fi
  else
    run "$@"
  fi
}

check_host_deps() {
  [[ "$CHECK_HOST_DEPS" == "1" ]] || return 0

  local missing=()
  local cmd
  for cmd in git make gcc g++ autoconf flex bison curl wget tar sed grep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if ((${#missing[@]})); then
    printf 'Missing host commands:' >&2
    printf ' %s' "${missing[@]}" >&2
    printf '\nInstall the required host packages, then rerun this script.\n' >&2
    exit 1
  fi
}

ensure_naxriscv_checkout() {
  log "Preparing NaxRiscv checkout at $NAXRISCV_DIR"

  if [[ -d "$NAXRISCV_DIR/.git" ]]; then
    log "Existing NaxRiscv checkout found"
    if [[ "$UPDATE_EXISTING_REPO" == "1" ]]; then
      run_network git -C "$NAXRISCV_DIR" fetch origin "$NAXRISCV_BRANCH"
      run git -C "$NAXRISCV_DIR" checkout -B "$NAXRISCV_BRANCH" "origin/$NAXRISCV_BRANCH"
    else
      log "Skipping repository update because UPDATE_EXISTING_REPO=0"
    fi
    return 0
  fi

  if [[ -e "$NAXRISCV_DIR" ]]; then
    die "$NAXRISCV_DIR exists but is not a Git checkout"
  fi

  run mkdir -p "$(dirname "$NAXRISCV_DIR")"
  run_network git clone "$NAXRISCV_REPO_URL" "$NAXRISCV_DIR"
  run git -C "$NAXRISCV_DIR" checkout -B "$NAXRISCV_BRANCH" "origin/$NAXRISCV_BRANCH"
}

configure_local_env() {
  log "Configuring repo-local build caches"

  export NAXRISCV="$NAXRISCV_DIR"
  export JAVA_HOME="$NAXRISCV_DIR/toolchain/openjdk"
  export PATH="$JAVA_HOME/bin:$NAXRISCV_DIR/toolchain/verilator-$VERILATOR_VERSION_NAX/bin:$PATH"
  export HOME="$LOCAL_HOME"
  export COURSIER_CACHE="$COURSIER_CACHE_DIR"
  export CCACHE_DIR="$CCACHE_DIR_LOCAL"

  mkdir -p "$LOCAL_HOME" "$COURSIER_CACHE_DIR" "$CCACHE_DIR_LOCAL" \
    "$SBT_BOOT_DIR" "$SBT_GLOBAL_DIR" "$IVY_HOME_DIR"

  local sbt_cache_opts
  sbt_cache_opts="-Dsbt.boot.directory=$SBT_BOOT_DIR"
  sbt_cache_opts="$sbt_cache_opts -Dsbt.global.base=$SBT_GLOBAL_DIR"
  sbt_cache_opts="$sbt_cache_opts -Dsbt.ivy.home=$IVY_HOME_DIR"
  sbt_cache_opts="$sbt_cache_opts -Dsbt.coursier.home=$COURSIER_CACHE_DIR"

  export SBT_OPTS="${SBT_OPTS:-} $sbt_cache_opts"

  if [[ -n "$JAVA_SOCKS_PROXY_HOST" || -n "$JAVA_SOCKS_PROXY_PORT" ]]; then
    [[ -n "$JAVA_SOCKS_PROXY_HOST" && -n "$JAVA_SOCKS_PROXY_PORT" ]] || \
      die "Set both JAVA_SOCKS_PROXY_HOST and JAVA_SOCKS_PROXY_PORT"
    local socks_opts
    socks_opts="-DsocksProxyHost=$JAVA_SOCKS_PROXY_HOST -DsocksProxyPort=$JAVA_SOCKS_PROXY_PORT -Djava.net.preferIPv4Stack=true"
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} $socks_opts"
    export SBT_OPTS="$SBT_OPTS $socks_opts"
  fi
}

patch_wget_downloaders() {
  [[ "$PATCH_WGET_TO_CURL" == "1" ]] || return 0

  log "Patching NaxRiscv downloader scripts to use curl"
  local file
  for file in "$NAXRISCV_DIR/ci/install-sbt.sh" "$NAXRISCV_DIR/ci/install-openjdk.sh"; do
    [[ -f "$file" ]] || continue
    if grep -qE '^[[:space:]]*wget[[:space:]]+https?://' "$file"; then
      run sed -i -E 's#^([[:space:]]*)wget[[:space:]]+(https?://[^[:space:]]+)[[:space:]]*$#\1curl -L --fail -O \2#' "$file"
    fi
  done
}

patch_verilator_memory_include() {
  [[ "$APPLY_HOST_FIXES" == "1" ]] || return 0

  local v3const="$NAXRISCV_DIR/toolchain/verilator-$VERILATOR_VERSION_NAX/src/V3Const.cpp"
  [[ -f "$v3const" ]] || return 0

  if ! grep -q '^#include <memory>' "$v3const"; then
    log "Adding missing <memory> include to Verilator V3Const.cpp"
    run sed -i '/#include <algorithm>/a #include <memory>' "$v3const"
  fi
}

install_initial_toolchain() {
  [[ "$INSTALL_TOOLCHAIN" == "1" ]] || return 0

  if [[ -x "$NAXRISCV_DIR/toolchain/sbt/bin/sbt" && -x "$NAXRISCV_DIR/toolchain/openjdk/bin/java" ]]; then
    log "SBT and OpenJDK already installed"
    return 0
  fi

  patch_wget_downloaders
  log "Installing initial NaxRiscv toolchain"
  (cd "$NAXRISCV_DIR" && run_network make install-toolchain-initial)
}

install_verilator() {
  [[ "$INSTALL_TOOLCHAIN" == "1" ]] || return 0

  local toolchain_dir="$NAXRISCV_DIR/toolchain"
  local verilator_dir="$toolchain_dir/verilator-$VERILATOR_VERSION_NAX"

  if [[ -x "$verilator_dir/bin/verilator" ]]; then
    log "Verilator already installed at $verilator_dir"
    return 0
  fi

  log "Installing Verilator $VERILATOR_VERSION_NAX"
  run mkdir -p "$toolchain_dir"
  if [[ ! -d "$verilator_dir/.git" ]]; then
    run_network git clone https://github.com/verilator/verilator.git "$verilator_dir"
  fi

  run git -C "$verilator_dir" checkout "$VERILATOR_VERSION_NAX"
  patch_verilator_memory_include
  (
    cd "$verilator_dir"
    unset VERILATOR_ROOT
    run autoconf
    run ./configure --prefix="$verilator_dir"
    run make -j"$THREAD_COUNT"
  )
}

relink_spike_without_boost() {
  [[ "$PATCH_BOOST_LINKS" == "1" ]] || return 0

  local build="$NAXRISCV_DIR/ext/riscv-isa-sim/build"
  local required=(
    "$build/spike.o"
    "$build/libspike_main.a"
    "$build/libriscv.a"
    "$build/libdisasm.a"
    "$build/libsoftfloat.a"
    "$build/libfesvr.a"
    "$build/libfdt.a"
  )
  local file
  for file in "${required[@]}"; do
    [[ -f "$file" ]] || return 0
  done

  log "Relinking Spike package.so without Boost libraries"
  (
    cd "$build"
    run g++ --shared -L. -Wl,--export-dynamic -L/usr/lib/x86_64-linux-gnu \
      -Wl,-rpath,/lib -o package.so \
      spike.o libspike_main.a libriscv.a libdisasm.a libsoftfloat.a \
      libfesvr.a libfdt.a -lpthread -ldl
  )
}

patch_boost_link_flags() {
  [[ "$PATCH_BOOST_LINKS" == "1" ]] || return 0

  log "Patching local Boost link flags"
  local rvls_mk="$NAXRISCV_DIR/ext/rvls/Makefile"
  local sim_mk="$NAXRISCV_DIR/src/test/cpp/naxriscv/makefile"

  if [[ -f "$rvls_mk" ]]; then
    run sed -i -E 's#^LIBRARIES[[:space:]]*\+=.*#LIBRARIES += -lpthread -ldl#' "$rvls_mk"
  fi
  if [[ -f "$sim_mk" ]]; then
    run sed -i -E 's#^LIBS[[:space:]]*\+=.*#LIBS +="-lpthread -ldl"#' "$sim_mk"
  fi
}

install_spike_sdl_elfio() {
  [[ "$INSTALL_TOOLCHAIN" == "1" ]] || return 0

  local spike_dir="$NAXRISCV_DIR/ext/riscv-isa-sim"
  if [[ -x "$spike_dir/build/spike" && -f "$spike_dir/build/package.so" ]]; then
    log "Spike, ELFIO, and SDL appear to be installed"
    relink_spike_without_boost
    return 0
  fi

  log "Installing ELFIO, SDL, and Spike"
  if ! (cd "$NAXRISCV_DIR" && run_network ./ci/install-libsdl-elfio-spikespinalhdl.sh "$spike_dir" "$ELFIO_VERSION" "$LIBSDL_VERSION"); then
    relink_spike_without_boost
    [[ -f "$spike_dir/build/package.so" ]] || die "Spike/SDL/ELFIO install failed before package.so could be relinked"
  fi
  relink_spike_without_boost
}

install_rvls() {
  [[ "$INSTALL_TOOLCHAIN" == "1" ]] || return 0

  patch_boost_link_flags
  if [[ -x "$NAXRISCV_DIR/ext/rvls/build/apps/rvls" ]]; then
    log "RVLS already installed"
    return 0
  fi

  log "Installing RVLS"
  (cd "$NAXRISCV_DIR" && run_network ./ci/install-rvls.sh "$NAXRISCV_DIR/ext/rvls")
}

generate_rtl() {
  [[ "$GENERATE_RTL" == "1" ]] || return 0

  log "Generating NaxRiscv RTL for target $NAXRISCV_TARGET"
  (cd "$NAXRISCV_DIR" && run_network make "TARGET_NAX=$NAXRISCV_TARGET" NaxRiscv.v)
}

build_simulator() {
  [[ "$BUILD_SIMULATOR" == "1" ]] || return 0

  patch_boost_link_flags
  log "Building Verilator simulator"
  run make -C "$NAXRISCV_DIR/src/test/cpp/naxriscv" compile "THREAD_COUNT=$THREAD_COUNT"
}

spike_ld_library_path() {
  printf '%s:%s' "$NAXRISCV_DIR/ext/riscv-isa-sim/lib" "$NAXRISCV_DIR/ext/riscv-isa-sim/build"
}

run_smoke_test() {
  [[ "$RUN_SMOKE_TEST" == "1" ]] || return 0

  log "Running smoke test $SMOKE_TEST_NAME"
  run env LD_LIBRARY_PATH="$(spike_ld_library_path)" \
    "$NAXRISCV_DIR/src/test/cpp/naxriscv/obj_dir/VNaxRiscv" \
    --load-elf "$NAXRISCV_DIR/$SMOKE_TEST_ELF" \
    --pass-symbol pass \
    --fail-symbol fail \
    --timeout "$SMOKE_TIMEOUT" \
    --name "$SMOKE_TEST_NAME"
}

run_regressions() {
  local sim_dir="$NAXRISCV_DIR/src/test/cpp/naxriscv"

  if [[ "$RUN_TEST_FAST" == "1" ]]; then
    log "Running test-fast"
    (cd "$sim_dir" && run env LD_LIBRARY_PATH="$(spike_ld_library_path)" make test-fast -j"$THREAD_COUNT")
  fi

  if [[ "$RUN_TEST_ALL" == "1" ]]; then
    log "Running test-all"
    (cd "$sim_dir" && run env LD_LIBRARY_PATH="$(spike_ld_library_path)" make test-all -j"$THREAD_COUNT")
  fi

  if [[ "$RUN_TEST_FAST" == "1" || "$RUN_TEST_ALL" == "1" ]]; then
    log "Test summary"
    (cd "$sim_dir" && run find output -name PASS | wc -l)
    (cd "$sim_dir" && run find output -name FAIL | wc -l)
    (cd "$sim_dir" && run make test-report || true)
  fi
}

main() {
  log "NaxRiscv setup started"
  log "DUTS_ROOT=$DUTS_ROOT"
  log "NAXRISCV_DIR=$NAXRISCV_DIR"
  log "NAXRISCV_BRANCH=$NAXRISCV_BRANCH"
  log "THREAD_COUNT=$THREAD_COUNT"

  check_host_deps
  ensure_naxriscv_checkout
  configure_local_env
  install_initial_toolchain
  install_verilator
  install_spike_sdl_elfio
  install_rvls
  generate_rtl
  build_simulator
  run_smoke_test
  run_regressions

  log "NaxRiscv setup completed"
}

main "$@"
