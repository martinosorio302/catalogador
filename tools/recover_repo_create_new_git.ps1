<#
Safely recover a repository when .git objects are missing/corrupt.

What this script does (non-destructive by default):
- Verifica la existencia de `.git` y comprueba si existen objetos/packfiles.
- Si faltan objetos, mueve `.git` a un backup con timestamp (`.git.corrupt_backup.YYYYMMDD_HHMMSS`).
- Inicializa un nuevo repositorio `git init` en el working tree.
- Intenta extraer la URL `origin` del backup `.git/config` y la añade como remoto si la encuentra.
- Añade, commitea todo el working tree y crea la rama indicada (por defecto `fix/mi-cambio-descripcion-autofix-20251109`).

Important:
- This script DOES NOT push by default. Review and push manually.
- Keep the `.git.corrupt_backup*` folder until you verify everything.

Usage examples:
  # Dry-run: shows what would be done
  .\tools\recover_repo_create_new_git.ps1 -WhatIf

  # Normal run (will move .git to backup and create a new git repo locally)
  .\tools\recover_repo_create_new_git.ps1

  # Provide branch name and remote URL explicitly
  .\tools\recover_repo_create_new_git.ps1 -BranchName 'fix/my-branch' -RemoteUrl 'https://github.com/you/repo.git'
#>

param(
    [string]$BranchName = 'fix/mi-cambio-descripcion-autofix-20251109',
    [string]$RemoteUrl = '',
    [switch]$WhatIf
)

Set-StrictMode -Version Latest

function Write-Log {
    param([string]$m)
    $ts = (Get-Date).ToString('s')
    Write-Host "$ts - $m"
}

$cwd = (Get-Location).Path
$gitDir = Join-Path $cwd '.git'

if (-not (Test-Path $gitDir)) {
    Write-Log "ERROR: No se encontró la carpeta .git en: $cwd"
    exit 1
}

# Check for objects or pack files
$objectsPath = Join-Path $gitDir 'objects'
$hasObjects = $false
if (Test-Path $objectsPath) {
    $fileCount = (Get-ChildItem -Path $objectsPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($fileCount -gt 0) { $hasObjects = $true }
}

if ($hasObjects) {
    Write-Log "Se detectaron objetos Git en '.git\objects' (count: $fileCount). Este script está pensado para casos sin objetos. Abortando to avoid accidental overwrite."
    exit 2
}

# Prepare backup name and move .git
$ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
$backupDir = Join-Path $cwd ".git.corrupt_backup.$ts"

Write-Log "No se detectaron objetos Git. Moviendo .git -> $backupDir"
if ($WhatIf) { Write-Log "WhatIf: Move-Item .git -> $backupDir"; exit 0 }

Move-Item -LiteralPath $gitDir -Destination $backupDir -Force

# Initialize new repo
Write-Log "Inicializando nuevo repositorio Git en $cwd"
git init | Out-Null

# Try to extract remote URL from backup config if not provided
if (-not $RemoteUrl) {
    $backupConfig = Join-Path $backupDir 'config'
    if (Test-Path $backupConfig) {
        try {
            $cfg = Get-Content $backupConfig -Raw -ErrorAction Stop
            if ($cfg -match 'url\s*=\s*(.+)') {
                $RemoteUrl = $Matches[1].Trim()
                Write-Log "Encontrada URL en backup config: $RemoteUrl"
            }
        } catch {
            # Avoid interpolation parsing issues by concatenating strings
            $err = $_.Exception.Message
            Write-Log ("No se pudo leer " + $backupConfig + ": " + $err)
        }
    }
}

if ($RemoteUrl) {
    Write-Log "Añadiendo remoto origin: $RemoteUrl"
    git remote add origin $RemoteUrl 2>$null
}

Write-Log "Staging de todos los archivos (excluye .git si existe)"
git add -A

Write-Log "Creando commit de recuperación"
git commit -m "chore(recover): recreate repository after corrupted .git on $(Get-Date -Format u)" 2>$null || Write-Log "No hay cambios para commitear o commit falló (revisar)"

Write-Log "Creando/estableciendo rama: $BranchName"
git branch -M $BranchName 2>$null

Write-Log "Recuperación local completada. No se realizó push." 
Write-Host "Siguientes pasos sugeridos:"
Write-Host "  git status"
if ($RemoteUrl) { Write-Host "  git push -u origin $BranchName" }
else { Write-Host "  git remote add origin <your-remote-url>  # then: git push -u origin $BranchName" }
Write-Host "Revisa el directorio: $backupDir (contiene la .git original) antes de borrarlo permanentemente."

exit 0
