<#
CI / local smoke test for the backend launcher.

Behavior:
- Attempts to call existing backend /health (using tools/get_backend_port.ps1).
- If not available, starts the canonical launcher (tools/run_backend_autofix.ps1) in the background.
- Polls /health for up to $TimeoutSec seconds.
- Cleans up any processes it started (tries to stop uvicorn/python processes started under this repo).

Exit codes:
- 0: success (health OK)
- 1: failure (health did not respond in time)

This script is intended for CI smoke checks and local verification. It will attempt to stop processes it started.
#>

param(
    [int]$TimeoutSec = 30,
    [int]$PollIntervalSec = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-BaseUrl {
    $helper = Join-Path $PSScriptRoot 'get_backend_port.ps1'
    if (Test-Path $helper) {
        try { return (& $helper -BaseUrl).Trim() } catch { }
    }
    return 'http://127.0.0.1:8000'
}

function Wait-ForHealth($baseUrl, $timeoutSec, $intervalSec) {
    $end = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $end) {
        try {
            $h = Invoke-RestMethod -Uri ("$baseUrl/health") -UseBasicParsing -TimeoutSec 3
            Write-Host "/health OK -> $h" -ForegroundColor Green
            return $true
        } catch {
            Start-Sleep -Seconds $intervalSec
        }
    }
    return $false
}

# Main
$base = Get-BaseUrl
Write-Host "CI smoke: probing backend base URL: $base"

$startedLauncher = $false
$launcherProc = $null
try {
    # Quick check
    if (Wait-ForHealth $base 2 1) {
        Write-Host 'Backend already healthy; smoke test passed.' -ForegroundColor Green
        exit 0
    }

    Write-Host 'Backend not responding; starting canonical launcher...' -ForegroundColor Yellow
    $launcher = Join-Path $PSScriptRoot 'run_backend_autofix.ps1'
    if (-not (Test-Path $launcher)) { Write-Error "Launcher not found: $launcher"; exit 1 }

    $startArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $launcher)
    $launcherProc = Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList $startArgs -PassThru
    $startedLauncher = $true

    # Wait a bit and poll /health for the desired timeout
    $ok = Wait-ForHealth $base $TimeoutSec $PollIntervalSec
    if (-not $ok) {
        Write-Error "Smoke test failed: /health did not respond within $TimeoutSec seconds"
        exit 1
    }
    Write-Host 'Smoke test succeeded: backend healthy.' -ForegroundColor Green
    exit 0
} finally {
    if ($startedLauncher -and $launcherProc) {
        Write-Host 'Cleaning up launcher process and any uvicorn/python children...' -ForegroundColor Cyan
        try {
            # Attempt to stop any uvicorn/python processes that mention api.main or uvicorn
            $procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match 'uvicorn' -or $_.CommandLine -match 'api.main') }
            foreach ($p in $procs) {
                try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
            }
            # Also stop the launcher process itself
            try { Stop-Process -Id $launcherProc.Id -Force -ErrorAction SilentlyContinue } catch {}
        } catch {
            Write-Warning "Cleanup encountered errors: $($_.Exception.Message)"
        }
    }
}
