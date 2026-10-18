<#
.SYNOPSIS
    1-Click Deployment Script for Tabattal Video Exporter to Modal.com
.DESCRIPTION
    Installs modal CLI, sets up authentication, and deploys the 8-core serverless endpoint.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Ensure UTF-8 output encoding across console and Python
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8 = "1"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Tabattal High-Speed Video Exporter - Modal Deployment   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check Python
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Error "Python is not installed or not in PATH. Please install Python 3.10+."
    exit 1
}

Write-Host "[1/4] Ensuring modal library is installed..." -ForegroundColor Yellow
python -m pip install -q --upgrade pip
python -m pip install -q -r "$PSScriptRoot\requirements.txt"

Write-Host "[2/4] Checking Modal authentication status..." -ForegroundColor Yellow
$authStatus = python -c "from modal.config import config; print('AUTHENTICATED' if config.get('token_id') else 'NOT_AUTHENTICATED')"
if ($authStatus -match "AUTHENTICATED" -and -not ($authStatus -match "NOT_AUTHENTICATED")) {
    Write-Host "[+] Modal authentication verified!" -ForegroundColor Green
} else {
    Write-Host "[*] No active Modal session found. Opening browser for authentication..." -ForegroundColor Cyan
    python -m modal token new
}

Write-Host "[3/4] Deploying Tabattal Video Exporter to Modal (8 vCPUs / 16GB RAM)..." -ForegroundColor Yellow
Set-Location $PSScriptRoot
python -m modal deploy main.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[-] Deployment failed with exit code $LASTEXITCODE. Please check the error above." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE!                                    " -ForegroundColor Green
Write-Host "  Copy the generated URL above (e.g., https://...modal.run) " -ForegroundColor Green
Write-Host "  and update your Flutter Web environment:                 " -ForegroundColor Green
Write-Host "  VIDEO_EXPORT_API_URL=https://YOUR_MODAL_URL              " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
