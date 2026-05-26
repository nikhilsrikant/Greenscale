<#
Open local port-forwards for the Kubernetes deployment.
This opens three PowerShell windows:
- Orchestrator: http://localhost:8080
- Prometheus:   http://localhost:9090
- Grafana:      http://localhost:3000
#>

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Start-PortForwardWindow {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Command
    )

    $escaped = $Command.Replace('"', '\"')
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='$Title'; $escaped"
}

Write-Host "Starting Kubernetes port-forwards..." -ForegroundColor Cyan
Start-PortForwardWindow -Title "GreenScale Orchestrator :8080" -Command "kubectl -n greenscale port-forward svc/greenscale-orchestrator 8080:8080"
Start-PortForwardWindow -Title "GreenScale Prometheus :9090" -Command "kubectl -n greenscale port-forward svc/prometheus 9090:9090"
Start-PortForwardWindow -Title "GreenScale Grafana :3000" -Command "kubectl -n greenscale port-forward svc/grafana 3000:3000"

Write-Host "" 
Write-Host "After the three windows show 'Forwarding from', open:" -ForegroundColor Green
Write-Host "  Orchestrator: http://localhost:8080/health"
Write-Host "  Prometheus:   http://localhost:9090/targets"
Write-Host "  Grafana:      http://localhost:3000"
Write-Host "" 
Write-Host "Grafana login: admin / greenscale" -ForegroundColor Green
