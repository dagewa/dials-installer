"""Reconcile DUI2's upstream pyproject.toml with how we actually build it.

Upstream (https://github.com/ccp4/DUI2) hard-pins ``PySide2 > 5.15.1`` in its
``dependencies``. We ship the package against PySide6 (DUI2's Qt-binding shim
supports it), so the installed wheel metadata would otherwise advertise a Qt
binding that is not present -- breaking ``pip check`` and confusing any tool
that reads the dist metadata. Rewrite the pin to PySide6 before ``pip install``
so the recorded metadata matches reality.

Run from the source root (conda-build's $SRC_DIR / work dir) with $PYTHON.
"""

import pathlib
import re

pyproject = pathlib.Path("pyproject.toml")
text = pyproject.read_text(encoding="utf-8")

# Replace the whole PySide2 requirement token (with or without a version spec).
patched = re.sub(r"PySide2[^'\"]*", "PySide6 >= 6.5", text)

if patched != text:
    pyproject.write_text(patched, encoding="utf-8")
    print("patch_pyproject: rewrote PySide2 pin -> 'PySide6 >= 6.5'")
else:
    print("patch_pyproject: no PySide2 requirement found; nothing to do")
