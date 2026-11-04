@echo off
setlocal EnableExtensions

@rem Make the upstream metadata honest about the Qt binding we actually ship.
"%PYTHON%" "%RECIPE_DIR%\patch_pyproject.py" || exit /b 1

@rem Install without pip dependencies: conda provides them, with pyside6 in
@rem place of the PySide2 that pyproject.toml asks for.
"%PYTHON%" -m pip install . --no-deps --no-build-isolation -vv || exit /b 1

@rem Stage menuinst metadata for the Windows Start Menu shortcut.
if not exist "%PREFIX%\Menu" mkdir "%PREFIX%\Menu" || exit /b 1
copy /y "%RECIPE_DIR%\menu\dui2.json" "%PREFIX%\Menu\dui2.json" || exit /b 1
