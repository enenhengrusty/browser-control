<#
.SYNOPSIS
Safely launch or connect to Microsoft Edge with Chrome DevTools Protocol (CDP) enabled.

.DESCRIPTION
Handles Microsoft Edge's "Startup Boost" background process trap:
if headless/background msedge.exe processes exist without a debugging port,
terminates orphaned background-only processes (unless -NoRestart or -UserDataDir is set)
and starts Edge with --remote-debugging-port and --remote-allow-origins=*.
#>
[CmdletBinding()]
param(
    [int]$Port = 9222,
    [string]$UserDataDir = "",
    [switch]$NoRestart
)

$ErrorActionPreference = "Stop"

function Resolve-EdgeExecutable {
    $cmd = Get-Command msedge.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:LocalAppData\Microsoft\Edge\Application\msedge.exe"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }
    return $null
}

function Test-CdpEndpoint {
    param([int]$TargetPort)
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$TargetPort/json/version" -TimeoutSec 2 -ErrorAction Stop
        if ($resp -and $resp.webSocketDebuggerUrl) {
            return $true
        }
    } catch {
        # Fall back to TCP check
        $conn = Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction SilentlyContinue
        if ($conn) { return $true }
    }
    return $false
}

Write-Host "[Edge CDP Loader] Checking CDP endpoint on port $Port ..." -ForegroundColor Cyan
if (Test-CdpEndpoint -TargetPort $Port) {
    Write-Host "[Edge CDP Loader] CDP endpoint http://127.0.0.1:$Port is already ready." -ForegroundColor Green
    exit 0
}

$edgePath = Resolve-EdgeExecutable
if (-not $edgePath) {
    Write-Error "[Edge CDP Loader] Microsoft Edge (msedge.exe) not found on this system."
    exit 1
}

if (-not $UserDataDir -and -not $NoRestart) {
    $allEdge = Get-Process msedge -ErrorAction SilentlyContinue
    if ($allEdge) {
        $visibleEdge = $allEdge | Where-Object { $_.MainWindowHandle -ne 0 }
        if (-not $visibleEdge) {
            Write-Host "[Edge CDP Loader] Detected background-only Edge processes (Startup Boost). Cleaning up..." -ForegroundColor Yellow
            Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 800
        } else {
            Write-Warning "[Edge CDP Loader] Visible Edge windows are already running without port $Port. Pass -UserDataDir '<temp_dir>' to launch an isolated instance, or close Edge first."
        }
    }
}

$argsList = @(
    "--remote-debugging-port=$Port",
    "--remote-allow-origins=*"
)
if ($UserDataDir) {
    $argsList += "--user-data-dir=`"$UserDataDir`""
}

Write-Host "[Edge CDP Loader] Starting Edge: $edgePath $($argsList -join ' ')" -ForegroundColor Cyan
Start-Process -FilePath $edgePath -ArgumentList $argsList

$maxRetries = 20
for ($i = 0; $i -lt $maxRetries; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-CdpEndpoint -TargetPort $Port) {
        Write-Host "[Edge CDP Loader] Edge CDP is ready at http://127.0.0.1:$Port !" -ForegroundColor Green
        exit 0
    }
}

Write-Error "[Edge CDP Loader] Timeout waiting for Edge CDP port $Port. If Edge was already open without CDP, close it or pass -UserDataDir."
exit 1
