<#
Rollback helper: restores the most recent backup created by auto_redeploy_catalogador.ps1
Usage (Administrator):
  .\rollback_catalogador.ps1
#>

param(
  [switch]$DryRun
)

$ProgramDataRoot = 'C:\ProgramData\Catalogador\python_api'

function Require-Admin {
  if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to perform this operation. Run PowerShell as Administrator."
    exit 1
  }
}

Require-Admin

if (-not (Test-Path $ProgramDataRoot)) { Write-Error "Destination not present: $ProgramDataRoot"; exit 2 }

$backups = Get-ChildItem -Path (Split-Path $ProgramDataRoot) -Directory -Filter "$(Split-Path $ProgramDataRoot -Leaf).backup.*" | Sort-Object LastWriteTime -Descending
if (-not $backups) { Write-Error "No backups found to restore."; exit 3 }

Write-Host "Found backups:" -ForegroundColor Cyan
foreach ($b in $backups) { Write-Host " - $($b.FullName)" }

if ($DryRun.IsPresent) { Write-Host "Dry-run: not restoring. Use without -DryRun to perform restore."; exit 0 }

$latest = $backups[0].FullName
Write-Host "Restoring backup: $latest -> $ProgramDataRoot" -ForegroundColor Cyan
robocopy $latest $ProgramDataRoot /MIR /COPY:DAT /R:1 /W:1 /NFL /NDL | Out-Null
Write-Host "Restore completed." -ForegroundColor Green
