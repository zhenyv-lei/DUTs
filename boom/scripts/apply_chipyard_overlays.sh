#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOOM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CHIPYARD_ROOT="$BOOM_ROOT/chipyard"
BOOM_CONFIGS="$CHIPYARD_ROOT/generators/chipyard/src/main/scala/config/BoomConfigs.scala"
COSPIKE_IMPL="$CHIPYARD_ROOT/generators/testchipip/src/main/resources/testchipip/csrc/cospike_impl.cc"

if [ ! -f "$BOOM_CONFIGS" ]; then
  echo "Missing Chipyard BOOM configs: $BOOM_CONFIGS" >&2
  exit 1
fi

if [ ! -f "$COSPIKE_IMPL" ]; then
  echo "Missing Chipyard cospike implementation: $COSPIKE_IMPL" >&2
  exit 1
fi

if ! grep -q "class DualMediumBoomV3CosimConfig" "$BOOM_CONFIGS"; then
  cat >> "$BOOM_CONFIGS" <<'EOF'

// DUTs local overlay: dual-core medium BOOM cosim targets.
class DualMediumBoomV3CosimConfig extends Config(
  new chipyard.harness.WithCospike ++
  new chipyard.config.WithTraceIO ++
  new boom.v3.common.WithNMediumBooms(2) ++
  new chipyard.config.AbstractConfig)

class DualMediumBoomV4CosimConfig extends Config(
  new chipyard.harness.WithCospike ++
  new chipyard.config.WithTraceIO ++
  new boom.v4.common.WithNMediumBooms(2) ++
  new chipyard.config.AbstractConfig)
EOF
fi

patch_cospike_impl() {
  local path="$1"

  python3 - "$path" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
replacements = [
(
"""void cospike_register_memory(unsigned long long int base,
                             unsigned long long int size)
{
  if (sim) {
    COSPIKE_PRINTF("Memories must be registered prior to sim execution\\n");
    exit(1);
  }
  mem_info.push_back(std::make_pair(base, size));
}
""",
"""void cospike_register_memory(unsigned long long int base,
                             unsigned long long int size)
{
  if (sim) {
    COSPIKE_PRINTF("Memories must be registered prior to sim execution\\n");
    exit(1);
  }
  if (mem_already_exists(base, size)) {
    return;
  }
  mem_info.push_back(std::make_pair(base, size));
}
""",
),
(
"""    for (int i = 0; i < info->nharts; i++) {
      // Use our own reset vector
      sim->get_core(hartid)->get_state()->pc = _RESET_VECTOR;
      // Set MMU capability
      sim->get_core(hartid)->set_impl(IMPL_MMU_SV48, info->maxpglevels >= 4);
      sim->get_core(hartid)->set_impl(IMPL_MMU_SV57, info->maxpglevels >= 5);
      // targets generally don't support ASIDs
      sim->get_core(hartid)->set_impl(IMPL_MMU_ASID, false);
      // HACKS: Our processor's don't implement zicntr fully, they don't provide time
      sim->get_core(hartid)->get_state()->csrmap.erase(CSR_TIME);
    }
""",
"""    for (int i = 0; i < info->nharts; i++) {
      // Use our own reset vector
      sim->get_core(i)->get_state()->pc = _RESET_VECTOR;
      // Set MMU capability
      sim->get_core(i)->set_impl(IMPL_MMU_SV48, info->maxpglevels >= 4);
      sim->get_core(i)->set_impl(IMPL_MMU_SV57, info->maxpglevels >= 5);
      // targets generally don't support ASIDs
      sim->get_core(i)->set_impl(IMPL_MMU_ASID, false);
      // HACKS: Our processor's don't implement zicntr fully, they don't provide time
      sim->get_core(i)->get_state()->csrmap.erase(CSR_TIME);
    }
""",
),
]

strict_load_check = """      bool ignore_read = sc_read || (!mem_read.empty() &&
                          (magic_addrs.count(mem_read_addr) ||
                           device_read ||
                           lr_read ||
                           (tohost_addr && mem_read_addr == tohost_addr) ||
                           (fromhost_addr && mem_read_addr == fromhost_addr)));
"""

relaxed_multicore_load_check = """      bool multicore_memory_read = info->nharts > 1 && !mem_read.empty() && !device_read;
      bool ignore_read = sc_read || multicore_memory_read || (!mem_read.empty() &&
                          (magic_addrs.count(mem_read_addr) ||
                           device_read ||
                           lr_read ||
                           (tohost_addr && mem_read_addr == tohost_addr) ||
                           (fromhost_addr && mem_read_addr == fromhost_addr)));
"""

text = text.replace(relaxed_multicore_load_check, strict_load_check)

for old, new in replacements:
    if old in text:
        text = text.replace(old, new, 1)
    elif new not in text:
        raise SystemExit(f"Could not find expected cospike block in {path}")

if strict_load_check not in text:
    raise SystemExit(f"Could not find expected cospike load-check block in {path}")

path.write_text(text)
PY
}

patch_cospike_jar() {
  local jar_path="$1"
  local resource="testchipip/csrc/cospike_impl.cc"
  local tmpdir

  if [ ! -f "$jar_path" ]; then
    return
  fi

  if unzip -p "$jar_path" "$resource" | grep -q "mem_already_exists(base, size)" &&
     unzip -p "$jar_path" "$resource" | grep -q "sim->get_core(i)->get_state()->pc" &&
     ! unzip -p "$jar_path" "$resource" | grep -q "multicore_memory_read"; then
    return
  fi

  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    unzip -q "$jar_path" "$resource"
    patch_cospike_impl "$tmpdir/$resource"
    zip -q "$jar_path" "$resource"
  )
  rm -rf "$tmpdir"
}

patch_cospike_impl "$COSPIKE_IMPL"

while IFS= read -r cached_cospike_impl; do
  patch_cospike_impl "$cached_cospike_impl"
done < <(find "$CHIPYARD_ROOT/generators/testchipip/src/target" \
  -path '*/testchipip/csrc/cospike_impl.cc' -type f 2>/dev/null || true)

while IFS= read -r generated_cospike_impl; do
  patch_cospike_impl "$generated_cospike_impl"
done < <(find "$CHIPYARD_ROOT/sims/verilator/generated-src" \
  -path '*/gen-collateral/cospike_impl.cc' -type f 2>/dev/null || true)

patch_cospike_jar "$CHIPYARD_ROOT/generators/testchipip/src/target/scala-2.13/testchipip_2.13-1.6.jar"
patch_cospike_jar "$CHIPYARD_ROOT/.classpath_cache/chipyard.jar"
