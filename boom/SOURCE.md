# BOOM / Chipyard Source

This DUT family uses one shared Chipyard checkout as the simulation platform for
BOOM cosimulation targets.

The checkout is installed under:

```text
boom/chipyard/
```

The exposed DUT entries are:

```text
targets/boomv3-medium -> MediumBoomV3CosimConfig
targets/boomv4-medium -> MediumBoomV4CosimConfig
targets/boomv3-medium-dual -> DualMediumBoomV3CosimConfig
targets/boomv4-medium-dual -> DualMediumBoomV4CosimConfig
```

Chipyard Scala configs are the source of truth for BOOM configuration. The
single-core Medium BOOM cospike configs are Chipyard built-ins. The DUTs
repository also applies a local Chipyard overlay with explicit dual-core debug
configs via `boom/scripts/apply_chipyard_overlays.sh`.
