<#
Run backend selecting preferred port (8000) or fallback if occupied.

Usage:
  pwsh .\tools\run_backend_autofix.ps1

What it does:
  - Checks whether port 8000 is free. If so, starts uvicorn on 8000.
  - If 8000 is taken, searches ports 8001..8010 and picks first free.
  - Starts uvicorn using the repo's venv python executable.
  - Writes the chosen port to runtime/backend_port.txt for other tools to read.

This script is non-destructive and does not attempt to kill other processes.
#>

Set-StrictMode -Version Latest

# Minimal safe backend starter: try runtime/backend_port.txt first, otherwise scan 8000..8010
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = (Resolve-Path -Path (Join-Path $scriptDir '..')).ProviderPath
$runtimeDir = Join-Path -Path $repoRoot -ChildPath 'runtime'
if (-not (Test-Path $runtimeDir)) { New-Item -ItemType Directory -Path $runtimeDir | Out-Null }

$portFile = Join-Path $runtimeDir 'backend_port.txt'
if (Test-Path $portFile) {
    try { $candidate = (Get-Content $portFile -Raw).Trim() } catch { $candidate = $null }
} else { $candidate = $null }

if (-not $candidate) {
    $candidate = $null
    for ($p = 8000; $p -le 8010; $p++) {
        try {
            $sock = New-Object System.Net.Sockets.TcpClient
            $async = $sock.BeginConnect('127.0.0.1',$p,$null,$null)
            $wait = $async.AsyncWaitHandle.WaitOne(200)
            if ($wait -and $sock.Connected) { $sock.Close(); continue }
            $sock.Close(); $candidate = $p; break
        } catch { }
    }
}

if (-not $candidate) { Write-Error 'No available ports found 8000..8010'; exit 1 }

Write-Host "Selected backend port: $candidate" -ForegroundColor Green

# Atomically write backend_port.txt
$portFile = Join-Path $runtimeDir 'backend_port.txt'
$tmp = "$portFile.tmp"
try {
    Set-Content -Path $tmp -Value $candidate -Encoding UTF8 -NoNewline
    Move-Item -Path $tmp -Destination $portFile -Force
    Write-Host "Wrote backend port to $portFile" -ForegroundColor Green
} catch {
    Write-Warning "Failed to write backend_port.txt: $($_.Exception.Message)"
}

# Resolve python in venv: try common locations
$possible = @(
    (Join-Path $repoRoot '.venv\Scripts\python.exe'),
    (Join-Path $repoRoot 'venv\Scripts\python.exe'),
    'python'
)
$venvPython = $possible | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $venvPython) { $venvPython = 'python' }

# Ensure $NoReload exists (script may be invoked without params)
if (-not (Get-Variable -Name NoReload -Scope 0 -ErrorAction SilentlyContinue)) { $NoReload = $false }

# Build uvicorn args
if ($NoReload) { $reloadFlag = '' } else { $reloadFlag = '--reload' }
$args = "-m uvicorn api.main:app --port $candidate --host 127.0.0.1 $reloadFlag"
Write-Host "Starting backend with: $venvPython $args" -ForegroundColor Cyan

try {
    $proc = Start-Process -FilePath $venvPython -ArgumentList $args -NoNewWindow -PassThru
    Start-Sleep -Seconds 1
    if ($proc -and $proc.Id) {
        Write-Host "Started process Id: $($proc.Id)" -ForegroundColor Green
        $info = @{ pid = $proc.Id; port = $candidate; started = (Get-Date).ToString('o') }
        $info | ConvertTo-Json | Set-Content -Path (Join-Path $runtimeDir 'backend_runtime_info.json') -Encoding UTF8
    } else {
        Write-Warning "Failed to start backend process."
        exit 2
    }
} catch {
    Write-Error "Exception while starting backend: $($_.Exception.Message)"
    exit 3
}

exit 0
