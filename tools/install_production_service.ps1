<#
Install or update Catalogador as a production Windows service using NSSM.

This script is idempotent and safe by default. It requires Administrator rights to install
or configure services. It will not forcibly stop unrelated system processes unless you
explicitly pass -Force.

Usage (Admin):
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\install_production_service.ps1 -Port 8000

Parameters:
  -ServiceName (string)  : name for the NSSM service (default: Catalogador-PythonAPI)
  -PythonExe  (string)   : python executable to run (prefer venv path)
  -InstallPath (string)  : repo or install folder containing `api` (defaults to script parent)
  -Port (int)            : production port to bind (default: 8000)
  -VenvPath (string)     : optional venv path to prefer
  -LogDir (string)       : where to write service logs (default: %ProgramData%\Catalogador\logs)
  -NssmUrl (string)      : URL to download NSSM if missing
  -Force (switch)        : allow stopping processes that are occupying the port (admin only)
  -WhatIf (switch)       : don't perform destructive actions, show plan only

# Notes:
# - This uses NSSM which must be available as nssm.exe on PATH or placed under %ProgramData%\nssm\nssm.exe.
# - If the chosen port is occupied, the script will produce diagnostics and exit unless -Force is given.
#>

param(
    [string]$ServiceName = 'Catalogador-PythonAPI',
    [string]$PythonExe = '',
    [string]$InstallPath = '',
    [int]$Port = 8000,
    [string]$VenvPath = '',
    [string]$LogDir = '',
    [string]$NssmUrl = 'https://nssm.cc/release/nssm-2.24.zip',
    [switch]$Force,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Is-Admin { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }

# Auto-elevate when necessary (unless running in WhatIf)
if (-not $WhatIf -and -not (Is-Admin)) {
    Write-Host 'Requires Administrator privileges. Relaunching elevated...' -ForegroundColor Yellow
    $arg = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath) + $MyInvocation.UnboundArguments
    Start-Process -FilePath (Get-Command powershell).Source -ArgumentList $arg -Verb RunAs
    exit 0
}

# Resolve paths
if (-not $InstallPath) { $InstallPath = Resolve-Path -Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..') | Select-Object -ExpandProperty Path }
if (-not $LogDir) { $LogDir = Join-Path $env:ProgramData 'Catalogador\logs' }
if ($VenvPath -and -not $PythonExe) { $candidate = Join-Path $VenvPath 'Scripts\python.exe'; if (Test-Path $candidate) { $PythonExe = $candidate } }
if (-not $PythonExe) {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { $PythonExe = $cmd.Source } else { Write-Error 'No python executable found; supply -PythonExe or -VenvPath'; exit 2 }
}

# Check if port is free
Write-Host "Checking port $Port availability..."
$net = netstat -aon | Select-String ":$Port\b"
if ($net) {
    Write-Warning "Port $Port appears to be in use. Gathering diagnostics..."
    # If port is 8000 and helper exists, call identify_owner_port8000.ps1 else produce simple netstat/tasklist output
    $runtimeDir = Join-Path $InstallPath 'runtime'
    if (-not (Test-Path $runtimeDir)) { New-Item -ItemType Directory -Path $runtimeDir | Out-Null }
    $diag = @{ port = $Port; netstat = ($net -join "`n") }
    try {
        $task = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%python%' OR Name='python.exe'" -ErrorAction SilentlyContinue | Select-Object ProcessId,CommandLine
        $diag.processes = $task | ForEach-Object { @{ pid = $_.ProcessId; cmd = $_.CommandLine } }
    } catch {}
    $outFile = Join-Path $runtimeDir ("port{0}_owner.json" -f $Port)
    $diag | ConvertTo-Json -Depth 4 | Out-File -FilePath $outFile -Encoding UTF8
    Write-Host "Wrote diagnostics to: $outFile"
    if (-not $Force) { Write-Error "Port $Port is occupied. Rerun with -Force to attempt to stop the owner (Admin required)."; exit 3 }
    Write-Host 'Force requested: attempting to stop processes that claim the port (Admin) ...' -ForegroundColor Yellow
    # attempt to stop python processes that include port or api.main
    $ownerProcs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match "\:$Port" -or $_.CommandLine -match 'uvicorn' -or $_.CommandLine -match 'api.main') }
    foreach ($p in $ownerProcs) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; Write-Host "Stopped PID $($p.ProcessId)" } catch { Write-Warning "Failed to stop $($p.ProcessId)" } }
    Start-Sleep -Seconds 2
}

