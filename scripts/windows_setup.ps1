<#
GreenScale Windows setup helper.
Run this in PowerShell as Administrator for the first installation pass.
It installs/updates the tools needed to run the local Docker Compose MVP.

Usage:
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  .\scripts\windows_setup.ps1
#>

$ErrorActionPreference = "Stop"

function Test-Command($Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

Write-Host "GreenScale Windows setup" -ForegroundColor Cyan
Write-Host "Checking winget..."
if (-not (Test-Command winget)) {
    Write-Error "winget was not found. Install App Installer from Microsoft Store, then rerun this script."
}

Write-Host "Installing Git..."
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements

Write-Host "Installing Docker Desktop..."
winget install --id Docker.DockerDesktop -e --source winget --accept-package-agreements --accept-source-agreements

Write-Host "Installing Python 3.12 for optional local tests..."
winget install --id Python.Python.3.12 -e --source winget --accept-package-agreements --accept-source-agreements

Write-Host "Installing Visual Studio Code..."
winget install --id Microsoft.VisualStudioCode -e --source winget --accept-package-agreements --accept-source-agreements

Write-Host "\nNext steps:" -ForegroundColor Green
Write-Host "1. Reboot Windows if Docker Desktop or WSL asks you to."
Write-Host "2. Open Docker Desktop and make sure it says Docker Engine is running."
Write-Host "3. In Docker Desktop settings, keep 'Use the WSL 2 based engine' enabled."
Write-Host "4. From this project folder, run: .\scripts\windows_run_local.ps1"
