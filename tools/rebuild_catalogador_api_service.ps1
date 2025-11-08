<#
Rebuild Catalogador API service (API-only copy)
Run this file from an elevated PowerShell (Run as Administrator).
Set $MODE to 'A' (full repo copy) or 'B' (API-only copy from Desktop repo) before running.

This script performs:
 - Stop/remove existing NSSM service and sc delete
 - Kill python processes that reference ProgramData\Catalogador
 - Take ownership (via cmd) and fix ACLs if needed
 - Robocopy the source to ProgramData (API-only or full repo)
 - Create venv, install requirements in that venv
 - Install package editable (if desired) and validate import
 - Create NSSM service pointing to api.main:app and start it
 - Poll /health and print logs on failure

Notes:
 - nssm.exe must be on PATH; if not, set $NSSM to the full path to nssm.exe
 - If the service is marked for deletion, reboot and re-run this script
 - This script avoids PowerShell heredoc for Python and uses a -c import instead
#>

param(
    [ValidateSet('A','B')]
    [string]$MODE = 'B', # A = copy whole repo from Desktop\Catalogador, B = copy only api folder
    [switch]$WhatIf
)

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Open PowerShell with 'Run as Administrator'."
    exit 1
}

$SERVICE = "Catalogador-PythonAPI"
$ROOT = "C:\ProgramData\Catalogador\python_api"
$DST = $ROOT
$LOGDIR = Join-Path $ROOT 'logs'
$NSSM = 'nssm' # or full path to nssm.exe

# Choose source based on mode
if ($MODE -eq 'A') {
    $SRC = "C:\Users\$env:USERNAME\Desktop\Catalogador"
} else {
    $SRC = "C:\Users\$env:USERNAME\Desktop\Catalogador"
}

Write-Host "Running rebuild (MODE=$MODE). Source: $SRC -> Dest: $DST" -ForegroundColor Cyan

function Run-Cmd { param($s) Write-Host "[cmd] $s"; cmd /c $s }

# 1) Stop/remove existing service
Write-Host "Stopping/removing existing service (if any)..." -ForegroundColor Yellow
try { & $NSSM stop $SERVICE 2>$null } catch {}
try { & $NSSM remove $SERVICE confirm 2>$null } catch {}
try { sc.exe stop $SERVICE 2>$null } catch {}
try { sc.exe delete $SERVICE 2>$null } catch {}
Start-Sleep -Seconds 2

# 2) Kill any python processes referencing the folder to avoid file locks
Write-Host "Killing python processes referencing ProgramData\Catalogador (if any)" -ForegroundColor Yellow
Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine -like '*ProgramData\\Catalogador*' } |
  ForEach-Object {
    try {
      Write-Host "Killing PID $($_.ProcessId): $($_.CommandLine)"
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    } catch {}
  }

# 3) Ensure destination exists and fix permissions if needed
Write-Host "Ensuring destination exists and fixing permissions if needed..." -ForegroundColor Yellow
if (-not (Test-Path $DST)) { New-Item -ItemType Directory -Path $DST | Out-Null }
# Use takeown/icacls via cmd to avoid PS parsing issues
Run-Cmd "takeown /F \"$DST\" /R /D Y"
Run-Cmd "icacls \"$DST\" /grant Administrators:F /T"
Run-Cmd "icacls \"$DST\" /grant \"$env:USERDOMAIN\$env:USERNAME\":F /T"

# 4) Copy source -> dest. If MODE B, copy only the api folder; if A, mirror whole repo
Write-Host "Copying files (robocopy)..." -ForegroundColor Yellow
if ($MODE -eq 'B') {
    # copy only api folder
    $srcApi = Join-Path $SRC 'api'
    if (-not (Test-Path $srcApi)) { Write-Error "Source api not found at $srcApi"; exit 1 }
    robocopy $srcApi (Join-Path $DST 'api') /MIR /COPY:DAT /R:3 /W:5 /NFL /NDL | Out-Null
} else {
    robocopy $SRC $DST /MIR /COPY:DAT /R:3 /W:5 /NFL /NDL | Out-Null
}

