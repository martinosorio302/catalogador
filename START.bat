@echo off
REM ============================================================================
REM Catalogador EsSalud - Inicio Rapido
REM ============================================================================
REM Ejecuta este archivo haciendo doble clic o desde CMD: START.bat
REM ============================================================================

echo.
echo ========================================================
echo    Catalogador EsSalud - Inicio Rapido
echo ========================================================
echo.
echo Iniciando aplicacion...
echo.

REM Obtener directorio del script
cd /d "%~dp0"

REM Verificar que estamos en el directorio correcto
if not exist "LAUNCH_CATALOGADOR.bat" (
    echo ERROR: No se encuentra LAUNCH_CATALOGADOR.bat
    echo Por favor ejecuta este archivo desde el directorio del repositorio
    pause
    exit /b 1
)

REM Ejecutar el launcher principal
call LAUNCH_CATALOGADOR.bat

pause
