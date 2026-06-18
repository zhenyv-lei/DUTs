# CVA6 Experiment Setup

This note documents the local experiment layout added around the imported CVA6
source snapshot and the steps to rebuild the tool environment and run the
`hello_world` smoke test.

## Directory Layout

```text
cva6/
  core/                       CVA6 core RTL.
  corev_apu/                  CVA6 APU/FPGA integration files.
  verif/                      Upstream CVA6 verification environment.
    sim/                      Python simulation front-end and ISS flow.
    tb/                       Verilator/SystemVerilog testbench files.
    tests/                    Bare-metal and generated test programs.
    core-v-verif/             Imported CORE-V verification dependency.
  config/                     Target/linker/ISA configuration files.
  util/toolchain-builder/     CVA6 toolchain builder used by local scripts.
  env.sh                      Local environment entry. Source this before tests.
  run_helloworld.sh           Wrapper for the hello_world cosim smoke test.
  tools/
    scripts/
      setup_python_env.sh     Create the Python virtual environment.
      build_riscv_toolchain.sh Build the bare-metal RISC-V GCC toolchain.
      build_verilator.sh      Clone, checkout, patch, build, and install Verilator.
      build_spike.sh          Build Spike from the vendored CVA6 source tree.
      build_pk_rv32.sh        Build rv32 pk runtime support.
      build_all.sh            Run all CVA6 tool setup scripts.
      versions.sh             Pinned tool version policy.
    src/                      Downloaded/cloned tool sources.
    build/
      riscv/                  Installed RISC-V GCC toolchain.
      verilator/              Installed Verilator.
      spike/                  Installed Spike.
      riscv-pk-rv32/          Installed rv32 pk runtime.
```

Only `env.sh`, `run_helloworld.sh`, `SOURCE.md`, and `tools/scripts/` are local
additions. The upstream CVA6 flow still uses `verif/sim/cva6.py` and the
repository `Makefile`.

## Step 1: Install CVA6 Tools

The local CVA6 smoke test uses a bare-metal RISC-V GCC toolchain, Verilator,
Spike, and a Python virtual environment. From the repository root:

```bash
cd ~/opt/cva6
NUM_JOBS=8 tools/scripts/build_all.sh
```

The script runs:

```text
tools/scripts/setup_python_env.sh
tools/scripts/build_riscv_toolchain.sh
tools/scripts/build_verilator.sh
tools/scripts/build_spike.sh
tools/scripts/build_pk_rv32.sh
```

This installs tools under:

```text
tools/build/riscv/
tools/build/verilator/
tools/build/spike/
tools/build/riscv-pk-rv32/
.venv/
```

Pinned tool policy:

```text
RISC-V GCC toolchain: gcc-13.1.0-baremetal
Verilator: v5.008
Spike: CVA6 vendored riscv-isa-sim source
```

Verify:

```bash
tools/build/riscv/bin/riscv-none-elf-gcc --version
tools/build/verilator/bin/verilator --version
tools/build/spike/bin/spike -v
.venv/bin/python --version
```

## Step 2: Enter The Experiment Environment

Always enter the environment from the CVA6 repository root:

```bash
cd ~/opt/cva6
source env.sh
```

`env.sh` sets:

```text
CVA6_ROOT=<repo>
RISCV=<repo>/tools/build/riscv
RISCV_CC=<repo>/tools/build/riscv/bin/riscv-none-elf-gcc
VERILATOR_INSTALL_DIR=<repo>/tools/build/verilator
SPIKE_INSTALL_DIR=<repo>/tools/build/spike
VIRTUAL_ENV=<repo>/.venv
PATH includes the local Python, Spike, Verilator, and RISC-V GCC tools
```

Check:

```bash
which python
which riscv-none-elf-gcc
riscv-none-elf-gcc --version
which verilator
verilator --version
which spike
spike -v
```

## Step 3: Run hello_world

Use the wrapper:

```bash
cd ~/opt/cva6
./run_helloworld.sh
```

The wrapper runs the known-good bare-metal hello_world cosim:

```text
Spike + CVA6 Verilator testharness
trace comparison through verif/sim/cva6.py
target: cv32a60x
test: verif/tests/custom/hello_world/hello_world.c
```

Or run the underlying command manually:

```bash
cd ~/opt/cva6
source env.sh
source verif/sim/setup-env.sh
cd verif/sim
python cva6.py \
  --target cv32a60x \
  --iss=veri-testharness,spike \
  --iss_yaml=cva6.yaml \
  --c_tests ../tests/custom/hello_world/hello_world.c \
  --linker=../../config/gen_from_riscv_config/linker/link.ld \
  --gcc_opts="-static -mcmodel=medany -fvisibility=hidden -nostdlib \
  -nostartfiles -g ../tests/custom/common/syscalls.c \
  ../tests/custom/common/crt.S -lgcc \
  -I../tests/custom/env -I../tests/custom/common"
```

A successful run completes the Spike and Verilator simulations and finishes the
trace comparison without mismatches.