# 5) Create venv clean
Write-Host "Creating venv if missing..." -ForegroundColor Yellow
$PY = Join-Path $DST 'venv\Scripts\python.exe'
if (-not (Test-Path $PY)) {
    & python -m venv (Join-Path $DST 'venv')
}
if (-not (Test-Path $PY)) { Write-Error "Venv python not found at $PY"; exit 1 }

# 6) Ensure __init__.py exists in api
$apiInit = Join-Path $DST 'api\__init__.py'
if (-not (Test-Path $apiInit)) { New-Item -Path $apiInit -ItemType File -Force | Out-Null }

# 7) Install requirements
Write-Host "Installing requirements into venv..." -ForegroundColor Yellow
& $PY -m pip install --upgrade pip setuptools wheel
$req = Join-Path $DST 'requirements.txt'
if (Test-Path $req) { & $PY -m pip install -r $req }

# 8) Optional: pip install -e project root (if you want editable install)
Write-Host "Attempting editable install (optional)" -ForegroundColor Yellow
try { & $PY -m pip install -e $DST } catch { Write-Warning "editable install failed: $_" }

# 9) Validate import
Write-Host "Validating import api.main..." -ForegroundColor Yellow
$importOk = $false
try {
    & $PY -c "import importlib, sys; sys.path.insert(0, r'$DST'); importlib.import_module('api.main'); print('IMPORT_OK')"
    $importOk = $true
} catch {
    Write-Host "Import failed: $_" -ForegroundColor Red
}
if (-not $importOk) { Write-Error "Import failed; aborting before service creation"; exit 1 }

# 10) Prepare logs
New-Item -ItemType Directory -Path $LOGDIR -Force | Out-Null

# 11) Create NSSM service (ensure NSSM is available)
Write-Host "Installing NSSM service..." -ForegroundColor Yellow
if (-not (Get-Command $NSSM -ErrorAction SilentlyContinue)) { Write-Error "nssm not found on PATH. Place nssm.exe on PATH or edit the script to set full path in $NSSM"; exit 1 }
try {
    & $NSSM install $SERVICE $PY "-m uvicorn api.main:app --host 127.0.0.1 --port 8000 --log-level info"
    & $NSSM set $SERVICE AppDirectory $DST
    & $NSSM set $SERVICE AppStdout (Join-Path $LOGDIR 'service_stdout.log')
    & $NSSM set $SERVICE AppStderr (Join-Path $LOGDIR 'service_stderr.log')
    & $NSSM set $SERVICE AppRotateBytes 1048576
} catch {
    Write-Warning "NSSM install/config may have partially failed: $_"
}

# 12) Start service and poll health
Write-Host "Starting service and polling /health..." -ForegroundColor Yellow
try { & $NSSM start $SERVICE } catch { Write-Warning "nssm start failed: $_" }
Start-Sleep -Seconds 3
$ok = $false
for ($i=0; $i -lt 15; $i++) {
    try {
        $r = Invoke-RestMethod -Uri http://127.0.0.1:8000/health -TimeoutSec 3
        Write-Host "Health OK: $($r | ConvertTo-Json -Compress)" -ForegroundColor Green
        $ok = $true
        break
    } catch {
        Write-Host "Waiting... ($($i+1)/15)"; Start-Sleep -Seconds 1
    }
}

if (-not $ok) {
    Write-Host "Service did not respond; showing last 200 lines of logs:" -ForegroundColor Red
    if (Test-Path (Join-Path $LOGDIR 'service_stderr.log')) { Get-Content (Join-Path $LOGDIR 'service_stderr.log') -Tail 200 }
    if (Test-Path (Join-Path $LOGDIR 'service_stdout.log')) { Get-Content (Join-Path $LOGDIR 'service_stdout.log') -Tail 200 }
    exit 1
}

Write-Host "Rebuild complete. Service running." -ForegroundColor Green
