# Tool Sources

This directory is populated by `tools/scripts/fetch_sources.sh` and the build scripts.
The generated external source checkouts are intentionally not committed.

Spike is the exception: CVA6 uses the vendored source tree at
`verif/core-v-verif/vendor/riscv/riscv-isa-sim`, and `tools/scripts/build_spike.sh`
invokes CVA6's own `verif/regress/install-spike.sh`.
