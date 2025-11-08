<#
tools/provision_and_ingest_safe.ps1
----------------------------------
Safe, idempotent provisioning script for Catalogador (Windows).

What it does (idempotent, safe defaults):
 - Self-elevates (UAC) when needed
 - Ensures a single venv at C:\ProgramData\Catalogador\python_api\venv
 - Installs Python dependencies from requirements.txt plus pdfplumber
 - Attempts to install Poppler (pdftotext) via choco or winget if missing
 - Configures NSSM service `Catalogador-PythonAPI` (AppPath, AppDirectory, AppParameters, AppEnvironmentExtra, logs)
 - Optionally runs ingester + importer against a provided PDF or searches common locations
 - Restarts the service and validates /health and /series

Usage (Admin PowerShell):
  .\tools\provision_and_ingest_safe.ps1 [-PdfPath <path>] [-RunIngest] [-Force]

Notes:
 - This script must be run as Administrator to modify NSSM and ProgramData.
 - It will NOT run automatic network installs if neither choco nor winget are available; it will print instructions.
#>
param(
    [string]$PdfPath = '',
    [switch]$RunIngest = $false,
    [switch]$Force = $false
)

function Is-Elevated {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Is-Elevated)) {
    Write-Host "Requesting elevation (UAC)..." -ForegroundColor Yellow
    # Pick a concrete PowerShell executable path for elevation. Try (in order): powershell.exe, pwsh (PowerShell Core), fallback to system PowerShell path.
    $elevExe = $null
    try { $elevExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source } catch { }
    if (-not $elevExe) {
        try { $elevExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source } catch { }
    }
    if (-not $elevExe) {
        $possible = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (Test-Path $possible) { $elevExe = $possible }
    }
    if (-not $elevExe) {
        Write-Host "Cannot locate a PowerShell executable to re-launch for elevation. Please run this script from an elevated PowerShell manually." -ForegroundColor Red
        exit 2
    }

    # Build ArgumentList as an array to avoid quoting/concatenation issues
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath)
    if ($PdfPath) { $argList += @('-PdfPath',$PdfPath) }
    if ($RunIngest) { $argList += '-RunIngest' }
    if ($Force) { $argList += '-Force' }
    Start-Process -FilePath $elevExe -ArgumentList $argList -Verb RunAs
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$# Configuration
# Determine repository root relative to this script file so elevation (which may change CWD)
# doesn't make $repo point to System32. $PSScriptRoot is available in script scope, but
# when executed via Start-Process we use MyInvocation to find the script directory.
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$repo = Split-Path -Path $scriptDir -Parent
$serviceName = 'Catalogador-PythonAPI'
$venvDir = 'C:\ProgramData\Catalogador\python_api\venv'
$pythonExe = Join-Path $venvDir 'Scripts\python.exe'
$dataDir = 'C:\ProgramData\Catalogador\data'
$logDir = 'C:\ProgramData\Catalogador\python_api\logs'
$requirements = Join-Path $repo 'requirements.txt'
$nssmCandidates = @("C:\ProgramData\nssm\nssm.exe","C:\Windows\System32\nssm.exe","C:\Program Files\nssm\nssm.exe")

Write-Host "Provisioning Catalogador (repo=$repo)" -ForegroundColor Cyan

# Ensure directories
$null = New-Item -ItemType Directory -Path $venvDir -Force -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path $dataDir -Force -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue

# 1) Ensure Python venv exists and install requirements
if (-not (Test-Path $pythonExe) -or $Force) {
    Write-Host "Creating virtual environment at $venvDir..." -ForegroundColor Yellow
    # If system python is available, use it to create venv
    $sysPython = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
    if (-not $sysPython) { throw 'No system python found in PATH. Install Python 3.10+ and re-run.' }
    & $sysPython -m venv $venvDir
}

if (-not (Test-Path $pythonExe)) { throw "Python executable not found at $pythonExe" }

Write-Host "Upgrading pip and installing dependencies in venv..." -ForegroundColor Yellow
& $pythonExe -m pip install --upgrade pip setuptools wheel

# Ensure requirements file contains minimal runtime deps; append if missing
$needed = @('fastapi','uvicorn[standard]','pydantic','pdfplumber','requests')
if (-not (Test-Path $requirements)) {
    Write-Host "requirements.txt not found in repo; creating minimal requirements.txt" -ForegroundColor Yellow
    $needed -join "`n" | Set-Content -Path $requirements -Encoding UTF8
}

