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

## Quick Start

Start from a checked-out `DUTs` repository:

```bash
cd ~/opt/DUTs/boom
```

On BOSC machines, run networked install/build commands through `bosc-ipv6`.
This command is the normal entry point. It installs the local environment if
needed, applies the local Chipyard overlay, creates the target wrapper, and
builds the BOOM v3 single-core cosim:

```bash
bosc-ipv6 bash -lc 'cd ~/opt/DUTs/boom && JOBS=16 scripts/setup_target.sh boomv3-medium'
```

Then build the other targets from the same local Chipyard environment:

```bash
cd ~/opt/DUTs/boom
JOBS=16 scripts/setup_target.sh boomv4-medium
JOBS=16 scripts/setup_target.sh boomv3-medium-dual
JOBS=16 scripts/setup_target.sh boomv4-medium-dual
```

If the later commands need network access on your machine, wrap them in
`bosc-ipv6` too:

```bash
bosc-ipv6 bash -lc 'cd ~/opt/DUTs/boom && JOBS=16 scripts/setup_target.sh boomv4-medium'
bosc-ipv6 bash -lc 'cd ~/opt/DUTs/boom && JOBS=16 scripts/setup_target.sh boomv3-medium-dual'
bosc-ipv6 bash -lc 'cd ~/opt/DUTs/boom && JOBS=16 scripts/setup_target.sh boomv4-medium-dual'
```

The first target build installs:

```text
boom/tools/conda/
boom/chipyard/
boom/chipyard/.conda-env/
```

Later target builds reuse those directories when they already exist.

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

## What setup_target.sh Does

`scripts/setup_target.sh` is the user-facing setup command. For one target, it
runs the internal steps below; you do not need to run these scripts manually for
normal setup:

```text
scripts/setup_target.sh <target>
  -> scripts/install_chipyard.sh
       -> scripts/install_conda.sh, if boom/tools/conda is missing
       -> clone/check out boom/chipyard at the pinned Chipyard ref
       -> initialize Chipyard non-toolchain submodules
       -> scripts/apply_chipyard_overlays.sh
       -> Chipyard build-setup.sh riscv-tools, if .conda-env is missing
  -> scripts/apply_chipyard_overlays.sh
  -> create boom/targets/<target>/{env.sh,run_cosim.sh,run_helloworld.sh}
  -> scripts/run_config.sh <ChipyardConfig>
```

`scripts/apply_chipyard_overlays.sh` modifies the local `boom/chipyard`
checkout. It adds the dual-core BOOM debug configs and applies local cospike
compatibility patches. The script is idempotent, so running it more than once is
expected.

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

## Logs And Troubleshooting

High-level logs are written under:

```text
boom/runs/<ChipyardConfig>/logs/build.log
boom/runs/<ChipyardConfig>/logs/run.log
```

Chipyard's Verilator output also writes per-binary logs under:

```text
boom/chipyard/sims/verilator/output/chipyard.harness.TestHarness.<ChipyardConfig>/
```

If a conda download fails with `CondaHTTPError` or `HTTP 000 CONNECTION FAILED`,
rerun the same command first. If the environment was left half-created, remove
the incomplete Chipyard conda directories and retry:

```bash
rm -rf ~/opt/DUTs/boom/chipyard/.conda-lock-env ~/opt/DUTs/boom/chipyard/.conda-env
bosc-ipv6 bash -lc 'cd ~/opt/DUTs/boom && JOBS=16 scripts/setup_target.sh boomv3-medium'
```

If `chipyard/env.sh` cannot be sourced after a failed setup, treat that as an
incomplete environment and retry after removing the same directories.
