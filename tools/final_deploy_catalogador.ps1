<#
Final deploy wrapper: runs auto_redeploy_catalogador.ps1 -Mode B -Force after confirming admin and user consent.
Usage (run as Administrator):
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\tools\final_deploy_catalogador.ps1
<#
Final deploy wrapper: runs auto_redeploy_catalogador.ps1 -Mode B -Force after confirming admin and user consent.
Usage (run as Administrator):
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\tools\final_deploy_catalogador.ps1
#>

function Test-Administrator {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# If not running as Administrator, re-launch this script elevated so the user
# only needs to run the script once. This will prompt UAC.
if (-not (Test-Administrator)) {
    Write-Host "Not running as Administrator - relaunching elevated to continue..." -ForegroundColor Yellow
    # Prefer pwsh from $PSHOME, fallback to powershell.exe or 'powershell'
    $psCandidate1 = Join-Path $PSHOME 'pwsh.exe'
    $psCandidate2 = Join-Path $PSHOME 'powershell.exe'
    if (Test-Path $psCandidate1) { $ps = $psCandidate1 }
    elseif (Test-Path $psCandidate2) { $ps = $psCandidate2 }
    else { $ps = 'powershell' }
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    # Launch elevated using the repository root as working directory so the elevated session runs from the repo
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = Split-Path -Parent $scriptDir
    Start-Process -FilePath $ps -ArgumentList $arguments -WorkingDirectory $repoRoot -Verb RunAs
    exit 0
}

$consent = Read-Host "This will perform a production deploy (backup + replace + venv + pip install + NSSM). Type 'YES' to continue"
if ($consent -ne 'YES') {
    Write-Host "Aborting. No changes made." -ForegroundColor Yellow
    exit 0
}

$script = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'auto_redeploy_catalogador.ps1'
if (-not (Test-Path $script)) { Write-Error "Missing auto-redeploy script: $script"; exit 2 }

Write-Host "Running: $script -Mode B -Force" -ForegroundColor Cyan
& $script -Mode B -Force

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deploy script exited with code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "Deploy script completed. Check service status and logs." -ForegroundColor Green
