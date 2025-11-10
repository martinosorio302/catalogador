<#
Idempotent redeploy script for Catalogador-PythonAPI
Run as Administrator in PowerShell:
    Set-ExecutionPolicy Bypass -Scope Process -Force; \"C:\Users\USER\Desktop\Catalogador\tools\redeploy_catalogador_service.ps1\"

This script performs the following (safe, idempotent) steps:
 1) Stop and remove existing NSSM service Catalogador-PythonAPI (if present)
 2) Remove old ProgramData copy and copy fresh repository from the Desktop
 3) Ensure or create venv under ProgramData and install requirements
 4) pip install -e the repository into that venv
 5) Create NSSM service pointing to venv python -m uvicorn ...
 6) Start the service and validate /health

Notes:
 - This script DOES NOT download NSSM; it expects "nssm.exe" to be available on PATH.
 - Run as Administrator. The script writes logs to C:\ProgramData\Catalogador\python_api\logs\deploy.log
#>

param(
    [switch]$WhatIf,
    [switch]$NoConfirm
)

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This script must be run as Administrator. Re-launch PowerShell 'Run as Administrator'."
        exit 1
    }
}

Assert-Admin

$RepoSrc = "$env:USERPROFILE\Desktop\Catalogador"
$Dest = "C:\ProgramData\Catalogador\python_api"
$VenvPy = Join-Path $Dest "venv\Scripts\python.exe"
$Req = Join-Path $Dest "requirements.txt"
$LogDir = Join-Path $Dest "logs"
$ServiceName = "Catalogador-PythonAPI"
$DeployLog = Join-Path $LogDir "deploy.log"

# Start transcript/logging
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
if (Test-Path $DeployLog) { Remove-Item $DeployLog -Force -ErrorAction SilentlyContinue }
Start-Transcript -Path $DeployLog -Force | Out-Null

Write-Host "=== Redeploy Catalogador-PythonAPI ==="
Write-Host "Repo source: $RepoSrc"
Write-Host "Destination: $Dest"
Write-Host "Service name: $ServiceName"

function Run-If { param($scriptblock) if (-not $WhatIf) { & $scriptblock } else { Write-Host "[WhatIf] Would run: $scriptblock" } }

# Helper to run a command and throw if it fails
function Run-Command {
    param(
        [Parameter(Mandatory=$true)][string]$Cmd,
        [int]$AllowedExit = 0
    )
    Write-Host "---> $Cmd"
    $proc = Start-Process -FilePath powershell -ArgumentList '-NoProfile','-NonInteractive',"-Command &{ $Cmd }" -Wait -PassThru -WindowStyle Hidden
    if ($proc.ExitCode -ne $AllowedExit) {
        Write-Error "Command failed (exit $($proc.ExitCode)): $Cmd"
        throw "Command failed: $Cmd"
    }
}

