<#
  Wrapper to create a PowerShell 5.1-compatible copy of catalogador_full_fix.ps1
  It replaces the Build-Dotnet function block (which uses modern operators) with
  an equivalent implementation that avoids the null-coalescing / null-conditional
  operators so the script can run under Windows PowerShell 5.1.
#>

param()

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$orig = Join-Path $scriptRoot '..\catalogador_full_fix.ps1'
if(-not (Test-Path $orig)){ Write-Error "Original orchestrator not found: $orig"; exit 2 }

$text = Get-Content -Path $orig -Raw -ErrorAction Stop

$pattern = '(?ms)function Build-Dotnet .*?\nBuild-Dotnet'

$replacement = @'
function Build-Dotnet {
  if(-not $InstallDotnet){ return }
  if(-not (Test-Path $DotnetDir)){ W "No se encontró carpeta .NET ($DotnetDir)"; return }
  $sln = Get-ChildItem -Path $DotnetDir -Filter *.sln -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  $csproj = if(-not $sln){ Get-ChildItem -Path $DotnetDir -Filter *.csproj -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 } else { $null }
  if(-not $sln -and -not $csproj){ W "No se encontró solución/proyecto .NET"; return }
  if ($sln) { $projectFile = $sln.FullName } elseif ($csproj) { $projectFile = $csproj.FullName } else { $projectFile = '' }
  I "[11/12] Compilando .NET…"
  Exec "dotnet" ("restore `"{0}`"" -f $projectFile) -Cwd $DotnetDir -Label "dotnet restore"
  Exec "dotnet" ("build `"{0}`" -c Release" -f $projectFile) -Cwd $DotnetDir -Label "dotnet build"
  $pubDir = Join-Path $DotnetDir "publish\win-x64"
  Ensure-Folder $pubDir
  Exec "dotnet" ("publish `"{0}`" -c Release -r win-x64 --self-contained false -o `"{1}`"" -f $projectFile, $pubDir) -Cwd $DotnetDir -Label "dotnet publish"
  S "Publish .NET OK → $pubDir"
}
Build-Dotnet
'@

try{
  $new = [regex]::Replace($text, $pattern, $replacement, 'Singleline')
} catch {
  Write-Error "Failed to patch orchestrator: $($_.Exception.Message)"
  exit 3
}

$tmp = Join-Path $env:TEMP 'catalogador_full_fix_compat.ps1'
Set-Content -Path $tmp -Value $new -Encoding UTF8

Write-Host "Created compatible copy: $tmp"
Write-Host "Launching elevated copy..."
Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$tmp`"" -Verb RunAs -Wait
Write-Host 'Done.'
