# Toooba Local Install Step by Step

This checkout was deployed with the script:

```bash
scripts/deploy_toooba_step_by_step.sh
```

All project-installed software is kept under `Toooba/tools/`. The only extra
software built locally for Toooba is Verilator 3.922.

## 1. Prerequisites

The script expects these system tools to already exist:

```bash
git make gcc g++ cc perl autoconf flex bison
```

It also checks that the system C compiler can link `libelf`:

```bash
cc test.c -lelf
```

No system-wide package installation is performed by the script.

## 2. Network Proxy

All external network commands are wrapped by:

```bash
scripts/with_bosc_proxy.sh
```

Default proxy:

```bash
http://bosc-ipv6:7890
```

Check proxy connectivity:

```bash
scripts/with_bosc_proxy.sh --check https://github.com
```

Override the proxy endpoint if needed:

```bash
BOSC_PROXY_URL=http://proxy-host:port scripts/with_bosc_proxy.sh --check https://github.com
```

## 3. Run the Installer

From the parent directory:

```bash
cd /nfs/home/leizhenyu/opt/DUTs
BOSC_PROXY_URL=http://bosc-ipv6:7890 Toooba/scripts/deploy_toooba_step_by_step.sh
```

The script performs these steps:

1. Reuse `Toooba/` if it already exists, otherwise clone `https://github.com/bluespec/Toooba.git` through the proxy.
2. Initialize recursive submodules through the proxy.
3. Clone Verilator `v3.922` into `Toooba/tools/src/verilator-v3.922`.
4. Patch Verilator 3.922 `bisonpre` for current bison 3.x compatibility.
5. Build and install Verilator into `Toooba/tools/verilator-3.922`.
6. Add local compatibility symlinks expected by Verilator 3.922 generated makefiles.
7. Patch Toooba's Verilator config from modern `lint_off -rule` syntax to Verilator 3.922 `lint_off -msg` syntax.
8. Build `builds/RV64ACDFIMSU_Toooba_verilator/exe_HW_sim`.
9. Run `make test`, which should end with `PASS`.

## 4. Offline Seed Mode

If `bosc-ipv6` is not resolvable on the current host, use local seed checkouts:

```bash
cd /nfs/home/leizhenyu/opt/DUTs
LOCAL_SEED_REPO=/nfs/home/leizhenyu/opt/DUTs/toooba \
LOCAL_VERILATOR_SEED=/nfs/home/leizhenyu/opt/DUTs/toooba/tools/src/verilator-v3.922 \
Toooba/scripts/deploy_toooba_step_by_step.sh
```

This is the mode used for this local deployment because `bosc-ipv6` could not
be resolved from the current machine.

## 5. Use the Installed Emulator

Set the local Toooba tool environment:

```bash
cd /nfs/home/leizhenyu/opt/DUTs/Toooba
source scripts/env.sh
```

Check the project-local Verilator:

```bash
verilator --version
```

Expected:

```text
Verilator 3.922 2018-03-17
```

Run the smoke test:

```bash
make -C builds/RV64ACDFIMSU_Toooba_verilator test
```

The installed emulator is:

```bash
builds/RV64ACDFIMSU_Toooba_verilator/exe_HW_sim
```

The smoke test runs `Tests/isa/rv64ui-p-add` and should print `PASS`.

