<#
start.ps1 - convenience entrypoint for local development & testing

Usage:
  .\start.ps1 -Mode test
  .\start.ps1 -Mode dev

What it does:
  - Shows ExecutionPolicy diagnostics
  - Detects Python/venv in common locations
  - Invokes tools\run_backend_autofix.ps1 to pick a free port and start the backend
  - Prints runtime/backend_port.txt and runtime/backend_runtime_info.json location

This script is safe and non-destructive. It will not force-stop other processes.
#>

param(
    [ValidateSet('test','dev','prod','help')]
    [string]$Mode = 'test'
)

Set-StrictMode -Version Latest

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = (Resolve-Path -Path $scriptDir).ProviderPath
Write-Host "Repo root: $repoRoot"

Write-Host "\nExecutionPolicy (effective):" (Get-ExecutionPolicy)
Write-Host "ExecutionPolicy -List:"; Get-ExecutionPolicy -List | Format-Table -AutoSize

if ($Mode -eq 'help') {
    Write-Host "\nThis script invokes tools\run_backend_autofix.ps1 which will choose a free port and start the backend."
    Write-Host "If your shell prevents script execution, run (in this session): Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process"
    exit 0
}

# runtime dir
$runtime = Join-Path $repoRoot 'runtime'
if (-not (Test-Path $runtime)) { New-Item -ItemType Directory -Path $runtime | Out-Null }

# Find python in common venv locations
$pythonCandidates = @(
    (Join-Path $repoRoot '.venv\Scripts\python.exe'),
    (Join-Path $repoRoot 'venv\Scripts\python.exe'),
    'python'
)
$pythonExe = $null
foreach ($p in $pythonCandidates) {
    if (Test-Path $p) { $pythonExe = $p; break }
}
if (-not $pythonExe) { $pythonExe = 'python' }
Write-Host "Using Python: $pythonExe"

# Ensure the run_backend_autofix launcher exists
$launcher = Join-Path $repoRoot 'tools\run_backend_autofix.ps1'
if (-not (Test-Path $launcher)) {
    Write-Error "Cannot find launcher script at: $launcher`nPlease ensure you're in the repo root and the tools folder exists."
    exit 1
}

Write-Host "Invoking launcher: $launcher (mode: $Mode)" -ForegroundColor Cyan
try {
    # Call the launcher in the current session so environment is shared
    & $launcher
    $portFile = Join-Path $runtime 'backend_port.txt'
    $infoFile = Join-Path $runtime 'backend_runtime_info.json'
    if (Test-Path $portFile) { Write-Host "Backend port file: $portFile -> $(Get-Content $portFile -Raw)" }
    if (Test-Path $infoFile) { Write-Host "Runtime info: $infoFile"; Get-Content $infoFile | Write-Host }
} catch {
    Write-Warning "Launcher execution failed: $($_.Exception.Message)"
    exit 2
}

Write-Host "Start complete. If the backend failed to bind, review runtime/port8000_owner.json via tools/identify_owner_port8000.ps1" -ForegroundColor Green
