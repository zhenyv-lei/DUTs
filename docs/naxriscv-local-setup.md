# NaxRiscv Local Setup Guide

This guide records the local setup flow used to deploy and test NaxRiscv with
the bundled Spike lockstep simulator. It is intended to live in the DUTs
workspace repository, not inside the upstream NaxRiscv repository.

For a fresh machine, prefer the one-shot setup script:

```bash
git clone https://github.com/zhenyv-lei/DUTs.git
cd DUTs
./scripts/setup_naxriscv.sh
```

All portable paths and behavior switches are macros at the top of
`scripts/setup_naxriscv.sh`. Override them through environment variables when
running on a different server:

```bash
NAXRISCV_DIR=/scratch/$USER/DUTs/NaxRiscv \
THREAD_COUNT=16 \
RUN_TEST_FAST=0 \
./scripts/setup_naxriscv.sh
```

If the server requires a site proxy for GitHub and package downloads, point the
script at the local proxy wrapper instead of editing the script:

```bash
USE_BOSC_PROXY=1 \
BOSC_PROXY_WRAPPER=/path/to/with_bosc_proxy.sh \
./scripts/setup_naxriscv.sh
```

Validated on 2026-07-06 with:

- Upstream repository: `https://github.com/SpinalHDL/NaxRiscv.git`
- Branch: `rvls-update`
- Commit: `c6bc85c Merge branch 'main' into rvls-update`
- Host build products:
  - `NaxRiscv.v`
  - `NaxRiscvSynt.v`
  - `nax.h`
  - `src/test/cpp/naxriscv/obj_dir/VNaxRiscv`

After running `test-fast` and then completing one additional FPU target during a
partial `test-all` attempt, the current output tree contained:

```bash
find output -name PASS | wc -l
# 208

find output -name FAIL | wc -l
# 0
```

`make test-report` reported `207/271 passed` after `test-fast` plus one
additional FPU target. The remaining entries are full FPU/MMU targets that were
not completed in that run; no `FAIL` files were observed.

## 1. Prerequisites

Install the basic host build tools first:

```bash
sudo apt-get update
sudo apt-get install -y \
  git make gcc g++ autoconf automake autotools-dev curl \
  device-tree-compiler flex bison libgmp-dev libmpfr-dev \
  libmpc-dev zlib1g-dev
```

The NaxRiscv makefiles install project-local copies of SBT, OpenJDK, Verilator,
Spike, ELFIO, SDL, and RVLS under `toolchain/` and `ext/`.

## 2. Clone the Repository

Use the `rvls-update` branch for the test flow described here:

```bash
cd /path/to/DUTs
git clone https://github.com/SpinalHDL/NaxRiscv.git
cd NaxRiscv
git checkout -B rvls-update origin/rvls-update
```

If the machine requires a proxy for external downloads, configure Git, curl, and
JVM-based tools according to the local site policy. Keep proxy endpoints and
credentials out of committed files.

## 3. Use Repo-Local Caches

Redirect SBT, Ivy, Coursier, and ccache into the NaxRiscv repository. This
avoids writes to a restricted home directory and makes the setup easier to
reproduce.

Run these exports from the NaxRiscv repository root:

```bash
export NAXRISCV=$PWD
export JAVA_HOME=$PWD/toolchain/openjdk
export PATH=$JAVA_HOME/bin:$PWD/toolchain/verilator-v4.216/bin:$PATH
export HOME=$PWD/.home
export COURSIER_CACHE=$PWD/.cache/coursier
export CCACHE_DIR=$PWD/.cache/ccache
export SBT_OPTS="-Dsbt.boot.directory=$PWD/.sbt/boot -Dsbt.global.base=$PWD/.sbt/global -Dsbt.ivy.home=$PWD/.ivy2 -Dsbt.coursier.home=$PWD/.cache/coursier"
```

If Java/SBT downloads must go through a proxy, add the appropriate JVM proxy
properties to `JAVA_TOOL_OPTIONS` and `SBT_OPTS` for the current shell. Do not
store site-specific proxy endpoints or credentials in the repository.

## 4. Install Toolchain and Submodules

From the NaxRiscv repository root:

```bash
make install-toolchain-initial
make install-toolchain
```

This flow initializes the submodules and builds the local toolchain:

- SBT and OpenJDK under `toolchain/`
- Verilator under `toolchain/verilator-v4.216`
- Spike, ELFIO, SDL under `ext/riscv-isa-sim`
- RVLS under `ext/rvls/build/apps`

