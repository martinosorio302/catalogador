param([string]$ServiceName = "Catalogador-PythonAPI")

$PY = "C:\ProgramData\Catalogador\python_api\venv\Scripts\python.exe"
$APPDIR = "C:\ProgramData\Catalogador\python_api"
$LOGDIR = "C:\ProgramData\Catalogador\python_api\logs"
New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null

nssm stop $ServiceName 2>$null
nssm remove $ServiceName confirm 2>$null
sc.exe delete $ServiceName 2>$null
Start-Sleep -Seconds 2

nssm install $ServiceName $PY "-m" "uvicorn" "api.main:app" "--host" "127.0.0.1" "--port" "8000" "--log-level" "info"
nssm set $ServiceName AppDirectory $APPDIR
nssm set $ServiceName AppStdout "$LOGDIR\service_stdout.log"
nssm set $ServiceName AppStderr "$LOGDIR\service_stderr.log"
nssm set $ServiceName AppRotateBytes 1048576
nssm set $ServiceName AppEnvironmentExtra "PYTHONPATH=$APPDIR"
nssm set $ServiceName Start SERVICE_AUTO_START
nssm start $ServiceName

Write-Host "Service $ServiceName installed and started"
