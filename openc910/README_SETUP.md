# OpenC910 Experiment Setup

This note documents the local experiment layout added around the upstream
OpenC910 repository and the steps to rebuild the tool environment and run the
`hello_world` smoke test.

## Directory Layout

```text
openc910/
  C910_RTL_FACTORY/          Upstream OpenC910 RTL factory directory.
  smart_run/                 Upstream smart testbench and simulation entry.
    env.sh                   Local environment entry. Source this before tests.
    run_helloworld.sh        Wrapper for the hello_world smoke test.
    setup/                   Upstream setup files, including example_setup.csh.
    tests/                   C/ASM/Verilog test cases and common test library.
    work/                    Generated build/simulation output. Recreated by runs.
  tools/
    scripts/
      install_xuantie_toolchain.sh  Install the XuanTie RISC-V GNU toolchain.
      install_verilator.sh          Clone, checkout, build, and install Verilator.
      install_all.sh                Run both install scripts.
    src/
      verilator/                    Verilator source checkout, tag v4.228.
      *.tar.gz                      Downloaded XuanTie toolchain archive.
    build/
      xuantie-gcc-2023.03.21/       Extracted XuanTie compiler package.
      xuantie-gcc -> ...            Stable symlink used by env.sh.
      verilator-v4.228/             Verilator install prefix after build.
      verilator -> ...              Stable symlink used by env.sh.
```

Only `smart_run/env.sh`, `smart_run/run_helloworld.sh`, and `tools/` are local
additions. The upstream OpenC910 flow still uses `smart_run/Makefile`.

## Step 1: Install XuanTie GNU Toolchain

The OpenC910 tests require a bare-metal XuanTie/RISC-V compiler that supports
extensions such as `xtheadc`. A generic `riscv64-linux-gnu-gcc` or generic
embedded RISC-V GCC is not sufficient.

From the repository root:

```bash
cd ~/opt/openc910
tools/scripts/install_xuantie_toolchain.sh
```

This installs:

```text
tools/build/xuantie-gcc-2023.03.21/
tools/build/xuantie-gcc -> xuantie-gcc-2023.03.21
```

Expected compiler:

```bash
tools/build/xuantie-gcc/bin/riscv64-unknown-elf-gcc --version
```

Expected version:

```text
riscv64-unknown-elf-gcc (GCC) 10.2.0
```

## Step 2: Install Verilator v4.228

OpenC910 documents Verilator 4.215 or newer. This setup pins Verilator to
`v4.228` for reproducibility.

Building Verilator can take several minutes:

```bash
cd ~/opt/openc910
JOBS=8 tools/scripts/install_verilator.sh
```

The script performs:

```text
git clone https://github.com/verilator/verilator.git tools/src/verilator
git checkout v4.228
autoconf
./configure --prefix=tools/build/verilator-v4.228
make -j$JOBS
make install
tools/build/verilator -> verilator-v4.228
```

Verify:

```bash
tools/build/verilator/bin/verilator --version
```

## Step 3: Enter The Experiment Environment

Always enter the environment from `smart_run`:

```bash
cd ~/opt/openc910/smart_run
source env.sh
```

`env.sh` sets:

```text
CODE_BASE_PATH=<repo>/C910_RTL_FACTORY
TOOL_EXTENSION=<repo>/tools/build/xuantie-gcc/bin
PATH includes <repo>/tools/build/verilator/bin when installed
```

Check:

```bash
which riscv64-unknown-elf-gcc
riscv64-unknown-elf-gcc --version
which verilator
verilator --version
```

## Step 4: Run hello_world

Use the wrapper:

```bash
cd ~/opt/openc910/smart_run
./run_helloworld.sh
```

Or run the upstream Makefile flow manually:

```bash
cd ~/opt/openc910/smart_run
source env.sh
mkdir -p work
make SHELL=/bin/bash buildcase CASE=hello_world SIM=verilator
make SHELL=/bin/bash runcase CASE=hello_world SIM=verilator DUMP=off
```

A successful run prints:

```text
Hello Friend!
Welcome to T-HEAD World!
!!! PASS !!!
simulation finished successfully
```
