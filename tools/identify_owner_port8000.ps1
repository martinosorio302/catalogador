<#
Collect diagnostics for the process/listener on port 8000.

Usage:
  pwsh .\tools\identify_owner_port8000.ps1

What it does:
  - Shows netstat entry for :8000
  - Shows tasklist for PID found
  - Tries Win32_Process and Win32_Service queries (may require elevation)
  - Prints actionable next steps for an admin
#>

Set-StrictMode -Version Latest
param(
    [switch]$ForceStop
)

Write-Host "Gathering network listener for port 8000..." -ForegroundColor Cyan
$net = netstat -aon | findstr ":8000"
if (-not $net) { Write-Host "No listener found for :8000" -ForegroundColor Green; exit 0 }
Write-Host $net

# parse PID from netstat output (take first numeric token at end)
$m = $net -match '\s+(\d+)$'
if ($m) {
    $detectedPid = [int]$Matches[1]
    Write-Host "Detected PID: $detectedPid" -ForegroundColor Yellow
} else {
    Write-Warning "Could not parse PID from netstat output."
    exit 0
}

Write-Host "Collecting tasklist and process info..." -ForegroundColor Cyan
 $task = & tasklist /FI "PID eq $detectedPid" | Out-String

$procInfo = $null
try {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$detectedPid" -ErrorAction Stop
    $procInfo = [pscustomobject]@{
        ProcessId = $proc.ProcessId
        Name = $proc.Name
        ExecutablePath = $proc.ExecutablePath
        CommandLine = $proc.CommandLine
        SessionId = $proc.SessionId
        ParentProcessId = $proc.ParentProcessId
    }
} catch {
    Write-Warning "Win32_Process query failed (insufficient permissions). Run PowerShell as Administrator to get full details.";
}

Write-Host "Attempting Win32_Service mapping (may require elevation) ..." -ForegroundColor Cyan
$svcInfo = $null
try {
    $svc = Get-CimInstance Win32_Service -Filter "ProcessId=$detectedPid" -ErrorAction Stop
    if ($svc) {
        $svcInfo = [pscustomobject]@{
            Name = $svc.Name
            DisplayName = $svc.DisplayName
            PathName = $svc.PathName
            StartName = $svc.StartName
            State = $svc.State
            StartMode = $svc.StartMode
        }
    }
} catch {
    Write-Warning "Win32_Service query failed (insufficient permissions). Run PowerShell as Administrator to get service mapping.";
}

Write-Host "Preparing JSON diagnostics in runtime/port8000_owner.json" -ForegroundColor Cyan
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = Resolve-Path -Path (Join-Path $scriptDir '..')
$runtimeDir = Join-Path -Path $repoRoot -ChildPath 'runtime'
if (-not (Test-Path $runtimeDir)) { New-Item -ItemType Directory -Path $runtimeDir | Out-Null }

$diag = [pscustomobject]@{
    netstat = $net -split "\r?\n"
    tasklist = $task -split "\r?\n"
    process = $procInfo
    service = $svcInfo
    collectedAt = (Get-Date).ToString('o')
}

$outFile = Join-Path $runtimeDir 'port8000_owner.json'
try {
    $diag | ConvertTo-Json -Depth 4 | Set-Content -Path $outFile -Encoding UTF8
    Write-Host "Wrote diagnostics to $outFile" -ForegroundColor Green
} catch {
    Write-Warning "Failed to write diagnostics: $($_.Exception.Message)"
}

Write-Host "Suggested next steps:" -ForegroundColor Cyan
if ($svcInfo) {
    Write-Host "  - Service detected: $($svcInfo.Name) (DisplayName: $($svcInfo.DisplayName)). As Admin run: Stop-Service -Name $($svcInfo.Name)" -ForegroundColor White
} else {
    Write-Host "  - No Windows Service owns this PID. Inspect owner and commandline via Process Explorer (Sysinternals) as Admin." -ForegroundColor White
}

Write-Host "  - You can inspect the JSON diag file at: $outFile" -ForegroundColor White
Write-Host "  - To forcibly stop the process (requires Admin): taskkill /PID $detectedPid /F (use only if you know it's safe)." -ForegroundColor White

if ($ForceStop) {
    Write-Warning "ForceStop requested: will attempt to stop the process now (requires Admin)." -ForegroundColor Yellow
    try {
        Stop-Process -Id $detectedPid -Force -ErrorAction Stop
        Write-Host "Process $detectedPid terminated." -ForegroundColor Green
    } catch {
        Write-Warning ("Failed to stop process {0}: {1}" -f $detectedPid, $_.Exception.Message)
    }
}

exit 0
