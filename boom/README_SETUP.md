# BOOM / Chipyard Setup

For a clean-machine reproduction checklist, start with `README.md`. This file
keeps the more detailed workflow and troubleshooting notes.

This setup keeps one shared Chipyard checkout under `boom/chipyard` and exposes
two BOOM DUT targets. The default acceptance path is single-core cospike; the
dual-core configs are kept as explicit debug paths.

```text
targets/boomv3-medium/
targets/boomv4-medium/
```

After the environment and target simulator are built, each target directory can
be used directly:

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
    apply_chipyard_overlays.sh
                             Add local dual-core BOOM debug configs to Chipyard.
    setup_target.sh          Setup and build boomv3-medium or boomv4-medium.
    run_config.sh            Run a Chipyard Verilator cosim config.
  builds/                    Local build output area; ignored by git.
  runs/                      Local run logs; ignored by git.
  targets/
    boomv3-medium/
      env.sh
      run_helloworld.sh       Chipyard default hello workload.
      run_dual_helloworld.sh  Dual-core debug run using Chipyard hello.
      run_cosim.sh
    boomv4-medium/
      env.sh
      run_helloworld.sh       Chipyard default hello workload.
      run_dual_helloworld.sh  Dual-core debug run using Chipyard hello.
      run_cosim.sh
```

## Workflow

The setup is intentionally split into environment installation and BOOM target
builds. `chipyard/`, `tools/conda/`, and all generated simulator outputs stay
under this `boom/` directory and are ignored by git.

### 1. Install Environment

```bash
cd ~/opt/DUTs/boom
JOBS=16 scripts/install_chipyard.sh
```

This stage installs the local environment resources:

```text
boom/tools/conda/       Local Miniforge installation.
boom/chipyard/          Chipyard checkout.
boom/chipyard/.conda-env/
                        Chipyard conda environment and RISC-V tools.
```

It may clone Chipyard, create conda environments, fetch submodules, download
CIRCT/firtool, build RISC-V tools, and precompile Scala sources. It does not
select a DUT target by itself.

On machines that require the BOSC IPv6 wrapper for network access:

```bash
cd ~/opt/DUTs/boom
bosc-ipv6 bash -lc 'JOBS=16 scripts/install_chipyard.sh'
```

### 2. Apply Local Chipyard Configs

Chipyard already provides the single-core cosim configs used by the default
target wrappers:

```text
boomv3-medium -> MediumBoomV3CosimConfig
boomv4-medium -> MediumBoomV4CosimConfig
```

The overlay additionally adds explicit dual-core debug configs:

```text
boomv3-medium dual debug -> DualMediumBoomV3CosimConfig
boomv4-medium dual debug -> DualMediumBoomV4CosimConfig
```

Those configs keep `WithCospike` and `WithTraceIO` enabled and instantiate two
medium BOOM cores with `WithNMediumBooms(2)`.

`scripts/install_chipyard.sh` applies the overlay automatically. If an existing
Chipyard checkout was created before this overlay existed, apply it explicitly:

```bash
cd ~/opt/DUTs/boom
scripts/apply_chipyard_overlays.sh
```

### 3. Build BOOM Cosim Targets

Build the target simulators:

```bash
cd ~/opt/DUTs/boom
JOBS=16 scripts/setup_target.sh boomv3-medium
JOBS=16 scripts/setup_target.sh boomv4-medium
```

This stage first ensures the local environment is installed, then creates the
target wrappers under `boom/targets/` and builds the corresponding single-core
Verilator cosim binaries:

```text
boom/chipyard/sims/verilator/simulator-chipyard.harness-MediumBoomV3CosimConfig
boom/chipyard/sims/verilator/simulator-chipyard.harness-MediumBoomV4CosimConfig
```

If you have just run `scripts/install_chipyard.sh` and only want to rebuild a
target wrapper/simulator, `BOOM_SKIP_CHIPYARD_INSTALL=1` can be used as an
optional speed-up. Do not use it for a clean deployment.

On machines that require the BOSC IPv6 wrapper:

```bash
cd ~/opt/DUTs/boom
bosc-ipv6 bash -lc 'JOBS=16 scripts/setup_target.sh boomv3-medium'
bosc-ipv6 bash -lc 'JOBS=16 scripts/setup_target.sh boomv4-medium'
```

Useful knobs:

```text
JOBS=48                         Parallel build jobs; lower this on shared hosts.
CHIPYARD_REF=<git-ref>          Chipyard ref to checkout.
CHIPYARD_REPO=<url>             Chipyard repository URL.
BOOM_SKIP_CHIPYARD_INSTALL=1    Reuse an existing boom/chipyard checkout.
```

Expect a long environment install and large local output. A completed setup with
both medium cosim targets can use tens of GB under `boom/chipyard` plus a few GB
under `boom/tools`.

### 4. Run Stock Hello Cosim

After target build:

```bash
cd ~/opt/DUTs/boom/targets/boomv3-medium
source ./env.sh
./run_helloworld.sh

