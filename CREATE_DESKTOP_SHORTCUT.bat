@echo off
REM ============================================================================
REM Crear Acceso Directo en Escritorio - Catalogador EsSalud
REM ============================================================================

echo.
echo ========================================================
echo    Crear Acceso Directo - Catalogador EsSalud
echo ========================================================
echo.

REM Obtener la ruta actual del script
set "SCRIPT_DIR=%~dp0"
set "LAUNCHER_PATH=%SCRIPT_DIR%LAUNCH_CATALOGADOR.bat"
set "ICON_PATH=%SCRIPT_DIR%build\icon.ico"

REM Crear el acceso directo usando PowerShell
echo Creando acceso directo en el escritorio...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$WshShell = New-Object -ComObject WScript.Shell; ^
$Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\Catalogador EsSalud.lnk'); ^
$Shortcut.TargetPath = '%LAUNCHER_PATH%'; ^
$Shortcut.WorkingDirectory = '%SCRIPT_DIR%'; ^
$Shortcut.Description = 'Catalogador EsSalud - Sistema de catalogacion de archivos'; ^
$Shortcut.WindowStyle = 1; ^
$Shortcut.Save()"

if %errorlevel% equ 0 (
    echo.
    echo ========================================================
    echo    Acceso directo creado exitosamente!
    echo    Ubicacion: %USERPROFILE%\Desktop\Catalogador EsSalud.lnk
    echo ========================================================
    echo.
    echo Puedes ejecutar la aplicacion haciendo doble clic en el icono del escritorio
    echo.
) else (
    echo.
    echo ERROR: No se pudo crear el acceso directo
    echo.
)

pause
