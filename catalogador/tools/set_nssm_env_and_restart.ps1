# Self-elevating helper to set NSSM AppEnvironmentExtra and restart the Catalogador service
param(
    [string]$ServiceName = 'Catalogador-PythonAPI'
)
function Is-RunningElevated {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Is-RunningElevated)) {
    Write-Host 'Not elevated. Relaunching with elevation...'
    # Use powershell.exe for elevation on Windows
    Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Running elevated. Setting NSSM environment for service: $ServiceName"
$nssmPaths = @(
    'C:\ProgramData\nssm\nssm.exe',
    'C:\Program Files\nssm\nssm.exe',
    'C:\Windows\nssm.exe'
)
$nssm = $null
foreach ($p in $nssmPaths) {
    if (Test-Path $p) { $nssm = $p; break }
}
if (-not $nssm) {
    $found = Get-ChildItem -Path 'C:\' -Filter 'nssm.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $nssm = $found.FullName }
}
if (-not $nssm) { Write-Error 'nssm.exe not found. Please install NSSM and re-run.'; exit 2 }
Write-Host "Using nssm at: $nssm"

# Read current AppEnvironmentExtra
$current = @()
try { $current = & $nssm get $ServiceName AppEnvironmentExtra } catch { }
if ($current) { Write-Host 'Current AppEnvironmentExtra:'; $current | ForEach-Object { Write-Host "  $_" } }

# Variables to ensure
# Force overwrite AppEnvironmentExtra with a known good set of environment variables.
# Using a here-string avoids tricky newline/quoting issues when calling nssm from PowerShell.
$new = @'
DATA_DIR=C:\Users\USER\Desktop\Catalogador\data
PYTHONUNBUFFERED=1
PYTHONUTF8=1
UVICORN_HOST=127.0.0.1
UVICORN_PORT=8000
CATALOGADOR_REPO=C:\Users\USER\Desktop\Catalogador
CATALOGADOR_VENV=C:\ProgramData\Catalogador\python_api\venv
'@
Write-Host 'Setting AppEnvironmentExtra (will overwrite existing entries)...'
& $nssm set $ServiceName AppEnvironmentExtra $new
if ($LASTEXITCODE -ne 0) { Write-Warning "nssm set returned exit code $LASTEXITCODE" }

# Restart service
Write-Host 'Restarting service...'
try { Stop-Service -Name $ServiceName -Force -ErrorAction Stop } catch { Write-Warning ("Stop-Service: {0}" -f $_.Exception.Message) }
Start-Sleep -Seconds 2
try { Start-Service -Name $ServiceName -ErrorAction Stop; Write-Host 'Service started' } catch { Write-Warning ("Start-Service: {0}" -f $_.Exception.Message) }

# Show AppEnvironmentExtra
Write-Host 'Now AppEnvironmentExtra:'
& $nssm get $ServiceName AppEnvironmentExtra

# Tail logs (if present)
$logdir = 'C:\ProgramData\Catalogador\python_api\logs'
if (Test-Path $logdir) {
    Get-ChildItem $logdir | ForEach-Object {
        Write-Host '----' $_.Name '----'
        Get-Content $_.FullName -Tail 200 -ErrorAction SilentlyContinue
    }
} else { Write-Host 'No log directory at' $logdir }

# Ensure AppParameters binds to 127.0.0.1 (safer). If AppParameters contains '--host 0.0.0.0', replace it.
try {
    $appParams = (& $nssm get $ServiceName AppParameters) -join " `n"
    Write-Host 'Current AppParameters:'
    Write-Host $appParams
    if ($appParams -match '--host\s+0\.0\.0\.0') {
        $newParams = $appParams -replace '--host\s+0\.0\.0\.0','--host 127.0.0.1'
        Write-Host 'Updating AppParameters to bind to 127.0.0.1'
        & $nssm set $ServiceName AppParameters $newParams
        if ($LASTEXITCODE -ne 0) { Write-Warning "nssm set AppParameters returned exit code $LASTEXITCODE" }
        Write-Host 'Restarting service to pick up new parameters...'
        try { Stop-Service -Name $ServiceName -Force -ErrorAction Stop } catch { }
        Start-Sleep -Seconds 2
    try { Start-Service -Name $ServiceName -ErrorAction Stop } catch { Write-Warning ("Start-Service: {0}" -f $_.Exception.Message) }
        Write-Host 'New AppParameters:'
        & $nssm get $ServiceName AppParameters
    } else {
        Write-Host 'AppParameters do not indicate binding to 0.0.0.0; no change made.'
    }
} catch {
    Write-Warning ("Could not inspect/update AppParameters: {0}" -f $_.Exception.Message)
}

# As a fallback, forcefully set AppParameters to a known-good command that binds to 127.0.0.1
try {
    $forceParams = "-m uvicorn api.main:app --host 127.0.0.1 --port 8000 --log-level info"
    Write-Host 'Force-setting AppParameters to:' $forceParams
    & $nssm set $ServiceName AppParameters $forceParams
    if ($LASTEXITCODE -ne 0) { Write-Warning "nssm set AppParameters (force) returned exit code $LASTEXITCODE" }
    Write-Host 'Restarting service to apply forced parameters...'
    try { Stop-Service -Name $ServiceName -Force -ErrorAction Stop } catch { }
    Start-Sleep -Seconds 2
    try { Start-Service -Name $ServiceName -ErrorAction Stop } catch { Write-Warning ("Start-Service: {0}" -f $_.Exception.Message) }
    Write-Host 'Forced AppParameters now:'
    & $nssm get $ServiceName AppParameters
} catch {
    Write-Warning ("Failed to force AppParameters: {0}" -f $_.Exception.Message)
}

Write-Host 'Done.'
