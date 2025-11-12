# Stop Catalogador Python API Service
# Requires: Administrator privileges (for service operations)

param(
    [string]$ServiceName = "CatalogadorAPI"
)

Write-Host "Stopping Catalogador API Service..." -ForegroundColor Cyan

# Try using NSSM first
$nssmPath = Join-Path $PSScriptRoot "nssm.exe"
if (Test-Path $nssmPath) {
    & $nssmPath stop $ServiceName
    Start-Sleep -Seconds 2
    $status = & $nssmPath status $ServiceName
    Write-Host "Service status: $status"
} else {
    # Fallback to net command
    net stop $ServiceName
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Service stopped successfully!" -ForegroundColor Green
} else {
    Write-Host "Failed to stop service" -ForegroundColor Red
}
