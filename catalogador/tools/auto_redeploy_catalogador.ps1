<#
Auto redeploy script for Catalogador API

Usage (dry-run, safe):
  .\auto_redeploy_catalogador.ps1 -Mode B

To perform real changes (requires Administrator):
  Start PowerShell as Administrator and run:
  .\auto_redeploy_catalogador.ps1 -Mode B -Force

What it does (when -Force is used):
 - Stop and remove existing NSSM service Catalogador-PythonAPI
 - Kill python processes referencing previous installation
 - Copy repository (API only or full) to C:\ProgramData\Catalogador\python_api
 - Create venv, install pinned requirements, perform editable install
 - Configure NSSM service and start it
 - Poll /health to confirm service readiness

This script is idempotent and safe by default (no destructive actions unless -Force).
#>

param(
    [ValidateSet('A','B')]
    [string]$Mode = 'B',
    [switch]$Force,
    [string]$NssmUrl = '',
    [string]$NssmSha256 = '',
    [switch]$AutoRollback
)

Function Require-Admin {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Administrator privileges are required to perform this operation. Run PowerShell as Administrator."
        exit 1
    }
}

$ServiceName = 'Catalogador-PythonAPI'
$ProgramDataRoot = 'C:\ProgramData\Catalogador\python_api'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

$RollbackScript = Join-Path (Split-Path $MyInvocation.MyCommand.Path) 'rollback_catalogador.ps1'

function Run-Rollback {
    if ($AutoRollback.IsPresent -and (Test-Path $RollbackScript)) {
        Write-Host "AutoRollback enabled - restoring latest backup..." -ForegroundColor Yellow
        & $RollbackScript
        Write-Host "Rollback invoked." -ForegroundColor Green
    }
}

Write-Host "Auto redeploy plan (Mode=$Mode). Force:$($Force.IsPresent)" -ForegroundColor Cyan
Write-Host "Source repo: $RepoRoot" -ForegroundColor Cyan
Write-Host "Destination: $ProgramDataRoot" -ForegroundColor Cyan

if (-not $Force.IsPresent) {
    Write-Host "DRY-RUN: No changes will be made. Re-run with -Force to apply." -ForegroundColor Yellow
}

if ($Force.IsPresent) { Require-Admin }

# 1) Stop/remove service
Write-Host "\nStep 1: Stop/remove existing service if present" -ForegroundColor Cyan
if ($Force.IsPresent) {
    try { nssm stop $ServiceName 2>$null } catch {}
    try { nssm remove $ServiceName confirm 2>$null } catch {}
    try { sc.exe stop $ServiceName 2>$null } catch {}
    try { sc.exe delete $ServiceName 2>$null } catch {}
    Write-Host "Service stop/remove attempted." -ForegroundColor Green
} else {
    Write-Host "Would stop and remove NSSM service named $ServiceName" -ForegroundColor Yellow
}

# 2) Kill python processes referencing ProgramData path
Write-Host "\nStep 2: Kill existing python processes referencing ProgramData path" -ForegroundColor Cyan
$procs = Get-CimInstance Win32_Process -Filter "Name='python.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -like '*ProgramData\\Catalogador*' }
if ($procs) {
    foreach ($p in $procs) {
        if ($Force.IsPresent) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; Write-Host "Killed PID $($p.ProcessId)" }
        else { Write-Host "Would kill PID $($p.ProcessId): $($p.CommandLine)" }
    }
} else { Write-Host "No matching python processes found." }

function Backup-ProgramData {
    param(
        [string]$Dst
    )
    $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $backup = "$Dst.backup.$ts"
    if (Test-Path $Dst) {
        Write-Host "Creating backup of $Dst -> $backup" -ForegroundColor Yellow
        robocopy $Dst $backup /MIR /COPY:DAT /R:1 /W:1 /NFL /NDL | Out-Null
        Write-Host "Backup created at $backup" -ForegroundColor Green
    } else {
        Write-Host "No existing destination to backup." -ForegroundColor Yellow
    }
}

# 3) Prepare destination and copy files (with backup)
Write-Host "\nStep 3: Copy repository to ProgramData (Mode=$Mode)" -ForegroundColor Cyan
if ($Force.IsPresent) {
    # ensure destination exists
    if (-not (Test-Path $ProgramDataRoot)) { New-Item -ItemType Directory -Path $ProgramDataRoot -Force | Out-Null }
    # take ownership and grant rights (call executables directly to avoid cmd quoting issues)
    try {
        # Use /A to assign ownership to the Administrators group (more robust than /D Y in some locales)
        & takeown.exe /F $ProgramDataRoot /R /A | Out-Null
    } catch {
        Write-Warning "takeown failed: $_"
    }
    try {
        & icacls $ProgramDataRoot /grant 'Administrators:F' /T | Out-Null
    } catch {
        Write-Warning "icacls failed: $_"
    }

    # backup existing install before replacing
    Backup-ProgramData -Dst $ProgramDataRoot

    if ($Mode -eq 'B') {
        $srcApi = Join-Path $RepoRoot 'api'
    if (-not (Test-Path $srcApi)) { Write-Error "Source api folder not found: $srcApi"; Run-Rollback; exit 1 }
        robocopy $srcApi (Join-Path $ProgramDataRoot 'api') /MIR /COPY:DAT /R:3 /W:5 /NFL /NDL | Out-Null
    } else {
        robocopy $RepoRoot $ProgramDataRoot /MIR /COPY:DAT /R:3 /W:5 /NFL /NDL | Out-Null
    }
    Write-Host "Files copied." -ForegroundColor Green
} else {
    if ($Mode -eq 'B') { Write-Host "Would robocopy api -> $ProgramDataRoot\\api" } else { Write-Host "Would robocopy repo -> $ProgramDataRoot" }
}

