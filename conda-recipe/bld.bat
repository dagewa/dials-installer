@echo off
setlocal EnableExtensions

@rem Forwarders for every DIALS/xia2/dui2/dxtbx/cctbx dispatcher found in %PREFIX%\Scripts.
"%PYTHON%" "%RECIPE_DIR%\make_shims.py" --prefix "%PREFIX%" --platform win || exit /b 1

copy /y "%RECIPE_DIR%\src\setpaths.bat"  "%PREFIX%\setpaths.bat"  || exit /b 1
copy /y "%RECIPE_DIR%\src\setpaths.ps1"  "%PREFIX%\setpaths.ps1"  || exit /b 1
copy /y "%RECIPE_DIR%\src\dials_env.bat" "%PREFIX%\dials_env.bat" || exit /b 1

@rem menuinst picks up Menu\*.json when the package is installed; constructor
@rem selects it by package name via `menu_packages`.
if not exist "%PREFIX%\Menu" mkdir "%PREFIX%\Menu" || exit /b 1
copy /y "%RECIPE_DIR%\src\menu\dials-launcher.json" "%PREFIX%\Menu\" || exit /b 1
copy /y "%RECIPE_DIR%\src\menu\dials.ico"           "%PREFIX%\Menu\" || exit /b 1
