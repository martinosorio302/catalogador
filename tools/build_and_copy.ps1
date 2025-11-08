Param()
Set-StrictMode -Version Latest
Write-Output "[build_and_copy] Building frontend (src) and copying to root dist/web..."
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Resolve-Path (Join-Path $root '..')
Push-Location $repoRoot
try {
    $src = Join-Path $repoRoot 'src'
    if (-not (Test-Path $src)) { throw "src folder not found at $src" }
    Write-Output "[build_and_copy] Running npm ci in $src"
    Push-Location $src
    if (Test-Path package-lock.json -or Test-Path yarn.lock) {
        npm ci
    } else {
        npm install
    }
    Write-Output "[build_and_copy] Running npm run build"
    npm run build
    Pop-Location

    $srcDist = Join-Path $src 'dist'
    $dest = Join-Path $repoRoot 'dist\web'
    Write-Output "[build_and_copy] Copying $srcDist -> $dest"
    if (-not (Test-Path $srcDist)) { throw "Frontend build output missing at $srcDist" }
    # Ensure destination exists
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    robocopy $srcDist $dest /MIR | Out-Null
    Write-Output "[build_and_copy] Copy complete"
} finally {
    Pop-Location
}
# Build UI inside src, then copy src/dist to top-level dist/web
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Push-Location $repoRoot
Write-Output "[build_and_copy] Running npm ci and build in src"
# ensure node deps installed in src
npm --prefix src ci
npm --prefix src run build

# ensure top-level dist/web exists
$dest = Join-Path $repoRoot 'dist\web'
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

Write-Output "[build_and_copy] Copying src\dist -> dist\web"
robocopy "$repoRoot\src\dist" "$dest" /MIR | Out-Null
Write-Output "[build_and_copy] Done"
Pop-Location
