$ErrorActionPreference = 'Stop'
$startTime = Get-Date

# --- Helper function to check if external commands failed ---
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
    return "App"
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

$appName = Get-AppName
$version = Get-AppVersion
$outputFolder = "..\B- Releases\Tabattal"

Write-Host "--- STARTING BUILD PROCESS: [$appName] v$version ---" -ForegroundColor Cyan

# --- Choice: Format ---
Write-Host "`nSelect Build Format:" -ForegroundColor Yellow
Write-Host "1) APK (Android Package - for testing)" -ForegroundColor Green
Write-Host "2) AAB (Android App Bundle - for Play Store)" -ForegroundColor Blue
Write-Host "3) BOTH" -ForegroundColor Magenta
$formatChoice = Read-Host "Enter your choice [Default is 1]"

# --- Choice: Clean Mode ---
Write-Host "`nSelect Build Mode:" -ForegroundColor Yellow
Write-Host "1) FAST MODE (Uses cache, takes seconds)" -ForegroundColor Green
Write-Host "2) FRESH CLEAN MODE (Clears cache, takes minutes)" -ForegroundColor Red
$cleanChoice = Read-Host "Enter your choice [Default is 1]"

if ($cleanChoice -eq '2') {
    # --- Phase: Optional Flutter Clean ---
    Write-Host "`nPHASE 1: Running Flutter Clean..." -ForegroundColor Cyan
    try {
        flutter clean
        Check-CommandSuccess "Flutter Clean"
    } catch {
        Write-Host "WARNING: Clean command had issues, proceeding to smart check..." -ForegroundColor Yellow
    }

    # --- Phase: Optional Smart Process Killer ---
    Write-Host "PHASE 2: Cleaning build directory safely..." -ForegroundColor Cyan
    if (Test-Path "build") {
        try {
            Remove-Item -Recurse -Force "build" -ErrorAction Stop
            Write-Host "Build folder cleared successfully." -ForegroundColor Green
        } catch {
            Write-Host "Build folder is locked. Hunting down OpenJDK processes..." -ForegroundColor Yellow
            $javaProc = Get-Process java -ErrorAction SilentlyContinue
            if ($javaProc) {
                $javaProc | Stop-Process -Force
                Start-Sleep -Seconds 2
            }
            Remove-Item -Recurse -Force "build" -ErrorAction Stop
        }
    }
    
    # Refresh dependencies only on clean
    Write-Host "PHASE 3: Refreshing dependencies..." -ForegroundColor Cyan
    flutter pub get
    Check-CommandSuccess "Flutter Pub Get"
} else {
    Write-Host "`nSPEED MODE ACTIVATED: Skipping clean and reusing build cache..." -ForegroundColor Green
}

# Ensure output folder exists
if (!(Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

$buildApk = ($formatChoice -eq '1' -or $formatChoice -eq '3' -or [string]::IsNullOrWhiteSpace($formatChoice))
$buildAab = ($formatChoice -eq '2' -or $formatChoice -eq '3')

# --- Phase: Build APK ---
if ($buildApk) {
    Write-Host "`nPHASE 4: Building Android APK (Release)..." -ForegroundColor Cyan
    flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build\app\outputs\symbols
    Check-CommandSuccess "Flutter Build APK"

    # Export APK
    $sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $sourceApk) {
        $newApkName = "$appName-v$version.apk"
        $destApkPath = Join-Path $outputFolder $newApkName
        Write-Host "Exporting APK: $newApkName" -ForegroundColor White
        Copy-Item $sourceApk -Destination $destApkPath -Force
    }
    
    # Export APK Symbols
    $sourceSymbols = "build\app\outputs\symbols"
    if (Test-Path $sourceSymbols) {
        $destSymbolsPath = Join-Path $outputFolder "symbols_apk_v$version"
        Write-Host "Exporting Symbols folder: symbols_apk_v$version" -ForegroundColor White
        Copy-Item -Path $sourceSymbols -Destination $destSymbolsPath -Recurse -Force
    }
}

# --- Phase: Build AAB ---
if ($buildAab) {
    Write-Host "`nPHASE 5: Building Android AppBundle (Release)..." -ForegroundColor Cyan
    flutter build appbundle --release --obfuscate --split-debug-info=build\app\outputs\symbols
    Check-CommandSuccess "Flutter Build AppBundle"

    # Export AAB
    $sourceAab = "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $sourceAab) {
        $newAabName = "$appName-v$version.aab"
        $destAabPath = Join-Path $outputFolder $newAabName
        Write-Host "Exporting AAB: $newAabName" -ForegroundColor White
        Copy-Item $sourceAab -Destination $destAabPath -Force
    }

    # Export AAB Symbols
    $sourceSymbols = "build\app\outputs\symbols"
    if (Test-Path $sourceSymbols) {
        $destSymbolsPath = Join-Path $outputFolder "symbols_aab_v$version"
        Write-Host "Exporting Symbols folder: symbols_aab_v$version" -ForegroundColor White
        Copy-Item -Path $sourceSymbols -Destination $destSymbolsPath -Recurse -Force
    }
}

# --- Phase: Final Report ---
$endTime = Get-Date
$duration = $endTime - $startTime
$durationText = "{0:mm} min {0:ss} sec" -f $duration

Write-Host "`n--- BUILD SUCCESSFUL ---" -ForegroundColor Green
Write-Host "TOTAL TIME: $durationText" -ForegroundColor White

try {
    $wshell = New-Object -ComObject WScript.Shell
    $wshell.Popup("$appName Build v$version Completed Successfully!", 0, "Flutter Build Tools", 64) | Out-Null
} catch {}

if (Test-Path $outputFolder) { Invoke-Item $outputFolder }
