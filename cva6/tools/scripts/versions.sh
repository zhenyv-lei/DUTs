#!/usr/bin/env bash
# Version policy: follow CVA6 checks/scripts first; use upstream releases only
# when CVA6 does not constrain a tool.

export VERILATOR_REPO="https://github.com/verilator/verilator.git"
export VERILATOR_VERSION="v5.008"

# CVA6 checks only GCC >= 11, but its toolchain-builder defaults to this
# reproducible bare-metal configuration.
export RISCV_TOOLCHAIN_CONFIG="gcc-13.1.0-baremetal"
export BINUTILS_COMMIT="binutils-2_40"
export GCC_COMMIT="releases/gcc-13.1.0"
export NEWLIB_COMMIT="newlib-4.3.0"

# Spike is built from CVA6/core-v-verif vendored sources, not an upstream tag.
export SPIKE_SOURCE_REL="verif/core-v-verif/vendor/riscv/riscv-isa-sim"

# Optional experiment dependency. CVA6 does not constrain riscv-pk, so the
# build script uses the upstream repository default branch unless overridden.
export RISCV_PK_REPO="https://github.com/riscv-software-src/riscv-pk.git"
export RISCV_PK_REF="${RISCV_PK_REF:-}"
