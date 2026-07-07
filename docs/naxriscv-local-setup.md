# NaxRiscv Local Setup Guide

This guide records how this DUTs workspace deploys NaxRiscv. The intended use is
script-based reproduction on a new machine; the upstream `NaxRiscv/` checkout and
its build products are not committed into this repository.

## Quick Start

```bash
git clone https://github.com/zhenyv-lei/DUTs.git
cd DUTs
cd NaxRiscv
./scripts/setup_naxriscv.sh
```

All path and behavior switches are macros near the top of
`NaxRiscv/scripts/setup_naxriscv.sh`. Override them with environment variables
instead of editing the script. The scripts use POSIX-style shell syntax and are
checked with `sh`, `bash`, and `zsh`.

By default, the script behaves like the other DUT-local installers:

- If `NaxRiscv/` is already an upstream NaxRiscv checkout, it reuses that
  directory.
- On a fresh DUTs clone, `NaxRiscv/` only contains the DUTs setup scripts, so
  the upstream source is cloned into `NaxRiscv/upstream/`.

```bash
NAXRISCV_DIR=/scratch/$USER/DUTs/NaxRiscv \
THREAD_COUNT=16 \
RUN_TEST_FAST=0 \
./scripts/setup_naxriscv.sh
```

## BOSC Proxy

External network access should go through the reusable proxy wrapper:

```bash
BOSC_PROXY_URL=socks5h://HOST:PORT \
./scripts/with_bosc_proxy.sh --check https://github.com
```

Use the same wrapper through the NaxRiscv setup script:

```bash
USE_BOSC_PROXY=1 \
BOSC_PROXY_URL=socks5h://HOST:PORT \
./scripts/setup_naxriscv.sh
```

Equivalent host/port form:

```bash
USE_BOSC_PROXY=1 \
BOSC_PROXY_HOST=HOST \
BOSC_PROXY_PORT=PORT \
./scripts/setup_naxriscv.sh
```

For other one-off network commands:

```bash
BOSC_PROXY_URL=socks5h://HOST:PORT \
./scripts/with_bosc_proxy.sh -- git clone https://github.com/SpinalHDL/NaxRiscv.git
```

Keep site-specific proxy endpoints and credentials out of Git.

## What The Setup Script Does

The script follows the upstream installation flow from
`NaxRiscv/src/test/README.md`:

1. Clone `https://github.com/SpinalHDL/NaxRiscv.git` and check out
   `rvls-update`.
2. Configure repo-local caches for SBT, Ivy, Coursier, ccache, and HOME.
3. Run `make install-toolchain-initial` for submodules, SBT, and OpenJDK.
4. Install Verilator, Spike/ELFIO/SDL, and RVLS using the upstream `ci/`
   scripts. This is equivalent to the remaining parts of
   `make install-toolchain`, but split so local compatibility fixes can be
   applied before the affected build step.
5. Run `make TARGET_NAX=rv64imafdcsu NaxRiscv.v`.
6. Build `src/test/cpp/naxriscv/obj_dir/VNaxRiscv`.
7. Run a smoke test and, by default, `make test-fast`.

The local fixes are intentionally narrow:

- Use `curl` instead of `wget` in the upstream SBT/OpenJDK installers, because
  `curl` handles the BOSC SOCKS proxy path more reliably on the validated host.
- Add `<memory>` to the Verilator v4.216 checkout when the host compiler needs
  it.
- Remove stale Boost link flags from the Spike package link when Spike is built
  with `--without-boost`.
- Normalize local RVLS and VNaxRiscv link flags to `-lpthread -ldl`.

Disable these fixes only when debugging upstream behavior:

```bash
APPLY_LOCAL_FIXES=0 ./scripts/setup_naxriscv.sh
```

## Manual Upstream Flow

Use this only when debugging the script. From the NaxRiscv checkout:

```bash
export NAXRISCV=$PWD
export JAVA_HOME=$PWD/toolchain/openjdk
export PATH=$JAVA_HOME/bin:$PWD/toolchain/verilator-v4.216/bin:$PATH

make install-toolchain-initial
make install-toolchain
make TARGET_NAX=rv64imafdcsu NaxRiscv.v
make -C src/test/cpp/naxriscv compile THREAD_COUNT=$(nproc)
```

Run a smoke test:

```bash
LD_LIBRARY_PATH=$NAXRISCV/ext/riscv-isa-sim/lib:$NAXRISCV/ext/riscv-isa-sim/build \
  ./src/test/cpp/naxriscv/obj_dir/VNaxRiscv \
  --load-elf ext/NaxSoftware/riscv-tests/rv64ui-p-addi \
  --pass-symbol pass \
  --fail-symbol fail \
  --timeout 100000 \
  --name rv64ui-p-addi
```

Run the fast regression:

```bash
cd "$NAXRISCV/src/test/cpp/naxriscv"
LD_LIBRARY_PATH=$NAXRISCV/ext/riscv-isa-sim/lib:$NAXRISCV/ext/riscv-isa-sim/build \
  make test-fast -j$(nproc)
find output -name PASS | wc -l
find output -name FAIL | wc -l
make test-report
```

`VNaxRiscv` links against the local Spike build. Spike lockstep checking is
enabled by default; use `--spike-disabled` only when you explicitly want to run
without Spike comparison.

## Validation Record

Validated locally on 2026-07-06:

- Upstream repository: `https://github.com/SpinalHDL/NaxRiscv.git`
- Branch: `rvls-update`
- Commit: `c6bc85c Merge branch 'main' into rvls-update`
- Generated outputs: `NaxRiscv.v`, `NaxRiscvSynt.v`, `nax.h`,
  `src/test/cpp/naxriscv/obj_dir/VNaxRiscv`
- `make test-fast` completed with no `FAIL` files.

After `test-fast` plus one additional FPU target from a partial `test-all`
attempt, the local output tree contained `208` PASS files and `0` FAIL files.
`make test-report` reported `207/271 passed`; the remaining entries were long
FPU/MMU targets that were not completed in that run.

## Cleanup

```bash
cd "$NAXRISCV"
make clean-gen
make clean-toolchain

cd "$NAXRISCV/src/test/cpp/naxriscv"
make test-clean
```

## Repository Policy

`/NaxRiscv/` is ignored by this repository. Commit the setup scripts and notes,
not the upstream checkout, toolchains, generated RTL, simulator objects, or test
outputs.
