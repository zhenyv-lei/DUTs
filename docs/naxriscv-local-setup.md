# NaxRiscv Local Setup

NaxRiscv is managed through the DUT wrapper under:

```text
naxriscv/
```

Use the wrapper README and setup script:

```bash
cd /path/to/DUTs/naxriscv
scripts/setup_naxriscv.sh --help
scripts/setup_naxriscv.sh
```

The upstream checkout is installed locally under:

```text
naxriscv/NaxRiscv/
```

That checkout, generated RTL, toolchains, simulator objects, and regression
outputs are local artifacts and are ignored by git. The committed DUTs entry is
the wrapper: `naxriscv/README.md`, `naxriscv/SOURCE.md`, and
`naxriscv/scripts/setup_naxriscv.sh`.
