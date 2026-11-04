#!/usr/bin/env bash
set -euxo pipefail

# Make the upstream metadata honest about the Qt binding we actually ship.
$PYTHON "$RECIPE_DIR/patch_pyproject.py"

# Install the package without its (pip) dependencies — conda provides them,
# and we deliberately substitute pyside6 for the PySide2 pin in pyproject.toml.
$PYTHON -m pip install . --no-deps --no-build-isolation -vv

# Stage the menuinst metadata so conda/menuinst can create a Start Menu
# shortcut on Windows at install time. This is packaged as ordinary noarch
# data; menuinst ignores it on platforms whose section is absent.
mkdir -p "$PREFIX/Menu"
cp "$RECIPE_DIR/menu/dui2.json" "$PREFIX/Menu/dui2.json"
