$ErrorActionPreference = "Stop"

Write-Host "GreenScale Milestone 2: experiment automation" -ForegroundColor Cyan

if (-not (Test-Path ".\docker-compose.yml")) {
    throw "Run this script from the GreenScale project root, e.g. C:\Users\kulka\downloads\greenscale"
}

try {
    $health = Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get -TimeoutSec 5
    Write-Host "Connected to GreenScale orchestrator." -ForegroundColor Green
    Write-Host "Configured regions: $($health.configured_regions -join ', ')"
}
catch {
    Write-Host "Could not reach http://localhost:8080/health" -ForegroundColor Red
    Write-Host "Start the project in another PowerShell window first:" -ForegroundColor Yellow
    Write-Host "  docker compose up --build"
    throw
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python was not found. Install it with: winget install -e --id Python.Python.3.12"
}

if (-not (Test-Path ".\.venv\Scripts\python.exe")) {
    Write-Host "Creating Python virtual environment .venv ..."
    python -m venv .venv
}

Write-Host "Installing experiment dependencies ..."
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r .\experiments\requirements.txt

Write-Host "Running experiments ..."
& .\.venv\Scripts\python.exe .\experiments\run_experiments.py `
    --base-url http://localhost:8080 `
    --out-dir .\results `
    --iterations 10 `
    --concurrency 2 `
    --analyze

$latest = Get-Content .\results\latest_run.txt
Write-Host ""
Write-Host "Milestone 2 complete." -ForegroundColor Green
Write-Host "Latest results folder: $latest"
Write-Host "Open the summary here: $latest\summary.md"
Write-Host "Charts are here: $latest\charts"
