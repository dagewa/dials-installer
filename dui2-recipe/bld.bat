@echo on

:: Make the upstream metadata honest about the Qt binding we actually ship.
%PYTHON% "%RECIPE_DIR%\patch_pyproject.py"
if errorlevel 1 exit 1

:: Install without pip deps — conda provides them (pyside6 in place of PySide2).
%PYTHON% -m pip install . --no-deps --no-build-isolation -vv
if errorlevel 1 exit 1

:: Stage menuinst metadata for the Windows Start Menu shortcut.
if not exist "%PREFIX%\Menu" mkdir "%PREFIX%\Menu"
copy /y "%RECIPE_DIR%\menu\dui2.json" "%PREFIX%\Menu\dui2.json"
if errorlevel 1 exit 1
