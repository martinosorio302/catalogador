<#
  catalogador_full_fix.ps1
  Simplified, idempotent Windows orchestrator for Catalogador backend.
  - Creates ProgramData venv and logs
  - Installs NSSM if missing and registers a service that runs a start script
  - Ensures the service sees the repo on PYTHONPATH so 'api' can be imported
  - Optional: -RunIngest delegates to a smaller orchestrator if present

  Usage (run as Administrator):
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\tools\catalogador_full_fix.ps1 -RunIngest -IngestPdfPath 'C:\path\to\anexo2.pdf'
#>

param(
  [switch]$RunIngest,
  [string]$IngestPdfPath
)

$ErrorActionPreference = 'Stop'

# Ensure script runs as Administrator (required for service install, icacls, takeown)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error 'This script must be run as Administrator. Re-run PowerShell as Administrator and try again.'
  exit 1
}

# Basic configuration (adjust to your environment if needed)
$RepoRoot    = Resolve-Path -Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) '..') | Select-Object -ExpandProperty Path
$ServiceName = 'Catalogador-PythonAPI'
$ProgramRoot = 'C:\ProgramData\Catalogador\python_api'
$VenvPath    = Join-Path $ProgramRoot 'venv'
$ScriptsDir  = Join-Path $ProgramRoot 'scripts'
$LogsDir     = Join-Path $ProgramRoot 'logs'
$ImportPath  = 'api.main:app'
$ApiHost     = '127.0.0.1'
$ApiPort     = 8000
$NssmDir     = 'C:\ProgramData\nssm'
$NssmExe     = Join-Path $NssmDir 'nssm.exe'
$NssmUrl     = 'https://nssm.cc/release/nssm-2.24.zip'
$Tmp         = $env:TEMP

function I([string]$m){ Write-Host $m -ForegroundColor Cyan }
function S([string]$m){ Write-Host $m -ForegroundColor Green }
function W([string]$m){ Write-Host $m -ForegroundColor Yellow }
function E([string]$m){ Write-Host $m -ForegroundColor Red }

# Ensure folders
foreach ($p in @($ProgramRoot, $ScriptsDir, $LogsDir)) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }

# Ensure a usable Python is available
$pythonCandidate = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $pythonCandidate) { throw 'Python not found in PATH. Install Python or run from an environment that has python available.' }
$SystemPython = $pythonCandidate.Path

# Create venv if missing
if (-not (Test-Path (Join-Path $VenvPath 'Scripts\python.exe'))) {
  I "Creating venv at $VenvPath"
  & $SystemPython -m venv $VenvPath
}
$VenvPython = Join-Path $VenvPath 'Scripts\python.exe'
if (-not (Test-Path $VenvPython)) { throw "Venv python not found: $VenvPython" }

# Install requirements from repo if present (non-fatal)
$Req = Join-Path $RepoRoot 'requirements.txt'
if (Test-Path $Req) {
  I 'Installing pip dependencies into venv (from requirements.txt)'
  & $VenvPython -m pip install --upgrade pip setuptools wheel | Out-Null
  & $VenvPython -m pip install -r $Req | Out-Null
  # Try an editable install of the repository so the service can import top-level packages like 'api'
  try {
    I 'Attempting editable install of repository into venv (pip install -e)'
    & $VenvPython -m pip install -e $RepoRoot --disable-pip-version-check | Out-Null
    S 'pip editable install completed (if setup.py/pyproject existed).'
  } catch {
    W ("pip install -e failed or repo not packaged — continuing without editable install: {0}" -f $_.Exception.Message)
  }
} else { I 'No requirements.txt found in repo — skipping pip install' }

# Write start/stop wrappers (UTF8 no BOM)
$StartScript = Join-Path $ScriptsDir 'start_python_api.ps1'
$StopScript  = Join-Path $ScriptsDir 'stop_python_api.ps1'

$startContent = @"
Set-Location -LiteralPath '$RepoRoot'
if (-not (Test-Path '$LogsDir')) { New-Item -ItemType Directory -Path '$LogsDir' | Out-Null }
# Diagnostics: print python version, PYTHONPATH and sys.path to stderr so logs show why imports might fail
"$VenvPath\Scripts\python.exe" -c "import sys, os; print('--- START DIAGNOSTICS ---'); print('python=' + sys.executable); print('version=' + sys.version.replace(chr(10),' ')); print('PYTHONPATH=' + os.environ.get('PYTHONPATH','')); print('\n'.join(sys.path))" 2>> "$LogsDir\service_stderr.log"
# Launch uvicorn
"$VenvPath\Scripts\python.exe" -m uvicorn $ImportPath --host $ApiHost --port $ApiPort --log-level info >> "$LogsDir\service_stdout.log" 2>> "$LogsDir\service_stderr.log"
"@

$stopContent = @"
Get-Process -Name python,uvicorn -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
"@

$Utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($StartScript, $startContent, $Utf8NoBOM)
[System.IO.File]::WriteAllText($StopScript,  $stopContent,  $Utf8NoBOM)
S "Wrappers written: `n  $StartScript`n  $StopScript"

# Ensure NSSM exists (download & extract if needed)
if (-not (Test-Path $NssmExe)) {
  I 'NSSM not found — downloading and extracting'
  $zip = Join-Path $Tmp 'nssm.zip'
  Invoke-WebRequest -Uri $NssmUrl -OutFile $zip -UseBasicParsing -ErrorAction Stop
  Expand-Archive -Path $zip -DestinationPath $NssmDir -Force
  # locate nssm.exe under the extracted folder (prefer win64)
  $cand = Get-ChildItem -Path $NssmDir -Recurse -Filter 'nssm.exe' | Where-Object { $_.FullName -match 'win64' } | Select-Object -First 1
  if (-not $cand) { $cand = Get-ChildItem -Path $NssmDir -Recurse -Filter 'nssm.exe' | Select-Object -First 1 }
  if ($cand) { Copy-Item -Path $cand.FullName -Destination $NssmExe -Force }
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path $NssmExe)) { throw "nssm.exe not available after download (expected at $NssmExe)" }
S "NSSM available at $NssmExe"

# Recreate service (idempotent)
try { & $NssmExe stop $ServiceName | Out-Null } catch {}
try { & $NssmExe remove $ServiceName confirm | Out-Null } catch {}

# Install service to run the start wrapper via PowerShell
& $NssmExe install $ServiceName 'powershell.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$StartScript`""
& $NssmExe set $ServiceName AppDirectory $RepoRoot
& $NssmExe set $ServiceName AppStdout "$LogsDir\service_stdout.log"
& $NssmExe set $ServiceName AppStderr "$LogsDir\service_stderr.log"
& $NssmExe set $ServiceName AppExit Default Restart
& $NssmExe set $ServiceName Start SERVICE_AUTO_START

# Make sure service process can import the repo: set PYTHONPATH to repo root and other envs
& $NssmExe set $ServiceName AppEnvironmentExtra "PYTHONUNBUFFERED=1"
& $NssmExe set $ServiceName AppEnvironmentExtra "PYTHONUTF8=1"
& $NssmExe set $ServiceName AppEnvironmentExtra "PYTHONPATH=$RepoRoot"
& $NssmExe set $ServiceName AppEnvironmentExtra "DATA_DIR=$RepoRoot\data"
& $NssmExe set $ServiceName AppEnvironmentExtra "CATALOGADOR_REPO=$RepoRoot"
& $NssmExe set $ServiceName AppEnvironmentExtra "CATALOGADOR_VENV=$VenvPath"

S 'Service installed/configured.'

# Start service and check /health
I 'Starting service...'
& $NssmExe start $ServiceName | Out-Null
Start-Sleep -Seconds 3

I 'Checking /health...'
$ok = $false
for ($i=0; $i -lt 20; $i++) {
  try {
    $uri = "http://$($ApiHost):$($ApiPort)/health"
    $r = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 3
    if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 300) { S "/health OK -> $($r.Content)"; $ok = $true; break }
  } catch { Start-Sleep -Seconds 1 }
}
if (-not $ok) {
  W 'Service did not respond on /health. Showing recent logs:'
  if (Test-Path "$LogsDir\service_stdout.log") { Write-Host '--- STDOUT ---'; Get-Content "$LogsDir\service_stdout.log" -Tail 200 }
  if (Test-Path "$LogsDir\service_stderr.log") { Write-Host '--- STDERR ---'; Get-Content "$LogsDir\service_stderr.log" -Tail 200 }
}

# Optional: delegate ingestion to repo-provided script if requested
if ($RunIngest) {
  $delegated = Join-Path $RepoRoot 'tools\auto_import_and_configure_service.ps1'
  if (Test-Path $delegated) {
    I "Running delegated ingestor: $delegated"
    $runArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$delegated,'-RunIngest')
    if ($IngestPdfPath) { $runArgs += @('-IngestPdfPath', $IngestPdfPath) }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $runArgs -Wait -NoNewWindow
  } else { W "Delegated ingestor not found: $delegated — skipping." }
}

# Final report
Write-Host ''
Write-Host '=== RUTAS CLAVE ==='
Write-Host ("RepoRoot:    {0}" -f $RepoRoot)
Write-Host ("ProgramRoot: {0}" -f $ProgramRoot)
Write-Host ("Venv:        {0}" -f $VenvPath)
Write-Host ("Logs:        {0}" -f $LogsDir)
Write-Host ("Service:     {0}" -f $ServiceName)
Write-Host ("Uvicorn:     http://{0}:{1}/health" -f $ApiHost, $ApiPort)
Write-Host ''
S 'Orchestration completed. If problems persist, check the logs under the ProgramData folder and ensure this script was run As Administrator.'

# end
