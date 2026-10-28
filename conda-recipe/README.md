# dials-launcher

Everything the constructor installers used to do from `post.sh` / `post.bat`,
packaged so that conda owns it.

| File | Purpose |
| --- | --- |
| `dialsbin/<command>` | Forwarder for each DIALS/xia2/dxtbx/cctbx dispatcher |
| `setpaths.sh`, `setpaths.bat`, `setpaths.ps1` | Put `dialsbin` on `PATH` for the current shell |
| `dials_env.sh`, `dials_env.bat` | Open a shell with DIALS on `PATH` |
| `Menu/dials-launcher.json` | menuinst "Launch DIALS environment" entry |

## Why a package rather than a post-install script

* **Uninstall works.** The old Start menu shortcut was written outside the
  install prefix, so the uninstaller could not remove it — as the comment in
  `post.bat` acknowledged. menuinst tracks and removes its own shortcuts.
* **No stale dispatchers.** `post.*` *copied* dispatchers into `dialsbin` at
  install time. Those copies did not change when the underlying package was
  updated. Here conda owns `dialsbin` and replaces it on update.
* **Relocatable.** Nothing embeds the prefix; every file resolves its own
  location, so the install directory can be moved.
* **Not installer-only.** A plain `conda install dials-launcher` gets the same
  setup, not just users of the constructor installers.
* **Cross-platform shortcuts.** The Windows-only PowerShell/COM block is
  replaced by one JSON file that also yields a Linux `.desktop` entry.

## How `dialsbin` keeps `PATH` clean

The point of `dialsbin` is that the user's `PATH` gains *only* the DIALS
commands, never the whole bundled environment. Copies could not fully deliver
that: on Windows the programs still need `%PREFIX%\Library\bin` and friends for
DLL resolution, and DIALS/xia2 spawn each other by bare command name — Windows
`CreateProcess` searches `PATH` and only appends `.exe`, so a `subprocess` call
to `dials.integrate` must find a real dispatcher.

The forwarders resolve this by applying the full conda-activation `PATH`
**inside their own process only**:

```bat
@setlocal EnableExtensions
@set "PREFIX=%~dp0.."
@set "PATH=%PREFIX%;%PREFIX%\Library\mingw-w64\bin;...;%PREFIX%\Scripts;%PATH%"
@"%PREFIX%\Scripts\dials.import.exe" %*
```

So the interactive shell keeps just `dialsbin`, while each program runs as if
the environment were fully activated. This is stricter isolation than the old
copies achieved, and it removes the need for the commented-out
`%PREFIX%\Library\bin` escape hatch that used to sit in `post.bat`.

## Building

`make_shims.py` enumerates the dispatchers at build time, so the recipe needs
the DIALS stack in `host`:

```bash
DIALS_VERSION=3.29.0 conda build conda-recipe
```

The version pin (`dials =={{ version }}`) means this package is rebuilt for
each DIALS release, alongside the installers.

### In CI

`.github/workflows/conda-package.yml` builds the recipe on `linux-64`,
`osx-64`, `osx-arm64` and `win-64`. It runs automatically on pushes to `main`
and on pull requests that touch `conda-recipe/`, building (and running the
recipe's `test:` commands) without uploading anything.

To publish, run the workflow manually and fill in the inputs:

| Input | Meaning |
| --- | --- |
| `version` | DIALS version to build against (sets `DIALS_VERSION`) |
| `channel` | anaconda.org user or organisation to upload to; empty means build only |
| `label` | anaconda.org label, default `main` |
| `force` | Overwrite packages already present on the channel |

Uploading needs an `ANACONDA_TOKEN` repository secret holding an anaconda.org
API token with write access to that channel. All four platforms must build
before anything is uploaded.

## How construct.yaml uses it

`construct.yaml` names the package in `menu_packages` and lists it in `specs`,
qualified with the channel it is published to since it is not on conda-forge:

```yaml
channels:
  - "https://conda.anaconda.org/conda-forge/"
specs:
  - dials =={{ version }}
  - xia2
  - DiamondLightSource::dials-launcher =={{ version }}
menu_packages:
  - dials-launcher
```

Note that `DiamondLightSource` is **not** in `channels`. The `channel::`
qualifier restricts that one spec to that one channel, so the channel is never
consulted for anything else — DiamondLightSource carries packages whose names
collide with conda-forge, and adding it to `channels` would let those shadow
the conda-forge builds the installer is supposed to ship. `dials-launcher`'s
own dependencies still resolve from conda-forge like everything else.

`menu_packages` restricts shortcut creation to this package, so no menu entry
shipped by a dependency is created by accident. The `post_install:` lines that
used to run `post.sh` / `post.bat` are gone.

**The package must be published before the installers are built**, and for the
same version — the `==` pin means the solve fails otherwise. The channel is
fixed in `specs`, not settable at dispatch time.

## Known limitations

* **macOS has no menu item.** `platforms` deliberately lists only `win` and
  `linux`. A macOS `.app` that opens an interactive shell needs a Terminal.app
  wrapper rather than a bare command, so it is left out rather than shipped
  half-working. `setpaths.sh` works normally on macOS.

  `build.sh` therefore skips `Menu/` entirely on macOS. Shipping the JSON there
  would leave menuinst with metadata that has nothing enabled for the running
  platform, and it warns about that on install *and* uninstall
  (`menuinst/api.py:136`, "Metadata for DIALS is not enabled for darwin").
* **Windows shortcuts use `terminal: true`** and target `dials_env.bat`, which
  itself ends in `cmd /K` — the same shape as the old `.lnk`. Worth eyeballing
  once on a real Windows install that you get exactly one console window.
* **Shim drift.** The command list is fixed at build time. If DIALS gains an
  entry point without this package being rebuilt, the new command will not
  appear in `dialsbin`. The version pin makes that unlikely in practice.
* **`dialsbin` shims are `.bat` on Windows.** They resolve fine when typed at a
  prompt (cmd appends `PATHEXT` entries), but a `subprocess` call naming a bare
  command finds the real `.exe` in `Scripts` via the `PATH` the shim sets, not
  the shim itself. That is intended.
