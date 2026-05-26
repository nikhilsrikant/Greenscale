<#
Optional Kubernetes tooling for Windows.
Run after Docker Desktop is working.
#>

$ErrorActionPreference = "Stop"

Write-Host "Installing kubectl..." -ForegroundColor Cyan
winget install --id Kubernetes.kubectl -e --source winget --accept-package-agreements --accept-source-agreements

Write-Host "Installing kind..." -ForegroundColor Cyan
winget install --id Kubernetes.kind -e --source winget --accept-package-agreements --accept-source-agreements

Write-Host "\nClose and reopen PowerShell, then verify:" -ForegroundColor Green
Write-Host "kubectl version --client"
Write-Host "kind version"
