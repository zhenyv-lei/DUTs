#!/usr/bin/env bash

_CVA6_ENV_SCRIPT="${BASH_SOURCE[0]}"
export CVA6_ROOT="$(cd "$(dirname "$_CVA6_ENV_SCRIPT")" && pwd -P)"
unset _CVA6_ENV_SCRIPT

export CVA6_TOOLS_BUILD="${CVA6_TOOLS_BUILD:-$CVA6_ROOT/tools/build}"
export CVA6_TOOLS_INSTALL="${CVA6_TOOLS_INSTALL:-$CVA6_TOOLS_BUILD/install}"

export RISCV="$CVA6_TOOLS_INSTALL/riscv"
export RISCV_CC="$RISCV/bin/riscv-none-elf-gcc"
export RISCV_OBJCOPY="$RISCV/bin/riscv-none-elf-objcopy"
export CV_SW_PREFIX="riscv-none-elf-"

export SPIKE_SRC_DIR="$CVA6_ROOT/verif/core-v-verif/vendor/riscv/riscv-isa-sim"
export SPIKE_INSTALL_DIR="$CVA6_TOOLS_INSTALL/spike"
export SPIKE_PATH="$SPIKE_INSTALL_DIR/bin"

export VERILATOR_INSTALL_DIR="$CVA6_TOOLS_INSTALL/verilator"
export VERILATOR_ROOT="$VERILATOR_INSTALL_DIR/share/verilator"

export PK_INSTALL_DIR="$CVA6_TOOLS_INSTALL/riscv-pk-rv32"
export PK_BIN="$PK_INSTALL_DIR/riscv32-unknown-elf/bin/pk"
export RISCV_PK_RV32="$PK_BIN"

export VIRTUAL_ENV="$CVA6_ROOT/.venv"
export PYTHONNOUSERSITE=1
export PIP_CACHE_DIR="$CVA6_ROOT/.cache/pip"
export CCACHE_DIR="$CVA6_ROOT/.cache/ccache"
export CCACHE_TEMPDIR="$CVA6_ROOT/.cache/ccache-tmp"

export ROOT_PROJECT="$CVA6_ROOT"
export RTL_PATH="$CVA6_ROOT/"
export TB_PATH="$CVA6_ROOT/verif/tb/core"
export TESTS_PATH="$CVA6_ROOT/verif/tests"
export RISCV_DV_ROOT="$CVA6_ROOT/verif/sim/dv"

export LIBRARY_PATH="$RISCV/lib:${LIBRARY_PATH:-}"
export C_INCLUDE_PATH="$RISCV/riscv-none-elf/include:$RISCV/lib/gcc/riscv-none-elf/13.1.0/include:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="$C_INCLUDE_PATH"

mkdir -p "$PIP_CACHE_DIR" "$CCACHE_DIR" "$CCACHE_TEMPDIR"

export PATH="$VIRTUAL_ENV/bin:$SPIKE_PATH:$VERILATOR_INSTALL_DIR/bin:$RISCV/bin:$PATH"
export LD_LIBRARY_PATH="$CVA6_ROOT/tools/host-libs:$SPIKE_INSTALL_DIR/lib:$RISCV/lib:${LD_LIBRARY_PATH:-}"
