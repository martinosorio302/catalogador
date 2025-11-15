# ==============================================================================
# Script: update_service.ps1
# Descripción: Actualizar servicio Catalogador-PythonAPI con código nuevo
# Requisitos: Ejecutar como Administrador
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host @"

═══════════════════════════════════════════════════════════════════════════════
   🔄 ACTUALIZANDO SERVICIO CATALOGADOR-PYTHONAPI
═══════════════════════════════════════════════════════════════════════════════

"@ -ForegroundColor Cyan

# Verificar privilegios de administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ ERROR: Este script requiere privilegios de Administrador" -ForegroundColor Red
    Write-Host "`nPara ejecutar como Administrador:" -ForegroundColor Yellow
    Write-Host "  1. Clic derecho en PowerShell" -ForegroundColor Yellow
    Write-Host "  2. Seleccionar 'Ejecutar como administrador'" -ForegroundColor Yellow
    Write-Host "  3. Ejecutar:" -ForegroundColor Yellow
    Write-Host "     cd C:\Users\USER\Desktop\Catalogador\tools" -ForegroundColor Yellow
    Write-Host "     .\update_service.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Rutas
$srcDir = "C:\Users\USER\Desktop\Catalogador"
$prodDir = "C:\ProgramData\Catalogador\python_api"
$serviceName = "Catalogador-PythonAPI"

Write-Host "[1/6] Deteniendo servicio..." -ForegroundColor Yellow
try {
    net stop $serviceName | Out-Null
    Start-Sleep -Seconds 2
    Write-Host "    ✅ Servicio detenido" -ForegroundColor Green
} catch {
    Write-Host "    ⚠️  Servicio ya estaba detenido" -ForegroundColor Yellow
}

Write-Host "[2/6] Copiando archivos api/..." -ForegroundColor Yellow
robocopy "$srcDir\api" "$prodDir\api" /E /XO /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
Write-Host "    ✅ api/ actualizado" -ForegroundColor Green

Write-Host "[3/6] Copiando archivos engine/..." -ForegroundColor Yellow
robocopy "$srcDir\engine" "$prodDir\engine" /E /XO /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
Write-Host "    ✅ engine/ actualizado" -ForegroundColor Green

Write-Host "[4/6] Verificando dependencias..." -ForegroundColor Yellow
$venvPython = "$prodDir\venv\Scripts\python.exe"

# Verificar PyMuPDF
$hasPyMuPDF = & $venvPython -c "import fitz; print('OK')" 2>$null
if ($hasPyMuPDF -ne "OK") {
    Write-Host "    📦 Instalando PyMuPDF..." -ForegroundColor Yellow
    & $venvPython -m pip install PyMuPDF==1.24.14 --quiet
}

# Verificar openpyxl
$hasOpenpyxl = & $venvPython -c "import openpyxl; print('OK')" 2>$null
if ($hasOpenpyxl -ne "OK") {
    Write-Host "    📦 Instalando openpyxl..." -ForegroundColor Yellow
    & $venvPython -m pip install openpyxl==3.1.5 --quiet
}
Write-Host "    ✅ Dependencias verificadas" -ForegroundColor Green

Write-Host "[5/6] Iniciando servicio..." -ForegroundColor Yellow
net start $serviceName | Out-Null
Start-Sleep -Seconds 3
Write-Host "    ✅ Servicio iniciado" -ForegroundColor Green

Write-Host "[6/6] Verificando endpoints..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

try {
    # Health check
    $health = Invoke-WebRequest -Uri "http://127.0.0.1:8000/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "    ✅ /health: $($health.StatusCode)" -ForegroundColor Green
    
    # TRD Info
    $trdInfo = Invoke-WebRequest -Uri "http://127.0.0.1:8000/trd-info" -UseBasicParsing -TimeoutSec 5
    Write-Host "    ✅ /trd-info: $($trdInfo.StatusCode)" -ForegroundColor Green
    
    # Docs
    $docs = Invoke-WebRequest -Uri "http://127.0.0.1:8000/docs" -UseBasicParsing -TimeoutSec 5
    Write-Host "    ✅ /docs: $($docs.StatusCode)" -ForegroundColor Green
    
} catch {
    Write-Host "    ⚠️  Error verificando endpoints: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host @"

═══════════════════════════════════════════════════════════════════════════════
   ✅ SERVICIO ACTUALIZADO CORRECTAMENTE
═══════════════════════════════════════════════════════════════════════════════

 📊 ENDPOINTS DISPONIBLES:
   • http://127.0.0.1:8000/health        - Health check
   • http://127.0.0.1:8000/trd-info      - Información TRD
   • http://127.0.0.1:8000/upload        - Upload + clasificación PDF
   • http://127.0.0.1:8000/export/inventory - Exportar Excel
   • http://127.0.0.1:8000/docs          - API Documentation

 🚀 PRÓXIMO PASO:
   Ejecutar la aplicación WPF (en terminal normal, sin Admin):
   
     cd C:\Users\USER\Desktop\Catalogador
     dotnet run --project Catalogador.App\Catalogador.App.csproj

═══════════════════════════════════════════════════════════════════════════════

"@ -ForegroundColor Cyan
