# VexiiRiscv Source

This DUT family uses one local VexiiRiscv checkout as the simulation platform.

The checkout is installed under:

```text
vexiiriscv/VexiiRiscv/
```

The wrapper scripts in this directory do not vendor generated outputs or build
products. Mill outputs, Verilator binaries, Spike/RVLS build products, and
simulation logs are local artifacts.

The upstream source is:

```text
https://github.com/SpinalHDL/VexiiRiscv.git
```

The local deployment tested in this workspace used:

```text
VexiiRiscv HEAD: 235753e24f2d960e49a0852205bae1400bf22c19
```

The smoke-test workload is:

```text
VexiiRiscv/ext/NaxSoftware/riscv-tests/rv32ui-p-add
```

RVLS/Spike cosim is active when:

```text
VexiiRiscv/ext/rvls/build/apps/rvls.so
```

exists and the run produces both `tracer.log` and `spike.log`.
