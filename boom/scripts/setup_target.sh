#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: setup_target.sh <boomv3-medium|boomv4-medium>

Environment:
  JOBS=48
  CHIPYARD_REF=<git-ref>
  BOOM_SKIP_CHIPYARD_INSTALL=1
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
    DUAL_CONFIG="DualMediumBoomV3CosimConfig"
    ;;
  boomv4-medium)
    CONFIG="MediumBoomV4CosimConfig"
    DUAL_CONFIG="DualMediumBoomV4CosimConfig"
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
export BOOM_DUAL_CONFIG="$DUAL_CONFIG"
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

cat > "$TARGET_DIR/run_dual_helloworld.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -z "${BOOM_DUAL_CONFIG:-}" ] || [ -z "${CHIPYARD_ROOT:-}" ]; then
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

exec "$SCRIPT_DIR/../../scripts/run_config.sh" "$BOOM_DUAL_CONFIG" "$HELLO_ELF"
EOF

cat > "$TARGET_DIR/README.md" <<EOF
# $TARGET

This DUT wrapper runs the single-core \`$CONFIG\` through the shared Chipyard
checkout in \`../../chipyard\`. Run Chipyard's stock hello workload with:

\`\`\`bash
source ./env.sh
./run_helloworld.sh
\`\`\`

The default acceptance path is single-core cospike, and cospike should report
\`harts: 1\`.

For dual-core debugging, the wrapper also records \`$DUAL_CONFIG\` as
\`BOOM_DUAL_CONFIG\`. This path is expected to expose the current strict-cospike
secondary-hart load mismatch:

\`\`\`bash
source ./env.sh
./run_dual_helloworld.sh
\`\`\`

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

Dual-core debug logs use:

\`\`\`text
../../runs/$DUAL_CONFIG/logs/build.log
../../runs/$DUAL_CONFIG/logs/run.log
\`\`\`
EOF

chmod +x "$TARGET_DIR/run_cosim.sh" "$TARGET_DIR/run_helloworld.sh" "$TARGET_DIR/run_dual_helloworld.sh"

"$BOOM_ROOT/scripts/run_config.sh" "$CONFIG"

echo "Ready: $TARGET_DIR"
