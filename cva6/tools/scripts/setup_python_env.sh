#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

UV_BIN="${UV_BIN:-$HOME/.local/bin/uv}"

if ! command -v uv >/dev/null 2>&1; then
  if [[ -x "$UV_BIN" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
  else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi

cd "$CVA6_ROOT"
uv python install 3.10
rm -rf .venv
uv venv --python 3.10 .venv
uv pip install --python .venv/bin/python \
  -r verif/sim/dv/requirements.txt \
  -r verif/core-v-verif/bin/requirements.txt \
  -r config/gen_from_riscv_config/requirements.txt

.venv/bin/python -c 'import yaml; print("Python dependencies OK")'
cd verif/sim
../../.venv/bin/python cva6.py --help >/dev/null

echo "Python environment ready: $CVA6_ROOT/.venv"
