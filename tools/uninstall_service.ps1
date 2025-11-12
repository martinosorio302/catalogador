# Uninstall Catalogador Python API Windows Service
# Requires: Administrator privileges

param(
    [string]$ServiceName = "CatalogadorAPI"
)

Write-Host "========================================"
Write-Host "Catalogador API - Service Uninstallation"
Write-Host "========================================"
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
    exit 1
}

Write-Host "Service Name: $ServiceName"
Write-Host ""

# Check if service exists
$serviceExists = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (-not $serviceExists) {
    Write-Host "Service '$ServiceName' not found" -ForegroundColor Yellow
    Write-Host "Nothing to uninstall" -ForegroundColor Yellow
    exit 0
}

# Confirm uninstallation
$confirm = Read-Host "Are you sure you want to uninstall the service? (Y/N)"
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host "Uninstallation cancelled" -ForegroundColor Yellow
    exit 0
}

# Stop service if running
Write-Host "Stopping service..." -ForegroundColor Cyan
& $nssmPath stop $ServiceName
Start-Sleep -Seconds 2

# Remove service
Write-Host "Removing service..." -ForegroundColor Cyan
& $nssmPath remove $ServiceName confirm

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Service uninstalled successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Log files and application data have been preserved." -ForegroundColor Yellow
    Write-Host "To remove them manually, delete the logs directory." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "ERROR: Failed to uninstall service" -ForegroundColor Red
    Write-Host "You may need to remove it manually using:" -ForegroundColor Yellow
    Write-Host "  sc delete $ServiceName" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================"
Write-Host "Uninstallation Complete"
Write-Host "========================================"
