<#
Autofix script: diagnose and fix 'catalogador' gitlink/submodule without mapping,
handle .git/index.lock / Out of diskspace, backup folder, and convert to tracked folder

USAGE (run locally in PowerShell):
  - Open PowerShell as your regular user (do NOT run in C:\Windows\System32)
  - cd to the repo root: Set-Location 'C:\Users\USER\Desktop\Catalogador'
  - Inspect script, then run: .\tools\autofix_submodule_and_space.ps1 -WhatIf
  - Remove -WhatIf once you reviewed the planned operations.

This script is conservative: it creates a backup, asks for confirmations for destructive
operations, logs actions to autofix.log and exits if disk space is too low.

# Parameters
param(
  [switch]$WhatIf,
  [string]$RepoRoot = "C:\Users\USER\Desktop\Catalogador",
  [string]$TargetBranch = "fix/mi-cambio-descripcion/autofix-submodule",
  [string]$KeepAsSubmoduleUrl = $null  # if provided, attempt to restore as submodule with this URL
)

Set-StrictMode -Version Latest
Push-Location $RepoRoot

function Log { param($m) $t = Get-Date -Format o; "$t $m" | Out-File -FilePath .\autofix.log -Append }

function Confirm-Or-Exit { param($msg) if ($WhatIf) { Write-Host "[WHATIF] $msg" -ForegroundColor Yellow; return } if (-not (Read-Host "$msg (y/n)") -match '^[Yy]') { Write-Host 'Aborting as requested'; Exit 1 } }

Log "Starting autofix script"
Write-Host "Autofix: diagnosing repo in $RepoRoot" -ForegroundColor Cyan

# 1) basic checks
Write-Host '1) Git availability and repo root checks' -ForegroundColor Cyan
try { $git = Get-Command git -ErrorAction Stop } catch { Write-Host 'git not found in PATH. Install Git for Windows and re-run.' -ForegroundColor Red; Exit 1 }
Write-Host ("git: {0}" -f (& git --version))

if (-not (Test-Path "$RepoRoot\.git")) { Write-Host "This directory does not look like a git repo: $RepoRoot" -ForegroundColor Red; Exit 1 }

Write-Host 'Current branch/status:'; git status -s -b | Write-Host
Write-Host 'List .gitmodules (if present):'
if (Test-Path .gitmodules) { Get-Content .gitmodules | Write-Host } else { Write-Host '(no .gitmodules found)' }

Write-Host 'Submodule status (if any):'; git submodule status --recursive 2>&1 | Write-Host
Write-Host 'catalogador index entry:'; git ls-files --stage catalogador 2>$null | Write-Host

# 2) Disk space check
$freeMb = (Get-PSDrive C).Free / 1MB
Write-Host ("Free space on C: {0} MB" -f [math]::Round($freeMb,1))
if ($freeMb -lt 200) {
  Write-Host 'Less than 200 MB free. Attempting non-destructive cleanup steps...' -ForegroundColor Yellow
  Log 'Low disk space detected. Running git gc --auto and cleaning user temp.'
  try { git gc --auto 2>&1 | Out-String | Write-Host } catch { Write-Host 'git gc failed or not enough permissions' }
  $uTemp = $env:TEMP
  Write-Host "User TEMP: $uTemp"
  Confirm-Or-Exit "Attempt to remove files from $uTemp? This may delete local temp files."
  try { Get-ChildItem -Path $uTemp -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PsIsContainer } | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } } catch { }
  $freeMb = (Get-PSDrive C).Free / 1MB
  Write-Host ("Free after cleanup: {0} MB" -f [math]::Round($freeMb,1))
  if ($freeMb -lt 150) { Write-Host 'Disk space still low. Please free space and re-run.' -ForegroundColor Red; Exit 1 }
}

# 3) Backup folder
if (-not (Test-Path catalogador.backup)) {
  Write-Host 'Creating backup: catalogador.backup (robocopy)'; Log 'Creating backup catalogador.backup'
  if ($WhatIf) { Write-Host "[WHATIF] robocopy catalogador catalogador.backup /E /COPYALL" } else {
    $rc = Start-Process -FilePath robocopy -ArgumentList 'catalogador','catalogador.backup','/E','/COPYALL','/R:1','/W:1' -Wait -NoNewWindow -PassThru
    if ($rc.ExitCode -ge 8) { Write-Host 'robocopy reported an error; inspect output' -ForegroundColor Red; Log 'Robocopy exit code ' + $rc.ExitCode }
  }
} else { Write-Host 'Backup already exists: catalogador.backup' }

