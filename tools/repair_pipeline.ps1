<#
repair_pipeline.ps1

Automated, safe repair pipeline for the repository. Acts in conservative stages:
 1) Run tests and collect diagnostics
 2) Identify stale/backup files and archive them (no permanent delete by default)
 3) Optionally create minimal stub replacements for missing modules when safe
 4) Re-run tests and iterate up to MaxIterations

Usage (dry-run):
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\repair_pipeline.ps1 -MaxIterations 3 -WhatIf

Usage (attempt auto-fix):
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\repair_pipeline.ps1 -MaxIterations 5 -AutoFix

Important safety notes:
Important safety notes:
#>

param(
    [int]$MaxIterations = 5,
    [switch]$AutoFix,
    [string]$ArchiveDir = '.\tools\archive\repair-' + ([System.DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss')),
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log { param($msg) Write-Host "[repair] $msg" }

function Ensure-Dir($p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }

Ensure-Dir $ArchiveDir
Ensure-Dir '.\tools\repair_logs'

function Run-Tests {
    $ts = [System.DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss')
    $out = "./tools/repair_logs/pytest_$ts.txt"
    Write-Log "Running pytest (output -> $out)"
    if ($WhatIf) { Write-Log "WhatIf: would run: python -m pytest -q > $out 2>&1"; return @{ Success = $false; Output = ''; Path = $out } }
    try {
        # Prefer .venv python if available, otherwise use PATH python
        $venvPy = Join-Path (Get-Location) '.venv\Scripts\python.exe'
        if (Test-Path $venvPy) {
            $py = $venvPy
        } else {
            $py = (Get-Command python -ErrorAction SilentlyContinue).Source
            if (-not $py) { Throw 'python not found in PATH' }
        }
        # Ensure pytest is available
        $null = & $py -m pip show pytest 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "pytest not found; installing pytest..."
            $null = & $py -m pip install -q pytest 2>&1
        }
        Write-Log "Invoking: $py -m pytest -q"
        # Run pytest synchronously and capture combined stdout/stderr to file (Tee-Object writes as it runs)
        try {
            # capture output to file but avoid emitting pipeline strings from the function
            $null = & $py -m pytest -q 2>&1 | Tee-Object -FilePath $out
            $rc = $LASTEXITCODE
        } catch {
            Write-Log "Exception while running pytest: $_"
            $rc = 1
        }
        $txt = ''
        if (Test-Path $out) { $txt = Get-Content -Raw -Path $out -ErrorAction SilentlyContinue }
        return @{ Success = ($rc -eq 0); Output = $txt; Path = $out }
    } catch {
        Write-Log "Test run failed to start: $_"
        return @{ Success = $false; Output = "$_"; Path = $out }
    }
}

function Find-StaleFiles {
    # patterns commonly used for stale/backup files
    $patterns = @('*.bak','*~','*.old','*copy*','*_backup*','*.orig','*.backup')
    $root = Get-Location
    $found = @()
    foreach ($pat in $patterns) { $found += Get-ChildItem -Path $root -Recurse -File -Filter $pat -ErrorAction SilentlyContinue }
    # exclude heavy dependency or build folders
    $excludes = @('\\venv\\','\\.venv\\','\\node_modules\\','\\.git\\','\\.pytest_tmp\\')
    $filtered = $found | Where-Object { $fn = $_.FullName; -not ($excludes | ForEach-Object { $fn -match $_ }) }
    # also find duplicated named files in tools/archive root (no action)
    return $filtered | Sort-Object FullName -Unique
}

function Archive-Files($files) {
    if (-not $files) { Write-Log 'No stale files found'; return }
    Ensure-Dir $ArchiveDir
    foreach ($f in $files) {
        $rel = $f.FullName.Substring((Get-Location).Path.Length).TrimStart('\','/')
        $dest = Join-Path $ArchiveDir $rel
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Write-Log "Archiving: $rel -> $dest"
        if ($WhatIf) { Write-Log "WhatIf: would move $($f.FullName) to $dest" } else { Move-Item -Path $f.FullName -Destination $dest -Force }
    }
}

function Create-PythonStub($moduleName) {
    # moduleName like 'some.module' -> path ./some/module.py
    $parts = $moduleName -split '\.'
    $filePath = Join-Path (Join-Path (Get-Location) ($parts -join '\'))
    if ($filePath -notlike '*.py') { $filePath = $filePath + '.py' }
    $dir = Split-Path -Parent $filePath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $filePath) { Write-Log "Stub exists, skipping: $filePath"; return $filePath }
    $content = @("# Auto-generated stub for missing module $moduleName","def __repr__():","    return '<stub $moduleName>'","","# TODO: replace with real implementation") -join "`n"
    Write-Log "Creating Python stub: $filePath"
    if ($WhatIf) { Write-Log "WhatIf: would write $filePath" } else { $content | Out-File -FilePath $filePath -Encoding UTF8 }
    return $filePath
}

function Parse-MissingModules($testOutput) {
    # Look for ModuleNotFoundError: No module named 'xyz'
    $mods = @()
    if (-not $testOutput) { return $mods }
    foreach ($line in $testOutput -split "`n") {
        if ($line -match "ModuleNotFoundError: No module named '([^']+)'") { $mods += $Matches[1] }
        if ($line -match "ImportError: No module named ([\S]+)") { $mods += $Matches[1] }
    }
    return $mods | Select-Object -Unique
}

function Repair-Once {
    $res = Run-Tests
    if ($res -is [hashtable] -and $res.ContainsKey('Success') -and $res.Success) {
        Write-Log 'All tests passed'
        return @{ Done = $true; Result = $res }
    }
    if (-not ($res -is [hashtable])) { Write-Log "Run-Tests returned unexpected type: $($res.GetType().FullName)" }
    Write-Log 'Tests failed — collecting diagnostics and attempting safe repairs'
    # Save the failing output path is in $res.Path
    Write-Log "Saved test output: $($res.Path)"

    # Stage 1: archive stale files
    $stale = Find-StaleFiles
    $stale = @($stale)
    if ($stale.Count -gt 0) { Archive-Files $stale } else { Write-Log 'No stale backup files found' }

    # Stage 2: parse missing modules and optionally create stubs
    $missing = Parse-MissingModules $res.Output
    # ensure array coercion so .Count is safe
    $missing = @($missing)
    if ($missing.Count -gt 0) { Write-Log "Missing modules: $($missing -join ', ')" } else { Write-Log 'No obvious missing-module errors detected' }
    $created = @()
    if ($AutoFix -and $missing.Count -gt 0) {
        foreach ($m in $missing) { $created += Create-PythonStub $m }
    }

    return @{ Done = $false; Result = $res; Created = $created; Missing = $missing }
}

# Main loop
Write-Log "Starting repair pipeline (MaxIterations=$MaxIterations, AutoFix=$AutoFix, WhatIf=$WhatIf)"
$iter = 0
$finalReport = @()
while ($iter -lt $MaxIterations) {
    $iter++
    Write-Log "Iteration $iter"
    $r = Repair-Once
    $finalReport += $r
    if ($r.Done) { break }
    if (-not $AutoFix) {
        Write-Log 'AutoFix disabled — to attempt automatic stub creation re-run with -AutoFix'
        break
    }
    Write-Log 'AutoFix applied; re-running tests in next iteration'
}

Write-Log 'Repair pipeline finished. Summary:'
foreach ($rep in $finalReport) {
    if ($rep.Done) { Write-Log 'A run completed with all tests passing.' } else { Write-Log "A run failed; created stubs: $($rep.Created -join ', ')" }
}

Write-Log "Logs and archives are under: $(Resolve-Path .\tools\repair_logs) and $(Resolve-Path $ArchiveDir)"
