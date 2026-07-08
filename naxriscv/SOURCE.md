# NaxRiscv Source

This DUT family uses one local NaxRiscv checkout as the simulation platform.

The checkout is installed under:

```text
naxriscv/NaxRiscv/
```

The upstream source is:

```text
https://github.com/SpinalHDL/NaxRiscv.git
```

The local deployment tested in this workspace used:

```text
Branch: rvls-update
Commit: c6bc85c Merge branch 'main' into rvls-update
```

The wrapper scripts do not vendor generated outputs or build products.
Toolchains, generated RTL, Verilator objects, Spike/RVLS builds, and regression
outputs are local artifacts under `naxriscv/NaxRiscv/`.
