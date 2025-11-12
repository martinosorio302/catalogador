<#
Generate or update an NSSM service for the Catalogador Python API.

Usage (Admin):
    .\generate_nssm_service.ps1 -ServiceName 'Catalogador-PythonAPI' -PythonExe 'C:\ProgramData\Catalogador\python_api\venv\Scripts\python.exe' -AppDir 'C:\ProgramData\Catalogador\python_api' -Port <port>

This script is idempotent: it will create or update the NSSM parameters.
It prefers `tools/get_backend_port.ps1` when present to determine the port.
#>

param(
    [string]$ServiceName = 'Catalogador-PythonAPI',
    [string]$PythonExe = 'C:\ProgramData\Catalogador\python_api\venv\Scripts\python.exe',
    [string]$AppDir = 'C:\ProgramData\Catalogador\python_api',
    [int]$Port = 0
)

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'This script must be run as Administrator. Re-run PowerShell as Administrator and try again.'
    exit 1
}

if (-not (Test-Path $PythonExe)) {
    Write-Error "Python executable not found: $PythonExe"
    exit 2
}

# If a canonical helper exists, prefer its value for the Port. Fall back to 8000.
$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'get_backend_port.ps1'
if (Test-Path $helper) {
    try { $h = [int](& $helper); if ($h) { $Port = $h } } catch {}
}
if (-not $Port -or $Port -eq 0) { $Port = 8000 }

$appParams = "-m uvicorn api.main:app --host 127.0.0.1 --port $Port --log-level info"

Write-Host "Installing/Updating NSSM service '$ServiceName' pointing to $PythonExe"
nssm install $ServiceName $PythonExe $appParams | Out-Null
nssm set $ServiceName AppDirectory $AppDir | Out-Null
nssm set $ServiceName AppStdout "$AppDir\logs\service_stdout.log" | Out-Null
nssm set $ServiceName AppStderr "$AppDir\logs\service_stderr.log" | Out-Null
nssm set $ServiceName AppRotateBytes 1048576 | Out-Null

Write-Host "Service '$ServiceName' configured. Use 'nssm start $ServiceName' to start it, or run this script as Admin to start immediately."