# Ensure NSSM exists
$nssmExe = 'nssm'
try { Get-Command $nssmExe -ErrorAction Stop | Out-Null } catch {
    $nssmDir = Join-Path $env:ProgramData 'nssm'
    $nssmExe = Join-Path $nssmDir 'nssm.exe'
    if (-not (Test-Path $nssmExe)) {
        if ($WhatIf) { Write-Host "Would download NSSM to $nssmDir from $NssmUrl"; } else {
            Write-Host "Downloading NSSM to $nssmDir" -ForegroundColor Cyan
            $zip = Join-Path $env:TEMP 'nssm.zip'
            Invoke-WebRequest -Uri $NssmUrl -OutFile $zip -UseBasicParsing
            Expand-Archive -Path $zip -DestinationPath $nssmDir -Force
            Remove-Item $zip -Force
            # locate nssm.exe
            $cand = Get-ChildItem -Path $nssmDir -Recurse -Filter 'nssm.exe' | Where-Object { $_.FullName -match 'win64' } | Select-Object -First 1
            if (-not $cand) { $cand = Get-ChildItem -Path $nssmDir -Recurse -Filter 'nssm.exe' | Select-Object -First 1 }
            if ($cand) { Copy-Item -Path $cand.FullName -Destination $nssmExe -Force }
        }
    }
}

if ($WhatIf) { Write-Host "WhatIf: would install NSSM service $ServiceName to run: $PythonExe -m uvicorn api.main:app --host 127.0.0.1 --port $Port"; exit 0 }

# Prepare log dir
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

# Build app parameters
$appParams = "-m uvicorn api.main:app --host 127.0.0.1 --port $Port --log-level info"

Write-Host "Installing/updating NSSM service: $ServiceName" -ForegroundColor Cyan
& $nssmExe install $ServiceName $PythonExe $appParams
& $nssmExe set $ServiceName AppDirectory $InstallPath
& $nssmExe set $ServiceName AppStdout (Join-Path $LogDir 'service_stdout.log')
& $nssmExe set $ServiceName AppStderr (Join-Path $LogDir 'service_stderr.log')
& $nssmExe set $ServiceName AppExit Default Restart
& $nssmExe set $ServiceName Start SERVICE_AUTO_START

# Set environment variables for service
& $nssmExe set $ServiceName AppEnvironmentExtra "PYTHONUNBUFFERED=1"
& $nssmExe set $ServiceName AppEnvironmentExtra "PYTHONUTF8=1"
& $nssmExe set $ServiceName AppEnvironmentExtra "UVICORN_HOST=127.0.0.1"
& $nssmExe set $ServiceName AppEnvironmentExtra "UVICORN_PORT=$Port"
& $nssmExe set $ServiceName AppEnvironmentExtra "CATALOGADOR_REPO=$InstallPath"
if ($VenvPath) { & $nssmExe set $ServiceName AppEnvironmentExtra "CATALOGADOR_VENV=$VenvPath" }
& $nssmExe set $ServiceName AppEnvironmentExtra "DATA_DIR=$InstallPath\data"

# Atomically write runtime/backend_port.txt
$runtimeDir = Join-Path $InstallPath 'runtime'
if (-not (Test-Path $runtimeDir)) { New-Item -ItemType Directory -Path $runtimeDir | Out-Null }
$tmp = Join-Path $runtimeDir ('backend_port.txt.tmp.' + ([System.Guid]::NewGuid().ToString()))
[System.IO.File]::WriteAllText($tmp, [string]$Port)
Move-Item -Path $tmp -Destination (Join-Path $runtimeDir 'backend_port.txt') -Force
Write-Host "Wrote runtime/backend_port.txt -> $Port"

# Start service
Write-Host "Starting service $ServiceName" -ForegroundColor Cyan
& $nssmExe start $ServiceName

# Poll /health
Write-Host 'Polling /health to confirm service readiness (10s timeout)...'
$base = "http://127.0.0.1:$Port"
$ok = $false
for ($i=0; $i -lt 10; $i++) {
    try { $r = Invoke-RestMethod -Uri "$base/health" -TimeoutSec 2 -ErrorAction Stop; Write-Host "/health -> $($r)" -ForegroundColor Green; $ok = $true; break } catch { Start-Sleep -Seconds 1 }
}
if (-not $ok) { Write-Warning 'Service did not respond on /health immediately. Check logs.' }

Write-Host 'Install script completed.' -ForegroundColor Green
