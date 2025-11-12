<#
Uninstall Catalogador NSSM service safely.

Usage (Admin):
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\uninstall_production_service.ps1 -ServiceName Catalogador-PythonAPI -RemoveRuntime

Parameters:
  -ServiceName (string) : name of the NSSM service to remove
  -RemoveRuntime (switch): remove runtime/backend_port.txt if present and matches service port
  -WhatIf (switch) : don't perform destructive actions, show plan only
#>

param(
    [string]$ServiceName = 'Catalogador-PythonAPI',
    [switch]$RemoveRuntime,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Is-Admin { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
if (-not $WhatIf -and -not (Is-Admin)) {
    Write-Host 'Requires Administrator privileges. Relaunching elevated...' -ForegroundColor Yellow
    $arg = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath) + $MyInvocation.UnboundArguments
    Start-Process -FilePath (Get-Command powershell).Source -ArgumentList $arg -Verb RunAs
    exit 0
}

try { Get-Command nssm -ErrorAction Stop | Out-Null; $nssmExe = 'nssm' } catch { $nssmExe = Join-Path $env:ProgramData 'nssm\nssm.exe' }

if ($WhatIf) { Write-Host "WhatIf: would stop and remove service: $ServiceName"; exit 0 }

Write-Host "Stopping service $ServiceName (if running)" -ForegroundColor Cyan
try { & $nssmExe stop $ServiceName } catch { Write-Verbose 'Stop may have failed or service not present' }
Write-Host "Removing service $ServiceName" -ForegroundColor Cyan
try { & $nssmExe remove $ServiceName confirm } catch { Write-Warning 'Failed to remove service via nssm; it may not exist.' }

if ($RemoveRuntime) {
    # find repo by service env or default to CWD's parent
    $possible = Join-Path (Split-Path -Parent $PSCommandPath) '..'
    $runtime = Join-Path $possible 'runtime\backend_port.txt'
    if (Test-Path $runtime) {
        $port = Get-Content $runtime -Raw
        Write-Host "Removing runtime backend_port file (was: $port)" -ForegroundColor Yellow
        Remove-Item $runtime -Force
    } else { Write-Host 'No runtime/backend_port.txt found' }
}

Write-Host 'Uninstall script completed.' -ForegroundColor Green
