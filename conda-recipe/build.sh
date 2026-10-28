#!/bin/bash
set -euo pipefail

# Forwarders for every DIALS/xia2/dxtbx/cctbx dispatcher found in $PREFIX/bin.
"${PYTHON}" "${RECIPE_DIR}/make_shims.py" --prefix "${PREFIX}" --platform unix

install -m 644 "${RECIPE_DIR}/src/setpaths.sh"  "${PREFIX}/setpaths.sh"
install -m 755 "${RECIPE_DIR}/src/dials_env.sh" "${PREFIX}/dials_env.sh"

# menuinst picks up Menu/*.json when the package is installed; constructor
# selects it by package name via `menu_packages`.
#
# Linux only: the entry declares no `osx` platform (a macOS .app that opens an
# interactive shell needs a Terminal.app wrapper), and menuinst warns on every
# install *and* uninstall when it finds metadata with nothing enabled for the
# running platform -- "Metadata for DIALS is not enabled for darwin". Shipping
# the file on macOS buys nothing but that warning.
if [[ "${target_platform}" == linux-* ]]; then
    mkdir -p "${PREFIX}/Menu"
    install -m 644 "${RECIPE_DIR}/src/menu/dials-launcher.json" "${PREFIX}/Menu/dials-launcher.json"
    install -m 644 "${RECIPE_DIR}/src/menu/dials.png"           "${PREFIX}/Menu/dials.png"
fi