# 4) Create venv and install requirements
Write-Host "\nStep 4: Create venv and install requirements" -ForegroundColor Cyan
$pyPath = Join-Path $ProgramDataRoot 'venv\Scripts\python.exe'
$reqPath = Join-Path $ProgramDataRoot 'requirements.txt'
if ($Force.IsPresent) {
    if (-not (Test-Path $pyPath)) { & python -m venv (Join-Path $ProgramDataRoot 'venv') }
    if (-not (Test-Path $pyPath)) { Write-Error "Venv python not found at $pyPath"; exit 1 }
    & $pyPath -m pip install --upgrade pip setuptools wheel
    if (Test-Path $reqPath) { & $pyPath -m pip install -r $reqPath }
    try { & $pyPath -m pip install -e $ProgramDataRoot } catch { Write-Warning "Editable install failed: $_" }
    Write-Host "Dependencies installed into venv." -ForegroundColor Green
} else {
    Write-Host "Would create venv at $ProgramDataRoot\\venv and install requirements from $reqPath" -ForegroundColor Yellow
}

# 5) Ensure api package importable
Write-Host "\nStep 5: Validate import of api.main" -ForegroundColor Cyan
if ($Force.IsPresent) {
    try {
        & $pyPath -c "import importlib, sys; sys.path.insert(0, r'$ProgramDataRoot'); importlib.import_module('api.main'); print('IMPORT_OK')"
        Write-Host "Import validation succeeded." -ForegroundColor Green
    } catch { Write-Error "Import validation failed: $_"; exit 1 }
} else {
    Write-Host "Would run python -c importlib to validate api.main import in venv." -ForegroundColor Yellow
}

# 6) Configure NSSM service
Write-Host "\nStep 6: Configure NSSM service" -ForegroundColor Cyan
$nssmPath = 'nssm'
$appParams = "-m uvicorn api.main:app --host 127.0.0.1 --port 8000 --log-level info"
if ($Force.IsPresent) {
    # Optional: if a NssmUrl and NssmSha256 are provided, download and verify nssm.exe
    if ($NssmUrl -and $NssmSha256) {
        Write-Host "NSSM URL provided. Downloading and verifying..." -ForegroundColor Cyan
        $tmp = Join-Path $env:TEMP "nssm_download.exe"
        try {
            Invoke-WebRequest -Uri $NssmUrl -OutFile $tmp -UseBasicParsing -ErrorAction Stop
            $sha = Get-FileHash -Path $tmp -Algorithm SHA256 | Select-Object -ExpandProperty Hash
            if ($sha.ToLower() -ne $NssmSha256.ToLower()) { Write-Error "NSSM SHA256 mismatch (got $sha)"; Run-Rollback; exit 4 }
            # place alongside ProgramDataRoot for use
            $nssmDest = Join-Path $ProgramDataRoot 'nssm.exe'
            Copy-Item -Path $tmp -Destination $nssmDest -Force
            $nssmPath = $nssmDest
            Write-Host "NSSM downloaded and verified to $nssmDest" -ForegroundColor Green
        } catch {
            Write-Error "Failed to download or verify NSSM: $_"; Run-Rollback; exit 5
        }
    } elseif (-not (Get-Command $nssmPath -ErrorAction SilentlyContinue)) {
        Write-Warning "nssm not found on PATH. You can supply nssm.exe in PATH or set NSSM path in script.";
    }
    & $nssmPath install $ServiceName $pyPath $appParams
    & $nssmPath set $ServiceName AppDirectory $ProgramDataRoot
    & $nssmPath set $ServiceName AppStdout (Join-Path $ProgramDataRoot 'logs\service_stdout.log')
    & $nssmPath set $ServiceName AppStderr (Join-Path $ProgramDataRoot 'logs\service_stderr.log')
    & $nssmPath set $ServiceName AppRotateBytes 1048576
    Write-Host "NSSM service configured." -ForegroundColor Green
} else {
    Write-Host "Would run nssm install and configure logs for service $ServiceName" -ForegroundColor Yellow
}

# 7) Start service and poll health
Write-Host "\nStep 7: Start service and poll /health" -ForegroundColor Cyan
if ($Force.IsPresent) {
    try { & $nssmPath start $ServiceName } catch { Write-Warning "nssm start failed (maybe already running): $_" }
    Start-Sleep -Seconds 3
    $ok = $false
    for ($i=0; $i -lt 15; $i++) {
        try {
            $r = Invoke-RestMethod -Uri http://127.0.0.1:8000/health -TimeoutSec 3
            Write-Host "Health response: $($r | ConvertTo-Json -Compress)" -ForegroundColor Green
            $ok = $true; break
        } catch { Start-Sleep -Seconds 1 }
    }
    if (-not $ok) {
        Write-Error "Service did not respond on /health after start."; exit 1
    }
} else {
    Write-Host "Would start the NSSM service and poll http://127.0.0.1:8000/health" -ForegroundColor Yellow
}

Write-Host "\nAuto redeploy script completed (dry-run: $(-not $Force.IsPresent))." -ForegroundColor Cyan
