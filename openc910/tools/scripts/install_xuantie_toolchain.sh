#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$TOOLS_DIR/src"
BUILD_DIR="$TOOLS_DIR/build"

TAG="${XUANTIE_GCC_TAG:-2023.03.21}"
ARCHIVE_NAME="riscv64-elf-ubuntu-20.04-nightly-${TAG}-nightly.tar.gz"
URL="https://github.com/XUANTIE-RV/xuantie-gnu-toolchain/releases/download/${TAG}/${ARCHIVE_NAME}"
ARCHIVE="$SRC_DIR/$ARCHIVE_NAME"
PREFIX="$BUILD_DIR/xuantie-gcc-$TAG"
LINK="$BUILD_DIR/xuantie-gcc"

mkdir -p "$SRC_DIR" "$BUILD_DIR"

if [ ! -f "$ARCHIVE" ]; then
  echo "[xuantie] downloading $URL"
  wget -c -O "$ARCHIVE" "$URL"
else
  echo "[xuantie] using existing archive: $ARCHIVE"
fi

if [ ! -x "$PREFIX/bin/riscv64-unknown-elf-gcc" ]; then
  tmp_dir="$(mktemp -d "$BUILD_DIR/.xuantie-gcc.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' EXIT

  echo "[xuantie] extracting into $PREFIX"
  tar -xf "$ARCHIVE" -C "$tmp_dir"

  if [ ! -d "$tmp_dir/riscv" ]; then
    echo "[xuantie] expected extracted directory '$tmp_dir/riscv' was not found" >&2
    exit 1
  fi

  rm -rf "$PREFIX"
  mv "$tmp_dir/riscv" "$PREFIX"
  rm -rf "$tmp_dir"
  trap - EXIT
else
  echo "[xuantie] using existing install: $PREFIX"
fi

ln -sfn "$(basename "$PREFIX")" "$LINK"

echo "[xuantie] installed at: $LINK"
"$LINK/bin/riscv64-unknown-elf-gcc" --version | head -1
