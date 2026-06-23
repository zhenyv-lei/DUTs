# boomv3-medium-dual

This DUT wrapper runs the dual-core debug `DualMediumBoomV3CosimConfig` through the shared Chipyard
checkout in `../../chipyard`. Run Chipyard's stock `hello.riscv` workload
with:

```bash
source ./env.sh
./run_helloworld.sh
```

Cospike should report `harts: 2`.

Current strict-cospike status: this target is expected to expose the known
secondary-hart load-data mismatch when running Chipyard's stock `hello.riscv`.
It is a debug target, not the current acceptance path.

Run a custom ELF with:

```bash
source ./env.sh
./run_cosim.sh /path/to/program.elf
```

Logs are written to:

```text
../../runs/DualMediumBoomV3CosimConfig/logs/build.log
../../runs/DualMediumBoomV3CosimConfig/logs/run.log
../../chipyard/sims/verilator/output/chipyard.harness.TestHarness.DualMediumBoomV3CosimConfig/
```
