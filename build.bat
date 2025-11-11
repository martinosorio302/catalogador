@echo off
REM Catalogador EsSalud - Build Script Wrapper
REM Ejecuta el script PowerShell de compilación

echo.
echo ================================================================
echo   Catalogador EsSalud - Compilador Automatico
echo ================================================================
echo.

REM Verificar si PowerShell está disponible
where powershell >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: PowerShell no encontrado
    echo.
    pause
    exit /b 1
)

REM Ejecutar script PowerShell
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\build_all.ps1" %*

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ================================================================
    echo   Build completado exitosamente
    echo ================================================================
    echo.
) else (
    echo.
    echo ================================================================
    echo   Build fallido - Ver errores arriba
    echo ================================================================
    echo.
)

pause
