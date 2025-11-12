# Test Application - Catalogador EsSalud
# Script para evaluar el funcionamiento completo de la aplicación

<#
.SYNOPSIS
    Script de pruebas automáticas para Catalogador EsSalud

.DESCRIPTION
    Ejecuta una serie de pruebas para validar:
    - Backend Python (API FastAPI)
    - Frontend WPF (aplicación de escritorio)
    - Integración entre componentes
    - Funcionalidad end-to-end

.PARAMETER SkipBackendTests
    Omite las pruebas del backend Python

.PARAMETER SkipBuild
    Omite la compilación de la aplicación WPF

.PARAMETER Verbose
    Muestra información detallada durante la ejecución

.EXAMPLE
    .\scripts\test_application.ps1
    
.EXAMPLE
    .\scripts\test_application.ps1 -SkipBuild -Verbose
#>

[CmdletBinding()]
param(
    [switch]$SkipBackendTests,
    [switch]$SkipBuild,
    [switch]$Verbose
)

# Colores para salida
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }

# Banner
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CATALOGADOR ESSALUD - TEST SUITE" -ForegroundColor Cyan
Write-Host "  Evaluación de Interfaz y Funcionalidad" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$ErrorCount = 0
$WarningCount = 0
$SuccessCount = 0

# Obtener ruta del proyecto
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $ProjectRoot

Write-Info "Directorio del proyecto: $ProjectRoot"
Write-Host ""

# ============================================================================
# FASE 1: VERIFICACIÓN DE PREREQUISITOS
# ============================================================================

Write-Info "═══ FASE 1: Verificación de Prerequisitos ═══"
Write-Host ""

# Verificar Python
Write-Info "Verificando Python..."
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python 3\.([0-9]+)") {
        $minorVersion = [int]$matches[1]
        if ($minorVersion -ge 11) {
            Write-Success "✓ Python instalado: $pythonVersion"
            $SuccessCount++
        } else {
            Write-Warning "⚠ Python $pythonVersion encontrado. Se recomienda Python 3.11+"
            $WarningCount++
        }
    }
} catch {
    Write-Error "✗ Python no encontrado o no accesible"
    $ErrorCount++
}

# Verificar .NET SDK
Write-Info "Verificando .NET SDK..."
try {
    $dotnetVersion = dotnet --version 2>&1
    if ($dotnetVersion -match "8\.") {
        Write-Success "✓ .NET SDK instalado: $dotnetVersion"
        $SuccessCount++
    } else {
        Write-Warning "⚠ .NET SDK $dotnetVersion encontrado. Se requiere .NET 8.0"
        $WarningCount++
    }
} catch {
    Write-Error "✗ .NET SDK no encontrado"
    $ErrorCount++
}

# Verificar estructura del proyecto
Write-Info "Verificando estructura del proyecto..."
$requiredDirs = @("api", "engine", "Catalogador.App", "tools", "installer")
foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Success "✓ Directorio '$dir' presente"
        $SuccessCount++
    } else {
        Write-Error "✗ Directorio '$dir' no encontrado"
        $ErrorCount++
    }
}

Write-Host ""

# ============================================================================
# FASE 2: PRUEBAS DEL BACKEND PYTHON
# ============================================================================