Do not rerun `make install-toolchain-initial` on an already patched working tree
without cleaning first. The repository installation scripts apply patches to
submodules, and reapplying them can fail.

## 5. Host Compatibility Fixes

These fixes were required on the validated host. Apply only when the same
failure appears.

### Verilator v4.216 with GCC 13

If Verilator fails to compile because `std::unique_ptr` or related symbols are
missing in `V3Const.cpp`, add the missing include:

```bash
sed -i '/#include <algorithm>/a #include <memory>' \
  toolchain/verilator-v4.216/src/V3Const.cpp
```

Then rerun the Verilator build step or `make install-toolchain`.

### Missing Boost Link Libraries

Spike was configured with `--without-boost`, but some local link lines still
referenced Boost libraries. On a host without Boost libraries, remove
`-lboost_regex` and `-lboost_system` from:

```text
ext/rvls/Makefile
src/test/cpp/naxriscv/makefile
```

The local setup used these link flags instead:

```make
LIBRARIES += -lpthread -ldl
LIBS +="-lpthread -ldl"
```

If `ext/riscv-isa-sim/build/package.so` was already linked with Boost, relink it
without Boost:

```bash
cd "$NAXRISCV/ext/riscv-isa-sim/build"

g++ --shared -L. -Wl,--export-dynamic -L/usr/lib/x86_64-linux-gnu -Wl,-rpath,/lib \
  -o package.so \
  spike.o libspike_main.a libriscv.a libdisasm.a libsoftfloat.a libfesvr.a libfdt.a \
  -lpthread -ldl
```

Return to the NaxRiscv repository root afterwards:

```bash
cd "$NAXRISCV"
```

## 6. Generate RTL

Generate the default `rv64imafdcsu` NaxRiscv RTL:

```bash
make NaxRiscv.v
```

Expected generated files in the NaxRiscv repository root:

```text
NaxRiscv.v
NaxRiscvSynt.v
nax.h
```

## 7. Build the Verilator Simulator

Compile the simulator:

```bash
make -C src/test/cpp/naxriscv compile THREAD_COUNT=$(nproc)
```

Expected output:

```text
src/test/cpp/naxriscv/obj_dir/VNaxRiscv
```

`VNaxRiscv` links the generated RTL simulator with the local Spike build. Spike
lockstep checking is enabled by default. Use `--spike-disabled` only when you
explicitly want to run without Spike comparison.

## 8. Run a Smoke Test

Run one RISC-V ISA test through the NaxRiscv Verilator simulator:

```bash
LD_LIBRARY_PATH=$NAXRISCV/ext/riscv-isa-sim/lib:$NAXRISCV/ext/riscv-isa-sim/build \
  ./src/test/cpp/naxriscv/obj_dir/VNaxRiscv \
  --load-elf ext/NaxSoftware/riscv-tests/rv64ui-p-addi \
  --pass-symbol pass \
  --fail-symbol fail \
  --timeout 100000 \
  --name rv64ui-p-addi
```

Expected result:

```text
SUCCESS rv64ui-p-addi
```

To save Spike reference traces, add:

```bash
--trace-ref --spike-debug --output-dir output/rv64ui-p-addi-debug
```

## 9. Run Fast Regression

Run the fast regression set:

```bash
cd "$NAXRISCV/src/test/cpp/naxriscv"

LD_LIBRARY_PATH=$NAXRISCV/ext/riscv-isa-sim/lib:$NAXRISCV/ext/riscv-isa-sim/build \
  make test-fast -j$(nproc)
```

Check the result:

```bash
find output -name PASS | wc -l
find output -name FAIL | wc -l
make test-report
```

`test-fast` is the recommended first check after setup. The full `test-all`
target also covers long FPU/MMU targets and can take much longer:

```bash
LD_LIBRARY_PATH=$NAXRISCV/ext/riscv-isa-sim/lib:$NAXRISCV/ext/riscv-isa-sim/build \
  make test-all -j$(nproc)
```

## 10. Useful Cleanup Commands

Clean generated RTL and simulator outputs:

```bash
cd "$NAXRISCV"
make clean-gen
```

Clean test outputs:

```bash
cd "$NAXRISCV/src/test/cpp/naxriscv"
make test-clean
```

Remove project-local toolchains:

```bash
cd "$NAXRISCV"
make clean-toolchain
```

## 11. DUTs Repository Notes

The NaxRiscv checkout is a separate Git repository under the DUTs workspace. Do
not add the whole `NaxRiscv/` directory to the DUTs repository unless the intent
is to vendor the upstream source and all generated artifacts. For documentation
purposes, commit only this guide or other small workspace-level notes.
