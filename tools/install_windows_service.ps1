# Install Catalogador Python API as Windows Service
# Requires: Administrator privileges, NSSM installed

param(
    [string]$PythonPath = "C:\Python312\python.exe",
    [string]$InstallPath = "$PSScriptRoot\..",
    [string]$ServiceName = "CatalogadorAPI",
    [int]$Port = 0
)

# If tools/get_backend_port.ps1 exists, prefer its value for the default port
$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'get_backend_port.ps1'
if (Test-Path $helper) {
    try { $helperPort = [int](& $helper); if ($helperPort) { $Port = $helperPort } } catch {}
}
if (-not $Port -or $Port -eq 0) { $Port = 8000 }

Write-Host "======================================"
Write-Host "Catalogador API - Service Installation"
Write-Host "======================================"
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

# Check if NSSM exists
$nssmPath = Join-Path $PSScriptRoot "nssm.exe"
if (-not (Test-Path $nssmPath)) {
    Write-Host "ERROR: nssm.exe not found in tools directory" -ForegroundColor Red
    Write-Host "Please download NSSM from https://nssm.cc/download" -ForegroundColor Yellow
    exit 1
}

# Check if Python exists
if (-not (Test-Path $PythonPath)) {
    Write-Host "ERROR: Python not found at $PythonPath" -ForegroundColor Red
    Write-Host "Please install Python 3.11+ or specify correct path with -PythonPath" -ForegroundColor Yellow
    exit 1
}

# Resolve absolute paths
$InstallPath = Resolve-Path $InstallPath
$ApiPath = Join-Path $InstallPath "api"

# Check if API directory exists
if (-not (Test-Path $ApiPath)) {
    Write-Host "ERROR: API directory not found at $ApiPath" -ForegroundColor Red
    exit 1
}

Write-Host "Configuration:"
Write-Host "  Python:       $PythonPath"
Write-Host "  Install Path: $InstallPath"
Write-Host "  API Path:     $ApiPath"
Write-Host "  Service Name: $ServiceName"
Write-Host "  Port:         $Port"
Write-Host ""

# Install Python dependencies
Write-Host "Installing Python dependencies..." -ForegroundColor Cyan
& $PythonPath -m pip install --upgrade pip
& $PythonPath -m pip install -r (Join-Path $InstallPath "requirements.txt")
& $PythonPath -m pip install -e $InstallPath

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install Python dependencies" -ForegroundColor Red
    exit 1
}

# Create service
Write-Host ""
Write-Host "Creating Windows service..." -ForegroundColor Cyan

# Remove existing service if it exists
& $nssmPath stop $ServiceName 2>$null
& $nssmPath remove $ServiceName confirm 2>$null

# Install new service
$uvicornArgs = "-m uvicorn api.main:app --host 127.0.0.1 --port $Port"
& $nssmPath install $ServiceName $PythonPath $uvicornArgs

# Configure service
& $nssmPath set $ServiceName AppDirectory $InstallPath
& $nssmPath set $ServiceName DisplayName "Catalogador EsSalud API"
& $nssmPath set $ServiceName Description "FastAPI backend service for Catalogador EsSalud document management system"
& $nssmPath set $ServiceName Start SERVICE_AUTO_START

# Configure logging
$logDir = Join-Path $InstallPath "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
& $nssmPath set $ServiceName AppStdout (Join-Path $logDir "service_stdout.log")
& $nssmPath set $ServiceName AppStderr (Join-Path $logDir "service_stderr.log")

# Configure restart on failure
& $nssmPath set $ServiceName AppExit Default Restart
& $nssmPath set $ServiceName AppRestartDelay 5000

Write-Host ""
Write-Host "Service installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "To start the service, run:" -ForegroundColor Yellow
Write-Host "  nssm start $ServiceName" -ForegroundColor White
Write-Host "  or"
Write-Host "  net start $ServiceName" -ForegroundColor White
Write-Host ""
Write-Host "To check service status:" -ForegroundColor Yellow
Write-Host "  nssm status $ServiceName" -ForegroundColor White
Write-Host "  or"
Write-Host "  sc query $ServiceName" -ForegroundColor White
Write-Host ""
Write-Host "Service logs location:" -ForegroundColor Yellow
Write-Host "  $logDir" -ForegroundColor White
Write-Host ""

# Start service
$startService = Read-Host "Start service now? (Y/N)"
if ($startService -eq "Y" -or $startService -eq "y") {
    Write-Host "Starting service..." -ForegroundColor Cyan
    & $nssmPath start $ServiceName
    Start-Sleep -Seconds 3
    
    # Check if service is running
    $status = & $nssmPath status $ServiceName
    if ($status -like "*SERVICE_RUNNING*") {
        Write-Host "Service started successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "API should be accessible at: http://127.0.0.1:$Port" -ForegroundColor Green
        Write-Host "Health check: http://127.0.0.1:$Port/health" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Service may not have started correctly" -ForegroundColor Yellow
        Write-Host "Status: $status" -ForegroundColor Yellow
        Write-Host "Check logs at: $logDir" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "======================================"
Write-Host "Installation Complete"
Write-Host "======================================"
