# BOOM DUT Reproduction Guide

This directory contains the scripts needed to reproduce the BOOM Chipyard cosim
setup from a clean machine. It does not vendor the generated environment itself:
Chipyard, conda, RISC-V tools, simulator binaries, and run logs are local build
artifacts and are ignored by git.

The scripts install all required environment resources under this directory:

```text
boom/tools/conda/       Local Miniforge installation.
boom/chipyard/          Chipyard checkout.
boom/chipyard/.conda-env/
                        Chipyard conda environment and RISC-V tools.
boom/runs/              Build and run logs.
```

## Fresh Environment Setup

Start from a checked-out `DUTs` repository:

```bash
cd ~/opt/DUTs/boom
```

Build the BOOM cospike targets. On the first run, `setup_target.sh` deploys the
local conda, Chipyard checkout, Chipyard conda environment, and RISC-V tools
before building the selected simulator. Later target builds reuse
`boom/tools/conda` and `boom/chipyard/.conda-env` when they are already present:

```bash
JOBS=16 scripts/setup_target.sh boomv3-medium
JOBS=16 scripts/setup_target.sh boomv4-medium
JOBS=16 scripts/setup_target.sh boomv3-medium-dual
JOBS=16 scripts/setup_target.sh boomv4-medium-dual
```

On BOSC machines where outbound network access must go through the IPv6 proxy,
wrap network/install commands with `bosc-ipv6`:

```bash
bosc-ipv6 bash -lc 'JOBS=16 scripts/setup_target.sh boomv3-medium'
bosc-ipv6 bash -lc 'JOBS=16 scripts/setup_target.sh boomv4-medium'
bosc-ipv6 bash -lc 'JOBS=16 scripts/setup_target.sh boomv3-medium-dual'
bosc-ipv6 bash -lc 'JOBS=16 scripts/setup_target.sh boomv4-medium-dual'
```

Check that the local conda and Chipyard tools are active from inside `boom/`:

```bash
tools/conda/bin/conda --version
export PATH="$PWD/tools/conda/bin:$PATH"
cd chipyard
source env.sh
which riscv64-unknown-elf-gcc
which spike
which verilator
which firtool
```

## Smoke Tests

Run Chipyard's stock `hello.riscv` on the BOOM v3 single-core cosim target:

```bash
cd ~/opt/DUTs/boom/targets/boomv3-medium
source ./env.sh
./run_helloworld.sh
```

Run the BOOM v4 single-core cosim target:

```bash
cd ~/opt/DUTs/boom/targets/boomv4-medium
source ./env.sh
./run_helloworld.sh
```

Expected result for both targets:

```text
Cosim: harts: 1
Hello world from core 0, a sonicboom
Verilog $finish
```

The `run_helloworld.sh` command should exit with status 0.

## Configurations

The default reproducible acceptance targets are single-core cospike configs:

```text
boomv3-medium -> MediumBoomV3CosimConfig
boomv4-medium -> MediumBoomV4CosimConfig
```

The setup also adds explicit dual-core debug targets to Chipyard:

```text
boomv3-medium-dual -> DualMediumBoomV3CosimConfig
boomv4-medium-dual -> DualMediumBoomV4CosimConfig
```

Run a dual-core debug target with:

```bash
cd ~/opt/DUTs/boom/targets/boomv3-medium-dual
source ./env.sh
./run_helloworld.sh
```

The dual-core path intentionally keeps the original strict cospike load-data
checks. It is useful for debugging and should report `Cosim: harts: 2`, but it
is not the current acceptance path.

## Notes

- `scripts/install_conda.sh` installs Miniforge into `boom/tools/conda/` if no
  local conda is already available there.
- `scripts/install_chipyard.sh` checks out Chipyard at the pinned ref recorded
  in the script and runs Chipyard's `build-setup.sh riscv-tools` on first
  deployment. If the pinned checkout and `.conda-env` already exist, it reuses
  them and only refreshes the local overlays.
- `scripts/apply_chipyard_overlays.sh` adds local dual-core debug configs and
  cospike compatibility fixes to the local Chipyard checkout.
- `scripts/setup_target.sh` creates the target wrappers and builds the selected
  Verilator cosim simulator. The clean-deployment path always lets this script
  install or refresh the local Chipyard environment first.

See `README_SETUP.md` for the detailed workflow, logs, artifacts, and
troubleshooting notes.
