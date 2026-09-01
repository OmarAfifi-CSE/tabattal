param (
    [switch]$Release
)

# ==============================================================================
# 🚀 Tabattal Web Runner with Auto-Spawn Local Video Export Microservice
# ==============================================================================

Write-Host "`n[TABATTAL] Checking Video Export Service on port 8080..." -ForegroundColor Cyan

$portInUse = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue

if ($portInUse) {
    Write-Host "[TABATTAL] Video Export Service is already running on port 8080." -ForegroundColor Green
} else {
    Write-Host "[TABATTAL] Spawning Video Export Microservice in background..." -ForegroundColor Yellow
    Start-Process -FilePath "node" -ArgumentList "index.js" -WorkingDirectory "$PSScriptRoot\server\video_export_service" -WindowStyle Hidden
    Start-Sleep -Seconds 1
    Write-Host "[TABATTAL] Video Export Service started successfully on http://localhost:8080." -ForegroundColor Green
}

$pubspecPath = "pubspec.yaml"
$pubspecBak = "pubspec.yaml.bak"
Copy-Item $pubspecPath -Destination $pubspecBak -Force

try {
    $lines = Get-Content $pubspecPath
    $leanLines = [System.Collections.Generic.List[string]]::new()
    $inQcfPageFont = $false

    foreach ($line in $lines) {
        if ($line -match '^\s+- family:\s+QCF_P\d{3}') {
            $inQcfPageFont = $true
            continue
        }
        if ($inQcfPageFont) {
            if ($line -match '^\s+- family:' -or ($line -notmatch '^\s+' -and -not [string]::IsNullOrWhiteSpace($line))) {
                $inQcfPageFont = $false
            } else {
                continue
            }
        }
        if ($line -match '^\s+- assets/data/quran.db') {
            $leanLines.Add($line)
            for ($p = 1; $p -le 604; $p++) {
                $pStr = $p.ToString().PadLeft(3, '0')
                $leanLines.Add("    - assets/fonts/quran/QCF_P$pStr.ttf")
            }
            continue
        }
        $leanLines.Add($line)
    }

    $leanLines | Out-File -FilePath $pubspecPath -Encoding utf8
    Write-Host "[TABATTAL] Lean Web Environment configured (4 core fonts for fast boot)." -ForegroundColor Green

    $modeText = if ($Release) { "RELEASE (Ultra Fast)" } else { "DEBUG" }
    Write-Host "`n[TABATTAL] Launching Flutter Web ($modeText) on 0.0.0.0:3000..." -ForegroundColor Cyan

    if ($Release) {
        flutter run -d chrome --release --web-hostname 0.0.0.0 --web-port 3000
    } else {
        flutter run -d chrome --web-hostname 0.0.0.0 --web-port 3000
    }
} finally {
    if (Test-Path $pubspecBak) {
        Copy-Item $pubspecBak -Destination $pubspecPath -Force
        Remove-Item $pubspecBak -Force
        Write-Host "[TABATTAL] Native Mobile Pubspec (All 604 Fonts) Restored." -ForegroundColor Green
    }
}
