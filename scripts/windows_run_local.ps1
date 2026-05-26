<#
Run GreenScale locally on Windows using Docker Compose.
Usage from the greenscale folder:
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  .\scripts\windows_run_local.ps1
#>

$ErrorActionPreference = "Stop"

function Test-Command($Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-Command docker)) {
    Write-Error "Docker was not found. Install Docker Desktop first, then reopen PowerShell."
}

try {
    docker info | Out-Null
} catch {
    Write-Error "Docker Desktop is installed but the Docker Engine is not running. Open Docker Desktop and wait until it starts."
}

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example"
}

Write-Host "Building and starting GreenScale..." -ForegroundColor Cyan
docker compose up --build
