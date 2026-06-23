#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: setup_target.sh <target>

Targets:
  boomv3-medium        Single-core BOOM v3 cospike target.
  boomv4-medium        Single-core BOOM v4 cospike target.
  boomv3-medium-dual   Dual-core BOOM v3 cospike debug target.
  boomv4-medium-dual   Dual-core BOOM v4 cospike debug target.

Environment:
  JOBS=48
  CHIPYARD_REF=<git-ref>
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

TARGET="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOOM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
JOBS="${JOBS:-48}"

case "$TARGET" in
  boomv3-medium)
    CONFIG="MediumBoomV3CosimConfig"
    CORES="1"
    TARGET_KIND="single-core"
    ;;
  boomv4-medium)
    CONFIG="MediumBoomV4CosimConfig"
    CORES="1"
    TARGET_KIND="single-core"
    ;;
  boomv3-medium-dual)
    CONFIG="DualMediumBoomV3CosimConfig"
    CORES="2"
    TARGET_KIND="dual-core debug"
    ;;
  boomv4-medium-dual)
    CONFIG="DualMediumBoomV4CosimConfig"
    CORES="2"
    TARGET_KIND="dual-core debug"
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [ "${BOOM_SKIP_CHIPYARD_INSTALL:-0}" != "1" ]; then
  "$BOOM_ROOT/scripts/install_chipyard.sh"
fi
"$BOOM_ROOT/scripts/apply_chipyard_overlays.sh"

TARGET_DIR="$BOOM_ROOT/targets/$TARGET"
mkdir -p "$TARGET_DIR"

cat > "$TARGET_DIR/env.sh" <<EOF
#!/usr/bin/env bash

if [ "\${BASH_SOURCE[0]}" = "\$0" ]; then
  echo "This file must be sourced, not executed:" >&2
  echo "  source env.sh" >&2
  exit 1
fi

DUT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd -P)"
CHIPYARD_ENV="\$DUT_DIR/../../chipyard/env.sh"

if [ ! -f "\$CHIPYARD_ENV" ]; then
  echo "Missing Chipyard environment: \$CHIPYARD_ENV" >&2
  echo "Run: ../../scripts/setup_target.sh $TARGET" >&2
  return 1
fi

LOCAL_CONDA_BIN="\$DUT_DIR/../../tools/conda/bin"
if ! command -v conda >/dev/null 2>&1 && [ -x "\$LOCAL_CONDA_BIN/conda" ]; then
  export PATH="\$LOCAL_CONDA_BIN:\$PATH"
fi

set +u
# shellcheck disable=SC1090
source "\$CHIPYARD_ENV"
set -u

export BOOM_TARGET="$TARGET"
export BOOM_CONFIG="$CONFIG"
export BOOM_CORES="$CORES"
export BOOM_ROOT="\$DUT_DIR/../.."
export CHIPYARD_ROOT="\$DUT_DIR/../../chipyard"
EOF

cat > "$TARGET_DIR/run_cosim.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -z "${BOOM_CONFIG:-}" ]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/env.sh"
fi

exec "$SCRIPT_DIR/../../scripts/run_config.sh" "$BOOM_CONFIG" "$@"
EOF

cat > "$TARGET_DIR/run_helloworld.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -z "${BOOM_CONFIG:-}" ] || [ -z "${CHIPYARD_ROOT:-}" ]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/env.sh"
fi

HELLO_ELF="$CHIPYARD_ROOT/tests/build/hello.riscv"

if [ ! -x "$HELLO_ELF" ]; then
  (
    cd "$CHIPYARD_ROOT"
    cmake -S tests -B tests/build -D CMAKE_BUILD_TYPE=Release
    cmake --build tests/build --target hello -j"${JOBS:-48}"
  )
fi

exec "$SCRIPT_DIR/run_cosim.sh" "$HELLO_ELF"
EOF

cat > "$TARGET_DIR/README.md" <<EOF
# $TARGET

This DUT wrapper runs the $TARGET_KIND \`$CONFIG\` through the shared Chipyard
checkout in \`../../chipyard\`. Run Chipyard's stock \`hello.riscv\` workload
with:

\`\`\`bash
source ./env.sh
./run_helloworld.sh
\`\`\`

Cospike should report \`harts: $CORES\`.

Run a custom ELF with:

\`\`\`bash
source ./env.sh
./run_cosim.sh /path/to/program.elf
\`\`\`

Logs are written to:

\`\`\`text
../../runs/$CONFIG/logs/build.log
../../runs/$CONFIG/logs/run.log
../../chipyard/sims/verilator/output/chipyard.harness.TestHarness.$CONFIG/
\`\`\`
EOF

chmod +x "$TARGET_DIR/run_cosim.sh" "$TARGET_DIR/run_helloworld.sh"

"$BOOM_ROOT/scripts/run_config.sh" "$CONFIG"

echo "Ready: $TARGET_DIR"