if (-not $SkipBackendTests) {
    Write-Info "═══ FASE 2: Pruebas del Backend Python ═══"
    Write-Host ""

    # Activar entorno virtual si existe
    $venvPath = ".venv\Scripts\Activate.ps1"
    if (Test-Path $venvPath) {
        Write-Info "Activando entorno virtual..."
        & $venvPath
    } else {
        Write-Warning "⚠ Entorno virtual no encontrado. Usando Python global."
        $WarningCount++
    }

    # Instalar dependencias de prueba si es necesario
    Write-Info "Verificando dependencias de prueba..."
    $pipList = pip list 2>&1 | Out-String
    if ($pipList -notmatch "pytest") {
        Write-Info "Instalando pytest..."
        pip install pytest pytest-asyncio httpx -q
    }

    # Ejecutar tests Python
    Write-Info "Ejecutando tests Python..."
    Write-Host ""
    
    try {
        $testResult = python -m pytest tests/ -v --tb=short 2>&1
        Write-Host $testResult
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "`n✓ Todos los tests Python pasaron correctamente"
            $SuccessCount++
        } else {
            Write-Error "`n✗ Algunos tests Python fallaron"
            $ErrorCount++
        }
    } catch {
        Write-Error "✗ Error al ejecutar tests Python: $_"
        $ErrorCount++
    }

    # Verificar que el backend puede iniciar
    Write-Info "`nVerificando inicio del backend..."
    
    $backendJob = Start-Job -ScriptBlock {
        param($ProjectRoot)
        Set-Location $ProjectRoot
        python -m uvicorn api.main:app --host 127.0.0.1 --port 8000
    } -ArgumentList $ProjectRoot
    
    Start-Sleep -Seconds 5
    
    try {
        $healthCheck = Invoke-WebRequest -Uri "http://127.0.0.1:8000/health" -UseBasicParsing -TimeoutSec 5
        if ($healthCheck.StatusCode -eq 200) {
            Write-Success "✓ Backend responde correctamente en http://127.0.0.1:8000"
            Write-Success "✓ Health endpoint: $($healthCheck.Content)"
            $SuccessCount++
        }
    } catch {
        Write-Error "✗ Backend no responde en http://127.0.0.1:8000"
        Write-Error "  Error: $_"
        $ErrorCount++
    } finally {
        Stop-Job -Job $backendJob
        Remove-Job -Job $backendJob
    }

    Write-Host ""
}

# ============================================================================
# FASE 3: COMPILACIÓN DE LA APLICACIÓN WPF
# ============================================================================

if (-not $SkipBuild) {
    Write-Info "═══ FASE 3: Compilación de la Aplicación WPF ═══"
    Write-Host ""

    Write-Info "Compilando solución..."
    try {
        $buildOutput = dotnet build Catalogador.sln -c Release 2>&1
        
        if ($Verbose) {
            Write-Host $buildOutput
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Compilación exitosa"
            $SuccessCount++
        } else {
            Write-Error "✗ Error en la compilación"
            Write-Host $buildOutput
            $ErrorCount++
        }
    } catch {
        Write-Error "✗ Error al compilar: $_"
        $ErrorCount++
    }

    # Verificar que el ejecutable existe
    $exePath = "Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe"
    if (Test-Path $exePath) {
        $exeInfo = Get-Item $exePath
        Write-Success "✓ Ejecutable generado: $exePath"
        Write-Info "  Tamaño: $([math]::Round($exeInfo.Length / 1MB, 2)) MB"
        Write-Info "  Fecha: $($exeInfo.LastWriteTime)"
        $SuccessCount++
    } else {
        Write-Error "✗ Ejecutable no encontrado en $exePath"
        $ErrorCount++
    }

    Write-Host ""
}

# ============================================================================
# FASE 4: VERIFICACIÓN DE COMPONENTES DE LA APLICACIÓN
# ============================================================================

Write-Info "═══ FASE 4: Verificación de Componentes ═══"
Write-Host ""

# Verificar archivos WPF críticos
Write-Info "Verificando archivos de la aplicación WPF..."
$wpfFiles = @(
    "Catalogador.App\App.xaml",
    "Catalogador.App\Views\MainWindow.xaml",
    "Catalogador.App\Services\ApiClient.cs",
    "Catalogador.App\Helpers\SimpleLogger.cs",
    "Catalogador.App\Models\DocumentModels.cs"
)

foreach ($file in $wpfFiles) {
    if (Test-Path $file) {
        Write-Success "✓ $file"
        $SuccessCount++
    } else {
        Write-Error "✗ $file no encontrado"
        $ErrorCount++
    }
}

# Verificar scripts de servicio
Write-Info "`nVerificando scripts de servicio Windows..."
$serviceScripts = @(
    "tools\install_windows_service.ps1",
    "tools\uninstall_service.ps1",
    "tools\start_service.ps1",
    "tools\stop_service.ps1"
)

