# boomv4-medium

This DUT wrapper runs the single-core `MediumBoomV4CosimConfig` through the shared Chipyard
checkout in `../../chipyard`. Run Chipyard's stock `hello.riscv` workload
with:

```bash
source ./env.sh
./run_helloworld.sh
```

Cospike should report `harts: 1`.

Run a custom ELF with:

```bash
source ./env.sh
./run_cosim.sh /path/to/program.elf
```

Logs are written to:

```text
../../runs/MediumBoomV4CosimConfig/logs/build.log
../../runs/MediumBoomV4CosimConfig/logs/run.log
../../chipyard/sims/verilator/output/chipyard.harness.TestHarness.MediumBoomV4CosimConfig/
```
