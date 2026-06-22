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
    ;;
  boomv4-medium)
    CONFIG="MediumBoomV4CosimConfig"
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [ "${BOOM_SKIP_CHIPYARD_INSTALL:-0}" != "1" ]; then
  "$BOOM_ROOT/scripts/install_chipyard.sh"
fi

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

This DUT wrapper runs Chipyard's built-in \`$CONFIG\` through the shared
Chipyard checkout in \`../../chipyard\`.

\`\`\`bash
source ./env.sh
./run_helloworld.sh
\`\`\`
EOF

chmod +x "$TARGET_DIR/run_cosim.sh" "$TARGET_DIR/run_helloworld.sh"

"$BOOM_ROOT/scripts/run_config.sh" "$CONFIG"

echo "Ready: $TARGET_DIR"
