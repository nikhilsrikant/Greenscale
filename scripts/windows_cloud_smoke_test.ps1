param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "Testing GreenScale cloud deployment at $BaseUrl ..." -ForegroundColor Cyan

$health = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -TimeoutSec 10
if ($health.status -ne "ok") {
    throw "Health endpoint did not return status ok."
}
Write-Host "  Health: OK"

$body = @{
    payload = @{ text = "cloud registry deployment smoke test" }
    slo_ms = 450
    priority = "latency-critical"
} | ConvertTo-Json -Depth 10

$result = Invoke-RestMethod `
    -Uri "$BaseUrl/invoke/text-classify" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body `
    -TimeoutSec 30

if (-not $result.selected_region) {
    throw "Scheduler response did not include a selected_region."
}

Write-Host "  Scheduler invocation: OK"
Write-Host "  Selected region: $($result.selected_region)"
Write-Host "  Provider: $($result.provider)"
Write-Host "  Estimated latency ms: $($result.estimated_latency_ms)"
Write-Host "Cloud smoke test passed." -ForegroundColor Green
