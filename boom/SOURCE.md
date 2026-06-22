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
```

Chipyard Scala configs are the source of truth for BOOM configuration. This
repository does not keep a separate YAML target description.