foreach ($script in $serviceScripts) {
    if (Test-Path $script) {
        Write-Success "✓ $script"
        $SuccessCount++
    } else {
        Write-Error "✗ $script no encontrado"
        $ErrorCount++
    }
}

# Verificar configuración del instalador
Write-Info "`nVerificando configuración del instalador..."
if (Test-Path "installer\catalogador_setup.iss") {
    Write-Success "✓ InnoSetup script presente"
    $SuccessCount++
} else {
    Write-Error "✗ InnoSetup script no encontrado"
    $ErrorCount++
}

Write-Host ""

# ============================================================================
# FASE 5: VERIFICACIÓN DE DOCUMENTACIÓN
# ============================================================================

Write-Info "═══ FASE 5: Verificación de Documentación ═══"
Write-Host ""

$docFiles = @(
    "DOCS.md",
    "QUICK_START.md",
    "TESTING_GUIDE.md",
    "README.md",
    "CHANGELOG.md"
)

foreach ($doc in $docFiles) {
    if (Test-Path $doc) {
        $docSize = (Get-Item $doc).Length
        Write-Success "✓ $doc ($([math]::Round($docSize / 1KB, 1)) KB)"
        $SuccessCount++
    } else {
        Write-Warning "⚠ $doc no encontrado"
        $WarningCount++
    }
}

Write-Host ""

# ============================================================================
# RESUMEN FINAL
# ============================================================================

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESUMEN DE LA EVALUACIÓN" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Success "✓ Pruebas exitosas: $SuccessCount"
Write-Warning "⚠ Advertencias:     $WarningCount"
Write-Error "✗ Errores:          $ErrorCount"

Write-Host ""

if ($ErrorCount -eq 0 -and $WarningCount -eq 0) {
    Write-Success "═══════════════════════════════════════════════════════════"
    Write-Success "  ✓ TODAS LAS PRUEBAS PASARON CORRECTAMENTE"
    Write-Success "  La aplicación está lista para pruebas de usuario"
    Write-Success "═══════════════════════════════════════════════════════════"
} elseif ($ErrorCount -eq 0) {
    Write-Warning "═══════════════════════════════════════════════════════════"
    Write-Warning "  ⚠ PRUEBAS COMPLETADAS CON ADVERTENCIAS"
    Write-Warning "  La aplicación es funcional pero revise las advertencias"
    Write-Warning "═══════════════════════════════════════════════════════════"
} else {
    Write-Error "═══════════════════════════════════════════════════════════"
    Write-Error "  ✗ SE ENCONTRARON ERRORES"
    Write-Error "  Revise los errores antes de continuar"
    Write-Error "═══════════════════════════════════════════════════════════"
}

Write-Host ""

# ============================================================================
# SIGUIENTES PASOS
# ============================================================================

Write-Info "═══ SIGUIENTES PASOS ═══"
Write-Host ""

if ($ErrorCount -eq 0) {
    Write-Info "Para ejecutar la aplicación manualmente:"
    Write-Host "  1. Iniciar backend:"
    Write-Host "     python -m uvicorn api.main:app --reload" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  2. Ejecutar aplicación WPF:"
    Write-Host "     .\Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe" -ForegroundColor Yellow
    Write-Host ""
    Write-Info "Para instalar como servicio Windows:"
    Write-Host "  .\tools\install_windows_service.ps1" -ForegroundColor Yellow
    Write-Host ""
    Write-Info "Para construir el instalador:"
    Write-Host "  .\scripts\build_all.ps1 -BuildInstaller" -ForegroundColor Yellow
    Write-Host ""
    Write-Info "Para pruebas de interfaz detalladas, consulte:"
    Write-Host "  TESTING_GUIDE.md" -ForegroundColor Yellow
} else {
    Write-Warning "Corrija los errores encontrados antes de continuar."
    Write-Warning "Consulte la documentación en DOCS.md para más ayuda."
}

Write-Host ""

# Retornar código de salida apropiado
if ($ErrorCount -gt 0) {
    exit 1
} else {
    exit 0
}
