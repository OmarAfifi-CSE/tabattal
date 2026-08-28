# ==============================================================================
# Tabattal - Unified Multi-Platform Build & Export System (Android & Web)
# ==============================================================================
$ErrorActionPreference = 'Stop'
$startTime = Get-Date

function Check-CommandSuccess {
    param ([string]$commandName)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nFATAL ERROR: $commandName failed with exit code $LASTEXITCODE. Halting script." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

function Get-AppName {
    if (Test-Path "pubspec.yaml") {
        $nameLine = Get-Content "pubspec.yaml" | Select-String "^name: "
        if ($nameLine) {
            $rawName = $nameLine.ToString().Split(":")[1].Trim()
            return $rawName.Substring(0,1).ToUpper() + $rawName.Substring(1)
        }
    }
    return "Tabattal"
}

function Get-AppVersion {
    if (Test-Path "pubspec.yaml") {
        $versionLine = Get-Content "pubspec.yaml" | Select-String "^version: "
        if ($versionLine) {
            $v = $versionLine.ToString().Split(":")[1].Trim()
            if ($v.Contains("+")) { $v = $v.Split("+")[0] }
            return $v
        }
    }
    return "1.0.0"
}

function Get-EnvVariable {
    param ([string]$key, [string]$defaultVal = "")
    if (Test-Path ".env") {
        $lines = Get-Content ".env"
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed.StartsWith("#") -or [string]::IsNullOrWhiteSpace($trimmed)) { continue }
            $parts = $trimmed.Split("=", 2)
            if ($parts.Length -eq 2 -and $parts[0].Trim() -eq $key) {
                return $parts[1].Trim().Trim('"').Trim("'")
            }
        }
    }
    return $defaultVal
}

$appName = Get-AppName
$version = Get-AppVersion
$androidOutputFolder = "..\B- Releases\Tabattal"
$docsAppFolder = "docs\app"
$webBaseHref = "/app/"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " [BUILD SYSTEM] : [$appName] v$version" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# --- Choice: Format ---
Write-Host "`nSelect Build Target:" -ForegroundColor Yellow
Write-Host "1) APK  (Android Package - for testing on device)" -ForegroundColor Green
Write-Host "2) AAB  (Android App Bundle - for Google Play Store)" -ForegroundColor Blue
Write-Host "3) WEB  (Flutter Web - auto deploy to docs/app for GitHub Pages)" -ForegroundColor Cyan
Write-Host "4) ALL  (APK + AAB + WEB)" -ForegroundColor Magenta
$formatChoice = Read-Host "Enter your choice [Default is 1]"

if ([string]::IsNullOrWhiteSpace($formatChoice)) {
    $formatChoice = '1'
}

$buildApk = ($formatChoice -eq '1' -or $formatChoice -eq '4')
$buildAab = ($formatChoice -eq '2' -or $formatChoice -eq '4')
$buildWeb = ($formatChoice -eq '3' -or $formatChoice -eq '4')

# --- Choice: Clean Mode ---
Write-Host "`nSelect Build Mode:" -ForegroundColor Yellow
Write-Host "1) FAST MODE (Uses cache, takes seconds)" -ForegroundColor Green
Write-Host "2) FRESH CLEAN MODE (Clears cache, takes minutes)" -ForegroundColor Red
$cleanChoice = Read-Host "Enter your choice [Default is 1]"

if ($cleanChoice -eq '2') {
    Write-Host "`n[PHASE] Running Flutter Clean..." -ForegroundColor Cyan
    try {
        flutter clean
        Check-CommandSuccess "Flutter Clean"
    } catch {
        Write-Host "WARNING: Clean command had issues, proceeding..." -ForegroundColor Yellow
    }

    if (Test-Path "build") {
        try {
            Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue
        } catch {
            $javaProc = Get-Process java -ErrorAction SilentlyContinue
            if ($javaProc) {
                $javaProc | Stop-Process -Force
                Start-Sleep -Seconds 2
            }
            Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue
        }
    }
    
    Write-Host "[PHASE] Refreshing dependencies..." -ForegroundColor Cyan
    flutter pub get
    Check-CommandSuccess "Flutter Pub Get"
} else {
    Write-Host "`n[SPEED MODE] Reusing build cache..." -ForegroundColor Green
}

