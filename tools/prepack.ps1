<#
    tools/prepack.ps1
    Usage:
        # Check for potential lock-holding processes (no changes):
        .\tools\prepack.ps1

        # Check and force-close known editors/processes that may lock files:
        .\tools\prepack.ps1 -ForceClose

    This script lists common processes (Code, node, electron) that frequently hold
    open handles on packaging outputs. When -ForceClose is provided it will attempt
    to stop them (requires running the script as Administrator for some processes).
#>

[CmdletBinding()]
param(
    [switch]$ForceClose
)

Set-StrictMode -Version Latest
Write-Output "[prepack] Checking for common lock-holders (VS Code / node / electron) before packaging..."

# Find candidate processes
$candidates = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(Code|Code\.exe|node|electron|app-builder).*' }
if ($null -ne $candidates -and $candidates.Count -gt 0) {
    Write-Output "[prepack] Found potential processes that may lock files:"
    $candidates | Select-Object Id, ProcessName, Path | Format-Table -AutoSize
} else {
    Write-Output "[prepack] No obvious lock-holder processes found."
}

if ($ForceClose) {
    Write-Output "[prepack] Force-closing candidate processes..."
    foreach ($p in $candidates) {
        try {
            Write-Output "[prepack] Stopping PID $($p.Id) $($p.ProcessName)"
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Output "[prepack] Could not stop PID $($p.Id): $_"
        }
    }
    Start-Sleep -Seconds 1
    Write-Output "[prepack] Force-close complete."
} else {
    if ($null -ne $candidates -and $candidates.Count -gt 0) {
        Write-Output "[prepack] To avoid file-lock issues, close the listed applications or re-run this script with -ForceClose to close them automatically."
        exit 1
    }
}

Write-Output "[prepack] Prepack checks complete."
