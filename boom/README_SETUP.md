# BOOM / Chipyard Setup

This setup keeps one shared Chipyard checkout under `boom/chipyard` and exposes
two BOOM DUT targets:

```text
targets/boomv3-medium/
targets/boomv4-medium/
```

Each target directory can be used directly after setup:

```bash
cd targets/boomv3-medium
source ./env.sh
./run_helloworld.sh
```

## Layout

```text
boom/
  chipyard/                  Installed Chipyard checkout; ignored by git.
  tools/conda/               Local Miniforge install; ignored by git.
  tools/downloads/           Download cache; ignored by git.
  scripts/
    install_conda.sh         Install local Miniforge if conda is unavailable.
    install_chipyard.sh      Clone/init Chipyard and install RISC-V tools.
    setup_target.sh          Setup and build boomv3-medium or boomv4-medium.
    run_config.sh            Run a Chipyard Verilator cosim config.
  builds/                    Local build output area; ignored by git.
  runs/                      Local run logs; ignored by git.
  targets/
    boomv3-medium/
      env.sh
      run_helloworld.sh
      run_cosim.sh
    boomv4-medium/
      env.sh
      run_helloworld.sh
      run_cosim.sh
```

## Setup

From the BOOM family directory:

```bash
cd ~/opt/DUTs/boom
scripts/setup_target.sh boomv3-medium
scripts/setup_target.sh boomv4-medium
```

If the machine needs a proxy or site-specific network wrapper for GitHub/conda
downloads, configure it outside these scripts and run the same commands inside
that environment.

Useful knobs:

```text
JOBS=48                         Parallel build jobs.
CHIPYARD_REF=<git-ref>          Chipyard ref to checkout.
CHIPYARD_REPO=<url>             Chipyard repository URL.
```

## Run Hello World Cosim

After setup:

```bash
cd ~/opt/DUTs/boom/targets/boomv3-medium
source ./env.sh
./run_helloworld.sh

cd ~/opt/DUTs/boom/targets/boomv4-medium
source ./env.sh
./run_helloworld.sh
```

Both wrappers build Chipyard's `tests/hello.c` into `hello.riscv` and run it on
the corresponding Medium BOOM cosim config.
