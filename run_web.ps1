param (
    [switch]$Release,
    [switch]$KeepExportServer
)

# ==============================================================================
# 🚀 Tabattal Web Runner with Auto-Spawn Local Video Export Microservice
# ==============================================================================

Write-Host "`n[TABATTAL] Checking Video Export Service on port 8080..." -ForegroundColor Cyan

$spawnedProcess = $null
$portInUse = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue

if ($portInUse) {
    Write-Host "[TABATTAL] Video Export Service is already running on port 8080." -ForegroundColor Green
} else {
    Write-Host "[TABATTAL] Spawning Video Export Microservice in background..." -ForegroundColor Yellow
    $spawnedProcess = Start-Process -FilePath "node" -ArgumentList "index.js" -WorkingDirectory "$PSScriptRoot\server\video_export_service" -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 1
    Write-Host "[TABATTAL] Video Export Service started successfully on http://localhost:8080 (PID: $($spawnedProcess.Id))." -ForegroundColor Green
}

$pubspecPath = "pubspec.yaml"
$pubspecBak = "pubspec.yaml.bak"

# If a previous run was abruptly terminated and left pubspec lean, restore it first
if (Test-Path $pubspecBak) {
    Copy-Item $pubspecBak -Destination $pubspecPath -Force
} else {
    Copy-Item $pubspecPath -Destination $pubspecBak -Force
}

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

    [System.IO.File]::WriteAllLines((Resolve-Path $pubspecPath).Path, $leanLines, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[TABATTAL] Lean Web Environment configured (4 core fonts for fast boot)." -ForegroundColor Green

    $modeText = if ($Release) { "RELEASE (Ultra Fast)" } else { "DEBUG" }
    Write-Host "`n[TABATTAL] Launching Flutter Web ($modeText) on 127.0.0.1:3000..." -ForegroundColor Cyan

    if ($Release) {
        flutter run -d chrome --release --web-hostname 127.0.0.1 --web-port 3000
    } else {
        flutter run -d chrome --web-hostname 127.0.0.1 --web-port 3000
    }
} finally {
    if (-not $KeepExportServer) {
        if ($spawnedProcess -and -not $spawnedProcess.HasExited) {
            Write-Host "[TABATTAL] Stopping Video Export Service (PID: $($spawnedProcess.Id))..." -ForegroundColor Yellow
            Stop-Process -Id $spawnedProcess.Id -Force -ErrorAction SilentlyContinue
        } else {
            $activeConns = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
            if ($activeConns) {
                $pids = $activeConns | Select-Object -ExpandProperty OwningProcess -Unique
                foreach ($procId in $pids) {
                    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
                    if ($p -and $p.ProcessName -eq 'node') {
                        Write-Host "[TABATTAL] Closing Video Export Service on port 8080 (PID: $procId)..." -ForegroundColor Yellow
                        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        Write-Host "[TABATTAL] Port 8080 released." -ForegroundColor Green
    }

    if (Test-Path $pubspecBak) {
        Copy-Item $pubspecBak -Destination $pubspecPath -Force
        Remove-Item $pubspecBak -Force
        Write-Host "[TABATTAL] Native Mobile Pubspec (All 604 Fonts) Restored." -ForegroundColor Green
    }
}
