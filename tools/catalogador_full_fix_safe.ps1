param(
  [switch]$RunIngest,
  [string]$IngestPdfPath
)

# Minimal, safer orchestrator for production provisioning (Windows)
# - Uses explicit, simple commands
# - Avoids complex here-strings and excessive quoting
# - Delegates ingestion to tools/auto_import_and_configure_service.ps1

$ErrorActionPreference = 'Stop'

# Self-elevate to Administrator if required (needed to install NSSM and write to ProgramData)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Requesting elevation (UAC)…'
  $arg = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSCommandPath")
  Start-Process -FilePath 'powershell' -ArgumentList $arg -Verb RunAs
  exit
}

$RepoRoot = 'C:\Users\USER\Desktop\Catalogador'
$ApiDir   = Join-Path $RepoRoot 'api'
$ProgramRoot = 'C:\ProgramData\Catalogador\python_api'
$VenvPath = Join-Path $ProgramRoot 'venv'
$ScriptsDir = Join-Path $ProgramRoot 'scripts'
$LogsDir = Join-Path $ProgramRoot 'logs'
$RunDir = Join-Path $ProgramRoot 'run'
$PidFile = Join-Path $RunDir '.python_api.pid'
$ServiceName = 'Catalogador-PythonAPI'
$ApiHost = '127.0.0.1'
# Resolve API port via canonical helper (runtime/backend_port.txt or env) when available
$portHelper = Join-Path $RepoRoot 'tools\get_backend_port.ps1'
$ApiPort = 0
if (Test-Path $portHelper) { try { $ApiPort = [int](& $portHelper) } catch {} }
if (-not $ApiPort -or $ApiPort -eq 0) { $ApiPort = 8000 }
$NssmUrl = 'https://nssm.cc/release/nssm-2.24.zip'
$NssmDir = 'C:\ProgramData\nssm'
$NssmExe = Join-Path $NssmDir 'nssm.exe'

function Ensure-Folder([string]$p){ if(-not (Test-Path $p)){ New-Item -ItemType Directory -Path $p | Out-Null } }
function Log([string]$m){ Write-Host $m }

# Prepare folders
Ensure-Folder $ProgramRoot; Ensure-Folder $ScriptsDir; Ensure-Folder $LogsDir; Ensure-Folder $RunDir

# Create venv if missing
if(-not (Test-Path (Join-Path $VenvPath 'Scripts\python.exe'))){
  if (Get-Command py -ErrorAction SilentlyContinue){ py -3 -m venv "$VenvPath" } elseif (Get-Command python -ErrorAction SilentlyContinue){ python -m venv "$VenvPath" } else {
    Write-Warning 'Python not found on PATH; please install Python 3.11 or run this script after installing it.'
  }
}

$PythonExe = Join-Path $VenvPath 'Scripts\python.exe'
if (Test-Path $PythonExe){
  & $PythonExe -m pip install --upgrade pip wheel setuptools > $null
  $req = Join-Path $RepoRoot 'requirements.txt'
  if (-not (Test-Path $req)){
    "fastapi>=0.115.0`nuvicorn[standard]>=0.30.0`npydantic>=2.9.0`n" | Out-File -FilePath $req -Encoding utf8
  }
  & $PythonExe -m pip install -r $req
} else { Write-Warning 'Venv python not found; skipping pip steps.' }

# Ensure NSSM exists (download if needed)
if(-not (Test-Path $NssmExe)){
  $tmpzip = Join-Path $env:TEMP 'nssm.zip'
  Invoke-WebRequest -Uri $NssmUrl -OutFile $tmpzip -UseBasicParsing
  Expand-Archive -Path $tmpzip -DestinationPath $NssmDir -Force
  # pick an exe under the extracted folder
  $found = Get-ChildItem -Path $NssmDir -Recurse -Filter 'nssm.exe' | Select-Object -First 1
  if ($found){ Copy-Item -Path $found.FullName -Destination $NssmExe -Force }
}

if(-not (Test-Path $NssmExe)){ Write-Warning 'NSSM not available. Service steps will be skipped.' }

# Write simple start/stop scripts
$startScript = Join-Path $ScriptsDir 'start_python_api.ps1'
$stopScript  = Join-Path $ScriptsDir 'stop_python_api.ps1'

$start = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath '$RepoRoot'
& '$PythonExe' -m uvicorn api.main:app --host $ApiHost --port $ApiPort --workers 1 --proxy-headers --forwarded-allow-ips='*'
"@

$stop = @"
`$ErrorActionPreference = 'SilentlyContinue'
Get-Process | Where-Object { `$_.ProcessName -match 'python|uvicorn' } | Stop-Process -Force -ErrorAction SilentlyContinue
"@

$start | Out-File -FilePath $startScript -Encoding UTF8
$stop  | Out-File -FilePath $stopScript  -Encoding UTF8

# Configure NSSM service if available
if (Test-Path $NssmExe){
  & $NssmExe install $ServiceName 'powershell.exe' "-NoProfile -ExecutionPolicy Bypass -File '$startScript'" | Out-Null
  & $NssmExe set $ServiceName AppDirectory $RepoRoot | Out-Null
  & $NssmExe set $ServiceName AppStdout (Join-Path $LogsDir 'service_stdout.log') | Out-Null
  & $NssmExe set $ServiceName AppStderr (Join-Path $LogsDir 'service_stderr.log') | Out-Null
  & $NssmExe set $ServiceName Start SERVICE_AUTO_START | Out-Null
  & $NssmExe set $ServiceName AppEnvironmentExtra "PYTHONUNBUFFERED=1" | Out-Null
  & $NssmExe set $ServiceName AppEnvironmentExtra "PYTHONUTF8=1" | Out-Null
  & $NssmExe set $ServiceName AppEnvironmentExtra "UVICORN_HOST=$ApiHost" | Out-Null
  & $NssmExe set $ServiceName AppEnvironmentExtra "UVICORN_PORT=$ApiPort" | Out-Null
  & $NssmExe set $ServiceName AppEnvironmentExtra "CATALOGADOR_REPO=$RepoRoot" | Out-Null
  & $NssmExe set $ServiceName AppEnvironmentExtra "CATALOGADOR_VENV=$VenvPath" | Out-Null
  & $NssmExe set $ServiceName AppEnvironmentExtra "DATA_DIR=$RepoRoot\data" | Out-Null
  Write-Host 'NSSM service configured (if running as Administrator)'
}

# Optionally delegate ingestion to small orchestrator
if ($RunIngest){
  $delegate = Join-Path $RepoRoot 'tools\auto_import_and_configure_service.ps1'
  if (Test-Path $delegate){
    $args = @('-RunIngest')
    if ($IngestPdfPath){ $args += '-IngestPdfPath'; $args += $IngestPdfPath }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $delegate @args
  } else { Write-Warning 'Delegated orchestrator not found.' }
}

Write-Host 'Safe orchestrator completed.'
