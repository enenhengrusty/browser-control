<#
.SYNOPSIS
Safely launch or connect to Google Chrome with Chrome DevTools Protocol (CDP) enabled.
#>
[CmdletBinding()]
param(
    [int]$Port = 9222,
    [string]$UserDataDir = ""
)

$ErrorActionPreference = "Stop"

function Resolve-ChromeExecutable {
    $cmd = Get-Command chrome.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
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
        $conn = Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction SilentlyContinue
        if ($conn) { return $true }
    }
    return $false
}

Write-Host "[Chrome CDP Loader] Checking CDP endpoint on port $Port ..." -ForegroundColor Cyan
if (Test-CdpEndpoint -TargetPort $Port) {
    Write-Host "[Chrome CDP Loader] CDP endpoint http://127.0.0.1:$Port is already ready." -ForegroundColor Green
    exit 0
}

$chromePath = Resolve-ChromeExecutable
if (-not $chromePath) {
    Write-Error "[Chrome CDP Loader] Google Chrome (chrome.exe) not found on this system."
    exit 1
}

$argsList = @(
    "--remote-debugging-port=$Port",
    "--remote-allow-origins=*"
)
if ($UserDataDir) {
    $argsList += "--user-data-dir=`"$UserDataDir`""
}

Write-Host "[Chrome CDP Loader] Starting Chrome: $chromePath $($argsList -join ' ')" -ForegroundColor Cyan
Start-Process -FilePath $chromePath -ArgumentList $argsList

$maxRetries = 20
for ($i = 0; $i -lt $maxRetries; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-CdpEndpoint -TargetPort $Port) {
        Write-Host "[Chrome CDP Loader] Chrome CDP is ready at http://127.0.0.1:$Port !" -ForegroundColor Green
        exit 0
    }
}

Write-Error "[Chrome CDP Loader] Timeout waiting for Chrome CDP port $Port. If Chrome was already open without CDP, enable remote debugging or pass -UserDataDir."
exit 1
