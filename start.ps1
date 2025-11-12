# start.ps1
# Script de inicio para Catalogador EsSalud
# Uso: .\start.ps1 -Mode [api|frontend|electron|both]

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("api", "frontend", "electron", "both", "test")]
    [string]$Mode = "api",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 8000
)

$RepoRoot = $PSScriptRoot
$ErrorActionPreference = "Stop"

# Colores
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

# Banner
Clear-Host
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       CATALOGADOR ESSALUD - INICIO RÁPIDO            ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Verificar ubicación
Write-Info "Repositorio: $RepoRoot"
Write-Info "Modo: $Mode"
Write-Host ""

# Verificar requisitos
Write-Info "Verificando requisitos del sistema..."

# Python
try {
    $pythonVersion = python --version 2>&1
    Write-Success "Python: $pythonVersion"
} catch {
    Write-Error "Python no encontrado. Instala Python 3.10+ desde python.org"
    exit 1
}

# Node.js (solo si necesario)
if ($Mode -in @("frontend", "electron", "both")) {
    try {
        $nodeVersion = node --version 2>&1
        Write-Success "Node.js: $nodeVersion"
    } catch {
        Write-Error "Node.js no encontrado. Instala Node.js 18+ desde nodejs.org"
        exit 1
    }
}

# Verificar entorno virtual Python
if (-not (Test-Path "$RepoRoot\.venv")) {
    Write-Warning "Entorno virtual no encontrado. Creando..."
    python -m venv "$RepoRoot\.venv"
    Write-Success "Entorno virtual creado"
}

# Verificar dependencias Python
$pipList = & "$RepoRoot\.venv\Scripts\pip.exe" list 2>&1
if ($pipList -notmatch "fastapi") {
    Write-Warning "Dependencias Python no instaladas. Instalando..."
    & "$RepoRoot\.venv\Scripts\pip.exe" install -r "$RepoRoot\requirements.txt" --quiet
    Write-Success "Dependencias Python instaladas"
}

# Verificar dependencias Node (para frontend/electron)
if ($Mode -in @("frontend", "both") -and -not (Test-Path "$RepoRoot\src\node_modules")) {
    Write-Warning "Dependencias Node (src) no instaladas. Instalando..."
    Set-Location "$RepoRoot\src"
    npm install --quiet
    Write-Success "Dependencias Node (src) instaladas"
    Set-Location $RepoRoot
}

if ($Mode -eq "electron" -and -not (Test-Path "$RepoRoot\node_modules")) {
    Write-Warning "Dependencias Node (raíz) no instaladas. Instalando..."
    Set-Location $RepoRoot
    npm install --quiet
    Write-Success "Dependencias Node instaladas"
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan

# Ejecutar según modo
switch ($Mode) {
    "api" {
        Write-Host ""
        Write-Success "🚀 Iniciando API Backend en puerto $Port..."
        Write-Info "📡 Swagger UI: http://127.0.0.1:$Port/docs"
        Write-Info "🔍 Health Check: http://127.0.0.1:$Port/health"
        Write-Host ""
        Write-Warning "Presiona Ctrl+C para detener"
        Write-Host ""
        
        Set-Location $RepoRoot
        & "$RepoRoot\.venv\Scripts\python.exe" -m uvicorn api.main:app --host 127.0.0.1 --port $Port --reload
    }
    
    "frontend" {
        Write-Host ""
        Write-Success "🎨 Iniciando Frontend..."
        Write-Info "🌐 URL: http://localhost:5173"
        Write-Host ""
        Write-Warning "Presiona Ctrl+C para detener"
        Write-Host ""
        
        Set-Location "$RepoRoot\src"
        npm run dev
    }
    
    "electron" {
        Write-Host ""
        Write-Success "🖥️  Iniciando Aplicación Electron..."
        Write-Host ""
        Write-Warning "Presiona Ctrl+C para detener"
        Write-Host ""
        
        Set-Location $RepoRoot
        npm run electron:dev
    }
    
    "both" {
        Write-Host ""
        Write-Success "🚀 Iniciando Backend + Frontend..."
        Write-Host ""
        Write-Info "Se abrirán dos ventanas:"
        Write-Info "  1. Backend API en http://127.0.0.1:$Port"
        Write-Info "  2. Frontend en http://localhost:5173"
        Write-Host ""
        Write-Warning "Nota: Se requieren dos terminales separadas"
        Write-Warning "Terminal 1: .\start.ps1 -Mode api"
        Write-Warning "Terminal 2: .\start.ps1 -Mode frontend"
        Write-Host ""
    }
    
    "test" {
        Write-Host ""
        Write-Success "🧪 Ejecutando Tests..."
        Write-Host ""
        
        Set-Location $RepoRoot
        & "$RepoRoot\.venv\Scripts\python.exe" -m pytest -v
        
        Write-Host ""
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Todos los tests pasaron exitosamente"
        } else {
            Write-Error "Algunos tests fallaron"
        }
    }
}
