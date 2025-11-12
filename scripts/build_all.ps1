# Catalogador EsSalud - Build Script
# Compila la aplicación WPF en modo Release

param(
    [string]$Configuration = "Release",
    [switch]$SkipTests,
    [switch]$BuildInstaller,
    [switch]$Help
)

# Colores para output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success { Write-ColorOutput Green $args }
function Write-Error { Write-ColorOutput Red $args }
function Write-Info { Write-ColorOutput Cyan $args }
function Write-Warning { Write-ColorOutput Yellow $args }

# Mostrar ayuda
if ($Help) {
    Write-Info "
Catalogador EsSalud - Script de Compilación

USO:
    .\scripts\build_all.ps1 [-Configuration <Debug|Release>] [-SkipTests] [-BuildInstaller]

PARÁMETROS:
    -Configuration    Configuración de compilación (Debug o Release). Default: Release
    -SkipTests        Omitir ejecución de tests Python
    -BuildInstaller   Compilar instalador InnoSetup después de build
    -Help             Mostrar esta ayuda

EJEMPLOS:
    .\scripts\build_all.ps1
    .\scripts\build_all.ps1 -Configuration Debug
    .\scripts\build_all.ps1 -BuildInstaller
    .\scripts\build_all.ps1 -SkipTests -BuildInstaller

REQUISITOS:
    - .NET 8 SDK
    - Python 3.11+
    - Inno Setup 6.x (solo si se usa -BuildInstaller)
"
    exit 0
}

Write-Info "═══════════════════════════════════════════════════════════"
Write-Info "  Catalogador EsSalud - Build Script"
Write-Info "  Configuración: $Configuration"
Write-Info "═══════════════════════════════════════════════════════════"
Write-Output ""

# Verificar que estamos en el directorio raíz
if (-not (Test-Path "Catalogador.sln")) {
    Write-Error "❌ Error: No se encuentra Catalogador.sln"
    Write-Error "   Ejecuta este script desde el directorio raíz del repositorio"
    exit 1
}

# Paso 1: Verificar Python
Write-Info "🐍 Verificando Python..."
try {
    $pythonVersion = python --version 2>&1
    Write-Success "✓ Python encontrado: $pythonVersion"
} catch {
    Write-Error "❌ Python no encontrado"
    Write-Error "   Descarga Python 3.11+ de: https://www.python.org/downloads/"
    exit 1
}

# Paso 2: Verificar .NET SDK
Write-Info "🔧 Verificando .NET SDK..."
try {
    $dotnetVersion = dotnet --version 2>&1
    Write-Success "✓ .NET SDK encontrado: $dotnetVersion"
} catch {
    Write-Error "❌ .NET SDK no encontrado"
    Write-Error "   Descarga .NET 8 SDK de: https://dotnet.microsoft.com/download/dotnet/8.0"
    exit 1
}

# Paso 3: Activar virtual environment (si existe)
if (Test-Path ".venv\Scripts\Activate.ps1") {
    Write-Info "📦 Activando entorno virtual Python..."
    & .\.venv\Scripts\Activate.ps1
    Write-Success "✓ Entorno virtual activado"
} else {
    Write-Warning "⚠ No se encontró .venv, usando Python global"
}

# Paso 4: Instalar dependencias Python
Write-Info "📦 Instalando dependencias Python..."
try {
    pip install -q -r requirements.txt
    Write-Success "✓ Dependencias Python instaladas"
} catch {
    Write-Warning "⚠ Advertencia al instalar dependencias Python"
}

# Paso 5: Ejecutar tests Python (opcional)
if (-not $SkipTests) {
    Write-Info "🧪 Ejecutando tests Python..."
    try {
        $testResult = python -m pytest -v 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Tests Python: PASSED"
        } else {
            Write-Warning "⚠ Algunos tests fallaron, pero continuando..."
        }
    } catch {
        Write-Warning "⚠ No se pudieron ejecutar tests"
    }
    Write-Output ""
}

# Paso 6: Limpiar builds anteriores
Write-Info "🧹 Limpiando builds anteriores..."
if (Test-Path "Catalogador.App\bin") {
    Remove-Item -Recurse -Force "Catalogador.App\bin" -ErrorAction SilentlyContinue
}
if (Test-Path "Catalogador.App\obj") {
    Remove-Item -Recurse -Force "Catalogador.App\obj" -ErrorAction SilentlyContinue
}
Write-Success "✓ Limpieza completada"

# Paso 7: Compilar solución .NET
Write-Info "🔨 Compilando Catalogador.App ($Configuration)..."
Write-Output ""

dotnet build Catalogador.sln -c $Configuration

if ($LASTEXITCODE -eq 0) {
    Write-Output ""
    Write-Success "✓ Compilación exitosa"
    
    $exePath = "Catalogador.App\bin\$Configuration\net8.0-windows\CatalogadorEsSalud.exe"
    if (Test-Path $exePath) {
        Write-Success "✓ Ejecutable generado: $exePath"
    }
} else {
    Write-Output ""
    Write-Error "❌ Error en la compilación"
    exit 1
}

# Paso 8: Compilar instalador InnoSetup (opcional)
if ($BuildInstaller) {
    Write-Output ""
    Write-Info "📦 Compilando instalador InnoSetup..."
    
    $isccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (-not (Test-Path $isccPath)) {
        Write-Error "❌ Inno Setup no encontrado en: $isccPath"
        Write-Error "   Descarga de: https://jrsoftware.org/isdl.php"
        exit 1
    }
    
    Push-Location installer
    
    try {
        & $isccPath catalogador_setup.iss
        
        if ($LASTEXITCODE -eq 0) {
            Write-Output ""
            Write-Success "✓ Instalador compilado exitosamente"
            
            $installerPath = "output\CatalogadorEsSalud_Setup_1.0.0.exe"
            if (Test-Path $installerPath) {
                $installerSize = (Get-Item $installerPath).Length / 1MB
                Write-Success "✓ Instalador: installer\$installerPath ($([math]::Round($installerSize, 2)) MB)"
            }
        } else {
            Write-Error "❌ Error al compilar instalador"
            Pop-Location
            exit 1
        }
    } finally {
        Pop-Location
    }
}

# Resumen final
Write-Output ""
Write-Info "═══════════════════════════════════════════════════════════"
Write-Info "  Build Completado"
Write-Info "═══════════════════════════════════════════════════════════"
Write-Success "✓ Configuración: $Configuration"
Write-Success "✓ Ejecutable: Catalogador.App\bin\$Configuration\net8.0-windows\CatalogadorEsSalud.exe"

if ($BuildInstaller) {
    Write-Success "✓ Instalador: installer\output\CatalogadorEsSalud_Setup_1.0.0.exe"
}

Write-Output ""
Write-Info "PRÓXIMOS PASOS:"
Write-Output "  1. Ejecutar aplicación:"
Write-Output "     .\Catalogador.App\bin\$Configuration\net8.0-windows\CatalogadorEsSalud.exe"
Write-Output ""
Write-Output "  2. Instalar servicio backend:"
Write-Output "     .\tools\install_windows_service.ps1"

if ($BuildInstaller) {
    Write-Output ""
    Write-Output "  3. Distribuir instalador:"
    Write-Output "     .\installer\output\CatalogadorEsSalud_Setup_1.0.0.exe"
}

Write-Output ""
Write-Info "═══════════════════════════════════════════════════════════"
