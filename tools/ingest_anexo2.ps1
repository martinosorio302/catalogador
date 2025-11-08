<#
.SYNOPSIS
  Ingesta integral del ANEXO 2 (PCD EsSalud) -> Normalizacion archivistica
  - Convierte PDF -> Texto con layout conservado
  - Parsea Series/Fracciones/Codigos/Retencion/Valoracion
  - Calcula "Valoracion: Eliminacion/Transferencia"
  - Exporta JSON/CSV/SQL + Módulo de consulta
  - Idempotente, con logs y validaciones

.PARAMETER PdfPath
  Ruta al PDF "ESSALUD-PCD-ANEXO-2-TABLA.pdf".
  Si se omite, intentará detectar el archivo en el Escritorio del usuario y en subcarpetas conocidas.

.PARAMETER OutDir
  Carpeta de salida. Por defecto: "$env:USERPROFILE\Desktop\PCD-EsSalud-OUT"

.PARAMETER Force
  Fuerza reinstalación de dependencias y reprocesado completo.

.NOTES
  Requiere Windows PowerShell 5.1+ o PowerShell 7+ (funciona en ambos).
  Usa Poppler (pdftotext). Intentará instalar con winget/choco si no se encuentra.

.AUTHOR
  GPT-5 Thinking - Implementacion archivistica integral para EsSalud
#>

param(
  [string]$PdfPath,
  [string]$OutDir = "$env:USERPROFILE\Desktop\PCD-EsSalud-OUT",
  [switch]$Force
)

# =========================================================
# 0) Auto-elevación (para instalar dependencias si faltan)
# =========================================================
function Ensure-Admin {
  $current = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($current)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "Re-ejecutando como Administrador..." -ForegroundColor Cyan
    $psi = @{
      FilePath  = (Get-Process -Id $PID).Path
      ArgumentList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"") + $PSBoundParameters.GetEnumerator() | ForEach-Object {
        if ($_.Value -is [switch] -and $_.Value.IsPresent) { "-$($_.Key)" }
        elseif ($_.Value -ne $null) { "-$($_.Key)","$($_.Value)" }
      }
      Verb = 'RunAs'
      WindowStyle = 'Normal'
    }
    Start-Process @psi
    exit
  }
}
Ensure-Admin

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# =============================================
# 1) Preparación de carpetas / logging
# =============================================
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$LogDir = Join-Path $OutDir "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir "run_$ts.log"

Start-Transcript -Path $LogFile -Append | Out-Null
Write-Host "PCD EsSalud - Ingesta integral (ANEXO 2)" -ForegroundColor Green

# =============================================
# 2) Localizar PDF si no se indicó
# =============================================
function Find-Pdf {
  param([string]$Hint)
  if ($Hint -and (Test-Path $Hint)) { return (Resolve-Path $Hint).Path }

  $candidatos = @(
    "$env:USERPROFILE\Desktop\ESSALUD-PCD-ANEXO-2-TABLA.pdf",
    "$env:USERPROFILE\Downloads\ESSALUD-PCD-ANEXO-2-TABLA.pdf",
    "$env:USERPROFILE\Desktop\ESSALUD\ESSALUD-PCD-ANEXO-2-TABLA.pdf"
  )
  foreach ($p in $candidatos) {
    if (Test-Path $p) { return (Resolve-Path $p).Path }
  }
  throw "No se encontró el PDF. Especifica -PdfPath con la ruta al 'ESSALUD-PCD-ANEXO-2-TABLA.pdf'."
}
$PdfPath = Find-Pdf -Hint $PdfPath
Write-Host "PDF detectado: $PdfPath" -ForegroundColor Green

