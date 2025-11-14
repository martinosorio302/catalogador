# autofix_all.ps1 - Complete hardening workflow
# Run as Administrator
param([switch]$VerboseLog)

$ROOT    = "C:\Users\USER\Desktop\Catalogador"
$SRVROOT = "C:\ProgramData\Catalogador\python_api"
$VENV    = Join-Path $SRVROOT "venv"
$PY      = Join-Path $VENV "Scripts\python.exe"
$LOGS    = Join-Path $SRVROOT "logs"
$SERVICE = "Catalogador-PythonAPI"

function Info($m){ Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "[+] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "[x] $m" -ForegroundColor Red }

try {
  Info "Ensuring runtime structure"
  New-Item -ItemType Directory -Force -Path $SRVROOT,$LOGS | Out-Null

  if (!(Test-Path $PY)) {
    Info "Creating production venv"
    py -3 -m venv $VENV
  } else {
    Ok "Venv already exists"
  }

  Info "Installing/upgrading dependencies"
  & $PY -m pip install --quiet --upgrade pip
  & $PY -m pip install --quiet fastapi uvicorn pydantic starlette pillow pytesseract pypdf2 python-multipart

  Info "Copying API and engine to service runtime"
  robocopy "$ROOT\api" "$SRVROOT\api" /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
  robocopy "$ROOT\engine" "$SRVROOT\engine" /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
  
  Info "Creating Python path file"
  $PTH = Join-Path $VENV "Lib\site-packages\catalogador_path.pth"
  "C:\ProgramData\Catalogador\python_api" | Set-Content $PTH

  Info "Reinstalling NSSM service"
  nssm stop $SERVICE 2>$null
  nssm remove $SERVICE confirm 2>$null
  sc.exe delete $SERVICE 2>$null
  Start-Sleep -Seconds 3

  $svc = sc.exe query $SERVICE 2>$null
  if ($LASTEXITCODE -eq 0) {
    Warn "Service marked for deletion, using alternate name"
    $SERVICE = "Catalogador-PythonAPI2"
  }

  nssm install $SERVICE $PY "-m" "uvicorn" "api.main:app" "--host" "127.0.0.1" "--port" "8000" "--log-level" "info"
  nssm set $SERVICE AppDirectory $SRVROOT
  nssm set $SERVICE AppStdout "$LOGS\service_stdout.log"
  nssm set $SERVICE AppStderr "$LOGS\service_stderr.log"
  nssm set $SERVICE AppRotateBytes 1048576
  nssm set $SERVICE AppPriority ABOVE_NORMAL_PRIORITY_CLASS
  nssm set $SERVICE AppEnvironmentExtra "PYTHONPATH=$SRVROOT"
  nssm set $SERVICE Start SERVICE_AUTO_START
  
  Info "Starting service"
  nssm start $SERVICE
  Start-Sleep -Seconds 2

  Info "Waiting for /health endpoint"
  $ok = $false
  for ($i=1; $i -le 25; $i++) {
    try {
      $r = Invoke-RestMethod "http://127.0.0.1:8000/health" -TimeoutSec 2
      if ($r.status -eq "ok" -or $r.ok) { 
        $ok = $true
        break 
      }
    } catch { 
      Start-Sleep -Milliseconds 600 
    }
  }

  if (-not $ok) {
    Warn "API did not respond to /health. Checking logs..."
    if (Test-Path "$LOGS\service_stderr.log") {
      Get-Content "$LOGS\service_stderr.log" -Tail 50 | ForEach-Object { Warn $_ }
    }
    if (Test-Path "$LOGS\service_stdout.log") {
      Get-Content "$LOGS\service_stdout.log" -Tail 50 | ForEach-Object { Info $_ }
    }
    throw "API service not responding"
  }

  Ok "API service OK at http://127.0.0.1:8000/health"

  Info "Building WPF client"
  $csproj = Join-Path $ROOT "Catalogador.App\Catalogador.App.csproj"
  if (Test-Path $csproj) {
    dotnet build $csproj -c Release | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Ok "WPF client built successfully"
    } else {
      Warn "WPF build had warnings/errors"
    }
  } else {
    Warn "WPF project not found at $csproj"
  }

  Ok "=== AUTOFIX COMPLETE ==="
  Ok "Backend API: http://127.0.0.1:8000/health"
  Ok "Service logs: $LOGS"
  if (Test-Path "$ROOT\Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe") {
    Ok "WPF executable: $ROOT\Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe"
  }

} catch {
  Err $_
  Err "Autofix failed. Check logs at: $LOGS"
  exit 1
}
