param (
    [switch]$Release
)

# ==============================================================================
# 🚀 Tabattal Web Runner
# ==============================================================================

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

    $videoExportApiUrl = ""
    if (Test-Path ".env") {
        $linesEnv = Get-Content ".env"
        foreach ($l in $linesEnv) {
            $t = $l.Trim()
            if ($t.StartsWith("VIDEO_EXPORT_API_URL=")) {
                $videoExportApiUrl = $t.Substring("VIDEO_EXPORT_API_URL=".Length).Trim().Trim('"').Trim("'")
                break
            }
        }
    }

    $modeText = if ($Release) { "RELEASE (Ultra Fast)" } else { "DEBUG" }
    Write-Host "`n[TABATTAL] Launching Flutter Web ($modeText) on 127.0.0.1:3000..." -ForegroundColor Cyan
    if ($videoExportApiUrl) {
        Write-Host "[TABATTAL] Injected Video Export API from .env" -ForegroundColor Green
    }

    if ($Release) {
        if ($videoExportApiUrl) {
            flutter run -d chrome --release --web-hostname 127.0.0.1 --web-port 3000 "--dart-define=VIDEO_EXPORT_API_URL=$videoExportApiUrl"
        } else {
            flutter run -d chrome --release --web-hostname 127.0.0.1 --web-port 3000
        }
    } else {
        if ($videoExportApiUrl) {
            flutter run -d chrome --web-hostname 127.0.0.1 --web-port 3000 "--dart-define=VIDEO_EXPORT_API_URL=$videoExportApiUrl"
        } else {
            flutter run -d chrome --web-hostname 127.0.0.1 --web-port 3000
        }
    }
} finally {
    if (Test-Path $pubspecBak) {
        Copy-Item $pubspecBak -Destination $pubspecPath -Force
        Remove-Item $pubspecBak -Force
        Write-Host "[TABATTAL] Native Mobile Pubspec (All 604 Fonts) Restored." -ForegroundColor Green
    }
}
