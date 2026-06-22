#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -z "${BOOM_CONFIG:-}" ]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/env.sh"
fi

exec "$SCRIPT_DIR/../../scripts/run_config.sh" "$BOOM_CONFIG" "$@"