# =============================================
# 3) Dependencias: pdftotext (Poppler) y utilidades
# =============================================
function Test-CommandExists([string]$cmd) {
  $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Ensure-Poppler {
  # Prueba comandos conocidos
  if (Test-CommandExists "pdftotext") { return }
  Write-Host "Instalando Poppler (pdftotext)..." -ForegroundColor Yellow
  try {
    if (Test-CommandExists "winget") {
      winget install --id=oschwartz10612.Poppler --accept-source-agreements --accept-package-agreements -e --silent | Out-Null
    } elseif (Test-CommandExists "choco") {
      choco install poppler -y --no-progress | Out-Null
    } else {
      throw "No hay winget ni choco. Instala Poppler manualmente o añade pdftotext al PATH."
    }
  } catch {
    throw "Fallo instalando Poppler: $($_.Exception.Message)"
  }
  if (-not (Test-CommandExists "pdftotext")) {
    throw "pdftotext no disponible tras la instalación."
  }
}
Ensure-Poppler

# =============================================
# 4) Conversión PDF -> Texto (layout fijo)
# =============================================
$WorkDir = Join-Path $OutDir "work"
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$TxtPath = Join-Path $WorkDir "anexo2_layout.txt"

if ($Force -or -not (Test-Path $TxtPath)) {
  Write-Host "Extrayendo texto con layout..." -ForegroundColor Cyan
  # -layout mantiene columnas; -enc UTF-8 garantiza acentos; -nopgbrk evita saltos page-feed
  & pdftotext -layout -enc UTF-8 -nopgbrk "`"$PdfPath`"" "`"$TxtPath`""
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $TxtPath)) {
    throw "Error en pdftotext. Verifica que Poppler esté en PATH."
  }
} else {
  Write-Host "Reutilizando extracción previa: $TxtPath" -ForegroundColor DarkCyan
}

# =============================================
# 5) Reglas de normalización archivística
# =============================================
$FondoDefault = "SEGURO SOCIAL DE SALUD (EsSalud)"
$SectorDefault = "MINISTERIO DE TRABAJO Y PROMOCION DEL EMPLEO"

function Resolve-Valorizacion {
  param(
    [ValidateSet('PERMANENTE','TEMPORAL')][string]$ValorSerie,
    [int]$AG,[int]$AP,[int]$OAA
  )
  # Lógica operativa:
  # - PERMANENTE: se transfiere al Archivo Central (conservación permanente). No eliminación.
  # - TEMPORAL: se conserva según plazos en AG/AP/OAA; tras cumplir OAA => Eliminación.
  #   * Si el Total >= 10 y la práctica institucional indica transferencia intermedia,
  #     marcamos "TRANSFERENCIA INTERMEDIA" al AC (si así lo define la entidad); por defecto, eliminación.
  $total = ($AG + $AP + $OAA)
  if ($ValorSerie -eq 'PERMANENTE') {
    return @{
      decision = 'TRANSFERENCIA'
      justificacion = 'Conservación permanente según PCD: valor primario/secundario.'
      destino = 'Archivo Central'
      momento = "Al término de plazos en AG/AP (si aplican), conservar en AC de forma indefinida."
    }
  } else {
    # TEMPORAL
    $destino = if ($total -ge 10) { 'Archivo Central (opcional/intermedio según lineamientos internos)' } else { 'Archivo de Gestión/Periférico' }
    return @{
      decision = 'ELIMINACION'
      justificacion = 'Agotado el valor primario y vencidos plazos reglados en AG/AP/OAA.'
      destino = $destino
      momento = 'Ejecutar eliminación documental con acta y expediente de eliminación conforme PCD/AGN.'
    }
  }
}

# =============================================
# 6) Parser robusto del layout del Anexo 2
#    - Mantiene estado de "Sector", "Entidad", "Asunto Principal" (Unidad productora)
#    - Detecta filas: Nº Ord | Código | Título | Valor | AG | AP | OAA | Total
# =============================================
$Parsed = New-Object System.Collections.Generic.List[Object]

$state = [ordered]@{
  sector = $SectorDefault
  entidad = $FondoDefault
  asunto = $null   # Unidad Productora / Asunto principal de la serie
  pagina = 0
}

# Patrones
$rxAsunto = '^\s*3\.\s*Asunto\s+Principal\s+de\s+la\s+Serie\s+Documental:\s*(.+?)\s*$'
$rxSector = '^\s*1\.\s*Sector:\s*(.+?)\s*$'
$rxEntidad= '^\s*2\.\s*Nombre\s+de\s+la\s+entidad:\s*(.+?)\s*$'
$rxEncabezadoTabla = '4\.\s*Codigo.*5\.\s*Título.*6\.\s*Valor.*7\.\s*Periodo'
# Fila típica con números al final (AG/AP/OAA/Total); soporta "PERMANENTE|TEMPORAL"
$rxFila = '^\s*(\d+)\s+([A-Z0-9\/\-]+)\s+(.+?)\s+(PERMANENTE|TEMPORAL)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$'

$lines = Get-Content -Raw -Path $TxtPath -Encoding UTF8 -ErrorAction Stop -ReadCount 0
$lines = $lines -split "`r?`n"

