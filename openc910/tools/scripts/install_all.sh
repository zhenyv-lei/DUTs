#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/install_xuantie_toolchain.sh"
"$SCRIPT_DIR/install_verilator.sh"
