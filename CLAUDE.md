# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is **not** the DIALS source code. It is the packaging repository that builds
cross-platform DIALS installers with [conda `constructor`](https://conda.github.io/constructor/).
DIALS, xia2, and dui2 are pulled in as pre-built conda packages from channels;
nothing here is compiled. The repo holds two things:

- a `constructor` spec (`construct.yaml`) that builds the installers, and
- a small conda recipe (`conda-recipe/`) for the `dials-launcher` package, which
  provides the PATH activation scripts and menu entry that the installers ship.

## Build

`constructor` produces a platform-native installer (`.sh` on Linux, `.pkg` on
macOS, `.exe` on Windows) for the host platform only — there is no
cross-compilation. `dials-launcher` must be available for the same version first.

```bash
export DIALS_VERSION=3.30.1        # construct.yaml and meta.yaml read this; fallback 3.30.1
conda install -y -n base conda-build
conda install -y constructor

# Build dials-launcher into a local channel, then point construct.yaml at it.
conda build conda-recipe -c conda-forge -c https://conda.anaconda.org/ndevenish \
    --output-folder "$PWD/local-channel"
export DIALS_LAUNCHER_CHANNEL="file://$PWD/local-channel"
constructor . --output-dir dist
```

Without `DIALS_LAUNCHER_CHANNEL`, construct.yaml takes the published
`DiamondLightSource::dials-launcher` instead. `license_file: LICENSE` is required
and not committed; fetch it from `https://raw.githubusercontent.com/dials/dials/v<version>/LICENSE`.

### CI

- **`.github/workflows/build-installers.yml`** — `workflow_dispatch` only, with a
  `version` input. On each runner (Linux, macOS Intel, macOS arm64, Windows) it
  fetches the DIALS `LICENSE`, builds `dials-launcher` from `conda-recipe/` into a
  local `file://` channel, sets `DIALS_LAUNCHER_CHANNEL` to it, runs `constructor`,
  and finally drafts a GitHub release tagged `v<version>`. Nothing is uploaded to
  anaconda.org, so recipe changes take effect in the very next installer build.
- **`.github/workflows/conda-package.yml`** — builds and tests `dials-launcher` on
  pushes/PRs touching `conda-recipe/`. Uploads to anaconda.org only when run
  manually with a non-empty `channel` input *and* an `ANACONDA_TOKEN` secret.

## Architecture / how the pieces fit

The bundled conda environment is large, but end users should only see the DIALS
programs. The design is: install the full environment, then **expose only the DIALS
dispatchers** via forwarders in `$PREFIX/dialsbin`, plus activation scripts.

- **`construct.yaml`** — package `specs` (`dials`, `xia2`, `dui2`,
  `<launcher_channel>::dials-launcher`), conda `channels` (conda-forge and
  ndevenish — dui2 is only published on ndevenish), installer branding images
  (`dials_*.png`), default install prefix, and `menu_packages` (which packages may
  create shortcuts). `dials-launcher` is channel-qualified rather than adding its
  channel to `channels`, because DiamondLightSource carries packages whose names
  collide with conda-forge.

- **`conda-recipe/`** — the `dials-launcher` package (see its `README.md`).
  `make_shims.py` runs at build time with the DIALS stack in `host`, finds every
  dispatcher matching `DISPATCHER_PREFIXES` in `bin/` (unix) or `Scripts\`
  (Windows), and writes a forwarder for each into `dialsbin/`. Each forwarder sets
  up the full environment PATH inside its own process only. `build.sh`/`bld.bat`
  also install `setpaths.sh`/`.bat`/`.ps1`, `dials_env.sh`/`.bat`, and the
  menuinst `Menu/dials-launcher.json` (Linux and Windows; not macOS).

### Editing invariants

- The set of exposed programs is `DISPATCHER_PREFIXES` in
  `conda-recipe/make_shims.py` — the single place that decides what a user sees on
  PATH. Any package providing those commands must also be in the recipe's `host`
  and `run` requirements, or its dispatchers will not exist at build time.
- Keep the conda channels consistent across `construct.yaml` and the
  `conda build -c ...` lines in both workflows, so the launcher is built against
  the same stack the installer ships.
- Keep `build.sh` and `bld.bat` behaviourally in sync.
- The `DIALS_VERSION` fallback (`3.30.1`) appears in `construct.yaml`,
  `conda-recipe/meta.yaml`, and the workflow defaults; update them together.