$withinTable = $false
$lineNum = 0
foreach ($line in $lines) {
  $lineNum++
  $trim = $line.Trim()

  if ($trim -match '^\s*\d+\s+de\s+\d+\s*$') {
    # marcador de página "N de M"
    $state.pagina++
    continue
  }

  if ($trim -match $rxSector) {
    $state.sector = ($matches[1] -replace '\\s{2,}',' ').Trim()
    continue
  }
  if ($trim -match $rxEntidad) {
    $state.entidad = ($matches[1] -replace '\\s{2,}',' ').Trim()
    continue
  }
  if ($trim -match $rxAsunto) {
    $state.asunto = ($matches[1] -replace '\\s{2,}',' ').Trim()
    # Tratamos "Asunto Principal..." como Unidad productora responsable
    continue
  }
  if ($trim -match $rxEncabezadoTabla) {
    $withinTable = $true
    continue
  }

  if ($withinTable -and $trim -match $rxFila) {
    $nord  = [int]$matches[1]
    $codigo= $matches[2].Trim()
    $titulo= ($matches[3] -replace '\\s{2,}',' ').Trim()
    $valor = $matches[4].ToUpper().Trim()
    $ag    = [int]$matches[5]
    $ap    = [int]$matches[6]
    $oaa   = [int]$matches[7]
    $total = [int]$matches[8]

    # Derivar "fracción documental" a partir del prefijo de código (antes de "/")
    $fraccion = $null
    if ($codigo -match '^([A-Z0-9]+)\/') { $fraccion = $matches[1] }

    # Tipo de documento: usamos el Título de Serie Documental como "tipo documental"
    $tipoDoc = $titulo

    # Unidad productora (si no hay asunto visible, usa entidad)
    $unidad = if ($state.asunto) { $state.asunto } else { $state.entidad }

    $val = Resolve-Valorizacion -ValorSerie $valor -AG $ag -AP $ap -OAA $oaa

    $obj = [ordered]@{
      fuente_pdf           = (Split-Path $PdfPath -Leaf)
      pagina_aprox         = $state.pagina
      sector               = $state.sector
      fondo_documental     = $state.entidad
      unidad_productora    = $unidad
      fraccion_documental  = $fraccion
      codigo_serie         = $codigo
      serie_documental     = $titulo
      tipo_documento       = $tipoDoc
      valor_serie          = $valor
      retencion_ag         = $ag
      retencion_ap         = $ap
      retencion_oaa        = $oaa
      retencion_total      = $total
      valoracion_decision  = $val.decision
      valoracion_destino   = $val.destino
      valoracion_momento   = $val.momento
      valoracion_justifica = $val.justificacion
      hash_fila            = ""
    }

    # Hash para trazabilidad (cambios en nuevas versiones del PCD)
    $obj.hash_fila = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Depth 4)))) -Algorithm SHA256).Hash

    $Parsed.Add([pscustomobject]$obj)
    continue
  }

  # Si detectamos fin de tabla (líneas vacías largas o nuevo bloque de encabezado), cerramos
  if ($withinTable -and $trim -match '^TABLA\s+GENERAL\s+DE\s+RETENCI(Ó|O)N\s+DE\s+DOCUMENTOS') {
    $withinTable = $false
    continue
  }
}

if ($Parsed.Count -eq 0) {
  throw "No se detectaron filas. Revisa el PDF, la extracción o ajusta las regex. (Activa -Force para reprocesar)."
}

Write-Host "✔ Filas parseadas: $($Parsed.Count)" -ForegroundColor Green

# =============================================
# 7) Normalización + validaciones de integridad
# =============================================
function Assert-Row {
  param($row)
  foreach ($k in 'codigo_serie','serie_documental','valor_serie','retencion_total') {
    if (-not $row.$k) { throw "Fila con campo obligatorio vacío [$k]: $($row | ConvertTo-Json -Compress -Depth 2)" }
  }
  $sum = [int]$row.retencion_ag + [int]$row.retencion_ap + [int]$row.retencion_oaa
  if ([int]$row.retencion_total -ne $sum) {
  Write-Warning "Inconsistencia en totales: $($row.codigo_serie) [$sum != $($row.retencion_total)]. Se ajusta total."
    $row.retencion_total = $sum
  }
}
$Parsed | ForEach-Object { Assert-Row $_ }

# =============================================
# 8) Exportaciones: JSON / CSV / SQL / Seeds
# =============================================
$DataDir = Join-Path $OutDir "data"
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

# JSON
$JsonPath = Join-Path $DataDir "retencion_normalizada.json"
$Parsed | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonPath -Encoding UTF8