cd ~/opt/DUTs/boom/targets/boomv4-medium
source ./env.sh
./run_helloworld.sh
```

These wrappers build and run Chipyard's stock `hello.riscv` on the corresponding
single-core BOOM cosim config. Cospike should report:

```text
Cosim: harts: 1
```

### Dual-Core Debug Path

For dual-core investigation, use the explicit debug wrapper:

```bash
cd ~/opt/DUTs/boom/targets/boomv3-medium
source ./env.sh
./run_dual_helloworld.sh

cd ~/opt/DUTs/boom/targets/boomv4-medium
source ./env.sh
./run_dual_helloworld.sh
```

This still uses Chipyard's stock `hello.riscv`, but runs it on
`DualMediumBoomV3CosimConfig` or `DualMediumBoomV4CosimConfig`.

Current strict-cospike status: with the original load-data check preserved,
both `DualMediumBoomV3CosimConfig` and `DualMediumBoomV4CosimConfig` fail on
stock `hello.riscv` when hart 1 observes the secondary-hart release flag before
Spike observes the same store in its commit-stepped model:

```text
Cosim: harts: 2
Cosim: ... wdata mismatch reg 5 ffffffffffffffff != 0
```

The local overlay does not relax normal memory load-data checks. The helper
`run_dual_helloworld.sh` records this useful failing configuration, but it is not
the current acceptance path.

For a custom ELF:

```bash
cd ~/opt/DUTs/boom/targets/boomv3-medium
source ./env.sh
./run_cosim.sh /path/to/program.elf
```

Extra Chipyard make arguments can be passed after the ELF.

## Logs And Artifacts

The scripts keep high-level logs under `boom/runs/<CONFIG>/logs/`:

```text
boom/runs/DualMediumBoomV3CosimConfig/logs/build.log
boom/runs/DualMediumBoomV3CosimConfig/logs/run.log
boom/runs/DualMediumBoomV4CosimConfig/logs/build.log
boom/runs/DualMediumBoomV4CosimConfig/logs/run.log
```

The single-core acceptance logs are:

```text
boom/runs/MediumBoomV3CosimConfig/logs/build.log
boom/runs/MediumBoomV3CosimConfig/logs/run.log
boom/runs/MediumBoomV4CosimConfig/logs/build.log
boom/runs/MediumBoomV4CosimConfig/logs/run.log
```

Chipyard's Verilator output also writes per-binary logs under:

```text
boom/chipyard/sims/verilator/output/chipyard.harness.TestHarness.<CONFIG>/
```

The old custom dual hello-world workload is not a strict-cospike acceptance
test; the debug wrapper now uses Chipyard's stock `hello.riscv` directly.

## Troubleshooting

If a conda download fails with `CondaHTTPError` or `HTTP 000 CONNECTION FAILED`,
rerun the same command first. If the environment was left half-created, remove
the incomplete Chipyard conda directories and retry:

```bash
rm -rf ~/opt/DUTs/boom/chipyard/.conda-lock-env ~/opt/DUTs/boom/chipyard/.conda-env
bosc-ipv6 bash -lc 'cd ~/opt/DUTs/boom && JOBS=16 scripts/setup_target.sh boomv3-medium'
```

If Chipyard reports that conda environment directories already exist but
`env.sh` cannot be sourced, treat that as an incomplete setup and retry after
removing the same directories.

The Chipyard setup may regenerate conda lockfiles on hosts whose glibc version is
newer than the checked-in lockfile constraints. This can take several minutes and
use noticeable CPU and memory.

`--skip-firesim --skip-marshal --use-lean-conda` keeps the setup focused on RTL
cosim, but Chipyard still initializes many submodules required by the shared
repository.
