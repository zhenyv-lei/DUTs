#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export CVA6_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
export TOOLS_ROOT="$CVA6_ROOT/tools"
export TOOLS_SRC_DIR="${TOOLS_SRC_DIR:-$TOOLS_ROOT/src}"
export TOOLS_BUILD_DIR="${TOOLS_BUILD_DIR:-$TOOLS_ROOT/build}"

if [[ -z "${NUM_JOBS:-}" ]]; then
  if command -v nproc >/dev/null 2>&1; then
    export NUM_JOBS="$(nproc)"
  else
    export NUM_JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
  fi
fi

need_cmd() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Missing required command: $cmd" >&2
      exit 1
    fi
  done
}

clone_or_fetch() {
  local repo="$1"
  local dir="$2"
  mkdir -p "$(dirname "$dir")"
  if [[ ! -d "$dir/.git" ]]; then
    git clone "$repo" "$dir"
  else
    git -C "$dir" fetch --tags origin
  fi
}

mkdir -p "$TOOLS_SRC_DIR" "$TOOLS_BUILD_DIR"