# CSV (separador coma; reemplazo de comas en textos)
$CsvPath = Join-Path $DataDir "retencion_normalizada.csv"
$Parsed | Select-Object `
  pagina_aprox,sector,fondo_documental,unidad_productora,fraccion_documental,`
  codigo_serie,serie_documental,tipo_documento,valor_serie,`
  retencion_ag,retencion_ap,retencion_oaa,retencion_total,`
  valoracion_decision,valoracion_destino,valoracion_momento,valoracion_justifica,hash_fila `
  | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

# SQL Schema + Seed (SQLite/ANSI)
$SqlSchemaLines = @(
  "-- retencion_schema.sql",
  "CREATE TABLE IF NOT EXISTS series_retencion (",
  "  id INTEGER PRIMARY KEY AUTOINCREMENT,",
  "  fuente_pdf TEXT,",
  "  pagina_aprox INTEGER,",
  "  sector TEXT,",
  "  fondo_documental TEXT,",
  "  unidad_productora TEXT,",
  "  fraccion_documental TEXT,",
  "  codigo_serie TEXT NOT NULL,",
  "  serie_documental TEXT NOT NULL,",
  "  tipo_documento TEXT,",
  "  valor_serie TEXT CHECK (valor_serie IN ('PERMANENTE','TEMPORAL')),",
  "  retencion_ag INTEGER DEFAULT 0,",
  "  retencion_ap INTEGER DEFAULT 0,",
  "  retencion_oaa INTEGER DEFAULT 0,",
  "  retencion_total INTEGER DEFAULT 0,",
  "  valoracion_decision TEXT CHECK (valoracion_decision IN ('TRANSFERENCIA','ELIMINACION')),",
  "  valoracion_destino TEXT,",
  "  valoracion_momento TEXT,",
  "  valoracion_justifica TEXT,",
  "  hash_fila TEXT UNIQUE",
  ");",
  "CREATE INDEX IF NOT EXISTS idx_codigo_serie ON series_retencion(codigo_serie);",
  "CREATE INDEX IF NOT EXISTS idx_unidad_prod ON series_retencion(unidad_productora);",
  "CREATE INDEX IF NOT EXISTS idx_valor_serie ON series_retencion(valor_serie);"
)
$SqlSchema = $SqlSchemaLines -join "`n"
$SqlSchemaPath = Join-Path $DataDir "retencion_schema.sql"
$SqlSchema | Set-Content -Path $SqlSchemaPath -Encoding UTF8

$SqlSeedPath = Join-Path $DataDir "retencion_seed.sql"
"BEGIN TRANSACTION;" | Set-Content -Path $SqlSeedPath -Encoding UTF8
foreach ($r in $Parsed) {
  $vals = @(
    $r.fuente_pdf.Replace("'","''"),
    $r.pagina_aprox,
    $r.sector.Replace("'","''"),
    $r.fondo_documental.Replace("'","''"),
    $r.unidad_productora.Replace("'","''"),
  ((if ($r.fraccion_documental) { $r.fraccion_documental } else { '' }).Replace("'","''")),
    $r.codigo_serie.Replace("'","''"),
    $r.serie_documental.Replace("'","''"),
    $r.tipo_documento.Replace("'","''"),
    $r.valor_serie,
    $r.retencion_ag, $r.retencion_ap, $r.retencion_oaa, $r.retencion_total,
    $r.valoracion_decision,
    $r.valoracion_destino.Replace("'","''"),
    $r.valoracion_momento.Replace("'","''"),
    $r.valoracion_justifica.Replace("'","''"),
    $r.hash_fila
  ) | ForEach-Object {
    if ($_ -is [string]) { "'$_'" } else { "$_" }
  } -join ", "

  $line = "INSERT OR IGNORE INTO series_retencion (fuente_pdf,pagina_aprox,sector,fondo_documental,unidad_productora,fraccion_documental,codigo_serie,serie_documental,tipo_documento,valor_serie,retencion_ag,retencion_ap,retencion_oaa,retencion_total,valoracion_decision,valoracion_destino,valoracion_momento,valoracion_justifica,hash_fila) VALUES ($vals);"
  Add-Content -Path $SqlSeedPath -Value $line
}
"COMMIT;" | Add-Content -Path $SqlSeedPath

# Seed JSON directo para tu backend/frontend
$SeedJsonPath = Join-Path $DataDir "series.seed.json"
$seed = @{
  generated_at = (Get-Date).ToString("s")
  source_pdf   = (Split-Path $PdfPath -Leaf)
  sector       = $SectorDefault
  fondo        = $FondoDefault
  series       = $Parsed
}
$seed | ConvertTo-Json -Depth 6 | Set-Content -Path $SeedJsonPath -Encoding UTF8