# Merge requirements (best-effort) - do not remove user entries
$existing = Get-Content $requirements -ErrorAction SilentlyContinue
foreach ($pkg in $needed) {
    if ($existing -notcontains $pkg) { Add-Content -Path $requirements -Value $pkg }
}

# Install requirements into venv
& $pythonExe -m pip install -r $requirements

# 2) Ensure Poppler/pdftotext is present (best-effort using choco/winget)
function Ensure-Poppler {
    if (Get-Command pdftotext.exe -ErrorAction SilentlyContinue) { return $true }
    Write-Host 'pdftotext not found. Attempting to install Poppler (requires choco or winget)...' -ForegroundColor Yellow
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host 'Installing via choco...' -ForegroundColor Yellow
        choco install poppler -y --no-progress
        return (Get-Command pdftotext.exe -ErrorAction SilentlyContinue) -ne $null
    } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host 'Installing via winget...' -ForegroundColor Yellow
        winget install --id=oschwartz10612.Poppler -e --silent --accept-package-agreements --accept-source-agreements
        return (Get-Command pdftotext.exe -ErrorAction SilentlyContinue) -ne $null
    } else {
        Write-Host 'No package manager available. Please install Poppler manually and ensure pdftotext.exe is on PATH.' -ForegroundColor Yellow
        return $false
    }
}
$popplerOk = Ensure-Poppler
if ($popplerOk) { Write-Host 'Poppler/pdftotext available.' -ForegroundColor Green } else { Write-Host 'Poppler not installed; pdfplumber fallback will be used.' -ForegroundColor Yellow }

# 3) Locate nssm.exe
$nssm = $null
foreach ($c in $nssmCandidates) { if (Test-Path $c) { $nssm = $c; break } }
if (-not $nssm) {
    $cmd = Get-Command nssm.exe -ErrorAction SilentlyContinue
    if ($cmd) { $nssm = $cmd.Source }
}
if (-not $nssm) {
    Write-Host 'nssm.exe not found on system. Attempting to install via Chocolatey (requires admin)...' -ForegroundColor Yellow
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        try {
            choco install nssm -y --no-progress
            $cmd = Get-Command nssm.exe -ErrorAction SilentlyContinue
            if ($cmd) { $nssm = $cmd.Source }
        } catch {
            Write-Host 'Chocolatey install of nssm failed or was blocked.' -ForegroundColor Yellow
        }
    } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host 'Attempting winget install of nssm (if available)...' -ForegroundColor Yellow
        try {
            winget install --id=nssm.NSSM -e --silent --accept-package-agreements --accept-source-agreements
            $cmd = Get-Command nssm.exe -ErrorAction SilentlyContinue
            if ($cmd) { $nssm = $cmd.Source }
        } catch {
            Write-Host 'winget install of nssm failed or is not available.' -ForegroundColor Yellow
        }
    }
}
if (-not $nssm) {
    Write-Host 'nssm.exe still not found. Please install NSSM manually and re-run. Download: https://nssm.cc/download' -ForegroundColor Red
    exit 2
}
Write-Host "Using NSSM at: $nssm" -ForegroundColor Green

# 4) Configure NSSM service
Write-Host "Configuring NSSM service: $serviceName" -ForegroundColor Yellow
# Stop service if running
try { & $nssm stop $serviceName } catch { }

# Use absolute python exe and repo dir
& $nssm set $serviceName Application "$pythonExe"
& $nssm set $serviceName AppDirectory "$repo"
# run uvicorn module referencing package path (api.main) - use explicit module path
& $nssm set $serviceName AppParameters "-m uvicorn api.main:app --host 127.0.0.1 --port 8000 --log-level info"
# stdout/stderr
& $nssm set $serviceName AppStdout "$logDir\service_stdout.log"
& $nssm set $serviceName AppStderr "$logDir\service_stderr.log"
# environment
$envList = @("DATA_DIR=$dataDir","PYTHONUNBUFFERED=1","PYTHONUTF8=1","CATALOGADOR_REPO=$repo","CATALOGADOR_VENV=$venvDir")
& $nssm set $serviceName AppEnvironmentExtra ($envList -join "`n")
# rotate logs weekly
& $nssm set $serviceName AppRotateFiles 1
& $nssm set $serviceName AppRotateOnline 1
& $nssm set $serviceName AppRotateSeconds 604800

# 5) Start service and verify
Write-Host 'Starting service...' -ForegroundColor Yellow
& $nssm start $serviceName
Start-Sleep -Seconds 3

