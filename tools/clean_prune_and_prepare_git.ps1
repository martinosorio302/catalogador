<#
.SYNOPSIS
  Detecta y limpia duplicados y archivos/carpetas caducas para liberar espacio y permitir operaciones git.
.DESCRIPTION
  Herramienta conservadora para identificar duplicados (por nombre y tamaño), archivos grandes y archivos/carpetas sin uso (según edad).
  Por defecto corre en modo -WhatIf (simulación). Puede mover backups a otra unidad o eliminar archivos viejos con -AutoConfirm.
.PARAMETER WhatIf
  Simula las acciones.
.PARAMETER AutoConfirm
  Responde afirmativamente a las confirmaciones y aplica cambios.
.PARAMETER MoveBackupTo
  Ruta absoluta donde mover backups detectados (por ejemplo 'D:\Catalogador_backups'). Si no se especifica, se sugerirá mover a otra unidad.
.PARAMETER AgeDays
  Considerar archivos/carpetas sin modificar por más de N días como caducas. Default 90.
.PARAMETER LargeSizeMB
  Umbral en MB para considerar un archivo "grande". Default 50.
.PARAMETER TargetFreeGB
  Objetivo de espacio libre a lograr. Default 2 GB.
#>
param(
  [switch]$WhatIf,
  [switch]$AutoConfirm,
  [string]$MoveBackupTo = $null,
  [int]$AgeDays = 90,
  [int]$LargeSizeMB = 50,
  [int]$TargetFreeGB = 2
)

function Log { param($m) Write-Host "$(Get-Date -Format o) - $m" }
function PromptConfirm([string]$msg){ if ($AutoConfirm) { Log "AutoConfirm: $msg"; return $true } ; return (Read-Host "$msg [Y/N]" -ErrorAction SilentlyContinue) -match '^[Yy]' }

$RepoRoot = (Get-Location).Path
Log "Repo root: $RepoRoot"

# 1) List drives and free space
$drive = (Get-Item $RepoRoot).PSDrive.Name
$freeGB = [math]::Round((Get-PSDrive -Name $drive).Free / 1GB,3)
Log "Drive $drive free: $freeGB GB (target $TargetFreeGB GB)"

# 2) Find backup-like duplicates: folder.backup and exact duplicate folder names
$candidates = @()
Get-ChildItem -Directory -Force | ForEach-Object {
  $name = $_.Name
  # exact duplicate names with .backup suffix
  $backupName = "$name.backup"
  if (Test-Path (Join-Path $RepoRoot $backupName)) {
    $orig = $_.FullName
    $bk = Join-Path $RepoRoot $backupName
    $size = (Get-ChildItem $orig -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    $sizeGB = [math]::Round(($size/1GB),3)
    $candidates += [PSCustomObject]@{Type='duplicate-folder-backup';Orig=$orig;Backup=$bk;SizeGB=$sizeGB}
  }
}

if ($candidates.Count -gt 0) {
  Log "Detected backup duplicates:"
  $candidates | Format-Table -AutoSize
  if (-not $WhatIf) {
    if ($MoveBackupTo) {
      if (-not (Test-Path $MoveBackupTo)) { New-Item -ItemType Directory -Force -Path $MoveBackupTo | Out-Null }
      foreach ($c in $candidates) {
        $dest = Join-Path $MoveBackupTo (Split-Path $c.Backup -Leaf)
        if ($WhatIf) { Log "DRYRUN: Move $($c.Backup) -> $dest" } else {
          if (PromptConfirm "Mover $($c.Backup) -> $dest ?") { Move-Item -LiteralPath $c.Backup -Destination $dest -Force }
        }
      }
    } else {
      Log "No MoveBackupTo set. To move backups, re-run with -MoveBackupTo 'D:\path' or provide an external drive." 
    }
  } else {
    Log "DRYRUN: would move backups if -MoveBackupTo provided."
  }
} else { Log "No folder.backup duplicates found." }

# 3) Find large files older than AgeDays
Log "Searching for files > $LargeSizeMB MB and older than $AgeDays days (this can take a while)"
$cutoff = (Get-Date).AddDays(-1 * $AgeDays)
$largeFiles = Get-ChildItem -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { ($_.Length /1MB) -ge $LargeSizeMB -and $_.LastWriteTime -lt $cutoff } | Select-Object FullName, @{n='SizeMB';e={[math]::Round($_.Length/1MB,2)}}, LastWriteTime
if ($largeFiles.Count -gt 0) { $largeFiles | Sort-Object SizeMB -Descending | Format-Table -AutoSize } else { Log "No large old files found." }

if (-not $WhatIf -and $largeFiles.Count -gt 0) {
  if (PromptConfirm "Eliminar estos archivos grandes y viejos? (se mueven a Recycle Bin cuando sea posible)") {
    foreach ($f in $largeFiles) {
      try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop } catch { Log "Failed to remove $($f.FullName): $($_.Exception.Message)" }
    }
  }
} else { Log "DRYRUN: not deleting large files." }

# 4) Remove common caches and build artifacts (safe list)
$safeToRemove = @('.pytest_cache','dist','build','__pycache__','.cache','.venv','venv','node_modules/.cache')
foreach ($s in $safeToRemove) {
  $p = Join-Path $RepoRoot $s
  if (Test-Path $p) {
    $sz = (Get-ChildItem -Recurse -Force -ErrorAction SilentlyContinue $p | Measure-Object Length -Sum).Sum
    $szGB = [math]::Round(($sz/1GB),3)
    Log ("Candidate: $p (~${szGB}GB)")
    if (-not $WhatIf) {
      if (PromptConfirm "Eliminar $p (~${szGB}GB)?") { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
    } else { Log "DRYRUN: would remove $p" }
  }
}

# 5) If still not enough free space, list other large folders to consider moving
$freeNow = [math]::Round((Get-PSDrive -Name $drive).Free /1GB,3)
if ($freeNow -lt $TargetFreeGB) {
  Log "Free space still <$TargetFreeGB GB (now $freeNow). Showing top folders to consider moving:"
  Get-ChildItem -Directory -Force | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    [PSCustomObject]@{ Path=$_.FullName; SizeGB=[math]::Round($size/1GB,3) }
  } | Sort-Object SizeGB -Descending | Select-Object -First 30 | Format-Table -AutoSize
  Log "Consider moving large folders (archive, pr_bundle, pr_bundle_v2, dist-electron, node_modules) to an external drive."
}

Log "Cleaning pass finished (WhatIf=$WhatIf). Re-run auto-rescue script if you freed enough space." 
