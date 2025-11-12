@echo off
REM Catalogador EsSalud - Build Script Wrapper
REM Ejecuta el script PowerShell de compilación

echo.
echo ================================================================
echo   Catalogador EsSalud - Compilador Automatico
echo ================================================================
echo.

REM Verificar si PowerShell está disponible (pwsh 7+ o powershell 5.x)
where pwsh >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set PWSH_CMD=pwsh
) else (
    where powershell >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        set PWSH_CMD=powershell
    ) else (
        echo ERROR: PowerShell no encontrado
        echo Por favor instala PowerShell 7+ o Windows PowerShell 5.x
        echo.
        pause
        exit /b 1
    )
)

REM Ejecutar script PowerShell
%PWSH_CMD% -ExecutionPolicy Bypass -File "%~dp0scripts\build_all.ps1" %*

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
