<#
Smoke test for GreenScale on Windows.
Run in a second PowerShell window while docker compose is running.
#>

$ErrorActionPreference = "Stop"

Write-Host "Checking orchestrator health..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get | ConvertTo-Json -Depth 10

Write-Host "\nInvoking text-classify workload..." -ForegroundColor Cyan
$body = @{
    payload = @{ text = "cloud computing research workload" }
    slo_ms = 450
    priority = "latency-critical"
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
    -Uri "http://localhost:8080/invoke/text-classify" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body | ConvertTo-Json -Depth 20
