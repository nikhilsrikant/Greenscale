$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "Testing orchestrator metrics endpoint..." -ForegroundColor Cyan
$metrics = Invoke-WebRequest -Uri "http://localhost:8080/metrics" -UseBasicParsing -TimeoutSec 5
if ($metrics.Content -notmatch "greenscale_requests_total") {
    throw "Orchestrator metrics endpoint responded, but expected GreenScale metrics were not found."
}
Write-Host "  Orchestrator metrics: OK"

Write-Host "Testing Prometheus query API..." -ForegroundColor Cyan
$query = [uri]::EscapeDataString("greenscale_requests_total")
$prom = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=$query" -Method Get -TimeoutSec 5
if ($prom.status -ne "success") {
    throw "Prometheus query did not return success."
}
Write-Host "  Prometheus query: OK"

Write-Host "Testing Grafana HTTP endpoint..." -ForegroundColor Cyan
$grafana = Invoke-WebRequest -Uri "http://localhost:3000/login" -UseBasicParsing -TimeoutSec 5
if ($grafana.StatusCode -ne 200) {
    throw "Grafana login page did not return HTTP 200."
}
Write-Host "  Grafana: OK"

Write-Host "Observability smoke test passed." -ForegroundColor Green
