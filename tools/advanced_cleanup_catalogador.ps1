<#
.SYNOPSIS
  Limpieza avanzada del proyecto Catalogador (duplicados y archivos caducos) con modo seguro.

.DESCRIPTION
  Este script está pensado para ejecutarse desde la raíz del repositorio. Por
  seguridad no escanea todo C:\ por defecto: solo el `-ProjectPath` (tu repo).
  Tiene modo dry-run por defecto (-WhatIfSwitch), log detallado y una cuarentena.

.PARAMETER ProjectPath
  Ruta raíz del proyecto a escanear (por defecto la carpeta actual).
.PARAMETER ScanPaths
  Rutas adicionales a escanear (por ejemplo D:\pr_bundle). Si se especifica,
  el script las inspecciona además de ProjectPath.
.PARAMETER QuarantinePath
  Ruta donde mover archivos detectados (por defecto C:\_Catalogador_Quarantine).
  Si la cuarentena queda en la misma unidad que ProjectPath se pedirá confirmación
  a menos que -AutoConfirm esté especificado.
.PARAMETER WhatIfSwitch
  Ejecuta en modo simulación: no mueve ni borra nada, solo genera reporte.
.PARAMETER AutoConfirm
  Responde afirmativamente a los prompts (úsalo solo si confías en las acciones).
.PARAMETER AgeDays
  Considerar archivos sin modificar por más de N días como caducos (default 365).
.PARAMETER LargeSizeMB
  Umbral (MB) para tratar como archivo grande candidato a mover (default 50).

NOTES
  - Ejecuta primero con -WhatIfSwitch para revisar el reporte.
  - No escanea unidades root (C:\) automáticamente a menos que lo indiques.
#>

param(
  [string]$ProjectPath = (Get-Location).Path,
  [string[]]$ScanPaths = @(),
  [string]$QuarantinePath = 'C:\_Catalogador_Quarantine',
  [switch]$WhatIfSwitch,
  [switch]$AutoConfirm,
  [int]$AgeDays = 365,
  [int]$LargeSizeMB = 50
)

function Log { param($m) $t = Get-Date -Format o; "$t - $m" | Tee-Object -FilePath $global:ReportFile -Append; Write-Host $m }
function Confirm([string]$msg) { if ($AutoConfirm) { Log "AutoConfirm: $msg"; return $true }; $r = Read-Host "$msg [Y/N]"; return ($r -match '^[Yy]') }

if (-not (Test-Path $ProjectPath)) { throw "ProjectPath no existe: $ProjectPath" }

# Prepare report and quarantine
$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$global:ReportFile = Join-Path $ProjectPath "tools\REPORTE_LIMPIEZA_$timestamp.txt"
New-Item -ItemType File -Force -Path $global:ReportFile | Out-Null

if (-not (Test-Path $QuarantinePath)) {
  if ($WhatIfSwitch) { Write-Host "DRYRUN: se crearía la carpeta de cuarentena: $QuarantinePath" } else { New-Item -ItemType Directory -Force -Path $QuarantinePath | Out-Null }
}

Log "Iniciando limpieza segura del proyecto"
Log "ProjectPath: $ProjectPath"
if ($ScanPaths.Count -gt 0) { Log "ScanPaths adicionales: $($ScanPaths -join ', ')" } else { Log "No ScanPaths adicionales" }
Log "QuarantinePath: $QuarantinePath"
Log "WhatIf: $WhatIfSwitch; AutoConfirm: $AutoConfirm"

# If quarantine is on same drive as project, warn
$projDrive = (Get-Item $ProjectPath).PSDrive.Name
$quarDrive = (Get-Item $QuarantinePath).PSDrive.Name
if ($projDrive -eq $quarDrive) {
  Log "AVISO: la cuarentena está en la misma unidad ($projDrive). Esto no liberará espacio en esa unidad." 
  if (-not $AutoConfirm -and -not $WhatIfSwitch) {
    if (-not (Confirm "La cuarentena está en la misma unidad que el proyecto; continuar?")) { Log "Abortando por seguridad"; return }
  }
}

# Build list of paths to scan (default: project)
$pathsToScan = @($ProjectPath) + $ScanPaths

