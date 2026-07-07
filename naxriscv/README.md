# NaxRiscv DUT Reproduction Guide

This directory contains the scripts needed to reproduce a local NaxRiscv
simulation flow with Spike/RVLS checking. It follows the same wrapper pattern
as `boom/` and `vexiiriscv/`: the upstream processor repository is installed
locally under this directory, while generated build outputs are ignored by git.

The scripts install and use these local paths:

```text
naxriscv/NaxRiscv/       NaxRiscv checkout.
naxriscv/runs/           Reserved for wrapper logs.
naxriscv/builds/         Reserved for future target wrappers.
```

## Quick Start

`<DUTs-root>` below means the root of your local `DUTs` checkout.

Start from the `naxriscv/` wrapper directory:

```bash
cd <DUTs-root>/naxriscv
THREAD_COUNT=16 scripts/setup_naxriscv.sh
```

The script follows the upstream NaxRiscv README flow:

1. clone or reuse `naxriscv/NaxRiscv`,
2. check out the `rvls-update` branch,
3. install initial toolchain and submodules,
4. install Verilator, Spike/ELFIO/SDL, and RVLS,
5. generate RTL,
6. build `VNaxRiscv`,
7. run the `rv64ui-p-addi` smoke test and optional regressions.

The script is written as a POSIX-style shell script, so it can be run from
bash, zsh, or `sh`.

## Useful Options

Use more or fewer build threads:

```bash
THREAD_COUNT=32 scripts/setup_naxriscv.sh
```

Run only the smoke test, skipping `test-fast`:

```bash
RUN_TEST_FAST=0 scripts/setup_naxriscv.sh
```

Use a custom checkout path:

```bash
NAXRISCV_DIR=/scratch/$USER/NaxRiscv scripts/setup_naxriscv.sh
```

Use the BOSC proxy wrapper for external downloads:

```bash
USE_BOSC_PROXY=1 scripts/setup_naxriscv.sh
```

Print help:

```bash
scripts/setup_naxriscv.sh --help
```

## Manual Smoke Test

After installation, run the smoke test directly from the checkout:

```bash
cd <DUTs-root>/naxriscv/NaxRiscv
LD_LIBRARY_PATH=$PWD/ext/riscv-isa-sim/lib:$PWD/ext/riscv-isa-sim/build \
  ./src/test/cpp/naxriscv/obj_dir/VNaxRiscv \
  --load-elf ext/NaxSoftware/riscv-tests/rv64ui-p-addi \
  --pass-symbol pass \
  --fail-symbol fail \
  --timeout 100000 \
  --name rv64ui-p-addi
```

## Logs And Artifacts

Generated outputs are local artifacts under:

```text
naxriscv/NaxRiscv/toolchain/
naxriscv/NaxRiscv/NaxRiscv.v
naxriscv/NaxRiscv/NaxRiscvSynt.v
naxriscv/NaxRiscv/src/test/cpp/naxriscv/obj_dir/
naxriscv/NaxRiscv/src/test/cpp/naxriscv/output/
```

These directories and files are not intended to be committed.

The local validation recorded for this workspace passed `test-fast` with no
`FAIL` files. A partial `test-all` run was started but interrupted and should
not be counted as a full-suite pass.
