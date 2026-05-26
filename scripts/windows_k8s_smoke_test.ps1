<#
Smoke test for the Milestone 4 Kubernetes deployment.
Run this after windows_k8s_port_forward.ps1 has started port-forward windows.
#>

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "Testing Kubernetes-exposed orchestrator health endpoint..." -ForegroundColor Cyan
$health = Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get -TimeoutSec 10
if ($health.status -ne "ok") {
    throw "Orchestrator health did not return status=ok."
}
Write-Host "  Orchestrator health: OK"

Write-Host "Invoking a Kubernetes-routed workload..." -ForegroundColor Cyan
$body = @{
    payload = @{ text = "kubernetes milestone four cloud scheduling workload" }
    slo_ms = 450
    priority = "latency-critical"
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod `
    -Uri "http://localhost:8080/invoke/text-classify" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body `
    -TimeoutSec 20

if ([string]::IsNullOrWhiteSpace($response.selected_region)) {
    throw "Workload response did not include selected_region."
}
Write-Host "  Workload selected region: $($response.selected_region)"

Write-Host "Testing orchestrator metrics endpoint..." -ForegroundColor Cyan
$metrics = Invoke-WebRequest -Uri "http://localhost:8080/metrics" -UseBasicParsing -TimeoutSec 10
if ($metrics.Content -notmatch "greenscale_requests_total") {
    throw "Expected GreenScale metrics were not found."
}
Write-Host "  Orchestrator metrics: OK"

Write-Host "Testing Prometheus query API..." -ForegroundColor Cyan
$query = [uri]::EscapeDataString("greenscale_requests_total")
$prom = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=$query" -Method Get -TimeoutSec 10
if ($prom.status -ne "success") {
    throw "Prometheus query did not return success."
}
Write-Host "  Prometheus query: OK"

Write-Host "Testing Grafana HTTP endpoint..." -ForegroundColor Cyan
$grafana = Invoke-WebRequest -Uri "http://localhost:3000/login" -UseBasicParsing -TimeoutSec 10
if ($grafana.StatusCode -ne 200) {
    throw "Grafana login page did not return HTTP 200."
}
Write-Host "  Grafana: OK"

Write-Host "Milestone 4 Kubernetes smoke test passed." -ForegroundColor Green
