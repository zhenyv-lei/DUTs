# VexiiRiscv DUT Reproduction Guide

This directory contains the scripts needed to reproduce a local VexiiRiscv
Verilator simulation flow with optional RVLS/Spike cosim. It follows the same
wrapper pattern as `boom/`: the upstream processor repository is installed
locally under this directory, while generated build outputs are ignored by git.

The scripts install and use these local paths:

```text
vexiiriscv/VexiiRiscv/       VexiiRiscv checkout.
vexiiriscv/runs/             Install and smoke-test logs.
vexiiriscv/builds/           Reserved for future target wrappers.
```

## Quick Start

`<DUTs-root>` below means the root of your local `DUTs` checkout.

Start from the `vexiiriscv/` wrapper directory:

```bash
cd <DUTs-root>/vexiiriscv
JOBS=8 scripts/install_vexiiriscv.sh
```

The script will:

1. clone or reuse `vexiiriscv/VexiiRiscv`,
2. initialize VexiiRiscv submodules,
3. compile the Mill test target,
4. build Spike with commit log support,
5. build the RVLS JNI backend,
6. run the bundled `rv32ui-p-add` cosim smoke test.

Expected final result:

```text
SUCCESS
Install/build flow completed
```

## Script Responsibilities

```text
scripts/install_vexiiriscv.sh
  -> clone/reuse the VexiiRiscv checkout
  -> initialize submodules
  -> run mill -i Test.2_12_18.compile
  -> build ext/riscv-isa-sim/build/spike
  -> build ext/rvls/build/apps/rvls.so
  -> run a TestBench RVLS/Spike cosim smoke test
```

The script is written as a POSIX-style shell script, so it can be run from
bash, zsh, or `sh`.

## Dependency Check

Before a full build on a new server, run:

```bash
CHECK_ONLY=1 scripts/install_vexiiriscv.sh
```

The script checks for:

```text
git
make
mill
c++
curl
verilator
```

If only `mill` is missing, the script can install a user-space Mill launcher
under `vexiiriscv/tools/bin/`:

```bash
INSTALL_DEPS=1 CHECK_ONLY=1 scripts/install_vexiiriscv.sh
```

System tools such as `git`, `make`, `c++`, and `verilator` are not installed by
this script because they normally require root privileges or site-specific
module/conda setup. Install those through the server's normal environment
mechanism, then rerun the check.

## Useful Options

Use more or fewer make jobs:

```bash
JOBS=16 scripts/install_vexiiriscv.sh
```

Build only, without the final smoke test:

```bash
SKIP_SMOKE=1 scripts/install_vexiiriscv.sh
```

Skip RVLS/Spike and run a non-cosim smoke test:

```bash
SKIP_RVLS=1 scripts/install_vexiiriscv.sh
```

Use an existing checkout in another location:

```bash
REPO_DIR=/path/to/VexiiRiscv scripts/install_vexiiriscv.sh
```

Print all options:

```bash
scripts/install_vexiiriscv.sh --help
```

## Running A Program

After installation, run the bundled ISA test from the VexiiRiscv checkout:

```bash
cd <DUTs-root>/vexiiriscv/VexiiRiscv
mill -i Test.2_12_18.runMain vexiiriscv.tester.TestBench --with-mul --with-div --load-elf ext/NaxSoftware/riscv-tests/rv32ui-p-add --start-symbol test_2 --with-rvls-log --with-spike-log --no-stdin --fail-after 100000 --name demo-rv32ui-add
```

Cosim logs are written under:

```text
VexiiRiscv/simWorkspace/VexiiRiscv/demo-rv32ui-add/tracer.log
VexiiRiscv/simWorkspace/VexiiRiscv/demo-rv32ui-add/spike.log
```

## Replacing The ELF

Use a real ELF path and choose a start symbol that exists in that ELF:

```bash
cd <DUTs-root>/vexiiriscv/VexiiRiscv
mill -i Test.2_12_18.runMain vexiiriscv.tester.TestBench --with-mul --with-div --load-elf path/to/your.elf --start-symbol _start --with-rvls-log --with-spike-log --no-stdin --fail-after 100000 --name your-test-name
```

Check symbols before running:

```bash
riscv64-unknown-elf-nm path/to/your.elf | grep ' _start\| main\| pass\| fail'
```

The NaxSoftware bare-metal template under `VexiiRiscv/ext/NaxSoftware` provides
`_start`, `pass`, and `fail`. Returning from `main` reaches `pass`, which the
testbench treats as simulation success.

## Testing On Another Server

If the DUTs checkout is shared through NFS, test another open server with:

```bash
ssh bosc_open10 'cd /nfs/home/leizhenyu/opt/DUTs/vexiiriscv && for c in git make mill c++ curl verilator; do printf "%s: " "$c"; command -v "$c" || echo MISSING; done'
```

Then run the full install/build/cosim flow:

```bash
ssh bosc_open10 'cd /nfs/home/leizhenyu/opt/DUTs/vexiiriscv && SMOKE_NAME=remote-open10-cosim JOBS=8 scripts/install_vexiiriscv.sh'
```

This was verified on `bosc_open10`. `bosc_open15` was missing `mill` in `PATH`
at the time of testing.

## Logs And Artifacts

Wrapper logs are written under:

```text
vexiiriscv/runs/vexiiriscv_install_*.log
```

VexiiRiscv build and simulation outputs are local artifacts under:

```text
vexiiriscv/VexiiRiscv/out/
vexiiriscv/VexiiRiscv/simWorkspace/
vexiiriscv/VexiiRiscv/ext/riscv-isa-sim/build/
vexiiriscv/VexiiRiscv/ext/rvls/build/
```

These directories are not intended to be committed.