# --- Build APK ---
if ($buildApk) {
    Write-Host "`n[BUILD] Building Android APK (Release)..." -ForegroundColor Cyan
    flutter build apk --release --target-platform android-arm64
    Check-CommandSuccess "Flutter Build APK"

    $apkFolder = Join-Path $androidOutputFolder "APK"
    if (!(Test-Path $apkFolder)) {
        New-Item -ItemType Directory -Path $apkFolder -Force | Out-Null
    }

    $sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $sourceApk) {
        $newApkName = "$appName-v$version.apk"
        $destApkPath = Join-Path $apkFolder $newApkName
        Write-Host "Exporting APK: $newApkName -> $apkFolder" -ForegroundColor White
        Copy-Item $sourceApk -Destination $destApkPath -Force
    }
}

# --- Build AAB ---
if ($buildAab) {
    Write-Host "`n[BUILD] Building Android AppBundle (Release)..." -ForegroundColor Cyan
    flutter build appbundle --release
    Check-CommandSuccess "Flutter Build AppBundle"

    $aabFolder = Join-Path $androidOutputFolder "AAB"
    if (!(Test-Path $aabFolder)) {
        New-Item -ItemType Directory -Path $aabFolder -Force | Out-Null
    }

    $sourceAab = "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $sourceAab) {
        $newAabName = "$appName-v$version.aab"
        $destAabPath = Join-Path $aabFolder $newAabName
        Write-Host "Exporting AAB: $newAabName -> $aabFolder" -ForegroundColor White
        Copy-Item $sourceAab -Destination $destAabPath -Force
    }
}

# --- Build Web ---
if ($buildWeb) {
    $videoExportApiUrl = Get-EnvVariable "VIDEO_EXPORT_API_URL" "http://localhost:8080/api/export-video"
    Write-Host "`n[BUILD] Building Flutter Web (Release for '$webBaseHref')..." -ForegroundColor Cyan
    
    if ($videoExportApiUrl -and $videoExportApiUrl -ne "http://localhost:8080/api/export-video") {
        Write-Host "[ENV] Injected Video Export API: $videoExportApiUrl" -ForegroundColor Green
        flutter build web --release --base-href "$webBaseHref" --dart-define=VIDEO_EXPORT_API_URL="$videoExportApiUrl"
    } else {
        flutter build web --release --base-href "$webBaseHref"
    }
    Check-CommandSuccess "Flutter Build Web"

    Write-Host "Deploying web release to '$docsAppFolder'..." -ForegroundColor Cyan
    if (Test-Path $docsAppFolder) {
        Remove-Item -Path "$docsAppFolder\*" -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -ItemType Directory -Path $docsAppFolder -Force | Out-Null
    }

    Copy-Item -Path "build\web\*" -Destination $docsAppFolder -Recurse -Force
    Check-CommandSuccess "Deploy to $docsAppFolder"

    if (-not (Test-Path "docs\.nojekyll")) {
        "# Disable Jekyll for GitHub Pages" | Out-File -FilePath "docs\.nojekyll" -Encoding utf8
    }

    $webFileCount = (Get-ChildItem -Path $docsAppFolder -Recurse -File).Count
    Write-Host "Web app deployed successfully: $webFileCount files in '$docsAppFolder'" -ForegroundColor Green
}

# --- Summary ---
$endTime = Get-Date
$duration = $endTime - $startTime
$durationText = "{0:mm} min {0:ss} sec" -f $duration

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host " [SUCCESS] BUILD PROCESS COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host " [TIME] Total Duration: $durationText" -ForegroundColor White
if ($buildApk -or $buildAab) {
    Write-Host " [ANDROID] Output: $androidOutputFolder" -ForegroundColor White
}
if ($buildWeb) {
    Write-Host " [WEB] Output: $docsAppFolder (GitHub Pages ready)" -ForegroundColor White
}
Write-Host "================================================================" -ForegroundColor Green

try {
    $wshell = New-Object -ComObject WScript.Shell
    $msg = "$appName Build Completed Successfully in $durationText!"
    $wshell.Popup($msg, 0, "Tabattal Build System", 64) | Out-Null
} catch {}

if (($buildApk -or $buildAab) -and (Test-Path $androidOutputFolder)) {
    Invoke-Item $androidOutputFolder
}
