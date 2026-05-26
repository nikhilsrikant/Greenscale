$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectRoot

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
}

Write-Host "Starting GreenScale with Prometheus and Grafana..." -ForegroundColor Cyan
docker compose up -d --build

Write-Host "Waiting for orchestrator health endpoint..." -ForegroundColor Cyan
$healthy = $false
for ($i = 1; $i -le 40; $i++) {
    try {
        $health = Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get -TimeoutSec 2
        if ($health.status -eq "ok") {
            $healthy = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}

if (-not $healthy) {
    throw "GreenScale orchestrator did not become healthy. Run 'docker compose logs orchestrator' for details."
}

Write-Host "Generating sample traffic for dashboards..." -ForegroundColor Cyan
$scenarios = @(
    @{ workload = "text-classify"; body = @{ payload = @{ text = "cloud computing carbon-aware scheduling" }; slo_ms = 450; priority = "latency-critical" } },
    @{ workload = "text-classify"; body = @{ payload = @{ text = "batch analytics green workload" }; slo_ms = 1200; priority = "delay-tolerant" } },
    @{ workload = "ml-inference"; body = @{ payload = @{ samples = 512 }; slo_ms = 300; priority = "latency-critical" } },
    @{ workload = "image-compress"; body = @{ payload = @{ image_id = "synthetic-cloud-image" }; slo_ms = 800; priority = "balanced" } },
    @{ workload = "stream-aggregate"; body = @{ payload = @{ values = @(1, 4, 9, 16, 25, 36) }; slo_ms = 600; priority = "balanced" } }
)

for ($round = 1; $round -le 8; $round++) {
    foreach ($scenario in $scenarios) {
        $json = $scenario.body | ConvertTo-Json -Depth 20
        try {
            $null = Invoke-RestMethod `
                -Uri "http://localhost:8080/invoke/$($scenario.workload)" `
                -Method Post `
                -ContentType "application/json" `
                -Body $json `
                -TimeoutSec 10
        } catch {
            Write-Warning "Traffic request failed for $($scenario.workload): $($_.Exception.Message)"
        }
    }
}

Write-Host "Checking Prometheus target health..." -ForegroundColor Cyan
$query = [uri]::EscapeDataString("up")
try {
    $prom = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=$query" -Method Get -TimeoutSec 5
    $prom.data.result | ForEach-Object {
        $instance = $_.metric.instance
        $job = $_.metric.job
        $value = $_.value[1]
        Write-Host "  $job / $instance = $value"
    }
} catch {
    Write-Warning "Prometheus is still starting. Open http://localhost:9090/targets in about 30 seconds."
}

Write-Host ""
Write-Host "Milestone 3 is running." -ForegroundColor Green
Write-Host "Orchestrator: http://localhost:8080/health"
Write-Host "Prometheus:   http://localhost:9090/targets"
Write-Host "Grafana:      http://localhost:3000"
Write-Host "Grafana login: admin / greenscale"
Write-Host "Dashboard: GreenScale / GreenScale Cloud Observability"
