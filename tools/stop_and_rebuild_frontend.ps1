<#
Stop and rebuild frontend helper

Usage (from the repo root):
  pwsh .\tools\stop_and_rebuild_frontend.ps1

What it does:
  - Detects processes likely locking the frontend executable
  - Tries to close them gracefully, then forces termination if needed
  - Waits for the file handle to be released
  - Runs the normal build script (scripts/build_all.ps1)

This is safe to run locally. It requires running PowerShell with permission
to stop processes (same user that launched them). The script avoids killing
unrelated processes whenever possible by matching the exe path or process
name 'CatalogadorEsSalud'.
#>

param(
    [switch]$ForceKill,
    [string]$ExeRelativePath = "Catalogador.App\bin\Release\net8.0-windows\CatalogadorEsSalud.exe",
    [int]$WaitSeconds = 10
)

Set-StrictMode -Version Latest
Try {
    Push-Location -ErrorAction Stop (Split-Path -Parent $MyInvocation.MyCommand.Definition)
} Catch {
    # If we cannot push the script folder, continue - we will resolve from current dir
}

$repoRoot = Resolve-Path ".." | Select-Object -ExpandProperty Path
Set-Location $repoRoot

$exeFullPath = Resolve-Path -Path $ExeRelativePath -ErrorAction SilentlyContinue
if (-not $exeFullPath) {
    Write-Host "Warning: executable not found at path $ExeRelativePath (relative to repo root)." -ForegroundColor Yellow
    Write-Host "Proceeding to look for running processes named 'CatalogadorEsSalud'."
    $exeFullPath = $null
} else {
    $exeFullPath = $exeFullPath.Path
}

function Get-LockingProcesses {
    param([string]$path)
    $results = @()

    # 1) try to find by process name
    $byName = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -in @('CatalogadorEsSalud') }
    if ($byName) { $results += $byName }

    # 2) try to find processes whose MainModule path exactly matches (may throw on protected processes)
    if ($path) {
        foreach ($p in Get-Process -ErrorAction SilentlyContinue) {
            try {
                if ($p.MainModule -and ($p.MainModule.FileName -eq $path)) { $results += $p }
            } catch {
                # ignore processes we can't inspect
            }
        }
    }

    # uniq by Id
    $results | Sort-Object Id -Unique
}

$procs = Get-LockingProcesses -path $exeFullPath

if (-not $procs -or $procs.Count -eq 0) {
    Write-Host "No processes named 'CatalogadorEsSalud' or matching the exe path were found." -ForegroundColor Green
} else {
    Write-Host "Found the following candidate process(es) blocking the exe:" -ForegroundColor Cyan
    $procs | Format-Table Id, ProcessName, StartTime -AutoSize

    foreach ($p in $procs) {
        try {
            Write-Host "Attempting graceful close for PID $($p.Id) ($($p.ProcessName))..." -ForegroundColor Yellow
            $closed = $false
            try {
                $closed = $p.CloseMainWindow()
            } catch {
                $closed = $false
            }

            if ($closed) {
                Write-Host "CloseMainWindow() sent. Waiting up to $WaitSeconds s for exit..." -ForegroundColor Yellow
                for ($i=0; $i -lt $WaitSeconds; $i++) {
                    Start-Sleep -Seconds 1
                    if ($p.HasExited) { break }
                }
            }

            if (-not $p.HasExited) {
                if ($ForceKill.IsPresent) {
                    Write-Host "Force-stopping PID $($p.Id)" -ForegroundColor Red
                    Stop-Process -Id $p.Id -Force -ErrorAction Stop
                } else {
                    Write-Host "Process PID $($p.Id) did not exit. Use -ForceKill to force termination, or run: Stop-Process -Id $($p.Id) -Force" -ForegroundColor Yellow
                }
            } else {
                Write-Host "Process $($p.Id) exited." -ForegroundColor Green
            }
        } catch {
            Write-Host "Error stopping PID $($p.Id): $_" -ForegroundColor Red
        }
    }
}

# Wait briefly for file handle to be released
Write-Host "Waiting briefly for OS to release file handles..." -ForegroundColor Cyan
Start-Sleep -Seconds 2

function Test-FileUnlocked {
    param([string]$file)
    if (-not (Test-Path $file)) { return $true }
    try {
        $fs = [System.IO.File]::Open($file, 'Open', 'Read', 'None')
        $fs.Close()
        return $true
    } catch {
        return $false
    }
}

if ($exeFullPath) {
    $maxWait = 10
    $waited = 0
    while (-not (Test-FileUnlocked -file $exeFullPath) -and $waited -lt $maxWait) {
        Write-Host "File still locked, waiting... ($waited/$maxWait)" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        $waited++
    }
    if ($waited -ge $maxWait) {
        Write-Host "Warning: file still appears locked after waiting. Build may still fail." -ForegroundColor Red
    } else {
        Write-Host "File looks unlocked or not present. Proceeding to build." -ForegroundColor Green
    }
} else {
    Write-Host "No exe path to test; proceeding to build." -ForegroundColor Yellow
}

# Run the high-level build script using pwsh to ensure consistent environment
Write-Host "Running build script: scripts/build_all.ps1" -ForegroundColor Cyan
try {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_all.ps1
    $rc = $LASTEXITCODE
    if ($rc -ne 0) { throw "Build script exited with code $rc" }
} catch {
    Write-Host "Build failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Build completed (exit code 0)." -ForegroundColor Green

Pop-Location 2>$null

exit 0
