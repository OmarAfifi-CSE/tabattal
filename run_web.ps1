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

Write-Host "`n[TABATTAL] Launching Flutter Web on Chrome..." -ForegroundColor Cyan
flutter run -d chrome
