# ============================================================================
# Catalogador EsSalud - Launcher Script (PowerShell)
# ============================================================================
# Este script lanza la aplicación completa desde el repositorio Git
# Ejecuta el backend API y el frontend UI automáticamente
# ============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   📁 Catalogador EsSalud - Lanzador de Aplicación        ║" -ForegroundColor Cyan
Write-Host "║   Iniciando backend API y frontend UI...                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Obtener la ruta del repositorio
$REPO_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $REPO_ROOT

# Verificar que Python está instalado
Write-Host "🔍 Verificando Python..." -ForegroundColor Yellow
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $pythonCmd) {
    Write-Host "❌ ERROR: Python no está instalado o no está en el PATH" -ForegroundColor Red
    Write-Host "   Por favor instala Python 3.10+ desde https://www.python.org" -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}
$pythonExe = $pythonCmd.Source
Write-Host "   ✓ Python encontrado: $pythonExe" -ForegroundColor Green

# Verificar que Node.js está instalado
Write-Host "🔍 Verificando Node.js..." -ForegroundColor Yellow
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Host "❌ ERROR: Node.js no está instalado o no está en el PATH" -ForegroundColor Red
    Write-Host "   Por favor instala Node.js 18+ desde https://nodejs.org" -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}
Write-Host "   ✓ Node.js encontrado: $($nodeCmd.Version)" -ForegroundColor Green

# Verificar/instalar dependencias Python
Write-Host "📦 Verificando dependencias Python..." -ForegroundColor Yellow
if (-not (Test-Path ".venv")) {
    Write-Host "   Creando entorno virtual Python..." -ForegroundColor Cyan
    & $pythonExe -m venv .venv
}

$venvPython = Join-Path $REPO_ROOT ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    $venvPython = $pythonExe
}

Write-Host "   Instalando dependencias Python..." -ForegroundColor Cyan
& $venvPython -m pip install -q --upgrade pip
& $venvPython -m pip install -q -r requirements.txt
& $venvPython -m pip install -q -e .
Write-Host "   ✓ Dependencias Python instaladas" -ForegroundColor Green

# Verificar/instalar dependencias Node.js
Write-Host "📦 Verificando dependencias Node.js..." -ForegroundColor Yellow
Set-Location (Join-Path $REPO_ROOT "src")
if (-not (Test-Path "node_modules")) {
    Write-Host "   Instalando dependencias Node.js..." -ForegroundColor Cyan
    npm install --silent
    Write-Host "   ✓ Dependencias Node.js instaladas" -ForegroundColor Green
} else {
    Write-Host "   ✓ Dependencias Node.js ya instaladas" -ForegroundColor Green
}
Set-Location $REPO_ROOT

# Función para limpiar procesos al salir
function Cleanup {
    Write-Host "`n🛑 Deteniendo servicios..." -ForegroundColor Yellow
    if ($apiJob) { Stop-Job -Job $apiJob -ErrorAction SilentlyContinue; Remove-Job -Job $apiJob -ErrorAction SilentlyContinue }
    if ($uiJob) { Stop-Job -Job $uiJob -ErrorAction SilentlyContinue; Remove-Job -Job $uiJob -ErrorAction SilentlyContinue }
    Write-Host "   ✓ Servicios detenidos" -ForegroundColor Green
}

# Registrar cleanup al salir
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Cleanup } | Out-Null

# Iniciar API backend en background
Write-Host "🚀 Iniciando API backend en http://127.0.0.1:8000 ..." -ForegroundColor Yellow
$apiJob = Start-Job -ScriptBlock {
    param($root, $python)
    Set-Location $root
    & $python -m uvicorn api.main:app --host 127.0.0.1 --port 8000 --reload
} -ArgumentList $REPO_ROOT, $venvPython

Start-Sleep -Seconds 3
Write-Host "   ✓ API backend iniciado" -ForegroundColor Green

# Iniciar UI frontend en background
Write-Host "🚀 Iniciando UI frontend en http://localhost:5173 ..." -ForegroundColor Yellow
$uiJob = Start-Job -ScriptBlock {
    param($root)
    Set-Location (Join-Path $root "src")
    npm run dev
} -ArgumentList $REPO_ROOT

Start-Sleep -Seconds 5
Write-Host "   ✓ UI frontend iniciado" -ForegroundColor Green

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ Catalogador EsSalud está ejecutándose!              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📍 API Backend:  http://127.0.0.1:8000" -ForegroundColor Cyan
Write-Host "📍 UI Frontend:  http://localhost:5173" -ForegroundColor Cyan
Write-Host "📖 API Docs:     http://127.0.0.1:8000/docs" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  Para detener la aplicación, presiona Ctrl+C" -ForegroundColor Yellow
Write-Host ""

# Abrir navegador
Write-Host "🌐 Abriendo navegador..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
Start-Process "http://localhost:5173"

# Mantener el script corriendo y mostrar logs
Write-Host "📋 Mostrando logs (presiona Ctrl+C para salir):" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

try {
    while ($true) {
        # Mostrar logs de los jobs
        $apiOutput = Receive-Job -Job $apiJob -ErrorAction SilentlyContinue
        $uiOutput = Receive-Job -Job $uiJob -ErrorAction SilentlyContinue
        
        if ($apiOutput) {
            $apiOutput | ForEach-Object { Write-Host "[API] $_" -ForegroundColor Blue }
        }
        if ($uiOutput) {
            $uiOutput | ForEach-Object { Write-Host "[UI]  $_" -ForegroundColor Magenta }
        }
        
        # Verificar si los jobs siguen corriendo
        if ($apiJob.State -ne "Running" -and $uiJob.State -ne "Running") {
            Write-Host "⚠️  Los servicios se han detenido" -ForegroundColor Red
            break
        }
        
        Start-Sleep -Milliseconds 500
    }
} finally {
    Cleanup
}

Write-Host ""
Write-Host "👋 Catalogador EsSalud cerrado. ¡Hasta pronto!" -ForegroundColor Cyan
