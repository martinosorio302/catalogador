# ==============================================================================
# Script: run_dev_mode.ps1
# Descripción: Ejecutar backend en modo desarrollo (sin servicio Windows)
# Requisitos: NO requiere Administrador
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host @"

═══════════════════════════════════════════════════════════════════════════════
   🛠️  MODO DESARROLLO - CATALOGADOR ESSALUD
═══════════════════════════════════════════════════════════════════════════════

"@ -ForegroundColor Cyan

# Verificar que estamos en el directorio correcto
$workspaceRoot = "C:\Users\USER\Desktop\Catalogador"
if ((Get-Location).Path -ne $workspaceRoot) {
    Set-Location $workspaceRoot
    Write-Host "📂 Cambiando a: $workspaceRoot" -ForegroundColor Yellow
}

# Verificar venv
$venvPython = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Host "❌ ERROR: No se encontró el venv en .venv\" -ForegroundColor Red
    exit 1
}

# Verificar dependencias
Write-Host "[1/3] Verificando dependencias..." -ForegroundColor Yellow
$hasPyMuPDF = & $venvPython -c "import fitz; print('OK')" 2>$null
$hasOpenpyxl = & $venvPython -c "import openpyxl; print('OK')" 2>$null

if ($hasPyMuPDF -ne "OK" -or $hasOpenpyxl -ne "OK") {
    Write-Host "    📦 Instalando dependencias faltantes..." -ForegroundColor Yellow
    if ($hasPyMuPDF -ne "OK") {
        & $venvPython -m pip install PyMuPDF==1.24.14 --quiet
    }
    if ($hasOpenpyxl -ne "OK") {
        & $venvPython -m pip install openpyxl==3.1.5 --quiet
    }
}
Write-Host "    ✅ Dependencias OK" -ForegroundColor Green

# Detectar si el servicio Windows está corriendo
Write-Host "[2/3] Detectando servicio Windows..." -ForegroundColor Yellow
try {
    $serviceRunning = (Get-Service -Name "Catalogador-PythonAPI" -ErrorAction SilentlyContinue).Status -eq "Running"
} catch {
    $serviceRunning = $false
}

if ($serviceRunning) {
    Write-Host "    ⚠️  ADVERTENCIA: El servicio Catalogador-PythonAPI está corriendo" -ForegroundColor Yellow
    Write-Host "    ⚠️  Esto ocupará el puerto 8000" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Opciones:" -ForegroundColor Cyan
    Write-Host "      A) Detener el servicio (requiere Admin):" -ForegroundColor White
    Write-Host "         net stop Catalogador-PythonAPI" -ForegroundColor Gray
    Write-Host ""
    Write-Host "      B) Ejecutar en puerto alternativo (8001):" -ForegroundColor White
    Write-Host "         Presione ENTER para continuar con puerto 8001" -ForegroundColor Gray
    Write-Host ""
    $response = Read-Host "    Presione ENTER para usar puerto 8001 o CTRL+C para salir"
    $port = 8001
    $altPort = $true
} else {
    Write-Host "    ✅ Puerto 8000 disponible" -ForegroundColor Green
    $port = 8000
    $altPort = $false
}

Write-Host "[3/3] Iniciando backend en modo desarrollo..." -ForegroundColor Yellow
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   🚀 BACKEND INICIANDO EN PUERTO $port" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "   • API: http://127.0.0.1:$port" -ForegroundColor White
Write-Host "   • Docs: http://127.0.0.1:$port/docs" -ForegroundColor White
Write-Host "   • Health: http://127.0.0.1:$port/health" -ForegroundColor White
Write-Host ""

if ($altPort) {
    Write-Host "   ⚠️  IMPORTANTE: Para usar la aplicación WPF con puerto 8001:" -ForegroundColor Yellow
    Write-Host "      1. Editar: Catalogador.App\Services\ApiClient.cs" -ForegroundColor White
    Write-Host "      2. Cambiar línea 36: http://127.0.0.1:8000 → http://127.0.0.1:8001" -ForegroundColor White
    Write-Host "      3. Recompilar WPF y ejecutar" -ForegroundColor White
    Write-Host ""
}

Write-Host "   Presione CTRL+C para detener el servidor" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Ejecutar uvicorn
& $venvPython -m uvicorn api.main:app --reload --host 127.0.0.1 --port $port