# =============================================
# 9) Módulo PowerShell para consumo en programa
# =============================================
$ModDir = Join-Path $OutDir "module"
New-Item -ItemType Directory -Force -Path $ModDir | Out-Null
$Ps1Mod = Join-Path $ModDir "EsSalud.PCD.psm1"

@"
# Módulo: EsSalud.PCD
# Funciones utilitarias para consultar las series de retención PCD (EsSalud)
# Carga el JSON normalizado generado por el ingestor.

Set-StrictMode -Version Latest

function Import-RetencionJson {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path $Path)) { throw "No existe el archivo JSON: $Path" }
  (Get-Content -Raw -Path $Path -Encoding UTF8 | ConvertFrom-Json)
}

# Retorna un array de PSCustomObject con las filas
function Get-Series {
  param(
    [string]$JsonPath = "$( ($JsonPath -replace '\\','/') )"
  )
  $data = Import-RetencionJson -Path $JsonPath
  # Si $data.series no existe, consideramos que el JSON es la lista
  if ($data.series) { return $data.series }
  else { return $data }
}

function Find-SeriesByCodigo {
  param(
    [Parameter(Mandatory)][string]$Codigo,
    [string]$JsonPath = "$( ($JsonPath -replace '\\','/') )"
  )
  $s = Get-Series -JsonPath $JsonPath
  $s | Where-Object { $_.codigo_serie -eq $Codigo }
}

function Find-SeriesByUnidad {
  param(
    [Parameter(Mandatory)][string]$UnidadProductora,
    [string]$JsonPath = "$( ($JsonPath -replace '\\','/') )"
  )
  $s = Get-Series -JsonPath $JsonPath
  $s | Where-Object { $_.unidad_productora -eq $UnidadProductora }
}

function Export-RetencionCsv {
  param(
    [string]$JsonPath = "$( ($JsonPath -replace '\\','/') )",
    [string]$OutCsv = "$( ($CsvPath -replace '\\','/') )"
  )
  $s = Get-Series -JsonPath $JsonPath
  $s | Select-Object `
    pagina_aprox,sector,fondo_documental,unidad_productora,fraccion_documental,`
    codigo_serie,serie_documental,tipo_documento,valor_serie,`
    retencion_ag,retencion_ap,retencion_oaa,retencion_total,`
    valoracion_decision,valoracion_destino,valoracion_momento,valoracion_justifica,hash_fila `
    | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
  $OutCsv
}

function Export-RetencionSql {
  param(
    [string]$SchemaPath = "$( ($SqlSchemaPath -replace '\\','/') )",
    [string]$SeedPath = "$( ($SqlSeedPath -replace '\\','/') )"
  )
  @($SchemaPath, $SeedPath)
}
"@ | Set-Content -Path $Ps1Mod -Encoding UTF8

# =============================================
# 10) Pruebas rápidas y reporte final
# =============================================
Import-Module $Ps1Mod -Force

# Smoke tests
$series = Get-Series
if ($series.Count -lt 10) {
  Write-Warning "Se parsearon menos de 10 filas. Revisa regex o layout. (Es válido si sólo probaste con pocas páginas)."
}

# Búsquedas de ejemplo (no bloquea)
try {
  $ej1 = Find-SeriesByCodigo -Codigo 'COIN/01'
  if ($ej1) { Write-Host "Ejemplo COIN/01 -> $($ej1.serie_documental) [$($ej1.valor_serie)] Total=$($ej1.retencion_total)" -ForegroundColor DarkGreen }
} catch {}

# Resumen por valoración
$grp = $series | Group-Object valoracion_decision | Select-Object Name, Count
Write-Host "- Resumen valoracion -" -ForegroundColor Cyan
$grp | Format-Table | Out-String | Write-Host

# Rutas de salida
Write-Host "`nSalidas generadas:" -ForegroundColor Green
Write-Host "  - JSON: $JsonPath"
Write-Host "  - CSV : $CsvPath"
Write-Host "  - SQL : $SqlSchemaPath"
Write-Host "         $SqlSeedPath"
Write-Host "  - Seed: $SeedJsonPath"
Write-Host "  - Mod.: $Ps1Mod"

Stop-Transcript | Out-Null

Write-Host "`nIngesta y normalizacion completadas. Integra 'retencion_normalizada.json' o 'retencion_seed.sql' en tu programa (FastAPI/WPF)." -ForegroundColor Green
