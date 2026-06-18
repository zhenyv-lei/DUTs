#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$TOOLS_DIR/src"
BUILD_DIR="$TOOLS_DIR/build"

VERILATOR_VERSION="${VERILATOR_VERSION:-v4.228}"
REPO_URL="${VERILATOR_REPO_URL:-https://github.com/verilator/verilator.git}"
SRC_REPO="$SRC_DIR/verilator"
PREFIX="$BUILD_DIR/verilator-$VERILATOR_VERSION"
LINK="$BUILD_DIR/verilator"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

mkdir -p "$SRC_DIR" "$BUILD_DIR"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[verilator] missing required command: $1" >&2
    exit 1
  fi
}

need_cmd git
need_cmd autoconf
need_cmd make
need_cmd perl

GIT_CMD=(git)
if [ -n "${GIT_PROXY_CMD:-}" ]; then
  read -r -a proxy_cmd <<< "$GIT_PROXY_CMD"
  GIT_CMD=("${proxy_cmd[@]}" git)
fi

if [ ! -d "$SRC_REPO/.git" ]; then
  echo "[verilator] cloning $REPO_URL into $SRC_REPO"
  "${GIT_CMD[@]}" clone "$REPO_URL" "$SRC_REPO"
else
  echo "[verilator] using existing source: $SRC_REPO"
fi

cd "$SRC_REPO"
"${GIT_CMD[@]}" fetch --tags
git checkout "$VERILATOR_VERSION"

if [ ! -x "$PREFIX/bin/verilator" ]; then
  echo "[verilator] building $VERILATOR_VERSION with JOBS=$JOBS"
  autoconf
  ./configure --prefix="$PREFIX"
  make -j"$JOBS"
  make install
else
  echo "[verilator] using existing install: $PREFIX"
fi

ln -sfn "$(basename "$PREFIX")" "$LINK"

echo "[verilator] installed at: $LINK"
"$LINK/bin/verilator" --version
