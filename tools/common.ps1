# common.ps1 - Common utilities for Catalogador PowerShell scripts
# Provides centralized configuration loading and reusable functions

# Load centralized configuration from config/backend.config.json
function Get-CatalogadorConfig {
    param(
        [string]$ConfigPath = $null
    )
    
    # Determine repo root and config path
    if (-not $ConfigPath) {
        $scriptDir = Split-Path -Parent $PSCommandPath
        if (-not $scriptDir) { $scriptDir = $PSScriptRoot }
        $repoRoot = Resolve-Path (Join-Path $scriptDir '..') | Select-Object -ExpandProperty Path
        $ConfigPath = Join-Path $repoRoot 'config\backend.config.json'
    }
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Warning "Config file not found: $ConfigPath"
        return $null
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        return $config
    } catch {
        Write-Warning "Failed to parse config file: $_"
        return $null
    }
}

# Get backend API port with fallback logic
function Get-BackendPort {
    param(
        [switch]$AsBaseUrl
    )
    
    $port = 8000  # Default fallback
    
    # Priority 1: Environment variable
    if ($env:CATALOGADOR_BACKEND_PORT) {
        try { $port = [int]$env:CATALOGADOR_BACKEND_PORT } catch {}
    }
    elseif ($env:UVICORN_PORT) {
        try { $port = [int]$env:UVICORN_PORT } catch {}
    }
    # Priority 2: Centralized config
    else {
        $config = Get-CatalogadorConfig
        if ($config -and $config.backend.port) {
            $port = [int]$config.backend.port
        }
    }
    
    if ($AsBaseUrl.IsPresent) {
        return "http://127.0.0.1:$port"
    }
    return $port
}

# Get service name from config
function Get-ServiceName {
    $config = Get-CatalogadorConfig
    if ($config -and $config.service.name) {
        return $config.service.name
    }
    return "Catalogador-PythonAPI"  # Default fallback
}

# Get production root path from config
function Get-ProductionRoot {
    $config = Get-CatalogadorConfig
    if ($config -and $config.deployment.production_root) {
        return $config.deployment.production_root
    }
    return "C:\ProgramData\Catalogador\python_api"  # Default fallback
}

# Get Python module path from config
function Get-PythonModule {
    $config = Get-CatalogadorConfig
    if ($config -and $config.deployment.python_module) {
        return $config.deployment.python_module
    }
    return "api.main:app"  # Default fallback
}

# Check if running as Administrator
function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Require Administrator privileges or exit
function Require-Administrator {
    if (-not (Test-Administrator)) {
        Write-Error "Administrator privileges are required. Run PowerShell as Administrator."
        exit 1
    }
}

# Wait for API health check to pass
function Wait-ForApiHealth {
    param(
        [int]$TimeoutSeconds = 30,
        [int]$RetryIntervalSeconds = 2
    )
    
    $baseUrl = Get-BackendPort -AsBaseUrl
    $healthUrl = "$baseUrl/health"
    $elapsed = 0
    
    Write-Host "Waiting for API health check at $healthUrl..." -ForegroundColor Cyan
    
    while ($elapsed -lt $TimeoutSeconds) {
        try {
            $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                $content = $response.Content | ConvertFrom-Json
                if ($content.ok -eq $true) {
                    Write-Host "✓ API is healthy" -ForegroundColor Green
                    return $true
                }
            }
        } catch {
            # Continue waiting
        }
        
        Start-Sleep -Seconds $RetryIntervalSeconds
        $elapsed += $RetryIntervalSeconds
        Write-Host "." -NoNewline
    }
    
    Write-Host ""
    Write-Warning "API health check timeout after $TimeoutSeconds seconds"
    return $false
}

# Create timestamped backup of directory
function Backup-Directory {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [string]$BackupRoot = $null
    )
    
    if (-not (Test-Path $SourcePath)) {
        Write-Warning "Source path does not exist: $SourcePath"
        return $null
    }
    
    $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    
    if ($BackupRoot) {
        $backupPath = Join-Path $BackupRoot "backup_$timestamp"
    } else {
        $backupPath = "$SourcePath.backup.$timestamp"
    }
    
    Write-Host "Creating backup: $backupPath" -ForegroundColor Yellow
    
    try {
        robocopy $SourcePath $backupPath /MIR /COPY:DAT /R:1 /W:1 /NFL /NDL | Out-Null
        Write-Host "✓ Backup created successfully" -ForegroundColor Green
        return $backupPath
    } catch {
        Write-Error "Backup failed: $_"
        return $null
    }
}

# Clean old backups based on retention policy
function Remove-OldBackups {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupRoot,
        
        [int]$RetentionDays = 7
    )
    
    if (-not (Test-Path $BackupRoot)) {
        return
    }
    
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $backups = Get-ChildItem -Path $BackupRoot -Directory -Filter "backup_*" -ErrorAction SilentlyContinue
    
    $removed = 0
    foreach ($backup in $backups) {
        if ($backup.CreationTime -lt $cutoffDate) {
            Write-Host "Removing old backup: $($backup.Name)" -ForegroundColor Yellow
            Remove-Item -Path $backup.FullName -Recurse -Force -ErrorAction SilentlyContinue
            $removed++
        }
    }
    
    if ($removed -gt 0) {
        Write-Host "✓ Removed $removed old backup(s)" -ForegroundColor Green
    }
}

# Log message with timestamp
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMap = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }
    
    Write-Host "[$timestamp] $Message" -ForegroundColor $colorMap[$Level]
}
