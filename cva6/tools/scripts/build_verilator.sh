#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$SCRIPT_DIR/versions.sh"

need_cmd git tar autoconf make patch

SRC_DIR="$TOOLS_SRC_DIR/verilator"
BUILD_DIR="$TOOLS_BUILD_DIR/verilator-${VERILATOR_VERSION}"
INSTALL_DIR="$TOOLS_BUILD_DIR/verilator"
PATCH_FILE="$CVA6_ROOT/verif/regress/verilator-v5.patch"

if [[ -x "$INSTALL_DIR/bin/verilator" && "${FORCE_REBUILD:-0}" != "1" ]]; then
  echo "Verilator already installed: $INSTALL_DIR/bin/verilator"
  "$INSTALL_DIR/bin/verilator" --version
  exit 0
fi

clone_or_fetch "$VERILATOR_REPO" "$SRC_DIR"
git -C "$SRC_DIR" fetch --tags origin
git -C "$SRC_DIR" checkout "$VERILATOR_VERSION"

rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"
git -C "$SRC_DIR" archive "$VERILATOR_VERSION" | tar -x -C "$BUILD_DIR"

cd "$BUILD_DIR"
if [[ -f "$PATCH_FILE" ]]; then
  patch -p1 < "$PATCH_FILE" || true
fi

autoconf
./configure --prefix="$INSTALL_DIR"
make -j"$NUM_JOBS"
make install

"$INSTALL_DIR/bin/verilator" --version