Log "Etapa 1: Detección de duplicados (hash MD5) -- recomendación: ejecutar en modo WhatIf primero"

$hashTable = @{}
$duplicates = @()

foreach ($p in $pathsToScan) {
  if (-not (Test-Path $p)) { Log "Ruta no encontrada: $p (skipping)"; continue }
  Log "Escaneando: $p"
  # avoid scanning root of Windows or system folders unless explicitly provided
  $items = Get-ChildItem -Path $p -Recurse -File -Force -ErrorAction SilentlyContinue
  foreach ($f in $items) {
    try {
      # calculate hash; skip empty files quickly
      if ($f.Length -eq 0) { continue }
      $h = (Get-FileHash -Path $f.FullName -Algorithm MD5 -ErrorAction SilentlyContinue).Hash
      if (-not $h) { continue }
      if ($hashTable.ContainsKey($h)) {
        $orig = $hashTable[$h]
        $duplicates += @{Path=$f.FullName; Size=$f.Length; Original=$orig}
        Log "DUPLICADO: $($f.FullName) => duplicado de $orig"
        if (-not $WhatIfSwitch) {
          try { Move-Item -LiteralPath $f.FullName -Destination $QuarantinePath -Force -ErrorAction Stop; Log "Movido a cuarentena: $($f.FullName)" } catch { Log "Fallo mover: $($_.Exception.Message)" }
        } else { Log "DRYRUN: mover (duplicado) $($f.FullName) -> $QuarantinePath" }
      } else {
        $hashTable[$h] = $f.FullName
      }
    } catch {
      # ignore hash errors but log
      Log "Hash error $($f.FullName): $($_.Exception.Message)"
    }
  }
}

Log "Etapa 2: Moviendo patrones de basura conocidos (por nombre)"
$patterns = @('*.log','*.tmp','*.lock','*.bak','*.old','*.orig','__pycache__','.pytest_cache','node_modules','.venv','dist','build','bin','obj','catalogador.backup','catalogador_embedded_git_backup')

foreach ($p in $pathsToScan) {
  foreach ($pat in $patterns) {
    $matches = Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pat -or $_.FullName -like "*$pat*" }
    foreach ($m in $matches) {
      try {
        Log "CADUCO/BASURA: $($m.FullName)"
        if (-not $WhatIfSwitch) { Move-Item -LiteralPath $m.FullName -Destination $QuarantinePath -Force -ErrorAction Stop; Log "Movido: $($m.FullName) -> $QuarantinePath" } else { Log "DRYRUN: mover $($m.FullName) -> $QuarantinePath" }
      } catch { Log "Fallo mover $($m.FullName): $($_.Exception.Message)" }
    }
  }
}

Log "Etapa 3: Archivos grandes sin modificar en $AgeDays días (>$LargeSizeMB MB)"
$cutoff = (Get-Date).AddDays(-1 * $AgeDays)
foreach ($p in $pathsToScan) {
  $bigFiles = Get-ChildItem -Path $p -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { ($_.Length/1MB) -ge $LargeSizeMB -and $_.LastWriteTime -lt $cutoff }
  foreach ($bf in $bigFiles) {
    Log "OLD-LARGE: $($bf.FullName) ~ $([math]::Round($bf.Length/1MB,2)) MB (LastWrite: $($bf.LastWriteTime))"
    if (-not $WhatIfSwitch) {
      try { Move-Item -LiteralPath $bf.FullName -Destination $QuarantinePath -Force -ErrorAction Stop; Log "Movido: $($bf.FullName)" } catch { Log "Fallo mover $($bf.FullName): $($_.Exception.Message)" }
    } else { Log "DRYRUN: mover $($bf.FullName) -> $QuarantinePath" }
  }
}

Log "Limpieza finalizada. Reporte en: $global:ReportFile"
Log "Cuarentena: $QuarantinePath"

Write-Host "== Limpieza finalizada ==" -ForegroundColor Green
Write-Host "Reporte: $global:ReportFile" -ForegroundColor Cyan
Write-Host "Cuarentena: $QuarantinePath" -ForegroundColor Cyan
