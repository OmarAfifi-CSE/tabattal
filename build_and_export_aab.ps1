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

# --- Modified: Numerical Build Choice ---
Write-Host "`nSelect Build Mode:" -ForegroundColor Yellow
Write-Host "1) FAST MODE (Uses cache, takes seconds)" -ForegroundColor Green
Write-Host "2) FRESH CLEAN MODE (Clears cache, takes minutes)" -ForegroundColor Red
$choice = Read-Host "Enter your choice [Default is 1]"

if ($choice -eq '2') {
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

# --- Phase: Building AppBundle ---
Write-Host "PHASE 4: Building Android AppBundle (Release)..." -ForegroundColor Cyan
flutter build appbundle --release --obfuscate --split-debug-info=build\app\outputs\symbols
Check-CommandSuccess "Flutter Build AppBundle"

# --- Phase: Organizing Outputs ---
Write-Host "PHASE 5: Organizing output files..." -ForegroundColor Cyan

if (!(Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# 1. Export the AAB
$sourceAab = "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $sourceAab) {
    $newAabName = "$appName-v$version.aab"
    $destAabPath = Join-Path $outputFolder $newAabName
    Write-Host "Exporting AAB: $newAabName" -ForegroundColor White
    Copy-Item $sourceAab -Destination $destAabPath -Force
}

# 2. Export the Symbols folder
$sourceSymbols = "build\app\outputs\symbols"
if (Test-Path $sourceSymbols) {
    $destSymbolsPath = Join-Path $outputFolder "symbols_aab_v$version"
    Write-Host "Exporting Symbols folder: symbols_aab_v$version" -ForegroundColor White
    Copy-Item -Path $sourceSymbols -Destination $destSymbolsPath -Recurse -Force
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