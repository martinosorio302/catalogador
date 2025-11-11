# Start Catalogador Python API Service
# Requires: Administrator privileges (for service operations)

param(
    [string]$ServiceName = "CatalogadorAPI"
)

Write-Host "Starting Catalogador API Service..." -ForegroundColor Cyan

# Try using NSSM first
$nssmPath = Join-Path $PSScriptRoot "nssm.exe"
if (Test-Path $nssmPath) {
    & $nssmPath start $ServiceName
    Start-Sleep -Seconds 2
    $status = & $nssmPath status $ServiceName
    Write-Host "Service status: $status"
} else {
    # Fallback to net command
    net start $ServiceName
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Service started successfully!" -ForegroundColor Green
} else {
    Write-Host "Failed to start service" -ForegroundColor Red
}