# 4) Create safe branch
Write-Host ("Creating/checkout branch {0}" -f $TargetBranch)
if ($WhatIf) { Write-Host "[WHATIF] git checkout -B $TargetBranch" } else { git fetch origin; git checkout -B $TargetBranch }

# 5) Remove index locks if present (and no git process running)
if (Test-Path .git\index.lock) {
  Write-Host '.git/index.lock exists; checking for git processes' -ForegroundColor Yellow
  $p = Get-Process -Name git -ErrorAction SilentlyContinue
  if ($p) { Write-Host 'Found git process running; aborting to avoid corruption' -ForegroundColor Red; Exit 1 }
  Confirm-Or-Exit 'Remove .git/index.lock now?'
  if (-not $WhatIf) { Remove-Item .git\index.lock -Force; Log 'Removed .git/index.lock' }
}

# 6) Decide conversion or restore
$hasMapping = $false
if (Test-Path .gitmodules) {
  $gm = Get-Content .gitmodules -Raw
  if ($gm -match '\[submodule "catalogador"\]') { $hasMapping = $true }
}

if ($hasMapping -and -not $KeepAsSubmoduleUrl) {
  Write-Host 'Found .gitmodules mapping for catalogador. Attempting to init submodule.' -ForegroundColor Cyan
  if ($WhatIf) { Write-Host "[WHATIF] git submodule sync --recursive; git submodule update --init --recursive catalogador" } else { git submodule sync --recursive; git submodule update --init --recursive catalogador }
  # attempt to enter submodule and push changes if any
  if (Test-Path catalogador) {
    Push-Location catalogador
    Write-Host 'Inside submodule: status'; git status -s -b | Write-Host
    # If there are local changes in submodule, commit them here
    if ((git status --porcelain) -ne '') {
      Confirm-Or-Exit 'Commit local changes inside submodule?'
      if (-not $WhatIf) { git add tools/*.ps1; git commit -m 'fix(ps1): format exception messages with -f'; git push -u origin HEAD }
    }
    Pop-Location
  }
  Write-Host 'Submodule init attempted. Now update parent pointer.'
  if (-not $WhatIf) { git add catalogador; git commit -m 'chore: update submodule pointer for catalogador' } 
  if (-not $WhatIf) { git push -u origin HEAD }
  Write-Host 'Done with submodule path' -ForegroundColor Green
  Log 'Submodule path handled via .gitmodules mapping flow'
  Exit 0
}

# Default: convert the gitlink to tracked folder (case: no mapping in .gitmodules)
Write-Host 'No .gitmodules mapping found for catalogador — converting gitlink into normal tracked folder' -ForegroundColor Cyan
Confirm-Or-Exit 'Proceed to convert catalogador gitlink into a normal folder tracked by parent repo?'

if (-not $WhatIf) {
  try {
    git rm --cached catalogador
  } catch { Write-Host 'git rm --cached failed; ensure index.lock removed and sufficient disk space' -ForegroundColor Red; Log 'git rm --cached failed: ' + $_.Exception.Message; Exit 1 }
  if (Test-Path .git\modules\catalogador) { Remove-Item -Recurse -Force .git\modules\catalogador }
  if (Test-Path .gitmodules) {
    $content = Get-Content .gitmodules -Raw
    $new = ($content -replace '(?ms)^\[submodule "catalogador"\].*?(?=(^\[|$))','')
    Set-Content .gitmodules -Value $new
    git add .gitmodules
  }
  git add catalogador
  git add tools\*.ps1
  git commit -m "chore: convert catalogador gitlink -> tracked folder; fix PS1 messages"
  git push -u origin HEAD
  Write-Host 'Conversion complete — parent repository now tracks catalogador files directly.' -ForegroundColor Green
  Log 'Converted gitlink to tracked folder and pushed.'
}

Pop-Location
Log 'Autofix script completed'
Write-Host 'Autofix finished. Review ./autofix.log for details.' -ForegroundColor Cyan

# End of script
