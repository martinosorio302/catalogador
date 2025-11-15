param(
	[switch]$BaseUrl
)

# get_backend_port.ps1
# Small helper that prints the backend port number (or the base URL if -BaseUrl is passed).
# Resolution order:
#  1. Environment variable CATALOGADOR_BACKEND_PORT or UVICORN_PORT
#  2. config/backend.config.json (repo-root relative) - PRIMARY SOURCE
#  3. runtime/backend_port.txt (repo-root relative) - LEGACY FALLBACK
#  4. fallback to 8000

function Write-Port([int]$p){ if ($BaseUrl.IsPresent) { Write-Output "http://127.0.0.1:$p" } else { Write-Output $p } }

$envPort = $null
if ($env:CATALOGADOR_BACKEND_PORT) { $envPort = $env:CATALOGADOR_BACKEND_PORT }
elseif ($env:UVICORN_PORT) { $envPort = $env:UVICORN_PORT }

if ($envPort) {
	try { Write-Port ([int]$envPort); exit 0 } catch {}
}

# Try to find config/backend.config.json walking up from script dir
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -Path (Join-Path $scriptDir '..') | Select-Object -ExpandProperty Path
$configFile = Join-Path $repoRoot 'config\backend.config.json'
if (Test-Path $configFile) {
	try {
		$config = Get-Content $configFile -Raw -ErrorAction Stop | ConvertFrom-Json
		if ($config.backend.port) { Write-Port ([int]$config.backend.port); exit 0 }
	} catch {
		Write-Warning "Failed to parse config file: $_"
	}
}

# Legacy fallback: Try runtime/backend_port.txt
$runtimeFile = Join-Path $repoRoot 'runtime\backend_port.txt'
if (Test-Path $runtimeFile) {
	try {
		$t = Get-Content $runtimeFile -ErrorAction Stop | Select-Object -First 1
		if ($t) { Write-Port ([int]$t); exit 0 }
	} catch {}
}

# Default
Write-Port 8000
