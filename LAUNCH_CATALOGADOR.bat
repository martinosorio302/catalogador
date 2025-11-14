@echo off
REM ============================================================================
REM Catalogador EsSalud - Launcher Script (Batch)
REM ============================================================================
REM Este script lanza la aplicación PowerShell launcher
REM ============================================================================

echo.
echo ========================================================
echo    Catalogador EsSalud - Lanzador de Aplicacion
echo ========================================================
echo.
echo Iniciando aplicacion...
echo.

REM Ejecutar el script PowerShell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0LAUNCH_CATALOGADOR.ps1"

if errorlevel 1 (
    echo.
    echo ERROR: No se pudo iniciar la aplicacion
    echo Por favor revisa que Python y Node.js esten instalados
    pause
    exit /b 1
)
