<#
.SYNOPSIS
  Auto-rescue script: libera espacio, hace backup, remueve index.lock si es seguro, y repara gitlink/submodule 'catalogador'.
.NOTES
  Run with -WhatIf first to review actions.
.PARAMETER WhatIf
  Simulate changes (default safe).
.PARAMETER AutoConfirm
  Skip interactive prompts.
.PARAMETER AutoPush
  Attempt to push changes automatically.
.PARAMETER Branch
  Branch to create for the fixes.
.PARAMETER GitHubPAT
  Optional: PAT used if pushing via HTTPS is needed (export to env var GITHUB_PAT instead).
.PARAMETER CreatePR
  If set, attempt to create PR (requires gh CLI or GITHUB_PAT).
#>
param(
  [switch]$WhatIf,
  [switch]$AutoConfirm,
  [switch]$AutoPush,
  [string]$Branch = 'fix/mi-cambio-descripcion/autofix-submodule',
  [string]$GitHubPAT = $env:GITHUB_PAT,
  [switch]$CreatePR
)

function Log { param($m) Write-Host "$(Get-Date -Format o) - $m" }
function Confirm([string]$msg){
  if ($AutoConfirm) { Log "AutoConfirm: $msg"; return $true }
  $r = Read-Host "$msg [Y/N]"
  return ($r -match '^[Yy]')
}

# Helpers
$RepoRoot = (Get-Location).Path
$GitDir = Join-Path $RepoRoot '.git'
$IndexLock = Join-Path $GitDir 'index.lock'
$CatalogadorPath = Join-Path $RepoRoot 'catalogador'
$BackupPath = Join-Path $RepoRoot 'catalogador.backup'
$LogFile = Join-Path $RepoRoot 'tools/auto_rescue_repo.log'

"---- Starting auto-rescue at $(Get-Date)" | Out-File -FilePath $LogFile -Append

# Detect git executable (use full path if git is not in PATH for this session)
$GitExe = $null
try {
  $cmd = Get-Command git -ErrorAction SilentlyContinue
  if ($cmd) { $GitExe = $cmd.Path }
} catch {}
if (-not $GitExe) {
  $candidates = @('C:\Program Files\Git\cmd\git.exe','C:\Program Files\Git\bin\git.exe')
  foreach ($p in $candidates) { if (Test-Path $p) { $GitExe = $p; break } }
}
if ($GitExe) { Log "Using git executable: $GitExe" } else { Log "git not found in PATH; git operations will fail unless you install git or add it to PATH." }

# 1) Check disk free space
$drive = (Get-Item $RepoRoot).PSDrive.Name
$free = (Get-PSDrive -Name $drive).Free
$freeGB = [math]::Round($free / 1GB, 2)
Log "Drive $drive free space: $freeGB GB"

$minRequiredGB = 2
if ($free / 1GB -lt $minRequiredGB) {
  Log "Free space <$minRequiredGB GB; will attempt safe cleanup."
  if (-not $WhatIf -and -not (Confirm "Continuar con limpieza automática para liberar espacio?")) {
    Log "Aborting per user."
    throw "User aborted cleanup"
  }
  # Safe cleanups (dry-run aware)
  $actions = @()

  # 1. Remove python caches and common build dirs
  $candidates = @('.pytest_cache','dist','build','__pycache__','.cache','.venv','.venv*','venv','venv*')
  foreach ($c in $candidates) {
    $p = Join-Path $RepoRoot $c
    if (Test-Path $p) {
      $sz = (Get-ChildItem -Recurse -Force -ErrorAction SilentlyContinue $p | Measure-Object -Property Length -Sum).Sum
      $szGB = if ($sz) { [math]::Round($sz/1GB,3) } else { 0 }
      $actions += @{Path=$p;SizeGB=$szGB}
    }
  }

  Log "Candidates for deletion (safe):"
  $actions | ForEach-Object { Log ("{0}  ~{1}GB" -f $_.Path, $_.SizeGB) }

  if (-not $WhatIf -and (Confirm "Eliminar candidatos mostrados (solo si ocupan espacio significativo)?")) {
    foreach ($a in $actions) {
      try {
        if (Test-Path $a.Path) {
          Log "Removing $($a.Path)"
          Remove-Item -LiteralPath $a.Path -Recurse -Force -ErrorAction Stop
        }
      } catch {
        Log ("Failed to remove {0}: {1}" -f $a.Path, $_.Exception.Message)
      }
    }
  } else {
    Log "Dry-run: no deletion performed."
  }

  # Attempt to empty Recycle Bin (best-effort)
  try {
    if (-not $WhatIf) {
      Log "Emptying Recycle Bin (may require elevation)"
      (New-Object -ComObject Shell.Application).NameSpace(0xA).Items() | ForEach-Object { $_.InvokeVerb("delete") }
    } else {
      Log "Dry-run: would empty Recycle Bin"
    }
  } catch {
    Log ("Recycle bin empty failed: {0}" -f $_.Exception.Message)
  }
}

