# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is **not** the DIALS source code. It is the packaging repository that builds
cross-platform DIALS installers with [conda `constructor`](https://conda.github.io/constructor/).
DIALS and xia2 are pulled in as pre-built conda packages from conda-forge;
nothing here is compiled. The repo holds three things:

- a `constructor` spec (`construct.yaml`) that builds the installers,
- a small conda recipe (`conda-recipe/`) for the `dials-launcher` package, which
  provides the PATH activation scripts and menu entry that the installers ship, and
- a conda recipe (`dui2-recipe/`, adapted from `ndevenish/dui2-feedstock`) that
  packages DUI2 from a `ccp4/DUI2` release tag. dui2 is not on conda-forge, so it
  is built here to control which release the installers ship.

## Build

`constructor` produces a platform-native installer (`.sh` on Linux, `.pkg` on
macOS, `.exe` on Windows) for the host platform only — there is no
cross-compilation. dui2 and then `dials-launcher` must be built first.

```bash
export DIALS_VERSION=3.30.1        # construct.yaml and meta.yaml read this; fallback 3.30.1
export DUI2_VERSION=2026.9.21      # dui2-recipe builds tag v$DUI2_VERSION
conda install -y -n base conda-build
conda install -y constructor

# Build dui2, then dials-launcher (which depends on it), into a local channel,
# then point construct.yaml at it.
ch="$PWD/local-channel"
conda build dui2-recipe -c conda-forge --output-folder "$ch"
conda build conda-recipe -c "file://$ch" -c conda-forge --output-folder "$ch"
export DIALS_LAUNCHER_CHANNEL="file://$ch" DUI2_CHANNEL="file://$ch"
constructor . --output-dir dist
```

Without those variables, construct.yaml falls back to the published
`DiamondLightSource::dials-launcher` and `ndevenish::dui2`. `license_file: LICENSE` is required
and not committed; fetch it from `https://raw.githubusercontent.com/dials/dials/v<version>/LICENSE`.

### CI

- **`.github/workflows/build-installers.yml`** — `workflow_dispatch` only, with
  `version` (DIALS) and `dui2_version` (DUI2 tag without the `v`) inputs. On each
  runner (Linux, macOS Intel, macOS arm64, Windows) it fetches the DIALS `LICENSE`,
  builds dui2 then `dials-launcher` into a local `file://` channel, sets
  `DUI2_CHANNEL` and `DIALS_LAUNCHER_CHANNEL` to it, runs `constructor`, and finally
  drafts a GitHub release tagged `v<version>`. Nothing is uploaded to anaconda.org,
  so recipe changes take effect in the very next installer build.
- **`.github/workflows/conda-package.yml`** — builds and tests `dials-launcher`
  (building dui2 first, into a separate channel that is never uploaded) on
  pushes/PRs touching `conda-recipe/` or `dui2-recipe/`. Uploads to anaconda.org only when run
  manually with a non-empty `channel` input *and* an `ANACONDA_TOKEN` secret.

## Architecture / how the pieces fit

The bundled conda environment is large, but end users should only see the DIALS
programs. The design is: install the full environment, then **expose only the DIALS
dispatchers** via forwarders in `$PREFIX/dialsbin`, plus activation scripts.

- **`construct.yaml`** — package `specs` (`dials`, `xia2`, `<dui2_channel>::dui2`,
  `<launcher_channel>::dials-launcher`), conda `channels` (conda-forge only),
  installer branding images (`dials_*.png`), default install prefix, and
  `menu_packages` (which packages may create shortcuts). dui2 and
  `dials-launcher` are channel-qualified rather than adding their channels to
  `channels`, so those channels are consulted for those packages only
  (DiamondLightSource carries packages whose names collide with conda-forge).

- **`dui2-recipe/`** — noarch python package of DUI2. The package version is the
  release tag minus its `v`. Upstream `pyproject.toml` pins PySide2;
  `patch_pyproject.py` rewrites that to PySide6, which is what conda-forge
  provides and what the package depends on.

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
  the same stack the installer ships (local channel first, then conda-forge).
- Keep `build.sh` and `bld.bat` behaviourally in sync.
- The `DIALS_VERSION` fallback (`3.30.1`) appears in `construct.yaml`,
  `conda-recipe/meta.yaml`, and the workflow defaults; update them together.
  Likewise the `DUI2_VERSION` fallback in `dui2-recipe/meta.yaml` and the
  `dui2_version` default in `build-installers.yml`.
