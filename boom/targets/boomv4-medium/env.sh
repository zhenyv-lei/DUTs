#!/usr/bin/env bash

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "This file must be sourced, not executed:" >&2
  echo "  source env.sh" >&2
  exit 1
fi

DUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CHIPYARD_ENV="$DUT_DIR/../../chipyard/env.sh"

if [ ! -f "$CHIPYARD_ENV" ]; then
  echo "Missing Chipyard environment: $CHIPYARD_ENV" >&2
  echo "Run: ../../scripts/setup_target.sh boomv4-medium" >&2
  return 1
fi

LOCAL_CONDA_BIN="$DUT_DIR/../../tools/conda/bin"
if ! command -v conda >/dev/null 2>&1 && [ -x "$LOCAL_CONDA_BIN/conda" ]; then
  export PATH="$LOCAL_CONDA_BIN:$PATH"
fi

set +u
# shellcheck disable=SC1090
source "$CHIPYARD_ENV"
set -u

export BOOM_TARGET="boomv4-medium"
export BOOM_CONFIG="MediumBoomV4CosimConfig"
export BOOM_ROOT="$DUT_DIR/../.."
export CHIPYARD_ROOT="$DUT_DIR/../../chipyard"
