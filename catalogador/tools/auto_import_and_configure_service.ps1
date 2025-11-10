param(
  [switch]$RunIngest,
  [string]$IngestPdfPath,
  [string]$ApiHost = "127.0.0.1",
  [int]$ApiPort = 8000
)

$RepoRoot    = "C:\Users\USER\Desktop\Catalogador"
$ProgramRoot = "C:\ProgramData\Catalogador\python_api"
$VenvPython  = Join-Path $ProgramRoot "venv\Scripts\python.exe"
$NssmExe     = "C:\ProgramData\nssm\nssm.exe"
$ServiceName = "Catalogador-PythonAPI"
$LogsDir     = Join-Path $ProgramRoot "logs"

function I([string]$m){ Write-Host $m -ForegroundColor Cyan }
function S([string]$m){ Write-Host $m -ForegroundColor Green }
function W([string]$m){ Write-Host $m -ForegroundColor Yellow }

I "Small orchestrator: configure NSSM env, optional ingest, auto-import."

# Validate NSSM
if (-not (Test-Path $NssmExe)){
  W "NSSM not found at $NssmExe. Install NSSM or run full orchestrator first.";
} else {
  I "Configuring NSSM environment variables for service '$ServiceName'..."
  & $NssmExe set $ServiceName AppEnvironmentExtra "PYTHONUNBUFFERED=1"
  & $NssmExe set $ServiceName AppEnvironmentExtra "PYTHONUTF8=1"
  & $NssmExe set $ServiceName AppEnvironmentExtra "UVICORN_HOST=$ApiHost"
  & $NssmExe set $ServiceName AppEnvironmentExtra "UVICORN_PORT=$ApiPort"
  & $NssmExe set $ServiceName AppEnvironmentExtra "CATALOGADOR_REPO=$RepoRoot"
  & $NssmExe set $ServiceName AppEnvironmentExtra "CATALOGADOR_VENV=$ProgramRoot\venv"
  & $NssmExe set $ServiceName AppEnvironmentExtra "DATA_DIR=$RepoRoot\data"
  S "NSSM env vars set (if service exists)."
}

# Choose python executable: prefer venv
$pythonExe = $null
if (Test-Path $VenvPython) { $pythonExe = $VenvPython } elseif (Get-Command python -ErrorAction SilentlyContinue) { $pythonExe = (Get-Command python).Path }
if (-not $pythonExe) { W "No python executable found (venv or system). Import won't run." }
else { S "Using python: $pythonExe" }

# Optionally run ingester
if ($RunIngest) {
  if (-not $IngestPdfPath) { W "-RunIngest specified but no -IngestPdfPath provided; skipping ingest." }
  elseif (-not $pythonExe) { W "No python to run ingester; skipping ingest." }
  else {
    I "Running ingester against: $IngestPdfPath"
    $pyScript = Join-Path $RepoRoot "tools\ingest_anexo2.py"
    if (-not (Test-Path $pyScript)) { W "ingest_anexo2.py not found in tools/; skipping." }
    else {
      & $pythonExe $pyScript --pdf $IngestPdfPath --outdir (Join-Path $RepoRoot "PCD-EsSalud-OUT") --force
      if ($LASTEXITCODE -ne 0) { W "Ingestor returned exit code $LASTEXITCODE (check logs)." } else { S "Ingestor finished." }
    }
  }
}

# Find retencion_normalizada.json
$found = Get-ChildItem -Path $RepoRoot -Recurse -Filter 'retencion_normalizada.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($found -and $found.FullName) {
  $srcPath = $found.FullName
  I "Found ingester output: $srcPath"
} else {
  W "No retencion_normalizada.json found in repo; aborting import step."
  exit 0
}

# Run importer using chosen python
$importer = Join-Path $RepoRoot 'tools\import_retencion.py'
if (-not (Test-Path $importer)) { W "import_retencion.py not found in tools/; aborting."; exit 1 }
if (-not $pythonExe) { W "No python to run importer; aborting."; exit 1 }

I "Running importer to normalize and write API data, then POST /reload..."
& $pythonExe $importer --src $srcPath --reload-host $ApiHost --reload-port $ApiPort
$importExit = $LASTEXITCODE
if ($importExit -ne 0) { W "import_retencion.py returned exit code $importExit" } else { S "import_retencion.py completed." }

# Verify API health
try {
  $health = Invoke-RestMethod -Method Get -Uri "http://$($ApiHost):$($ApiPort)/health" -TimeoutSec 5 -ErrorAction Stop
  S "/health -> $($health | ConvertTo-Json -Compress)"
} catch {
  W ("Could not reach API /health at http://{0}:{1}/health: {2}" -f $ApiHost, $ApiPort, $_.Exception.Message)
}

# Optionally fetch /series and count
try {
  $series = Invoke-RestMethod -Method Get -Uri "http://$($ApiHost):$($ApiPort)/series" -TimeoutSec 10 -ErrorAction Stop
  if ($series -is [Array]) { S "/series count -> $($series.Count)" } else { S "/series returned non-array (type: $($series.GetType().FullName))" }
} catch {
  W ("Could not fetch /series: {0}" -f $_.Exception.Message)
}

S "Done."