# 2) Backup 'catalogador' folder (robocopy)
if (Test-Path $CatalogadorPath) {
  Log "Backing up 'catalogador' to $BackupPath (robocopy)"
  $robocopyCmd = @(
    'robocopy',  # uses external exe
    "`"$CatalogadorPath`"",
    "`"$BackupPath`"",
    '/MIR','/Z','/R:2','/W:5','/NFL','/NDL','/NJH','/NJS'
  ) -join ' '
  if ($WhatIf) {
    Log "DRYRUN: $robocopyCmd"
  } else {
    Log "Running robocopy..."
    $rc = & robocopy $CatalogadorPath $BackupPath /MIR /Z /R:2 /W:5 /NFL /NDL /NJH /NJS
    Log "robocopy exit code $rc"
  }
} else {
  Log "'catalogador' folder not found; skipping backup."
}

# 3) Git maintenance
if (-not $WhatIf) {
  try {
    Log "Running 'git gc --aggressive --prune=now' (may take time)"
    if ($GitExe) { & $GitExe gc --aggressive --prune=now 2>&1 | Tee-Object -FilePath $LogFile -Append }
    else { throw "git executable not found" }
  } catch {
    Log "git gc failed: $($_.Exception.Message)"
  }
} else {
  Log "DRYRUN: git gc --aggressive --prune=now"
}

# 4) Handle index.lock
if (Test-Path $IndexLock) {
  Log "Found index.lock at $IndexLock"
  $gitProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'git' }
  if ($gitProcs) {
    Log "Git processes running: $($gitProcs | Select-Object -First 5 | Format-Table -AutoSize | Out-String)"
    if (-not $WhatIf -and -not (Confirm "Hay procesos git en ejecución. Forzar eliminación de index.lock?")) {
      throw "Cannot safely remove index.lock while git processes run."
    }
  }
  if (-not $WhatIf) {
    try {
      Log "Removing index.lock..."
      Remove-Item -LiteralPath $IndexLock -Force -ErrorAction Stop
      Log "index.lock removed"
    } catch {
      Log ("Failed to remove index.lock: {0}" -f $_.Exception.Message)
      throw $_
    }
  } else {
    Log "DRYRUN: would remove $IndexLock"
  }
} else {
  Log "No index.lock present."
}

# 5) Repair or convert gitlink for catalogador
# Detect if catalogador is submodule mapping in .gitmodules
$gitmodules = Join-Path $RepoRoot '.gitmodules'
$hasMapping = $false
if (Test-Path $gitmodules) {
  $gm = Get-Content $gitmodules -ErrorAction SilentlyContinue
  if ($gm -match 'path\s*=\s*catalogador') { $hasMapping = $true }
}
if ($hasMapping) {
  Log ".gitmodules contains mapping for catalogador; will init/sync/update submodule"
  if ($WhatIf) { Log "DRYRUN: git submodule sync && git submodule update --init --recursive catalogador" }
  else {
    if ($GitExe) {
      & $GitExe submodule sync catalogador 2>&1 | Tee-Object -FilePath $LogFile -Append
      & $GitExe submodule update --init --recursive catalogador 2>&1 | Tee-Object -FilePath $LogFile -Append
    } else {
      Log "git not found: cannot init/sync submodule"
    }
  }
} else {
  Log "No .gitmodules mapping for 'catalogador'. Checking index entry type."
  if ($GitExe) { $entry = & $GitExe ls-files --stage catalogador 2>$null } else { $entry = $null }
  if ($entry -and ($entry -match '160000')) {
    Log "catalogador is a gitlink (160000). Will convert to tracked folder in branch $Branch"
    if ($WhatIf) {
      Log "DRYRUN: git checkout -b $Branch; git rm --cached catalogador; git add catalogador; git commit -m 'fix: convert gitlink catalogador to tracked folder'"
    } else {
      # Create branch
      if ($GitExe) { & $GitExe rev-parse --verify $Branch 2>$null } else { $null }
      if ($LASTEXITCODE -ne 0) {
        Log "Creating branch $Branch"
        if ($GitExe) { & $GitExe checkout -b $Branch 2>&1 | Tee-Object -FilePath $LogFile -Append } else { Log "git not found: cannot create branch" }
      } else {
        Log "Switching to existing branch $Branch"
        if ($GitExe) { & $GitExe checkout $Branch 2>&1 | Tee-Object -FilePath $LogFile -Append } else { Log "git not found: cannot checkout branch" }
      }

      # Remove gitlink from index
      Log "git rm --cached catalogador"
  if ($GitExe) { & $GitExe rm --cached -r catalogador 2>&1 | Tee-Object -FilePath $LogFile -Append } else { Log "git not found: cannot git rm --cached" }

      # Re-add folder contents so it's tracked
      Log "git add catalogador"
  if ($GitExe) { & $GitExe add catalogador 2>&1 | Tee-Object -FilePath $LogFile -Append } else { Log "git not found: cannot git add" }

      # Add the autofix script explicitly if present
      if (Test-Path (Join-Path $RepoRoot 'tools/autofix_submodule_and_space.ps1')) {
  if ($GitExe) { & $GitExe add tools/autofix_submodule_and_space.ps1 2>&1 | Tee-Object -FilePath $LogFile -Append }
      }

      # Commit
      Log "Committing conversion"
      $msg = "fix(repo): convert gitlink 'catalogador' to tracked folder; repair index.lock and free space"
  if ($GitExe) { & $GitExe commit -m $msg 2>&1 | Tee-Object -FilePath $LogFile -Append } else { Log "git not found: cannot commit" }
    }
  } else {
    Log "catalogador is not detected as gitlink 160000. Skipping conversion step."
  }
}