# Ensure service is actually running; if paused/stopped try to start it
try {
    $status = (& $nssm status $serviceName 2>$null)
    Write-Host "NSSM service status: $status" -ForegroundColor Yellow
    if ($status -ne 'SERVICE_RUNNING') {
        Write-Host "Service not running (status=$status). Attempting to start..." -ForegroundColor Yellow
        & $nssm start $serviceName
        Start-Sleep -Seconds 2
        $status2 = (& $nssm status $serviceName 2>$null)
        Write-Host "Post-start status: $status2" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Warning: could not query NSSM service status: $_" -ForegroundColor Yellow
}

# 6) Optional: run ingest/import if requested
function Find-PDFCandidate {
    param([string]$hint)
    if ($hint -and (Test-Path $hint)) { return (Resolve-Path $hint).Path }
    # common candidate paths
    $cands = @(
        Join-Path $env:USERPROFILE 'Desktop\ESSALUD-PCD-ANEXO-2-TABLA.pdf',
        Join-Path $env:USERPROFILE 'Downloads\ESSALUD-PCD-ANEXO-2-TABLA.pdf'
    )
    foreach ($p in $cands) { if (Test-Path $p) { return (Resolve-Path $p).Path } }
    # try repo
    $r = Get-ChildItem -Path $repo -Filter '*ANEXO*2*.pdf' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($r) { return $r.FullName }
    return $null
}

if ($RunIngest) {
    Write-Host 'Running ingest + import flow...' -ForegroundColor Cyan
    $pdf = Find-PDFCandidate -hint $PdfPath
    if (-not $pdf) { Write-Host 'PDF not found. Place ANEXO-2 PDF on Desktop/Downloads or pass -PdfPath.' -ForegroundColor Red; exit 3 }
    Write-Host "Found PDF: $pdf" -ForegroundColor Green

    $outdir = Join-Path $env:USERPROFILE 'Desktop\PCD-EsSalud-OUT'
    New-Item -ItemType Directory -Path $outdir -Force | Out-Null

    # run ingester using venv python
    Write-Host 'Extracting and parsing PDF (ingester)...' -ForegroundColor Yellow
    & $pythonExe (Join-Path $repo 'tools\ingest_anexo2.py') --pdf "$pdf" --outdir "$outdir" --force

    $srcJson = Join-Path $outdir 'data\retencion_normalizada.json'
    if (-not (Test-Path $srcJson)) { Write-Host 'Ingest did not produce expected JSON. Check logs and extraction output.' -ForegroundColor Red; exit 4 }

    Write-Host 'Importing normalized JSON into repo and reloading API...' -ForegroundColor Yellow
    & $pythonExe (Join-Path $repo 'tools\import_retencion.py') --src "$srcJson" --dest (Join-Path $repo 'api\data\essalud_pcd_anexo02.full.json')

    # ask the API to reload explicitly
    try {
        Invoke-RestMethod -Uri 'http://127.0.0.1:8000/reload' -Method Post -TimeoutSec 10 | ConvertTo-Json | Write-Host
    } catch {
        Write-Host 'Warning: reload endpoint may not be reachable. Check service logs.' -ForegroundColor Yellow
    }
}

# 7) Final verification
Write-Host 'Verifying API health and /series...' -ForegroundColor Cyan
try {
    $h = Invoke-RestMethod -Uri 'http://127.0.0.1:8000/health' -UseBasicParsing -TimeoutSec 5
    Write-Host '/health ->' ($h | ConvertTo-Json)
} catch { Write-Host '/health failed:' $_.Exception.Message -ForegroundColor Red }
try {
    $s = Invoke-RestMethod -Uri 'http://127.0.0.1:8000/series' -UseBasicParsing -TimeoutSec 10
    if ($s -is [System.Array]) { Write-Host "/series count: $($s.Count)" -ForegroundColor Green } else { Write-Host '/series returned unexpected payload' -ForegroundColor Yellow }
} catch { Write-Host '/series failed:' $_.Exception.Message -ForegroundColor Red }

# 8) Archive logs
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$archive = Join-Path $repo "_build_logs\service_logs_$ts"
New-Item -ItemType Directory -Path $archive -Force | Out-Null
Get-ChildItem -Path $logDir -File -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item $_.FullName -Destination $archive -Force }
Write-Host "Logs archived to $archive" -ForegroundColor Green

Write-Host 'Provisioning complete.' -ForegroundColor Cyan
exit 0
