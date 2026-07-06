#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/bluespec/Toooba.git}"
VERILATOR_URL="${VERILATOR_URL:-https://github.com/verilator/verilator.git}"
VERILATOR_TAG="${VERILATOR_TAG:-v3.922}"
INSTALL_ROOT="${INSTALL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TOOOBA_DIR="${TOOOBA_DIR:-$INSTALL_ROOT/Toooba}"
LOCAL_SEED_REPO="${LOCAL_SEED_REPO:-}"
LOCAL_VERILATOR_SEED="${LOCAL_VERILATOR_SEED:-}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

log() {
  printf '\n[%s] %s\n' "$(date '+%F %T')" "$*" >&2
}

run() {
  log "$*"
  "$@"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

proxy() {
  "$TOOOBA_DIR/scripts/with_bosc_proxy.sh" -- "$@"
}

ensure_basics() {
  for cmd in git make gcc g++ cc perl autoconf flex bison; do
    need_cmd "$cmd"
  done
  if ! printf '#include <gelf.h>\nint main(void){return 0;}\n' | cc -x c - -lelf -o /tmp/toooba-libelf-check >/dev/null 2>&1; then
    echo "Missing libelf development files. Install libelf-dev/libelf-devel before running Toooba tests." >&2
    exit 1
  fi
}

clone_or_reuse_repo() {
  if [[ -d "$TOOOBA_DIR/.git" ]]; then
    log "Using existing Toooba checkout: $TOOOBA_DIR"
    return
  fi

  if [[ -n "$LOCAL_SEED_REPO" ]]; then
    run git clone "$LOCAL_SEED_REPO" "$TOOOBA_DIR"
    run git -C "$TOOOBA_DIR" remote set-url origin "$REPO_URL"
    return
  fi

  run mkdir -p "$(dirname "$TOOOBA_DIR")"
  proxy git clone "$REPO_URL" "$TOOOBA_DIR"
}

init_submodules() {
  if [[ -n "$LOCAL_SEED_REPO" ]]; then
    run git -C "$TOOOBA_DIR" submodule init
    if [[ -d "$LOCAL_SEED_REPO/src_Core/BSV_Additional_Libs/BlueStuff/.git" ]]; then
      run git -C "$TOOOBA_DIR" config submodule.src_Core/BSV_Additional_Libs/BlueStuff.url \
        "$LOCAL_SEED_REPO/src_Core/BSV_Additional_Libs/BlueStuff"
    fi
    run git -C "$TOOOBA_DIR" -c protocol.file.allow=always submodule update --init src_Core/BSV_Additional_Libs/BlueStuff
    run git -C "$TOOOBA_DIR/src_Core/BSV_Additional_Libs/BlueStuff" submodule init
    if [[ -d "$LOCAL_SEED_REPO/src_Core/BSV_Additional_Libs/BlueStuff/BlueBasics/.git" ]]; then
      run git -C "$TOOOBA_DIR/src_Core/BSV_Additional_Libs/BlueStuff" config submodule.BlueBasics.url \
        "$LOCAL_SEED_REPO/src_Core/BSV_Additional_Libs/BlueStuff/BlueBasics"
    fi
    if [[ -d "$LOCAL_SEED_REPO/src_Core/BSV_Additional_Libs/BlueStuff/SocketPacketUtils/.git" ]]; then
      run git -C "$TOOOBA_DIR/src_Core/BSV_Additional_Libs/BlueStuff" config submodule.SocketPacketUtils.url \
        "$LOCAL_SEED_REPO/src_Core/BSV_Additional_Libs/BlueStuff/SocketPacketUtils"
    fi
    run git -C "$TOOOBA_DIR" -c protocol.file.allow=always submodule update --init --recursive
    return
  fi

  "$TOOOBA_DIR/scripts/with_bosc_proxy.sh" --check https://github.com
  proxy git -C "$TOOOBA_DIR" submodule update --init --recursive
}

prepare_verilator_source() {
  local src="$TOOOBA_DIR/tools/src/verilator-$VERILATOR_TAG"
  run mkdir -p "$TOOOBA_DIR/tools/src" "$TOOOBA_DIR/tools/build"

  if [[ -d "$src/.git" ]]; then
    log "Using existing Verilator source: $src"
  elif [[ -n "$LOCAL_VERILATOR_SEED" ]]; then
    run git clone "$LOCAL_VERILATOR_SEED" "$src"
  else
    proxy git clone --branch "$VERILATOR_TAG" --depth 1 "$VERILATOR_URL" "$src"
  fi

  run git -C "$src" checkout "$VERILATOR_TAG"
  patch_verilator_bisonpre "$src"
}

patch_verilator_bisonpre() {
  local src="$1"
  local file="$src/src/bisonpre"
  if grep -q 'Keep that include pointed at bisonpre' "$file"; then
    log "Verilator bisonpre compatibility patch already present"
    return
  fi

  perl -0pi -e '
    my $old = q{    $fh = IO::File->new(">$outname") or die "%Error: $! writing $outname\n";
    foreach my $line (@lines) {
	# Fix filename refs
	$line =~ s!$basename!$newbase!g;
	# Fix bison 2.3 and GCC 4.2.1
};
    my $new = q{    $fh = IO::File->new(">$outname") or die "%Error: $! writing $outname\n";
    (my $outbase = output_prefix()) =~ s!.*/!!;
    foreach my $line (@lines) {
	# Fix filename refs
	$line =~ s!$basename!$newbase!g;
	# Bison 3.x emits an include of the generated header.  Keep that
	# include pointed at bisonpre actual output name.
	$line =~ s!^#include\s+"$newbase\Qh\E"!#include "$outbase.h"!;
	# Fix bison 2.3 and GCC 4.2.1
};
    s/\Q$old\E/$new/ or die "Could not find expected bisonpre patch point\n";
  ' "$file"
}

install_verilator() {
  local src="$TOOOBA_DIR/tools/src/verilator-$VERILATOR_TAG"
  local prefix="$TOOOBA_DIR/tools/verilator-3.922"

  (cd "$src" && run autoconf)
  (cd "$src" && run ./configure --prefix="$prefix")
  run make -C "$src" -j"$JOBS"
  run make -C "$src" install
  ensure_verilator_layout "$prefix"
  run "$prefix/bin/verilator" --version
}

ensure_verilator_layout() {
  local prefix="$1"
  if [[ ! -e "$prefix/include" ]]; then
    run ln -s share/verilator/include "$prefix/include"
  fi
  if [[ ! -e "$prefix/bin/verilator_includer" ]]; then
    run ln -s ../share/verilator/bin/verilator_includer "$prefix/bin/verilator_includer"
  fi
}

patch_toooba_verilator_config() {
  local file="$TOOOBA_DIR/builds/Resources/Verilator_resources/verilator_config.vlt"
  run perl -0pi -e 's/lint_off -rule /lint_off -msg /g' "$file"
}

build_and_test() {
  source "$TOOOBA_DIR/scripts/env.sh"
  patch_toooba_verilator_config
  run make -C "$TOOOBA_DIR/builds/RV64ACDFIMSU_Toooba_verilator" simulator
  run make -C "$TOOOBA_DIR/builds/RV64ACDFIMSU_Toooba_verilator" test
}

main() {
  ensure_basics
  clone_or_reuse_repo
  init_submodules
  prepare_verilator_source
  install_verilator
  build_and_test
  log "Toooba deployment completed: $TOOOBA_DIR"
}

main "$@"