# 6) Push changes if requested
if ($AutoPush -and -not $WhatIf) {
  Log "Attempting to push branch $Branch to origin"
  try {
    if ($GitExe) {
      & $GitExe push -u origin $Branch 2>&1 | Tee-Object -FilePath $LogFile -Append
      if ($LASTEXITCODE -ne 0) {
        Log "git push returned non-zero. If using HTTPS with PAT, set GITHUB_PAT env var and re-run or push manually."
        throw "git push failed"
      }
    } else {
      throw "git not found: cannot push"
    }
  } catch {
    Log ("Push failed: {0}" -f $_.Exception.Message)
    throw $_
  }
} elseif ($WhatIf) {
  Log "DRYRUN: would push branch $Branch if AutoPush set."
}

# 7) Create PR (optional)
if ($CreatePR -and -not $WhatIf) {
  # Prefer gh if available
  $gh = Get-Command gh -ErrorAction SilentlyContinue
  if ($gh) {
    Log "Creating PR with gh..."
    gh pr create --fill --base main --head $Branch 2>&1 | Tee-Object -FilePath $LogFile -Append
  } elseif ($GitHubPAT) {
    Log "Creating PR using GitHub API with PAT (note: PAT scope must allow repo:status, repo)."
  # Detect owner/repo
  if ($GitExe) { $remoteInfo = & $GitExe remote get-url origin } else { $remoteInfo = $null }
  $m = if ($remoteInfo) { ($remoteInfo | Select-String -Pattern '[:\/](?<owner>[^\/]+)\/(?<repo>[^\/\.]+)(\.git)?$').Matches } else { @() }
    if ($m.Count -gt 0) {
      $owner = $m[0].Groups['owner'].Value
      $repo = $m[0].Groups['repo'].Value
      $uri = "https://api.github.com/repos/$owner/$repo/pulls"
      $body = @{title="fix: convert catalogador gitlink and repair repo"; head=$Branch; base="main"; body="Automated fix: convert gitlink 'catalogador' to tracked folder and repair index.lock/diskspace. Run CI."} | ConvertTo-Json
      $hdr = @{ Authorization = "token $GitHubPAT"; "User-Agent" = "auto-rescue-script" }
      $resp = Invoke-RestMethod -Uri $uri -Method Post -Headers $hdr -Body $body -ContentType "application/json"
      Log ("PR created: {0}" -f $resp.html_url)
    } else {
      Log "Could not parse remote owner/repo; please create PR manually."
    }
  } else {
    Log "gh CLI not found and no GITHUB_PAT available; cannot create PR automatically."
  }
} elseif ($CreatePR -and $WhatIf) {
  Log "DRYRUN: would create PR if CreatePR set."
}

# 8) Run tests quickly (best-effort)
try {
  if (-not $WhatIf) {
    if (Test-Path (Join-Path $RepoRoot 'venv') -or Test-Path (Join-Path $RepoRoot '.venv')) {
      Log "Running pytest (venv autodetect)"
      python -m pytest -q 2>&1 | Tee-Object -FilePath $LogFile -Append
    } else {
      Log "No venv detected; skipping pytest run."
    }
  } else {
    Log "DRYRUN: Would run pytest"
  }
} catch {
  Log ("pytest failed or not available: {0}" -f $_.Exception.Message)
}

Log "Auto-rescue finished (dry-run=$WhatIf). See $LogFile for details."