try {
    # 1) Stop and remove NSSM service
    if (Get-Command nssm -ErrorAction SilentlyContinue) {
        Write-Host "Stopping and removing service if it exists..."
        if (-not $WhatIf) {
            try { nssm stop $ServiceName 2>$null } catch {}
            try { nssm remove $ServiceName confirm 2>$null } catch {}
        } else {
            Write-Host "[WhatIf] nssm stop $ServiceName ; nssm remove $ServiceName confirm"
        }
    } else {
        Write-Host "nssm not found in PATH. Please install NSSM or place nssm.exe on PATH and re-run."
    }

    # 2) Remove old ProgramData copy and copy fresh repo
    Write-Host "Removing old destination (if any): $Dest"
    if (-not $WhatIf) { Remove-Item $Dest -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host "Copying repository from $RepoSrc to $Dest"
    if (-not (Test-Path $RepoSrc)) { throw "Source repo not found at $RepoSrc" }
    if (-not $WhatIf) { Copy-Item -Path $RepoSrc -Destination $Dest -Recurse -Force }

    # 3) Ensure venv exists (create if missing) and install requirements
    if (-not (Test-Path $VenvPy)) {
        Write-Host "Venv python not found at $VenvPy; creating venv..."
        $sysPythonCmd = (Get-Command python -ErrorAction SilentlyContinue)
        if (-not $sysPythonCmd) { throw "System python not found in PATH. Please install Python 3.8+ and re-run." }
        $sysPython = $sysPythonCmd.Source
        if (-not $WhatIf) {
            & $sysPython -m venv (Join-Path $Dest 'venv')
        } else {
            Write-Host "[WhatIf] $sysPython -m venv $Dest\venv"
        }
    } else {
        Write-Host "Venv found at $VenvPy"
    }

    if (-not (Test-Path $VenvPy)) { throw "Venv python still missing at $VenvPy" }

    Write-Host "Upgrading pip/setuptools/wheel in venv"
    if (-not $WhatIf) { & $VenvPy -m pip install --upgrade pip setuptools wheel }

    if (Test-Path $Req) {
        Write-Host "Installing requirements from $Req"
        if (-not $WhatIf) { & $VenvPy -m pip install -r $Req }
    } else {
        Write-Host "requirements.txt not found at $Req; skipping pip install -r"
    }

    # 4) pip install -e the repo into the venv
    Write-Host "Installing package into venv (editable)"
    if (-not $WhatIf) { & $VenvPy -m pip install -e $Dest }

    Write-Host "Testing import of catalogador.api.main"
    if (-not $WhatIf) {
        try {
            & $VenvPy -c "import importlib; importlib.import_module('catalogador.api.main'); print('IMPORT_OK')"
        } catch {
            Write-Error "Import test failed. See output above."
            throw
        }
    }

    # 5) Create NSSM service
    if (-not (Get-Command nssm -ErrorAction SilentlyContinue)) { Write-Warning "nssm not found; cannot auto-install service. Please install NSSM and re-run." } else {
        $VENV = $VenvPy
        $APPDIR = $Dest
    # The repository exposes the FastAPI app at api.main:app (top-level package 'api'),
    # so point uvicorn there to avoid ModuleNotFoundError for 'catalogador'.
    $ARGS = "-m uvicorn api.main:app --host 127.0.0.1 --port 8000 --log-level info"
        Write-Host "Installing NSSM service: $ServiceName -> $VENV $ARGS"
        if (-not $WhatIf) {
            try {
                nssm install $ServiceName $VENV $ARGS
                nssm set $ServiceName AppDirectory $APPDIR
                nssm set $ServiceName AppStdout "$LogDir\\service_stdout.log"
                nssm set $ServiceName AppStderr "$LogDir\\service_stderr.log"
                nssm set $ServiceName AppRotateBytes 1048576
            } catch {
                Write-Warning "nssm install or configuration failed: $_"
            }
        } else {
            Write-Host "[WhatIf] nssm install $ServiceName $VENV $ARGS"
        }
    }

    # 6) Start service and validate /health
    if (Get-Command nssm -ErrorAction SilentlyContinue) {
        Write-Host "Starting service $ServiceName"
        if (-not $WhatIf) { nssm start $ServiceName } else { Write-Host "[WhatIf] nssm start $ServiceName" }
    } else {
        Write-Host "nssm not available; skipping start step"
    }

    Write-Host "Waiting for service to respond on http://127.0.0.1:8000/health"
    $resp = $null
    for ($i=0; $i -lt 15; $i++) {
        try {
            $resp = Invoke-RestMethod -Uri http://127.0.0.1:8000/health -TimeoutSec 3
            Write-Host "Health OK:" ($resp | ConvertTo-Json -Compress)
            break
        } catch {
            Write-Host "Waiting for service to be ready... ($($i+1)/15)"
            Start-Sleep -Seconds 1
        }
    }

    if (-not $resp) {
        Write-Host "Service did not respond; showing last 200 lines of stderr and stdout logs if available:"
        if (Test-Path (Join-Path $LogDir 'service_stderr.log')) { Get-Content (Join-Path $LogDir 'service_stderr.log') -Tail 200 -ErrorAction SilentlyContinue }
        if (Test-Path (Join-Path $LogDir 'service_stdout.log')) { Get-Content (Join-Path $LogDir 'service_stdout.log') -Tail 200 -ErrorAction SilentlyContinue }
        throw "Service not responding. Check the logs above."
    }

    Write-Host "Redeploy completed successfully."

} catch {
    Write-Error "Redeploy failed: $_"
    exit 1
} finally {
    Stop-Transcript | Out-Null
}
