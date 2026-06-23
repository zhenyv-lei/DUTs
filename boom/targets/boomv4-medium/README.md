# boomv4-medium

This DUT wrapper runs the single-core `MediumBoomV4CosimConfig` through the
shared Chipyard checkout in `../../chipyard`. Run Chipyard's stock hello
workload with:

```bash
source ./env.sh
./run_helloworld.sh
```

The default acceptance path should report `Cosim: harts: 1`.

For dual-core debugging, this wrapper also exposes
`DualMediumBoomV4CosimConfig` through `run_dual_helloworld.sh`. That path uses
Chipyard's stock `hello.riscv` and currently records the strict-cospike
secondary-hart load mismatch:

```bash
source ./env.sh
./run_dual_helloworld.sh
```

Run a custom ELF with:

```bash
source ./env.sh
./run_cosim.sh /path/to/program.elf
```

Logs are written to:

```text
../../runs/DualMediumBoomV4CosimConfig/logs/build.log
../../runs/DualMediumBoomV4CosimConfig/logs/run.log
../../runs/MediumBoomV4CosimConfig/logs/build.log
../../runs/MediumBoomV4CosimConfig/logs/run.log
../../chipyard/sims/verilator/output/chipyard.harness.TestHarness.MediumBoomV4CosimConfig/
```
